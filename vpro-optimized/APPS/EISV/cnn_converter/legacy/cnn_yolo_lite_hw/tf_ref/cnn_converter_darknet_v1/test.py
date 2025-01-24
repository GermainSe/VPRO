import math
import tensorflow as tf

def bits_width(a, b):

    if a > b:
        min_value = b
        max_value = a
    else:
        min_value = a
        max_value = b
    if min_value < 0 and abs(min_value) > abs(math.ceil(max_value)):
            min_value = math.floor(abs(min_value + 1))
            width = min_value.bit_length()
    else:
            max_value = math.ceil(abs(max_value))
            min_value = math.ceil(abs(min_value))
            width = max(max_value.bit_length(), min_value.bit_length())
    return width

def conv2d_fpf(input_tensor, convfilter, stride, pad, dy_convfilter_fpf, dy_bias_fpf):
    # pad = 'VALID', which refers to no padding at all or 'SAME'
    # pad = 'SAME', which refers to stride = 1 and padding = 1
    x = tf.dtypes.cast(input_tensor, tf.float32)  # tf.nn.conv2d supports only float
    w = tf.dtypes.cast(convfilter, tf.float32)
    conv2d_result = tf.nn.conv2d(x, w, strides=[stride, stride, stride, stride], padding=pad)
    conv2d_result = tf.dtypes.cast(conv2d_result, tf.int32)
    if dy_convfilter_fpf > dy_bias_fpf:  # fixed point format of convfilter greater than bias
        shift_ar = dy_convfilter_fpf - dy_bias_fpf  # shift right, arithmetic shift
        conv2d_result = tf.bitwise.right_shift(conv2d_result, shift_ar)
    else:
        conv2d_result = tf.math.multiply(x, tf.constant(2 ** (dy_bias_fpf - dy_convfilter_fpf)))
    conv2d_result = tf.dtypes.cast(conv2d_result, tf.int32)
    return conv2d_result  # int32


def biasadd_fpf(input_tensor, b, dy_bias_fpf):
    x = tf.dtypes.cast(input_tensor, tf.int32)
    b = tf.dtypes.cast(b, tf.int32)
    # the adjustment of input data for bias addition has been preformed in previous step of convolution
    # biasadd_result = tf.math.multiply(x, tf.constant(2 ** dy_bias_fpf)) + b
    biasadd_result = x + b
    biasadd_result = tf.bitwise.right_shift(biasadd_result, dy_bias_fpf)
    biasadd_result = tf.dtypes.cast(biasadd_result, tf.int16)
    return biasadd_result  # int16


def max_pool(input_tensor, size, stride, pad):
    pooling_result = tf.nn.max_pool2d(input_tensor, ksize=[1, size, size, 1],
                                      strides=[1, stride, stride, 1],
                                      padding=pad)
    return pooling_result


def leaky_relu_fpf(x, alpha, fpf):
    x = tf.dtypes.cast(x, tf.int32)
    alpha_fpf = int(alpha * (2 ** fpf))
    relu_result = tf.maximum(x, 0) + tf.bitwise.right_shift((tf.minimum(x, 0) * alpha_fpf), fpf)
    relu_result = tf.dtypes.cast(relu_result, tf.int16)
    print('alpha {} with fpf {} = {}'.format(alpha, fpf, alpha_fpf))
    return relu_result  # int 16


# test
"""""
test_in = tf.constant([100.0, -111111.1])
out_float = leaky_relu(test_in, relu_alpha)
out_int= leaky_relu_fpf(test_in, relu_alpha, relu_fpf[0])

with tf.Session() as session:
    print("Input of leaky ReLU:", test_in.eval())
    print("leaky_ReLU_float:", out_fpf.eval())
    print('leaky_ReLU_int:', out_int.eval())

"""""


x = tf.constant([[[[1, 1, 0], [1, 1, 1], [0, 0, 1]],
                [[1, 1, 0], [1, 1, 1], [0, 0, 1]],
                [[1, 1, 0], [1, 1, 1], [0, 0, 1]]]])
w = tf.constant([[[[1, 1, 0], [1, 1, 1], [0, 0, 1]],
                [[1, 1, 0], [1, 1, 1], [0, 0, 1]],
                [[1, 1, 0], [1, 1, 1], [0, 0, 1]]]])

conv_fpf = 3
x = tf.multiply(x, tf.constant(2 ** conv_fpf))
conv_out = conv2d_fpf(x, w, 1, "SAME", conv_fpf)
pool_out = max_pool(conv_out, size=2, stride=2, pad='VALID')

bias = 1024  # bias_org = 128
bias_fpf = 3

# out = biasadd_fpf(x, bias, bias_fpf)

with tf.Session() as sess:
    # print('bias add out = ', out.eval())
    print('conv 2d out = ', conv_out.eval())
    print(conv_out)
    print('pool_out=', pool_out.eval())
    print(pool_out)

"""""
l0 = bits_width(-128, 127)      # 7
l1 = bits_width(-127, 127)      # 7
l2 = bits_width(-127, 128)      # 8
l3 = bits_width(0, 255)         # 8
l4 = bits_width(-127.8, 127)    # 7
l5 = bits_width(-128, 127.1)    # 8
l6 = bits_width(-127.8, 127.1)  # 8
l7 = bits_width(-256, 255)      # 8
l8 = bits_width(-256, -128)     # 8

print(l0, l1, l2, l3, l4, l5, l6, l7, l8)
"""""


