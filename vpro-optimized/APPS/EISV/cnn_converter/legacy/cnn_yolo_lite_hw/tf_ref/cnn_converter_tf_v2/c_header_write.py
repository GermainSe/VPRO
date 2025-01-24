import math
import sys
import re
import os
import numpy as np
from termcolor import colored
from datetime import datetime
# own functions
from bit_width import bit_width
from verify_conv_bias_layer import verify
from verify_conv_bias_layer_fixp import verify_fixp

import cv2
# cv2.waitKey(0)

PRINT_FPF = True       # print fixp format steps to console?
WRITE_TO_FILE = False    # shift values, weights, bias, (large header file)...
VERIFY = True          # for BN & structure, using float
VERIFY_FIXP = True      # requires VERIFY, uses shift,... to get fixp results

if WRITE_TO_FILE:
    WEIGHTS_HEADER = '../includes/weights_mobilenet.h'
    WEIGHTS_SOURCE = '../sources/weights/mobilenet.cpp'
    WEIGHTS_HEADER_FILE = open(WEIGHTS_HEADER, 'w', newline='\n')
    WEIGHTS_SOURCE_FILE = open(WEIGHTS_SOURCE, 'w', newline='\n')

# WRITE_REFERENCE_DATA needs VERIFY (those data [incl BN] are written out)!
WRITE_REFERENCE_DATA = False # binary for later compare with VPRO results
WRITE_REFERENCE_DATA_DIR = "../../data/reference/"
reference_data_statistic_file_layer = open(WRITE_REFERENCE_DATA_DIR+"layer_properties.txt", "w")
reference_data_statistic_file_channels = open(WRITE_REFERENCE_DATA_DIR+"channel_properties.txt", "w")

# to create a chain of fixpoint data.
# error incrementes through convolutional layer chain!? (should be visible by this data chain)
last_output_fixp = [np.array([0])]
last_output_fixp_format = [(0,0)]

def init_weight_out():
    np.set_printoptions(linewidth=90)
    np.set_printoptions(suppress=True)
    np.set_printoptions(formatter={'float': '{: 0.16f}'.format})
    np.set_printoptions(threshold=sys.maxsize)  # print without truncation

    now = datetime.now() # current date and time
    date_time = now.strftime("%m/%d/%Y, %H:%M:%S")

    if WRITE_TO_FILE:
        print("#ifndef CNN_WEIGHTS", file=WEIGHTS_HEADER_FILE)
        print("#define CNN_WEIGHTS", file=WEIGHTS_HEADER_FILE)
        print("", file=WEIGHTS_HEADER_FILE)
        print("#include <stdint.h>", file=WEIGHTS_HEADER_FILE)
        print("", file=WEIGHTS_HEADER_FILE)
        print("// Creation: ", date_time, file=WEIGHTS_HEADER_FILE)
        print("", file=WEIGHTS_HEADER_FILE)

        print('#include "../'+WEIGHTS_HEADER+'"', file=WEIGHTS_SOURCE_FILE)
        print("", file=WEIGHTS_SOURCE_FILE)
        print("// Creation: ", date_time, file=WEIGHTS_SOURCE_FILE)
        print("", file=WEIGHTS_SOURCE_FILE)

    print("Creation: ", date_time, "\n", file=reference_data_statistic_file_layer)
    print("Creation: ", date_time, "\n", file=reference_data_statistic_file_channels)

def exit_weight_out():
    if WRITE_TO_FILE:
        print("", file=WEIGHTS_HEADER_FILE)
        print("#endif //CNN_WEIGHTS", file=WEIGHTS_HEADER_FILE)
        WEIGHTS_SOURCE_FILE.close()
        WEIGHTS_HEADER_FILE.close()
    reference_data_statistic_file_layer.close()
    reference_data_statistic_file_channels.close()


