# TensorFlow 1.14.0

#!/b
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()
import numpy as np
import cv2
import warnings
import sys
import math
import argparse
import os

# network define and weights loading utilizing TensorFlow
import net_yolo_lite_2
import weights_loader_yolo_lite_2
import binary_detection_2

# yolov2_tiny network
# import net_yolov2_tiny
# import weights_loader_yolov2_tiny

warnings.filterwarnings('ignore')
os.environ['TF_CPP_MIN_LOG_LEVEL'] = '3'
'''''
0 = all messages are logged (default behavior)
1 = INFO messages are not printed
2 = INFO and WARNING messages are not printed
3 = INFO, WARNING, and ERROR messages are not printed
'''


# resize and split image ---> rgb
def tf_preprocessing(input_img_path, input_height, input_width):

    input_img = cv2.imread(input_img_path)                   # OpenCV reading order B,G,R
    input_img = cv2.cvtColor(input_img, cv2.COLOR_BGR2RGB)   # OpenCV reading order R,G,B

    # Resize the image and convert to array of float32
    # shape = CHW
    resized_img = cv2.resize(input_img, (input_height, input_width), interpolation=cv2.INTER_CUBIC)

    # split to RGB channels

    # ------------------------------------------------------------ #
    # --------------- input image process for TF ----------------- #
    # ------------------------------------------------------------ #

    img_data = np.array(resized_img, dtype='f')

    # Normalization [0,255] -> [0,1]
    img_data -= img_data.min()
    img_data /= img_data.max()
    # print("input image ranges in between ", img_data.min(), " and ", img_data.max())

    # Add the dimension relative to the batch size N
    # shape = NCHW
    image_array = np.expand_dims(img_data, axis=0)  # Add batch dimension

    return image_array


# Inference utilizing TensorFlow
def tf_inference(input_width, input_height, input_img_path, tf_wghts_path, out_node):
    # Definition of the session for TensorFlow
    # Check for an existing checkpoint
    # Load the weights for TensorFlow
    # Definition of the paths of weights for TF
    #
    # Load Weights/Bias from wghts file or from saved session
    # calls: weights_loader_yolo_lite.load:
    #
    sess = tf.compat.v1.InteractiveSession()
    tf.compat.v1.global_variables_initializer().run()
    # print('Looking for a checkpoint...')
    saver = tf.compat.v1.train.Saver()
    _ = weights_loader_yolo_lite_2.load(sess, tf_wghts_path, ckpt_folder_path = './ckpt_yolo_lite/', saver=saver)

    # get input image
    preprocessed_image = tf_preprocessing(input_img_path, input_height, input_width)

    # pass input into the network defined in net_yolo_lite_2.py
    predictions = sess.run(out_node, feed_dict={net_yolo_lite_2.x: preprocessed_image})

    # print("tf inference of node ", out_node)
    return predictions


# Returns the number of bits necessary to represent an integer in binary, 2-complement format
def bit_width(a, b):
    if a > b:
        min_value = b
        max_value = a
    else:
        min_value = a
        max_value = b

    i = 0
    while max_neg_nint[i] > min_value or max_pos_nint[i] < max_value:
        i+=1

    #value = max(abs(min_value), abs(max_value)+1)
    #width = int(math.ceil(math.log2(value))+1)
    # print("min: ", min_value, ", max: ", max_value, " -> req bit width: ", width)
    return i

max_precision = 16
# maximal number with only fraction bits
max_fractions = []
for i in range(max_precision+1):
    if i == 0:
        max_fractions.append(0)
        continue
    max_fractions.append(max_fractions[i-1]+1/(2**i))

# maximal pos number with only integer bits
max_pos = []
for i in range(max_precision+1):
    max_pos.append(2**(i-1)-1)

# maximal neg number with only integer bits
max_neg = []
for i in range(max_precision+1):
    max_neg.append(-2**(i-1))

max_pos_nint = []
for i in range(max_precision+1):
    max_pos_nint.append(max_pos[i] + max_fractions[max_precision-i])

