
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()
import warnings

tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.FATAL)  # DEBUG,ERROR,FATAL,INFO,WARN
warnings.filterwarnings('ignore')

def weight_variable(shape):
    initial = tf.random.truncated_normal(shape, stddev=0.1)
    return tf.Variable(initial)


def bias_variable(shape):
    initial = tf.constant(0.0, shape=shape)
    return tf.Variable(initial)


def max_pool(input_tensor, kernel_size, stride, padding):
    pooling_result = tf.nn.max_pool2d(input_tensor, ksize=[1,kernel_size, kernel_size, 1], strides=[1, stride, stride, 1], padding=padding)
    return pooling_result


def leaky_relu(x, alpha):
    x = tf.dtypes.cast(x, tf.float32)
    return tf.maximum(alpha * x, x)


input_height = 224
input_width = 224
n_input_imgs = 1  # batch size 1, for single input inference
relu_alpha = 0.1
# Input placeholders for x and y
with tf.compat.v1.name_scope('input'):
    x = tf.compat.v1.placeholder(tf.float32, shape=[n_input_imgs, input_height, input_width, 3])
    labels = tf.compat.v1.placeholder(tf.float32, shape=[n_input_imgs, 1])



# Convolution
conv_input = []
conv_input_shape = []
conv_weights = []
conv_output = []
conv_output_shape = []

#Bias
bias_input = []
bias_weights = []
bias_output = []

#Relu
relu_output = []

# Pool
pool_output = []
pool_output_shape = []

network_structure = [[3, 3,   3,  16, relu_alpha],  # conv 3x3 kernel, 3 input maps, 16 output maps, relu with leaky value
                     [2, 2],                        # max pool size 2, stride 2
                     [3, 3,  16,  32, relu_alpha],
                     [2, 2],
                     [3, 3,  32,  64, relu_alpha],
                     [2, 2],
                     [3, 3,  64, 128, relu_alpha],
                     [2, 2],
                     [3, 3, 128, 128, relu_alpha],
                     [2, 2],
                     [3, 3, 128, 256, relu_alpha],
                     [1, 1, 256, 125]]

n_params = 0    # number of calculated weights, for tracking
layer = 0
while layer < len(network_structure):
    # print("Layer ", layer, "\n")
    if layer == 0:
        conv_input.append(x)
    else:
        conv_input.append(pool_output[-1])
    conv_input_shape.append(tf.shape(input=conv_input[-1])) # e.g. for layer 0: [1, 224, 224, 3]
    # print("perform conv: ")
    # print(network_structure[layer])
    conv_weights.append(weight_variable([network_structure[layer][0],network_structure[layer][1],
                                         network_structure[layer][2],network_structure[layer][3]]))
    # print(conv_input[-1])
    # print(conv_weights[-1])
    conv_output.append(tf.nn.conv2d(input=conv_input[-1], filters=conv_weights[-1], strides=[1, 1, 1, 1], padding='SAME'))
    conv_output_shape.append(tf.shape(input=conv_output[-1]))
    bias_input.append(conv_output[-1])
    bias_weights.append(bias_variable([network_structure[layer][3]]))
    bias_output.append(bias_input[-1] + bias_weights[-1])
    if len(network_structure[layer]) > 4:
        relu_output.append(leaky_relu(bias_output[-1], network_structure[layer][4]))
        # print("perform relu")
    else:
        relu_output.append(bias_output[-1])
    n_params += network_structure[layer][3] + \
                network_structure[layer][0] * network_structure[layer][1] * \
                network_structure[layer][2] * network_structure[layer][3]

    # print(relu_output[-1])
    # pooling layer?
    if len(network_structure) > layer+1:
        if len(network_structure[layer+1]) == 2:
            layer += 1
            pool_output.append(max_pool(relu_output[-1], kernel_size=network_structure[layer][0],
                                        stride=network_structure[layer][1], padding='VALID'))
            # print("perform pool: ")
            # print(network_structure[layer])
        else:
            pool_output.append(relu_output[-1])
    else:
        pool_output.append(relu_output[-1])
    pool_output_shape.append(tf.shape(input=pool_output[-1]))
    # print(pool_output[-1])
    layer += 1
    # print(n_params)


print('Total number of params = {}'.format(n_params))
