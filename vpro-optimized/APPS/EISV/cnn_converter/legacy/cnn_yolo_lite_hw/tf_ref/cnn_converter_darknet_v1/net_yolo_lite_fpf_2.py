
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()
import warnings
import os
import sys
import argparse
import numpy as np

import subprocess
tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.FATAL)  # DEBUG,ERROR,FATAL,INFO,WARN
warnings.filterwarnings('ignore')


def input_args():

    parser = argparse.ArgumentParser(description='Dynamic Quantization of weights')
    parser.add_argument('--img_x', '-x', type=int, help='necessary arg, Input image width of network', required=True)
    parser.add_argument('--img_y', '-y', type=int, help='necessary arg, Input image height of network', required=True),
    parser.add_argument('--img', '-img', type=str, help='necessary arg, Input image path', required=True)
    parser.add_argument('--weights', '-wghts', type=str, help='necessary arg, xxx.weights file path', required=True)
    args = parser.parse_args()

    return args


args = input_args()
input_height = args.img_x  # 224
input_width = args.img_y  # 224
input_img_path = args.img  # ./data/dog.jpg
wghts_path = args.weights  # ./lib/yolo_files/yolo-lite.weights

print("Loading Net!\n")
print(input_height, "x", input_width, ": ", input_img_path, ", ", wghts_path)

# Input placeholders
n_input_imgs = 1  # batch size 1, for single input inference
with tf.compat.v1.name_scope('input'):
    x = tf.compat.v1.placeholder(tf.float32, shape=[n_input_imgs, input_height, input_width, 3])
    labels = tf.compat.v1.placeholder(tf.float32, shape=[n_input_imgs, 1])

# cw = subprocess.Popen('Python ./converter_wghts.py
#                      -x 224 -y 224 -img ./data/dog.jpg -wghts ./losib/yolo_files/yolo-lite.weights',
#                      shell=True, stdout=subprocess.PIPE)
# print(cw.wait())

#if not (os.path.exists('../data/dynamic_convfilter_fpf.dat') or os.path.exists('../data/dynamic_bias_fpf.dat')):
print('Warning: Please convert the weights to obtain "./data/dynamic_convfilter_fpf.dat"')
print('Warning: Please convert the weights to obtain "./data/dynamic_bias_fpf.dat"')
print('Enter into Subprocee: converter the weights ......')
# subprocess
proc = subprocess.Popen(['python3', './converter_wghts_2.py',
						  '-x', str(input_height), '-y', str(input_width), '-img',
						 str(input_img_path), '-wghts', str(wghts_path)])
print('############ Subprocess start ###################')
try:
	outs = proc.communicate(timeout=500)
except subprocess.TimeoutExpired:
	proc.kill()
	outs = proc.communicate()
# print(outs)
print('Exit code of subprocess:', proc.returncode)
print('############ Subprocess finished ###################')
dynamic_convfilter_fpf = np.fromfile('../../data/dynamic_convfilter_fpf.dat', dtype=np.int, sep=',')
dynamic_bias_fpf = np.fromfile('../../data/dynamic_bias_fpf.dat', dtype=np.int, sep=',')
    # sys.exit()
# else:
    # dynamic_convfilter_fpf = np.fromfile('../data/dynamic_convfilter_fpf.dat', dtype=np.int, sep=',')
    # dynamic_bias_fpf = np.fromfile('../data/dynamic_bias_fpf.dat', dtype=np.int, sep=',')


# dynamic_convfilter_fpf = [11,  8,  7,  7,  8,  8,  8]
# dynamic_bias_fpf = [6, 6, 5, 6, 7, 8, 6]


def weight_variable_fpf(shape, fpf):
    initial = tf.random.truncated_normal(shape, stddev=0.1)  # stddev: standard deviation
    out = tf.math.multiply(tf.Variable(initial), (2 ** fpf))
    out = tf.dtypes.cast(out, tf.int32)
    return out


