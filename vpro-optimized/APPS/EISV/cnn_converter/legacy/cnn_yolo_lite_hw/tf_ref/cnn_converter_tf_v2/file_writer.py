import math
import sys
import re
import os
import numpy as np
from termcolor import colored
from datetime import datetime
from bit_width import bit_width



class WEIGHT_FILE_WRITER:
    def __init__(self, header="./includes/yolo_lite_tf2.h", source="./sources/weights/yolo_lite_tf2.cpp"):
        self.WEIGHTS_HEADER_FILE_NAME = header
        self.WEIGHTS_SOURCE_FILE_NAME = source

        np.set_printoptions(linewidth=90)
        np.set_printoptions(suppress=True)
        np.set_printoptions(formatter={'float': '{: 0.16f}'.format})
        np.set_printoptions(threshold=sys.maxsize)  # print without truncation

        self.now = datetime.now()  # current date and time
        self.date_time = self.now.strftime("%m/%d/%Y, %H:%M:%S")

        self.WEIGHTS_HEADER_FILE = open(self.WEIGHTS_HEADER_FILE_NAME, 'w', newline='\n')
        self.WEIGHTS_SOURCE_FILE = open(self.WEIGHTS_SOURCE_FILE_NAME, 'w', newline='\n')

        print("#ifndef CNN_WEIGHTS", file=self.WEIGHTS_HEADER_FILE)
        print("#define CNN_WEIGHTS", file=self.WEIGHTS_HEADER_FILE)
        print("", file=self.WEIGHTS_HEADER_FILE)
        print("#include <stdint.h>", file=self.WEIGHTS_HEADER_FILE)
