import numpy as np
from scipy import signal
from scipy import misc
import tensorflow as tf
from termcolor import colored

from bit_width import bit_width

def conv(data_input, data_weight, data_bias, shift, outshift, s=(1, 1)):
    data_input = np.float64(data_input)     #NHWC
    data_weight = np.float64(data_weight)  #HWIO
    mac = tf.nn.conv2d(data_input, data_weight, [1, s[0], s[1], 1], "SAME")
    mac = tf.dtypes.cast(mac, tf.int64)
    # print("VPRO mac is: min: ", np.min(mac), " - max ", np.max(mac))
    # print("VPRO shift back by", shift)
    mac_shifted = tf.bitwise.right_shift(mac, shift)
    # print("VPRO mac_shifted is: min: ", np.min(mac_shifted), " - max ", np.max(mac_shifted))
    data_bias = np.int64(data_bias)
    bias = tf.nn.bias_add(mac_shifted, data_bias)
    # print("VPRO biased is: min: ", np.min(bias), " - max ", np.max(bias))
    mm = tf.bitwise.right_shift(bias, outshift)
    # print("VPRO outshifted is: min: ", np.min(mm), " - max ", np.max(mm))
    out = np.int32(mm)
    return out

# returns calculated array  NHWC
# in fix point format
def calc_fixp(name,
                data_input_fixp, data_weight_fixp, data_bias_fixp,  # fix point values
                conv_result_shift_right, bias_load_shift_right, bias_store_shift_right,
                relu=-0.1,  # 6 = RELU6, -0.1 = LEAKY
                maxpool=1,  # 1 = max pooling
                stride=1):

    # print("VPRO Bias is: min: ", np.min(data_bias_fixp), " - max ", np.max(data_bias_fixp))
    # print("VPRO Bias shift ", bias_load_shift_right)
    if bias_load_shift_right > 0:
        bias_load_shifted = np.right_shift(data_bias_fixp, bias_load_shift_right)
    else:
        bias_load_shifted = np.left_shift(data_bias_fixp, -bias_load_shift_right)
    # print("VPRO Bias is: min: ", np.min(bias_load_shifted), " - max ", np.max(bias_load_shifted))

    data_conv_bias_result = conv(data_input_fixp, data_weight_fixp, bias_load_shifted,
                                 conv_result_shift_right, bias_store_shift_right, (stride, stride))


    if maxpool == 1:
        data_conv_bias_result = tf.nn.max_pool(data_conv_bias_result, [1, 2, 2, 1], [1, 2, 2, 1], "SAME")
        # print("VPRO max_pool is: min: ", np.min(data_conv_bias_result), " - max ", np.max(data_conv_bias_result))

    if relu == -0.1:
        relu_input = np.int64(data_conv_bias_result)
        result = np.where(relu_input < 0, np.right_shift(relu_input * 26214, 18), relu_input)
        result = np.int32(result)
        # print("VPRO relued is: min: ", np.min(result), " - max ", np.max(result))
    else:
        result = data_conv_bias_result

    return result