def bias_variable_fpf(shape, fpf):
    initial = tf.constant(0.0, shape=shape)
    out = tf.math.multiply(tf.Variable(initial), 255)
    out = tf.math.multiply(out, (2 ** fpf))
    out = tf.dtypes.cast(out, tf.int32)
    return out


def conv2d_fpf(input_tensor, convfilter, stride, pad, dy_convfilter_fpf, dy_bias_fpf):
    # pad = 'VALID', which refers to no padding at all or 'SAME'
    # pad = 'SAME', which refers to stride = 1 and padding = 1
    x = tf.dtypes.cast(input_tensor, tf.float32)  # tf.nn.conv2d supports only float
    w = tf.dtypes.cast(convfilter, tf.float32)
    conv2d_result = tf.nn.conv2d(input=x, filters=w, strides=[stride, stride, stride, stride], padding=pad)
    conv2d_result = tf.dtypes.cast(conv2d_result, tf.int32)
    if dy_convfilter_fpf > dy_bias_fpf:  # fixed point format of convfilter greater than bias
        shift_ar = dy_convfilter_fpf - dy_bias_fpf  # shift right, arithmetic shift
        conv2d_result = tf.bitwise.right_shift(conv2d_result, shift_ar)
        conv2d_result = tf.dtypes.cast(conv2d_result, tf.int32)
    elif dy_bias_fpf == dy_convfilter_fpf:
         conv2d_result = tf.dtypes.cast(conv2d_result, tf.int32)
    else:
        shift_ar = dy_bias_fpf - dy_convfilter_fpf
        conv2d_result = tf.bitwise.left_shift(conv2d_result, shift_ar)
#        conv2d_result = tf.math.multiply(conv2d_result, tf.dtypes.cast(tf.constant(2 ** (dy_bias_fpf - dy_convfilter_fpf)), tf.int32))
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


def leaky_relu(x, alpha):
    x = tf.dtypes.cast(x, tf.float32)
    return tf.maximum(alpha * x, x)


def leaky_relu_fpf(x, alpha, alpha_fpf):
    x = tf.dtypes.cast(x, tf.int32)
    alpha_int = int(alpha * (2 ** alpha_fpf))
    relu_result = tf.maximum(x, 0) + tf.bitwise.right_shift((tf.minimum(x, 0) * alpha_int), alpha_fpf)
    relu_result = tf.dtypes.cast(relu_result, tf.int16)
    # print('ReLU Alpha {} with fpf {} = {}'.format(alpha, alpha_fpf, alpha_int))
    return relu_result  # int 16


n_bias = 7          # number of bias
n_kernel = 7        # number of convolution kernel
n_CONV = n_kernel   # number of 2d-convolution calculation
n_BIAS = n_bias     # number of bias addition calculation
n_RELU = 6          # number of relu (leaky or rect)
n_POOL = 5          # number of pooling (leaky or rect)


# list of weights
# convolution weights
w = []
for i in range(n_kernel):
    w.append(i)
# bias weights
b = []
for i in range(n_bias):
    b.append(i)

# list of computational steps
# result of convulution
conv2d_out = []
layer_out = []
for i in range(n_CONV):
    conv2d_out.append(i)
    layer_out.append(i)

# result of bias addition
biasadd_out = []
for i in range(n_BIAS):
    biasadd_out.append(i)
# result of relu
relu_out = []
for i in range(n_RELU):
    relu_out.append(i)
# results of pooling
pool_out = []
for i in range(n_POOL):
    pool_out.append(i)


# results(feature maps) before conv
fmaps2conv = []
for i in range(n_CONV):
    fmaps2conv.append(i)
# results(feature maps) before bias
fmaps2bias = []
for i in range(n_BIAS):
    fmaps2bias.append(i)


relu_alpha = 0.1  # Slope of the activation function at x < 0
alpha_fpf = 5
relu_alpha_fpf = []
for i in range(n_RELU):
    relu_alpha_fpf.append(alpha_fpf)


n_params = 0    # number of calculated weights, for tracking