#        print("#include \"testlayer.h\"", file=self.WEIGHTS_HEADER_FILE)
        print("", file=self.WEIGHTS_HEADER_FILE)
        print("// Creation: ", self.date_time, file=self.WEIGHTS_HEADER_FILE)
        print("", file=self.WEIGHTS_HEADER_FILE)

        includefile = os.path.normpath(self.WEIGHTS_HEADER_FILE_NAME)
        includefile = includefile.split(os.sep)[-1]
        print('#include "' + includefile + '"', file=self.WEIGHTS_SOURCE_FILE)
        print("", file=self.WEIGHTS_SOURCE_FILE)
        print("// Creation: ", self.date_time, file=self.WEIGHTS_SOURCE_FILE)
        print("", file=self.WEIGHTS_SOURCE_FILE)


    def setKernel(self, filter_kernel):
        self.kernel = filter_kernel

    def setBias(self, bias_values):
        self.bias = bias_values

    def addLayer(self, nr, input_fpf, data_input_fpf, coeff_fpf, data_coeff_fpf, conv_result_shift_right, bias_fpf, data_bias_fpf, bias_load_shift_right, store_fpf, data_store_fpf, bias_store_shift_right, name):

        # kernel are in # NHWC ? more NHWC!
        # input is in # NHWC? more NHWC!

        data_coeff_fpf = np.transpose(data_coeff_fpf, (2, 0, 1, 3))   # reorder h and w and n?
        data_coeff_fpf = np.reshape(data_coeff_fpf, (data_coeff_fpf.shape[0], data_coeff_fpf.shape[1]*data_coeff_fpf.shape[2], data_coeff_fpf.shape[3]))   # merge h and w
        
        data_coeff_fpf = np.transpose(data_coeff_fpf, (2, 0, 1))   # reorder to n c h*w
        
        data_coeff_fpf = np.transpose(data_coeff_fpf, (1, 0, 2))   # reorder to in out kernel²
        
        # HEADER
        print('namespace ', name, "{\n", file=self.WEIGHTS_HEADER_FILE)
        print('\t// Input-Shape:', data_input_fpf.shape, "\n\t//           FPF: ", str(input_fpf[0]) + "." + str(input_fpf[1]),
              file=self.WEIGHTS_HEADER_FILE)
        print('\t//           Data Range: Min = ' + str(np.min(data_input_fpf)) + ", Max = " + str(np.max(data_input_fpf))+ "\n\t//",
              file=self.WEIGHTS_HEADER_FILE)
        print('\t// Weight-Shape:', data_coeff_fpf.shape, "\n\t//           FPF: ",
              str(coeff_fpf[0]) + "." + str(coeff_fpf[1]), file=self.WEIGHTS_HEADER_FILE)
        print('\t//           Data Range: Min = ' + str(np.min(data_coeff_fpf)) + ", Max = " + str(np.max(data_coeff_fpf))+ "\n\t//",
              file=self.WEIGHTS_HEADER_FILE)
        print('\t// Bias-Shape:', data_bias_fpf.shape, "\n\t//           FPF: ", str(bias_fpf[0]) + "." + str(bias_fpf[1]),
              file=self.WEIGHTS_HEADER_FILE)
        print('\t//           Data Range: Min = ' + str(np.min(data_bias_fpf)) + ", Max = " + str(np.max(data_bias_fpf))+ "\n\t//",
              file=self.WEIGHTS_HEADER_FILE)
        print('\t// Conv-Relu Output-Shape:', data_store_fpf.shape, "\n\t//           FPF: ",
              str(store_fpf[0]) + "." + str(store_fpf[1]), file=self.WEIGHTS_HEADER_FILE)
        print('\t//           Data Range: Min = ' + str(np.min(data_store_fpf)) + ", Max = " + str(np.max(data_store_fpf))+ "\n\t//",
              file=self.WEIGHTS_HEADER_FILE)


        print("", file=self.WEIGHTS_HEADER_FILE)
        print("\textern int16_t conv_result_shift_right;", "\t// = ", conv_result_shift_right, file=self.WEIGHTS_HEADER_FILE)
        print("\textern int16_t bias_store_shift_right;", "\t// = ", bias_store_shift_right, file=self.WEIGHTS_HEADER_FILE)
        print("\textern int16_t bias_load_shift_right;", "\t// = ", bias_load_shift_right, file=self.WEIGHTS_HEADER_FILE)
        print("", file=self.WEIGHTS_HEADER_FILE)
        print("\textern int16_t result_fractional_bit;", file=self.WEIGHTS_HEADER_FILE)
        print("\textern int16_t result_integer_bit;", file=self.WEIGHTS_HEADER_FILE)
        # if relu == 6:
        #     print("\textern int16_t relu_6;", "\t// = ", input_shift, file=self.WEIGHTS_HEADER_FILE)
        print("", file=self.WEIGHTS_HEADER_FILE)
        print("\t//Data Format is (# in channels)(# out channels)(# kernel W*H)", file=self.WEIGHTS_HEADER_FILE)
        print("\t//Coeff fpf: ", str(coeff_fpf[0]) + "." + str(coeff_fpf[1]), file=self.WEIGHTS_HEADER_FILE)
        print("\textern int16_t",
              "conv_weights[%i][%i][%i];" % (data_coeff_fpf.shape[0], data_coeff_fpf.shape[1], data_coeff_fpf.shape[2] ),
              file=self.WEIGHTS_HEADER_FILE)
        print("", file=self.WEIGHTS_HEADER_FILE)
        print("\t//Data Format is (# out channels)", file=self.WEIGHTS_HEADER_FILE)
        print("\t//Bias fpf: ", str(bias_fpf[0]) + "." + str(bias_fpf[1]), file=self.WEIGHTS_HEADER_FILE)
        print("\textern int16_t bias[%i];\n" % (data_bias_fpf.shape[0]), file=self.WEIGHTS_HEADER_FILE)
        print('}; // namespace ', name, "\n", file=self.WEIGHTS_HEADER_FILE)

        # SOURCE
        print('namespace ', name, "{\n", file=self.WEIGHTS_SOURCE_FILE)
        print('\t// Name:', name, file=self.WEIGHTS_SOURCE_FILE)
        print('\t// Input-Shape:', data_input_fpf.shape, "FPF: ", str(input_fpf[0]) + "." + str(input_fpf[1]),
              file=self.WEIGHTS_SOURCE_FILE)
        print('\t// Weight-Shape:', data_coeff_fpf.shape, "FPF: ",
              str(coeff_fpf[0]) + "." + str(coeff_fpf[1]), file=self.WEIGHTS_SOURCE_FILE)
        print('\t// Bias-Shape:', data_bias_fpf.shape, "FPF: ", str(bias_fpf[0]) + "." + str(bias_fpf[1]),
              file=self.WEIGHTS_SOURCE_FILE)
        print('\t// Conv-Relu Output-Shape:', data_store_fpf.shape, "FPF: ",
              str(store_fpf[0]) + "." + str(store_fpf[1]), file=self.WEIGHTS_SOURCE_FILE)
        print("", file=self.WEIGHTS_SOURCE_FILE)
        #
        # Shift info to FILE
        #
        print("\n\tint16_t conv_result_shift_right", " = ", conv_result_shift_right, ";", file=self.WEIGHTS_SOURCE_FILE)
        print("\tint16_t bias_store_shift_right", " = ", bias_store_shift_right, ";", file=self.WEIGHTS_SOURCE_FILE)
        print("\tint16_t bias_load_shift_right", " = ", bias_load_shift_right, ";", file=self.WEIGHTS_SOURCE_FILE)

        print("\tint16_t result_fractional_bit", " = ", str(store_fpf[1]), ";", file=self.WEIGHTS_SOURCE_FILE)
        print("\tint16_t result_integer_bit", " = ", str(store_fpf[0]), ";", file=self.WEIGHTS_SOURCE_FILE)

        # COEFF to FILE
        #
        print("\n\t//Coeff fpf: ", str(coeff_fpf[0]), ".", str(coeff_fpf[1]), file=self.WEIGHTS_SOURCE_FILE)
        print("\tint16_t", "conv_weights[%i][%i][%i] =" %
              (data_coeff_fpf.shape[0], data_coeff_fpf.shape[1], data_coeff_fpf.shape[2] ), file=self.WEIGHTS_SOURCE_FILE)
        p0 = re.compile('(^|\n)')
        print(p0.sub(r'\1\t', np.array2string(data_coeff_fpf, separator=",").replace("[", "{").replace("]", "}")), ";",
              file=self.WEIGHTS_SOURCE_FILE)

        #
        # BIAS to FILE
        #
        print("\n\t//Bias fpf: ", str(bias_fpf[0]), ".", str(bias_fpf[1]), file=self.WEIGHTS_SOURCE_FILE)
        print("\tint16_t bias[%i] =" % (data_bias_fpf.shape[0]), file=self.WEIGHTS_SOURCE_FILE)
        p0 = re.compile('(^|\n)')
        print(p0.sub(r'\1\t', np.array2string(data_bias_fpf, separator=",").replace("[", "{").replace("]", "}")), ";",
              file=self.WEIGHTS_SOURCE_FILE)

        print('\n}; // namespace ', name, "\n", file=self.WEIGHTS_SOURCE_FILE)

        stride = math.ceil(data_input_fpf.shape[1] / data_store_fpf.shape[1])  # only in H Dim
        if math.ceil(data_input_fpf.shape[2] / data_store_fpf.shape[2]) != stride:
            print(colored("ERROR on stride. X and Y doesnt match!", "red"), stride, "!=",
                  math.ceil(data_input_fpf.shape[2] / data_store_fpf.shape[2]))

    def finish(self):
        print("", file=self.WEIGHTS_HEADER_FILE)
        print("#endif //CNN_WEIGHTS", file=self.WEIGHTS_HEADER_FILE)
        self.WEIGHTS_SOURCE_FILE.close()
        self.WEIGHTS_HEADER_FILE.close()


    def saveToFile(self, array, fname):
        # array = np.multiply(array, (1 << 14)).astype(np.int16)
        # array[:, :, :, 0]
        f = open(fname, "wb")
        f.write(array.flatten())