def write_weight_out(name, data_input, data_weight, data_bias, data_bn_output, data_relu_output,
                     bit_width_input, bit_width_weight, bit_width_bias, bit_width_conv_output, output_bitwidth_bn, bit_width_output,
                     depthwise = False, relu = 0, biasfinal = False, biasfinalIndex = -2):

    conv_params = data_weight.transpose((3, 2, 0, 1))
    shape = conv_params.shape
    conv_params = conv_params.reshape(shape[0], shape[1], shape[3] * shape[2])

    fraction_precision = 16 - bit_width_weight
    input_fractional_bit = 16 - bit_width_input

    if name == "Layer_20":
        bit_width_conv_output += 1
    elif name == "Layer_35":
        bit_width_conv_output += 2
    if name == "Layer_68":
        bit_width_conv_output += 2
    # if name == "Layer_68":
    #     bit_width_conv_output += 2
    # if name == "Layer_71":
    #     bit_width_conv_output += 3

    bit_width_conv_output = max(output_bitwidth_bn, bit_width_conv_output)    # even if wrong, the conv out should stay high
    result_fractional_bit_mac = max(input_fractional_bit, 0) + max(fraction_precision, 0) # simple mac of inputs

    result_fractional_bit = 24 - bit_width_conv_output
    conv_mac_shift = result_fractional_bit_mac - result_fractional_bit

    # prepare for biasing. if bias int_bit larger, shift more
    if 24 - bit_width_bias < result_fractional_bit:
        add_shift = (result_fractional_bit - (24 - bit_width_bias))
        conv_mac_shift += add_shift
        result_fractional_bit -= add_shift
        # print("\n\n################################### BIAS ADD SHIFT:", add_shift, "\n\n")

    conv_params = (conv_params * (2 ** fraction_precision)).astype(np.int64)
    # check for overflow (should not appear due to previous min/max detection)
    for d in conv_params.flatten():
        if d > 2 ** (16-1) - 1 or d < -2 ** (16-1):
            print(colored("Coeff Overflow!", "red"), d)
    conv_params = conv_params.astype(np.int16)

    if bit_width_weight + fraction_precision > 16:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! coeff to large! >16\n", "red"))
    if bit_width_input + input_fractional_bit > 16:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! input to large! >16\n", "red"))
    if output_bitwidth_bn + result_fractional_bit > 24:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! conv result to large! >24\n", "red"))

    if PRINT_FPF:
        print("Coeff fpf:      \t\t", bit_width_weight, ".", fraction_precision)
        print("Input fpf:      \t\t", bit_width_input, ".", input_fractional_bit)
        print("Conv Result fpf:\t\t", bit_width_conv_output, ".", result_fractional_bit_mac, " >> ", conv_mac_shift,
              " \t[MAC accu shift] => \t", bit_width_conv_output, ".", result_fractional_bit, "\t[! reality is bigger due to BN. Good: bias result includes BN]")

    bias_fraction_precision = 16 - bit_width_bias
    input_shift = bias_fraction_precision - result_fractional_bit # to be same fpf as Conv Result (after MAC shift)
    if relu != 0:
        bit_width_output_relu = bit_width(0, relu)
        if bit_width_output > bit_width_output_relu: # if smalle it is ok; e.g. values in conv result smaller 6 only...
            print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! relu result not as reference\n", "red"), "Relu:", bit_width_output_relu, "Reference:", bit_width_output)
    output_shift = (bit_width_output + bias_fraction_precision - input_shift) - 16

    bias_params = (data_bias * (2 ** bias_fraction_precision)).astype(np.int64)
    # check for overflow (should not appear due to previous min/max detection)
    for d in bias_params.flatten():
        if d > 2 ** (16-1) - 1 or d < -2 ** (16-1):
            print(colored("Bias Overflow!", "red"), d)
    bias_params = bias_params.astype(np.int16)

    if output_bitwidth_bn + (bias_fraction_precision - input_shift) > 24:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! bias RF result to large! >24\n", "red"))
    if bit_width_bias + bias_fraction_precision > 16:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! bias input to large! >16\n", "red"))
    if bit_width_bias + bias_fraction_precision - input_shift > 24:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! bias input shifted to large! >24\n", "red"))
    if output_bitwidth_bn + bias_fraction_precision - input_shift > 24:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! final to large! >24\n", "red"))
    if bit_width_output + bias_fraction_precision - input_shift - output_shift > 16:
        print(colored("\n\tERROR !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! final to large! >16\n", "red"))

    if PRINT_FPF:
        print("Bias fpf:             \t", bit_width_bias, ".", bias_fraction_precision, " >> ", input_shift,
              " \t[bias input shift] => \t", bit_width_bias, ".", bias_fraction_precision - input_shift)
        print("Bias Result fpf:      \t", output_bitwidth_bn, ".", bias_fraction_precision - input_shift)
        print("After Relu + Pool fpf:\t", bit_width_output, ".", bias_fraction_precision - input_shift, " >> ", output_shift,
              " \t[out store shift] => \t", bit_width_output, ".", bias_fraction_precision - input_shift - output_shift)

    if WRITE_TO_FILE:
    # HEADER

        print('namespace ', name.split("/")[0].split(":")[0], "{", file=WEIGHTS_HEADER_FILE)
        print('\t// Input-Shape:', data_input.shape, "FPF: ", str(bit_width_input)+"."+str(16-bit_width_input), file=WEIGHTS_HEADER_FILE)
        print('\t// Weight-Shape:', data_weight.shape, "FPF: ", str(bit_width_weight)+"."+str(16-bit_width_weight), file=WEIGHTS_HEADER_FILE)
        print('\t// Bias-Shape:', data_bias.shape, "FPF: ", str(bit_width_bias)+"."+str(16-bit_width_bias), file=WEIGHTS_HEADER_FILE)
        print('\t// BN/Relu Output-Shape:', data_bn_output.shape, "FPF: ", str(bit_width_output)+"."+str(16-bit_width_output), file=WEIGHTS_HEADER_FILE)
        print("", file=WEIGHTS_HEADER_FILE)
        print("\textern int16_t conv_result_shift_right;", "\t// = ", conv_mac_shift, file=WEIGHTS_HEADER_FILE)
        print("\textern int16_t bias_store_shift_right;", "\t// = ", output_shift, file=WEIGHTS_HEADER_FILE)
        print("\textern int16_t bias_load_shift_right;", "\t// = ", input_shift, file=WEIGHTS_HEADER_FILE)
        print("", file=WEIGHTS_HEADER_FILE)
        print("\textern int16_t result_fractional_bit;", file=WEIGHTS_HEADER_FILE)
        print("\textern int16_t result_integer_bit;", file=WEIGHTS_HEADER_FILE)
        # if relu == 6:
        #     print("\textern int16_t relu_6;", "\t// = ", input_shift, file=WEIGHTS_HEADER_FILE)
        print("", file=WEIGHTS_HEADER_FILE)
        print("\t//Coeff fpf: ", bit_width_weight, ".", fraction_precision, file=WEIGHTS_HEADER_FILE)
        print("\textern int16_t", "conv_weights[%i][%i][%i];" %(conv_params.shape[0], conv_params.shape[1], conv_params.shape[2]), file=WEIGHTS_HEADER_FILE)
        print("", file=WEIGHTS_HEADER_FILE)
        print("\t//Bias fpf: ", bit_width_bias, ".", bias_fraction_precision, file=WEIGHTS_HEADER_FILE)
        print("\textern int16_t bias[%i];" % (bias_params.shape[0]), file=WEIGHTS_HEADER_FILE)
        print('}; // namespace', name.split("/")[0].split(":")[0], file=WEIGHTS_HEADER_FILE)

    # SOURCE
        print('namespace ', name.split("/")[0].split(":")[0], "{", file=WEIGHTS_SOURCE_FILE)
        print('\t// Name:', name, file=WEIGHTS_SOURCE_FILE)
        print('\t// Reduced Name:', name.split("/")[0].split(":")[0], file=WEIGHTS_SOURCE_FILE)
        print('\t// Input-Shape:', data_input.shape, "FPF: ", str(bit_width_input)+"."+str(16-bit_width_input), file=WEIGHTS_SOURCE_FILE)
        print('\t// Weight-Shape:', data_weight.shape, "FPF: ", str(bit_width_weight)+"."+str(16-bit_width_weight), file=WEIGHTS_SOURCE_FILE)
        print('\t// Bias-Shape:', data_bias.shape, "FPF: ", str(bit_width_bias)+"."+str(16-bit_width_bias), file=WEIGHTS_SOURCE_FILE)
        print('\t// BN/Relu Output-Shape:', data_bn_output.shape, "FPF: ", str(bit_width_output)+"."+str(16-bit_width_output), file=WEIGHTS_SOURCE_FILE)
        print('\t// Relu Output-Shape:', data_relu_output.shape, file=WEIGHTS_SOURCE_FILE)

        #
        # Shift info to FILE
        #
        print("\n\tint16_t conv_result_shift_right", " = ", conv_mac_shift, ";", file=WEIGHTS_SOURCE_FILE)
        print("\tint16_t bias_store_shift_right", " = ", output_shift, ";", file=WEIGHTS_SOURCE_FILE)
        print("\tint16_t bias_load_shift_right", " = ", input_shift, ";", file=WEIGHTS_SOURCE_FILE)

        print("\tint16_t result_fractional_bit", " = ", (16-bit_width_output), ";",file=WEIGHTS_SOURCE_FILE)
        print("\tint16_t result_integer_bit", " = ", bit_width_output, ";",file=WEIGHTS_SOURCE_FILE)

        # if relu == 6:
        #     print("\tint16_t relu_6 = ",(6 << (16-bit_width_output)),";", "\t// = ", input_shift, file=WEIGHTS_SOURCE_FILE)
        #
        # COEFF to FILE
        #
        print("\n\t//Coeff fpf: ", bit_width_weight, ".", fraction_precision, file=WEIGHTS_SOURCE_FILE)
        print("\tint16_t", "conv_weights[%i][%i][%i] =" %
              (conv_params.shape[0], conv_params.shape[1], conv_params.shape[2]), file=WEIGHTS_SOURCE_FILE)
        p0 = re.compile('(^|\n)')
        print(p0.sub(r'\1\t', np.array2string(conv_params, separator=",").replace("[", "{").replace("]", "}")), ";", file=WEIGHTS_SOURCE_FILE)

        #
        # BIAS to FILE
        #
        print("\n\t//Bias fpf: ", bit_width_bias, ".", bias_fraction_precision, file=WEIGHTS_SOURCE_FILE)
        print("\tint16_t bias[%i] =" % (bias_params.shape[0]), file=WEIGHTS_SOURCE_FILE)
        p0 = re.compile('(^|\n)')
        print(p0.sub(r'\1\t', np.array2string(bias_params, separator=",").replace("[", "{").replace("]", "}")), ";", file=WEIGHTS_SOURCE_FILE)

        print('}; // namespace', name.split("/")[0].split(":")[0], file=WEIGHTS_SOURCE_FILE)

    stride = math.ceil(data_input.shape[1] / data_bn_output.shape[1]) # only in H Dim
    if math.ceil(data_input.shape[2] / data_bn_output.shape[2]) != stride:
        print(colored("ERROR on stride. X and Y doesnt match!", "red"), stride, "!=", math.ceil(data_input.shape[2] / data_bn_output.shape[2]))

    # get Result for bias/conv
    if VERIFY:
        verify_result = verify(name, data_input, data_weight, data_bias, data_bn_output, stride, depthwise=depthwise)
        if VERIFY_FIXP:
            global last_output_fixp, last_output_fixp_format
            conv_result_shift_right=conv_mac_shift
            bias_load_shift_right=input_shift
            bias_store_shift_right=output_shift

            input_fpf=(bit_width_input, 16 - bit_width_input)
            coeff_fpf=(bit_width_weight, 16 - bit_width_weight)
            bias_fpf=(bit_width_bias, 16 - bit_width_bias)
            result_fractional_bit = bias_fpf[1] - bias_store_shift_right - bias_load_shift_right
            result_fpf=(16 - result_fractional_bit, result_fractional_bit)

            data_input_fixp = np.int32(data_input * np.left_shift(1, input_fpf[1]))

            index = biasfinalIndex + 1

            if last_output_fixp[index].shape != data_input_fixp.shape:
                print(colored("ERROR!", "yellow"), "Could not use previous (Shape:", last_output_fixp[index].shape,
                      ") out as in (Shape:", data_input_fixp.shape, ")!! @name:", name)
                # exit(0)
            elif last_output_fixp_format[index] != input_fpf:
                print(colored("ERROR!", "yellow"), "Could not use previous out (Format:", last_output_fixp_format[index],
                      ") as in (Format:", input_fpf, ")!! @name:", name)
                # exit(0)
            else:
                data_input_fixp = last_output_fixp[index]

            data_weight_fixp = np.int32(data_weight * np.left_shift(1, coeff_fpf[1]))
            data_bias_fixp = np.int32(data_bias * np.left_shift(1, bias_fpf[1]))
            data_bias_fixp = np.int32(data_bias_fixp * np.left_shift(1, -bias_load_shift_right)) # two step to cut last bits (as fixp does on vpro)
            data_output_fixp = np.int32(data_bn_output * np.left_shift(1, result_fractional_bit))

            verify_fixp_result = verify_fixp(name,
                                             data_input_fixp, data_weight_fixp, data_bias_fixp, data_output_fixp,
                                             stride, depthwise,
                                             input_fpf, coeff_fpf, bias_fpf, result_fpf,
                                             conv_result_shift_right, bias_load_shift_right, bias_store_shift_right, relu
                                             )
            if relu == 6:
                verify_fixp_result_relu = np.float32(np.maximum(np.minimum(verify_fixp_result, (6 << result_fractional_bit)), 0))
            else:
                verify_fixp_result_relu = np.float32(verify_fixp_result)
            last_output_fixp.append(np.int32(verify_fixp_result_relu))

            try:
                verify_fixp_result_relu_float= verify_fixp_result_relu / (1 << result_fpf[1])
                relu_format = bit_width(np.min(verify_fixp_result_relu_float), np.max(verify_fixp_result_relu_float))
                last_output_fixp_format.append((relu_format, 16-relu_format))
            except:
                print("Could not find fixpoint format of Relu result...")
            # print("\n###################\n###################Saved LAST OUTPUT!\n###################")

            if bit_width(np.min(verify_fixp_result_relu), np.max(verify_fixp_result_relu)) > 16:
                print(colored("[Error] on save of Relu'ed Layer. More than 16-bit in fix point number!", "red"))

            verify_fixp_result = np.float32(verify_fixp_result) / (1 << result_fpf[1])
            # print(verify_fixp_result[:, 0:2, 0:2, 0])
            # print(data_bn_output[:, 0:2, 0:2, 0])

            try:
                verify_result_width = bit_width(np.min(verify_fixp_result), np.max(verify_fixp_result))
            except:
                print(colored("ERROR on verify BN CONV Fixp!", "red"))
                return False
            if verify_result_width != output_bitwidth_bn:
                print(colored("ERROR on verify BN CONV! FIXPOINT", "red"), "Verify Result takes", verify_result_width, "instead references", output_bitwidth_bn, "bit")
                print(name)
                print("Wrong Range: ",np.min(verify_fixp_result), "-",np.max(verify_fixp_result))
                print("Correct Range: ",np.min(data_bn_output), "-",np.max(data_bn_output))
                return False

        try:
            verify_result_width = bit_width(np.min(verify_result), np.max(verify_result))
        except:
            print(colored("ERROR on verify BN CONV!", "red"))
            return False
        if verify_result_width != output_bitwidth_bn:
            print(colored("ERROR on verify BN CONV!", "red"), "Verify Result takes", verify_result_width, "instead references", output_bitwidth_bn, "bit")
            return False
        if WRITE_REFERENCE_DATA:
            if relu == 6:
                verify_result = np.minimum(6, np.maximum(0, verify_result))
            # NHWC
            print(name + ", " + str(verify_result.shape[1]) + "x" + str(verify_result.shape[2]) +
                  " , Channels: " + str(verify_result.shape[3]) + (" (Relu6)" if relu == 6 else "") + "",
                  file=reference_data_statistic_file_channels)
            for c in range(verify_result.shape[3]):
                array = verify_result[0,:,:,c]
                try:
                    os.mkdir(WRITE_REFERENCE_DATA_DIR+name+"/")
                except OSError:
                    pass
                with open(WRITE_REFERENCE_DATA_DIR+name+"/channel_"+str(c)+".bin", "w") as f:
                    array.astype('float32').tofile(f)
                print("\tChannel: " + str(c), file=reference_data_statistic_file_channels, end="")
                print("\tMin: " + str(np.min(array)) + "\tMax: " + str(np.max(array)) + "",
                      file=reference_data_statistic_file_channels)
            print(name+", "+str(verify_result.shape[1])+"x"+str(verify_result.shape[2])+
                  " , Channels: "+str(verify_result.shape[3])+(" (Relu6)" if relu == 6 else "")+"",
                  file=reference_data_statistic_file_layer)
            print("\tMin: " + str(np.min(verify_result)) + "\t Max: " + str(np.max(verify_result))+ "\n",
                  file=reference_data_statistic_file_layer)
    return True