max_neg_nint = max_neg

print("Fixpoint Format and related Min-/Max-values:")
for i in range(max_precision+1):
    print("fpf", i, ".", (max_precision-i), ": \t[min: ", max_neg_nint[i], ", \t max: ", max_pos_nint[i], "\t]" )


def print_begin(input_width, input_height, input_img_path, tf_wghts_path, nodes):
    # 
    tf_predictions = tf_inference(input_width, input_height, input_img_path, tf_wghts_path, nodes[0])
    print(tf_predictions[0,0,:])
        
# calculation of bits width range of intermediate results (nodes) (feature maps or calculation steps defined in net)
def range_log(input_width, input_height, input_img_path, tf_wghts_path, nodes):
    # inspect the value range of each operation outputs
    bit_width_fmaps = []
    bit_width_fmaps_min = []
    bit_width_fmaps_max = []
    for i in range(len(nodes)):
        tf_predictions = tf_inference(input_width, input_height, input_img_path, tf_wghts_path, nodes[i])
        # tf_predictions = tf_predictions.astype(int)
        min_value = tf_predictions.flatten().min()
        bit_width_fmaps_min.append(min_value)
        max_value = tf_predictions.flatten().max()
        bit_width_fmaps_max.append(max_value)
        bits = bit_width(min_value, max_value)  # round up
        bit_width_fmaps.append(bits)

    print("min (float):              ", bit_width_fmaps_min)
    print("max (float):              ", bit_width_fmaps_max)
    for i in range(len(bit_width_fmaps)):
        bit_width_fmaps_min[i] = int(bit_width_fmaps_min[i] * (2**(16-bit_width_fmaps[i])))
        bit_width_fmaps_max[i] = int(bit_width_fmaps_max[i] * (2**(16-bit_width_fmaps[i])))
    print("on vpro: (using fpf) min: ", bit_width_fmaps_min)
    print("on vpro: (using fpf) max: ", bit_width_fmaps_max, "\n")
    return bit_width_fmaps

# #Conv
# conv_input = []
# conv_input_shape = []
# conv_weights = []
# conv_output = []
# conv_output_shape = []
#
# #Bias
# bias_input = []
# bias_weights = []
# bias_output = []
#
# #Relu
# relu_output = []
#
# # Pool
# pool_output = []
# pool_output_shape = []

# weights conversion .weights ---> .h
# static quantization with given maximal fpf
def weights2h_max(input_width, input_height, input_img_path, wghts_path):

    print("\n\n\nFmap maximal bit widths (input of conv)")
    bit_width_conv_input = range_log(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.conv_input)
    print(bit_width_conv_input)

    print("Fmap maximal bit widths (coeff of conv)")
    bit_width_weights = range_log(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.conv_weights)    
    print(bit_width_weights)
#    print_begin(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.conv_weights)

    print("Fmap maximal bit widths (input of bias)")
    bit_width_bias_input = range_log(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.bias_input)
    print(bit_width_bias_input)

    print("maximal bit width of bias's")
    bit_width_bias = range_log(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.bias_weights)
    print(bit_width_bias)

    print("Fmap maximal bit widths (output of bias)")
    bit_width_bias_output = range_log(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.bias_output)
    print(bit_width_bias_output)

    print("Fmap maximal bit widths (after relu+pool)")
    bit_width_final = range_log(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.pool_output)
    print(bit_width_final)