# Layer[0]     16  3 x 3 / 1   224 x 224 x   3   ->   224 x 224 x  16
w[0] = weight_variable_fpf([3, 3, 3, 16], dynamic_convfilter_fpf[0])   # int16
b[0] = bias_variable_fpf([16], dynamic_bias_fpf[0])                      # int16
fmaps2conv[0] = x

conv2d_out[0] = conv2d_fpf(fmaps2conv[0], w[0], stride=1, pad='SAME',
                           dy_convfilter_fpf=dynamic_convfilter_fpf[0],
                           dy_bias_fpf=dynamic_bias_fpf[0])
biasadd_out[0] = biasadd_fpf(conv2d_out[0], b[0], dy_bias_fpf=dynamic_bias_fpf[0])
relu_out[0] = leaky_relu_fpf(biasadd_out[0], alpha=relu_alpha, alpha_fpf=relu_alpha_fpf[0])
# max          2 x 2 / 2   224 x 224 x  16   ->   112 x 112 x  16
pool_out[0] = max_pool(relu_out[0], size=2, stride=2, pad='VALID')
layer_out[0] = pool_out[0]

# update: statistics of the number of weights
n_params = 3*3*3*16 + 16*1
# n_params = conv_kernel_shape + n_biases
# n_params = con_kernel_shape + n_output_channels


# Layer[1]     32  3 x 3 / 1   112 x 112 x  16   ->   112 x 112 x  32
w[1] = weight_variable_fpf([3, 3, 16, 32], dynamic_convfilter_fpf[1])
b[1] = bias_variable_fpf([32], dynamic_bias_fpf[1])
fmaps2conv[1] = layer_out[0]

conv2d_out[1] = conv2d_fpf(fmaps2conv[1], w[1], stride=1, pad='SAME',
                           dy_convfilter_fpf=dynamic_convfilter_fpf[1],
                           dy_bias_fpf=dynamic_bias_fpf[1])
biasadd_out[1] = biasadd_fpf(conv2d_out[1], b[1], dy_bias_fpf=dynamic_bias_fpf[1])
relu_out[1] = leaky_relu_fpf(biasadd_out[1], alpha=relu_alpha, alpha_fpf=relu_alpha_fpf[1])
# max          2 x 2 / 2   112 x 112 x  32   ->   56 x 56 x  32
pool_out[1] = max_pool(relu_out[1], size=2, stride=2, pad='VALID')
layer_out[1] = pool_out[1]

# update: statistics of the number of weights
n_params = n_params + 3*3*16*32 + 32*4


# Layer[2]     64  3 x 3 / 1   56 x 56 x  32   ->   56 x 56 x 64
w[2] = weight_variable_fpf([3, 3, 32, 64], dynamic_convfilter_fpf[2])
b[2] = bias_variable_fpf([64], dynamic_bias_fpf[2])
fmaps2conv[2] = layer_out[1]
conv2d_out[2] = conv2d_fpf(fmaps2conv[2], w[2], stride=1, pad='SAME',
                           dy_convfilter_fpf=dynamic_convfilter_fpf[2],
                           dy_bias_fpf=dynamic_bias_fpf[2])
biasadd_out[2] = biasadd_fpf(conv2d_out[2], b[2], dy_bias_fpf=dynamic_bias_fpf[2])
relu_out[2] = leaky_relu_fpf(biasadd_out[2], alpha=relu_alpha, alpha_fpf=relu_alpha_fpf[2])
# max          2 x 2 / 2   56 x 56 x 64   ->    28 x 28 x  64
pool_out[2] = max_pool(relu_out[2], size=2, stride=2, pad='VALID')
layer_out[2] = pool_out[2]
# update: statistics of the number of weights
n_params = n_params + 3*3*32*64 + 64*1


#  Layer[3]    128  3 x 3 / 1    28 x 28 x  64   ->    28 x  28 x 128
w[3] = weight_variable_fpf([3, 3, 64, 128], dynamic_convfilter_fpf[3])
b[3] = bias_variable_fpf([128], dynamic_bias_fpf[3])
fmaps2conv[3] = layer_out[2]
conv2d_out[3] = conv2d_fpf(fmaps2conv[3], w[3], stride=1, pad='SAME',
                           dy_convfilter_fpf=dynamic_convfilter_fpf[3],
                           dy_bias_fpf=dynamic_bias_fpf[3])