def overwrite_verify_last_output():
    global last_output_fixp, last_output_fixp_format
    last_output_fixp.append(np.array([0]))
    last_output_fixp_format.append((0,0))

def set_verify_last_output(array, format = (0,0)):
    global last_output_fixp, last_output_fixp_format
    print("Set LastOut to (input): ", array.shape, "\tRange:", np.min(array), "-", np.max(array), "\tFormat:", format)
    last_output_fixp.append(array)
    last_output_fixp_format.append(format)

def verify_last_output_residual(first, second):
    global last_output_fixp, last_output_fixp_format
    first += 1
    second += 1
    # print("RESIDUAL VERIFY:...")
    print("In 0: ", first, last_output_fixp[first].shape, "\tRange:", np.min(last_output_fixp[first]), "-", np.max(last_output_fixp[first]), "\tFormat:", last_output_fixp_format[first],
          "=", np.float32(np.min(last_output_fixp[first])) / (1<<last_output_fixp_format[first][1]), " - ", np.float32(np.max(last_output_fixp[first])) / (1<<last_output_fixp_format[first][1]))
    print("In 1: ", second, last_output_fixp[second].shape, "\tRange:", np.min(last_output_fixp[second]), "-", np.max(last_output_fixp[second]), "\tFormat:", last_output_fixp_format[second],
          "=", np.float32(np.min(last_output_fixp[second])) / (1<<last_output_fixp_format[second][1]), " - ", np.float32(np.max(last_output_fixp[second])) / (1<<last_output_fixp_format[second][1]))

    # for high precision, use higher fractional format to add
    higher_fractional_bits = max(last_output_fixp_format[second][1], last_output_fixp_format[first][1])

    # shift (upon load) left to be in this format
    first_left_shift = max(higher_fractional_bits - last_output_fixp_format[first][1], 0)
    second_left_shift = max(higher_fractional_bits - last_output_fixp_format[second][1], 0)

    print("To be in .",higher_fractional_bits, "fixp format:")
    print("first_left_shift", first_left_shift)
    print("second_left_shift", second_left_shift)

    result = np.left_shift(last_output_fixp[first], first_left_shift) + np.left_shift(last_output_fixp[second], second_left_shift)

    result_bit = bit_width(np.min(result), np.max(result))
    result_bit_shift = max(result_bit - 16, 0)
    result = np.right_shift(result, result_bit_shift)
    print("result_right_shift:", result_bit_shift)

    last_output_fixp.append(result)
    last_output_fixp_format.append((16-(higher_fractional_bits-result_bit_shift), higher_fractional_bits-result_bit_shift))

    print("Result: ", result.shape, "\tRange:", np.min(result), "-", np.max(result), "\tFormat:", last_output_fixp_format[-1])

    if bit_width(np.min(result), np.max(result)) > 16:
        print(colored("ERROR! OVERFLOW after add (Residual)!", "red"))
        exit(0)

    return (first_left_shift, second_left_shift, result_bit_shift)