#    print_begin(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.pool_output)

    # print setting
    np.set_printoptions(linewidth=90)
    np.set_printoptions(suppress=True)
    np.set_printoptions(formatter={'float': '{: 0.16f}'.format})
    np.set_printoptions(threshold=sys.maxsize)  # print without truncation

    # conv weights: hwcn - > nchw (tf --> vpro(similar with caffe))
    wght_path = '../sources/weights/tmp'
    if not os.path.exists(wght_path):
        os.makedirs(wght_path)
        print('Make dir: {}'.format(wght_path))

    wght_tmp = wght_path + '/yolo_lite_tmp_static.cpp'
    wght_out = wght_path + '/yolo_lite_static.cpp'

    conv_input_int_precision = []
    conv_input_frac_precision = []
    conv_int_precision = []
    conv_frac_precision = []
    conv_result_int_precision = []
    conv_result_frac_precision = []
    conv_result_shift = []
    bias_store_shift_right = []
    bias_load_shift_right = []
    bias_input_int_precision = []
    bias_input_frac_precision = []
    bias_int_precision = []
    bias_frac_precision = []
    bias_result_int_precision = []
    bias_result_frac_precision = []

    with open(wght_tmp, 'w', newline='\n') as f:
        print("#include \"../../includes/weights16.h\"\n\n", file=f)
        for i in range(len(net_yolo_lite_2.conv_weights)):
            print("\n>> Analyse (Conv) Layer ", i)

            ##########
            ##### CONV
            ##########
            conv_params = tf_inference(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.conv_weights[i])
            conv_params = conv_params.transpose((3, 2, 0, 1))
            shape = conv_params.shape
            conv_params = conv_params.reshape(shape[0], shape[1], shape[3] * shape[2])

            max_conv_value = max(abs(conv_params.flatten()))
            int_precision = bit_width(0, max_conv_value)
            fraction_precision = 16 - int_precision

            # check for overflow (should not appear due to previous min/max detection)
            conv_params = (conv_params * (2 ** fraction_precision)).astype(np.int64)
            for d in conv_params.flatten():
                if d > 2 ** 16 -1 or d < -2 ** 16:
                    print("Coeff Overflow!", d)
            conv_params = conv_params.astype(np.int16)

            input_integer_bit = bit_width_conv_input[i]
            input_fractional_bit = 16 - input_integer_bit

            result_integer_bit = bit_width_bias_input[i]
            result_fractional_bit_mac = max(input_fractional_bit,0) + max(fraction_precision, 0)

            result_shift = result_fractional_bit_mac - (24 - result_integer_bit)
            result_fractional_bit = result_fractional_bit_mac - result_shift

            if int_precision+fraction_precision > 16:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! coeff to large! >16\n")

            if input_integer_bit+input_fractional_bit > 16:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! input to large! >16\n")

            if result_integer_bit+result_fractional_bit > 24:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! conv result to large! >24\n")

            print("Coeff fpf:       \t", int_precision, ".", fraction_precision)
            print("Input fpf:       \t", input_integer_bit, ".", input_fractional_bit)
            print("Conv Result fpf: \t", result_integer_bit, ".", result_fractional_bit_mac, " >> ", result_shift, " \t[MAC accu shift] => \t", result_integer_bit, ".", result_fractional_bit)

            # save to file
            conv_input_int_precision.append(input_integer_bit)
            conv_input_frac_precision.append(input_fractional_bit)
            conv_int_precision.append(int_precision)
            conv_frac_precision.append(fraction_precision)
            conv_result_int_precision.append(result_integer_bit)
            conv_result_frac_precision.append(result_fractional_bit)
            conv_result_shift.append(result_shift)
            print("//Coeff fpf: ", int_precision, ".", fraction_precision, file = f)
            print("int16_t conv%i[%i][%i][%i] =" % (i,  conv_params.shape[0], conv_params.shape[1],
                                                        conv_params.shape[2]), file=f)
            print(repr(conv_params), file=f)
            #print ("Conv coeffs saved ", conv_params.min(), " - ", conv_params.max())

            ##########
            ##### BIAS
            ##########
            bias_params = tf_inference(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.bias_weights[i])
            max_bias_value = max(abs(bias_params.flatten()))
            # print("max bias: ", max(bias_params.flatten()))
            # print("min bias: ", min(bias_params.flatten()))
            int_precision = bit_width(0, max_bias_value)
            fraction_precision = 16 - int_precision

            # check for overflow (should not appear due to previous min/max detection)
            bias_params = (bias_params * (2 ** fraction_precision)).astype(np.int64)
            for d in bias_params.flatten():
                if d > 2 ** 16 -1 or d < -2 ** 16:
                    print("Bias Overflow!", d)
            bias_params = bias_params.astype(np.int16)

            input_integer_bit = bit_width_bias_input[i]
            input_fractional_bit = result_fractional_bit
            # print("Bias input fpf: ", input_integer_bit, ".", input_fractional_bit) # same as result of conv fpf

            input_shift = fraction_precision - result_fractional_bit
            output_shift = (bit_width_final[i]+fraction_precision - input_shift)-16

            if bit_width_bias_output[i]+(fraction_precision - input_shift) > 24:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! bias result to large! >24\n")

            if int_precision+fraction_precision > 16:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! bias to large! >16\n")

            if int_precision+fraction_precision - input_shift > 24:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! bias to large! >24\n")

            if bit_width_final[i]+fraction_precision - input_shift > 24:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! final to large! >24\n")

            if bit_width_final[i]+fraction_precision - input_shift - output_shift > 24:
                print("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! final to large! >16\n")

            print("Bias fpf:             \t", int_precision, ".", fraction_precision, " >> ", input_shift, " \t[bias input shift] => \t", int_precision, ".", fraction_precision - input_shift)
            print("Bias Result fpf:      \t", bit_width_bias_output[i], ".", fraction_precision - input_shift)
            print("After Relu + Pool fpf:\t", bit_width_final[i], ".", fraction_precision - input_shift, " >> ", output_shift, " \t[out store shift] => \t", bit_width_final[i], ".", fraction_precision - input_shift - output_shift)

            # save shifts, ... to file [later]
            bias_store_shift_right.append(output_shift)
            bias_load_shift_right.append(input_shift)
            bias_input_int_precision.append(input_integer_bit)
            bias_input_frac_precision.append(input_fractional_bit)
            bias_int_precision.append(int_precision)
            bias_frac_precision.append(fraction_precision)
            bias_result_int_precision.append(bit_width_bias_output[i])
            bias_result_frac_precision.append(fraction_precision - input_shift)

            print("//Bias fpf: ", int_precision, ".", fraction_precision, file = f)
            print("int16_t bias%i[%i] =" % (i, bias_params.shape[0]), file=f)
            print(repr(bias_params), file=f)

        print("int16_t conv_result_shift_right[",len(net_yolo_lite_2.conv_weights),"] = \narray(", conv_result_shift, ";", file=f)
        # print("int16_t conv_input_int_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", conv_input_int_precision, ";", file=f)
        # print("int16_t conv_input_frac_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", conv_input_frac_precision, ";", file=f)
        # print("int16_t conv_int_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", conv_int_precision, ";", file=f)
        # print("int16_t conv_frac_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", conv_frac_precision, ";", file=f)
        # print("int16_t conv_result_int_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", conv_result_int_precision, ";", file=f)
        # print("int16_t conv_result_frac_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", conv_result_frac_precision, ";", file=f)
        print("int16_t bias_store_shift_right[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_store_shift_right, ";", file=f)
        print("int16_t bias_load_shift_right[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_load_shift_right, ";", file=f)
        # print("int16_t bias_input_int_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_input_int_precision, ";", file=f)
        # print("int16_t bias_input_frac_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_input_frac_precision, ";", file=f)
        # print("int16_t bias_int_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_int_precision, ";", file=f)
        # print("int16_t bias_frac_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_frac_precision, ";", file=f)
        # print("int16_t bias_result_int_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_result_int_precision, ";", file=f)
        # print("int16_t bias_result_frac_precision[",len(net_yolo_lite_2.conv_weights),"] = \narray(", bias_result_frac_precision, ";", file=f)

    # Transform python array format into C array format
    f1 = open(wght_tmp, 'r')
    f2 = open(wght_out, 'w+')
    line = f1.readlines()
    for i in range(0, len(line)):
        s = line[i]
        if s.startswith('//'):
            f2.write(line[i].replace("Temporal", "Final"))
        else:
            if s.startswith('array') or s.startswith(' ') or s.startswith('//'):
                    f2.write(line[i].replace("Temporal", "Final").replace("[", "{").replace("]", "}")
                             .replace("array(", "      ").replace(", dtype=int16)", ";").replace(")", "")
                             .replace("dtype=int16", "").replace("}}},", "}}};"))
            else:
                f2.write(line[i])
    f1.close()
    f2.close()
    print("Static Quantization and Conversion of Weights (.weights ---> .h) finished")
    print('Please check: {}'.format(wght_out))

def input_args():
    parser = argparse.ArgumentParser(description='Dynamic Quantization of weights')
    parser.add_argument('--img_x', '-x', type=int, help='necessary arg, Input image width of network', required=True)
    parser.add_argument('--img_y', '-y', type=int, help='necessary arg, Input image height of network', required=True),
    parser.add_argument('--img', '-img', type=str, help='necessary arg, Input image path', required=True)
    parser.add_argument('--weights', '-wghts', type=str, help='necessary arg, xxx.weights file path', required=True)
    args = parser.parse_args()
    return args

def main(_):
    #  python3 converter_wghts.py -x 224 -y 224 -img ../data/test_img.png -wghts ../lib/yolo_files/yolo-lite.weights
    args = input_args()
    input_height = args.img_x           # 224
    input_width = args.img_y            # 224
    input_img_path = args.img           # ./data/dog.jpg
    wghts_path = args.weights           # ./lib/yolo_files/yolo-lite.weights

    # ------------------------------------------------------------ #
    # ----------------------   quantization   -------------------- #
    # ---------------------- .weights ---> .h -------------------- #
    # ------------------------------------------------------------ #
    weights2h_max(input_width, input_height, input_img_path, wghts_path)

    # ------------------------------------------------------------ #
    # --------------------   save output channels  --------------- #
    # ---------------------- ../data/tf_ref_float/binary/...  ---- #
    # ------------------------------------------------------------ #
    # get final results
    output = tf_inference(input_width, input_height, input_img_path, wghts_path, net_yolo_lite_2.pool_output)
    layer_number = len(output) - 1
    output = np.array(output[layer_number])
    output = np.reshape(output,(7, 7, 125))

    # check results in image
    img = binary_detection_2.postprocessing(output, input_img_path, 0.5, 0.3, input_height, input_width)
    cv2.imwrite("../data/tf_float_ref.png", img)

    # save binary
    from pathlib import Path
    Path("../data/tf_ref_float/binary/Layer_"+str(layer_number)+"/").mkdir(parents=True, exist_ok=True)
    out_fraction_bits = 16 - bit_width(output.min(), output.max())
    print("saving as int with ", out_fraction_bits, " fractional bits")
    output = np.transpose(output,[2,0,1])
    channel_number = 0
    print("min: ", np.min(output), " max: ", np.max(output), "\n\n\n\n\n")
    for c in output:
        (c * 2**(out_fraction_bits)).astype('int16').byteswap().tofile("../data/tf_ref_float/binary/Layer_"+str(layer_number)+"/tf_rf_7x7_"+str(channel_number)+".bin")
        channel_number += 1

    # reload
    tf_ref_root_path = '../../data/tf_ref_float/binary/Layer_'
    tf_out_bin_path = tf_ref_root_path + str(layer_number) + '/tf_rf_7x7_'
    output_reload = binary_detection_2.binary_inference(tf_out_bin_path, 7, 7, channel_number)

    # check results in image
    output_reload = np.reshape(output_reload,(7, 7, 125))
    output_reload = output_reload.astype('float')
    output_reload = output_reload / (2**out_fraction_bits)
    img = binary_detection_2.postprocessing(output_reload, input_img_path, 0.5, 0.3, input_height, input_width)
    cv2.imwrite("../data/tf_float_reload_ref.png", img)

if __name__ == '__main__':
    try:
        input_args()
    except Exception as e:
        print(e)
    tf.compat.v1.app.run(main=main)