biasadd_out[3] = biasadd_fpf(conv2d_out[3], b[3], dy_bias_fpf=dynamic_bias_fpf[3])
relu_out[3] = leaky_relu_fpf(biasadd_out[3], alpha=relu_alpha, alpha_fpf=relu_alpha_fpf[3])
# max          2 x 2 / 2    28 x  28 x 128   ->    14 x 14 x 128
pool_out[3] = max_pool(relu_out[3], size=2, stride=2, pad='VALID')
layer_out[3] = pool_out[3]
# update: statistics of the number of weights
n_params = n_params + 3*3*64*128 + 128*1


# Layer[4]    256  3 x 3 / 1    14 x 14 x 128   ->    14 x 14 x 128
w[4] = weight_variable_fpf([3, 3, 128, 128], dynamic_convfilter_fpf[4])
b[4] = bias_variable_fpf([128], dynamic_bias_fpf[4])
fmaps2conv[4] = layer_out[3]
conv2d_out[4] = conv2d_fpf(fmaps2conv[4], w[4], stride=1, pad='SAME',
                           dy_convfilter_fpf=dynamic_convfilter_fpf[4],
                           dy_bias_fpf=dynamic_bias_fpf[4])
biasadd_out[4] = biasadd_fpf(conv2d_out[4], b[4], dy_bias_fpf=dynamic_bias_fpf[4])
relu_out[4] = leaky_relu_fpf(biasadd_out[4], alpha=relu_alpha, alpha_fpf=relu_alpha_fpf[4])
# max          2 x 2 / 2    14 x 14 x 128   ->    7 x 7 x 128
pool_out[4] = max_pool(relu_out[4], size=2, stride=2, pad='VALID')
layer_out[4] = pool_out[4]
# update: statistics of the number of weights
n_params = n_params + 3*3*128*128 + 128*1


# Layer[5]   512  3 x 3 / 1    7 x 7 x 128   ->    7 x 7 x 256
w[5] = weight_variable_fpf([3, 3, 128, 256], dynamic_convfilter_fpf[5])
b[5] = bias_variable_fpf([256], dynamic_bias_fpf[5])
fmaps2conv[5] = layer_out[4]
conv2d_out[5] = conv2d_fpf(fmaps2conv[5], w[5], stride=1, pad='SAME',
                           dy_convfilter_fpf=dynamic_convfilter_fpf[5],
                           dy_bias_fpf=dynamic_bias_fpf[5])
biasadd_out[5] = biasadd_fpf(conv2d_out[5], b[5], dy_bias_fpf=dynamic_bias_fpf[5])
relu_out[5] = leaky_relu_fpf(biasadd_out[5], alpha=relu_alpha, alpha_fpf=relu_alpha_fpf[5])
layer_out[5] = relu_out[5]
# update: statistics of the number of weights
n_params = n_params + 3*3*128*256 + 256*1


# Layer[6]   125  1 x 1 / 1    7 x 7 x 256   ->    7 x 7 x 125
w[6] = weight_variable_fpf([1, 1, 256, 125], dynamic_convfilter_fpf[6])
b[6] = bias_variable_fpf([125], dynamic_bias_fpf[6])
fmaps2conv[6] = layer_out[5]
conv2d_out[6] = conv2d_fpf(fmaps2conv[6], w[6], stride=1, pad='SAME',
                           dy_convfilter_fpf=dynamic_convfilter_fpf[6],
                           dy_bias_fpf=dynamic_bias_fpf[1])
biasadd_out[6] = biasadd_fpf(conv2d_out[6], b[6], dy_bias_fpf=dynamic_bias_fpf[6])
layer_out[6] = biasadd_out[6]
# update: statistics of the number of weights
n_params = n_params + 1*1*1024*125 + 125*1

print('Total number of params = {}'.format(n_params))
