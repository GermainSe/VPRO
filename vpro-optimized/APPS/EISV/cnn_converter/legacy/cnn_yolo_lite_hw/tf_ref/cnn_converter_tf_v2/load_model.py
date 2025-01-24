import tensorflow as tf
try:
    print(tf.__version__)
except:
    pass

import numpy as np
import cv2
import time

# own functions from this folder
from termcolor import colored
from bit_width import bit_width
from script_print_functions import print_formats
from fixpoint_cnn_functions import calc_fixp
from postprocessing import postprocessing
from file_writer import *

# TF files
GRAPH_WEIGHTS = 'YOLO_LITE/tiny-yolov2-trial3-noBatch.weights'
GRAPH_LABELS  = 'YOLO_LITE/voc.names'

INPUT_IMAGE = "../../data/image_in.png"

# print messages of script
PRINT_FORMATS = True    # fpf analysis print?

WRITE_WEIGHTS_FILE = True
from pathlib import Path
Path("../../sources/weights/").mkdir(parents=True, exist_ok=True)
WEIGHTS_SOURCE_FILE_NAME = "../../sources/weights/yolo_lite_tf2.cpp"
WEIGHTS_HEADER_FILE_NAME = "../../includes/yolo_lite_tf2.h"

WRITE_INPUT_FILE_BINARY = WRITE_WEIGHTS_FILE
INPUT_FILE_NAME = "../../data/input" # _<i>.bin

# to generate fpf graph, quantize functions are used
# kernel and bias in MM (max 16-bit)
setting_fpf_kernel = 14
setting_fpf_bias = setting_fpf_kernel
# input in MM (max 16-bit)
setting_fpf_input = 14
# result of convolution (bias) in RF (max 24-bit)
setting_fpf_conv = 22
# result in MM (max 16-bit)
setting_fpf_output = 14

# on fixp generation the result is compared to float result
# this treshold creates corresponding warnings
MAX_ERROR_FLOAT_VS_FIXP = 10

###
# YOLO LITE (Darknet) specific load function
# reads .weights file and parses coefficient arrays to specified shape
###
def load_weights(weigths, biases, file_name):
    """Reshapes and loads official pretrained Yolo weights.
    Args:
        weigths: weights array to be assigned.
        biases: biases array to be assigned.
        file_name: A name of a file containing weights.
    Returns:
        A list of assign operations.
    """
    with open(file_name, "rb") as f:
        loadedData = np.fromfile(f, dtype=np.float32)
        loadedData = loadedData[4:]

        print("Len of read file. ", len(loadedData))
        loadedW = []
        loadedB = []
        ptr = 0
        for w, b in zip(weigths, biases):
            num_params = b.shape[0]
            shape = b.shape
            loadedB.append(loadedData[ptr:ptr + num_params].reshape(shape))
            ptr += num_params
            #print("Got ", num_params, "Biases")

            num_params = w.shape[0] * w.shape[1] * w.shape[2] * w.shape[3]
            shape = w.shape
            loadedW.append(loadedData[ptr:ptr + num_params].reshape(shape))

            # DarkNet conv_weights are serialized Caffe-style: (out_dim, in_dim, height, width)
            # We would like to set these to Tensorflow order: (height, width, in_dim, out_dim)
            # or:
            # nchw - > hwcn
            # kernel_weights = kernel_weights.transpose((3, 2, 0, 1))
            loadedW[-1] = np.reshape(loadedW[-1], (shape[3], shape[2], shape[0], shape[1]), order='C')
            loadedW[-1] = np.transpose(loadedW[-1], [2, 3, 1, 0])

            ptr += num_params
            #print("Got ", num_params, "Weights")
        print("Loaded ", ptr, "items (Bias + Conv Weights)")
    return (loadedW, loadedB)


def get_fpf(array, max_size = 16):
    """Determines the fpf for a given array
    Args:
        array: the data (python's float/double)
        max_size: limits the fractional bit length (fixed point format)
    Returns:
        A touple of (integer, fractional) - bits
    """
    minv = np.min(array)
    maxv = np.max(array)
    width = bit_width(minv, maxv)
    return (width, max_size - width)


def float_to_fpf(array, fpf):
    """Converts a given array to a given fixed point format
    Args:
        array: the data (python's float/double)
        fpf: A touple of fixed point format (integer, fractional) - bits
    Returns:
        The converted array as np.int32
    """
    # if fpf[0] + fpf[1] == 16:
    #     print("Converting float to 16-bit fpf")
    # if fpf[0] + fpf[1] == 24:
    #     print("Converting float to 24-bit fpf")
    return np.int32(array * np.left_shift(1, fpf[1]))

def fpf_to_float(array, fpf):
    """Converts a given array in fixed point format back to np.float32
    Args:
        array: the data (np.int32 or similar)
        fpf: A touple of fixed point format (integer, fractional) - bits
    Returns:
        The converted array as np.float32
    """
    return np.divide(np.float32(array), np.left_shift(1, fpf[1]))

def quantize(array, width):
    """Converts a given array to fixed point format limited by the specified width
    Args:
        array: the data (np.float32 or similar)
        width: maximum fixed point bits
    Returns:
        The converted array as np.float32 (Float!)
    """
    fpf = get_fpf(array, width)
    data_fpf = float_to_fpf(array, fpf)
    return fpf_to_float(data_fpf, fpf)  # continue with fixpoint values

if __name__ == '__main__':
    if WRITE_WEIGHTS_FILE:
        writer = WEIGHT_FILE_WRITER(source=WEIGHTS_SOURCE_FILE_NAME, header=WEIGHTS_HEADER_FILE_NAME)

    # Create YOLO LITE Graph
    _LEAKY_RELU = 0.1

    # initialize coefficient arrays
    filter_kernel = []
    filter_kernel.append(np.zeros(shape=(3,3,3,16)))
    filter_kernel.append(np.zeros(shape=(3,3,16,32)))
    filter_kernel.append(np.zeros(shape=(3,3,32,64)))
    filter_kernel.append(np.zeros(shape=(3,3,64,128)))
    filter_kernel.append(np.zeros(shape=(3,3,128,128)))
    filter_kernel.append(np.zeros(shape=(3,3,128,256)))
    filter_kernel.append(np.zeros(shape=(1,1,256,125)))

    bias_values = []
    bias_values.append(np.zeros(shape=(16,)))
    bias_values.append(np.zeros(shape=(32,)))
    bias_values.append(np.zeros(shape=(64,)))
    bias_values.append(np.zeros(shape=(128,)))
    bias_values.append(np.zeros(shape=(128,)))
    bias_values.append(np.zeros(shape=(256,)))
    bias_values.append(np.zeros(shape=(125,)))

    # load coefficients from .weights file
    (filter_kernel, bias_values) = load_weights(filter_kernel, bias_values, GRAPH_WEIGHTS)

    # load input image
    print("Reading INPUT")
    inpImg = cv2.imread(INPUT_IMAGE)
    image_bgr = cv2.cvtColor(inpImg, cv2.COLOR_RGB2BGR)
    image_resized = cv2.resize(image_bgr, (224,224), interpolation=cv2.INTER_CUBIC)
    image_np_expanded = np.expand_dims(image_resized, axis=0)
    image_np_expanded = np.array(image_np_expanded, dtype='f')
    image_np_expanded -= np.min(image_np_expanded)  # 0 to max
    image_np_expanded /= np.max(image_np_expanded)  # 0 to 1
    # image_np_expanded *= 255  # 0 to 255
    # image_np_expanded *= 2  # 0 to 2
    # image_np_expanded -= 1  # -1 to 1
    print("Input Shape: ", image_np_expanded.shape)
    print("Input Range: ", np.min(image_np_expanded),"-", np.max(image_np_expanded))

    #############
    ### FLOAT Inference
    #############
    print("CREATING Float GRAPH")
    inputs = [image_np_expanded]

    # Layers 0-4 (index)
    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[0], padding='SAME', strides=[1, 1, 1, 1], name="C1"))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[0]))
    inputs.append(tf.nn.max_pool(inputs[-1], ksize=2, strides=2, padding="SAME", name="M1"))
    inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU))

    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[1], padding='SAME', strides=[1, 1, 1, 1], name="C2"))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[1]))
    inputs.append(tf.nn.max_pool(inputs[-1], ksize=2, strides=2, padding="SAME", name="M2"))
    inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU))

    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[2], padding='SAME', strides=[1, 1, 1, 1], name="C3"))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[2]))
    inputs.append(tf.nn.max_pool(inputs[-1], ksize=2, strides=2, padding="SAME", name="M3"))
    inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU))

    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[3], padding='SAME', strides=[1, 1, 1, 1], name="C4"))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[3]))
    inputs.append(tf.nn.max_pool(inputs[-1], ksize=2, strides=2, padding="SAME", name="M4"))
    inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU))

    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[4], padding='SAME', strides=[1, 1, 1, 1], name="C5"))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[4]))
    inputs.append(tf.nn.max_pool(inputs[-1], ksize=2, strides=2, padding="SAME", name="M5"))
    inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU))

    # no pool in 5. Layer (index)
    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[5], padding='SAME', strides=[1, 1, 1, 1], name="C6"))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[5]))
    inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU))

    # no relu no pool in 6. Layer (index)
    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[6], padding='SAME', strides=[1, 1, 1, 1], name="C7"))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[6]))

    # Result
    print(inputs[-1].shape)
    result_float = inputs[-1]

    # perform post processing on array of float (7x7x125)
    print("PERFORMING POST PROCESSING (Float)")
    result = result_float
    print("Result DType: ", result.dtype)
    print("Result Shape: ", result.shape)
    print("Result Min: ", np.min(result), ", max:", np.max(result))

    image_out = postprocessing(result, INPUT_IMAGE, 0.5, 0.3, 224, 224)
    cv2.imshow("Result Float", image_out)
    cv2.waitKey(500) # wait 500ms

    #############
    ### Fix Point Analysis + Inference
    #############
    print("CREATING Fixpoint GRAPH")
    # continue with fixpoint values of previous loaded kernels/bias/input

    for i in range(0, 6):
        filter_kernel[i] = quantize(filter_kernel[i], setting_fpf_kernel)
    for i in range(0, 6):
        bias_values[i] = quantize(bias_values[i], setting_fpf_bias)

    if WRITE_WEIGHTS_FILE:
        writer.setKernel(filter_kernel)
        writer.setBias(bias_values)

    inputs = [image_np_expanded]

    if WRITE_WEIGHTS_FILE:
        input_fpf = get_fpf(inputs[-1], setting_fpf_input)
        data_input_fixp = float_to_fpf(inputs[-1], input_fpf)
        data = data_input_fixp.astype(np.int16)
        print("Save input data... ")
        print(" input format: ", data.shape)
        for a in range(0, data.shape[3]):
            writer.saveToFile(data[0, :, :, a], INPUT_FILE_NAME + str(a) + ".bin")

    # Analyse, ... Layer 0.-4. (index)
    for i in range(0, 5):    # 5 not included?
        input_fpf = get_fpf(inputs[-1], setting_fpf_input)
        data_input_fixp = float_to_fpf(inputs[-1], input_fpf)
        inputs[-1] = quantize(inputs[-1], setting_fpf_input)   # continue with fixpoint values

        print(inputs[-1].shape)
        inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[i], padding='SAME', strides=[1, 1, 1, 1], name="Conv"+str(i)))
        # print("Float MAC is: min: ", np.min(inputs[-1]), " - max ", np.max(inputs[-1]))
        # print("Float MAC to fpf is: min: ", np.min(float_to_fpf(inputs[-1], get_fpf(inputs[-1], 24))), " - max ", np.max(float_to_fpf(inputs[-1], get_fpf(inputs[-1], 24))))

        inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[i], name="Bias"+str(i)))
        conv_result_fpf = get_fpf(inputs[-1], setting_fpf_conv)
        data_conv_result_fixp = float_to_fpf(inputs[-1], conv_result_fpf)
        # print("Float MAC+Bias is: min: ", np.min(inputs[-1]), " - max ", np.max(inputs[-1]))
        # print("Float MAC+Bias to fpf is: min: ", np.min(float_to_fpf(inputs[-1], conv_result_fpf)), " - max ", np.max(float_to_fpf(inputs[-1], conv_result_fpf)))
        inputs[-1] = quantize(inputs[-1], setting_fpf_conv)

        coeff_fpf = get_fpf(filter_kernel[i], setting_fpf_kernel)
        data_weight_fixp = float_to_fpf(filter_kernel[i], coeff_fpf)
        bias_fpf = get_fpf(bias_values[i], setting_fpf_bias)
        data_bias_fixp = float_to_fpf(bias_values[i], bias_fpf)

        conv_result_shift_right = input_fpf[1] + coeff_fpf[1] - conv_result_fpf[1]  # to fit into RF (24)
        bias_load_shift_right   = -(conv_result_fpf[1] - bias_fpf[1]) # to match fpf of conv result in RF (24)

        inputs.append(tf.nn.max_pool(inputs[-1], ksize=2, strides=2, padding="SAME", name="MaxPool"+str(i)))
        inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU, name="Relu"+str(i)))

        store_fpf = get_fpf(inputs[-1], setting_fpf_output)
        data_store_fixp = float_to_fpf(inputs[-1], store_fpf)
        bias_store_shift_right  = conv_result_fpf[1] - store_fpf[1] # after relu, store to fit into LM (16)
        inputs[-1] = quantize(inputs[-1], setting_fpf_output)

        # get result of vpro execution (same as float_to_fpf(inputs[-1]) !)
        vpro_res = calc_fixp("C"+str(i)+" fixpoint",
                        data_input_fixp, data_weight_fixp, data_bias_fixp,  # fix point values
                        conv_result_shift_right, bias_load_shift_right, bias_store_shift_right,
                        relu=-0.1,  # 6 = RELU6, -0.1 = LEAKY
                        maxpool=1,  # 1 = max pooling
                        stride=1)

        diff_max = np.max(np.abs(vpro_res - float_to_fpf(inputs[-1], store_fpf)))
        if diff_max > MAX_ERROR_FLOAT_VS_FIXP:
            print("VPRO ERROR on Layer ", i)
            print("\tDiff is: ", diff_max)
            print("\tFloat to fpf is: min: ", np.min(float_to_fpf(inputs[-1], store_fpf)), " - max ", np.max(float_to_fpf(inputs[-1], store_fpf)))
            print("\tVPRO is: min: ", np.min(vpro_res), " - max ", np.max(vpro_res))

        if PRINT_FORMATS:
            print_formats(input_fpf, coeff_fpf, conv_result_shift_right, bias_fpf, bias_load_shift_right, store_fpf, bias_store_shift_right, "Layer"+str(i))

        if WRITE_WEIGHTS_FILE:
            writer.addLayer(i, input_fpf, data_input_fixp, coeff_fpf, data_weight_fixp, conv_result_shift_right, bias_fpf, data_bias_fixp, bias_load_shift_right, store_fpf, data_store_fixp, bias_store_shift_right, "Layer_"+str(i))
    
    # Layer 5. (index)
    input_fpf = get_fpf(inputs[-1], setting_fpf_input)
    data_input_fixp = float_to_fpf(inputs[-1], input_fpf)
    inputs[-1] = quantize(inputs[-1], setting_fpf_input)   # continue with fixpoint values
    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[5], padding='SAME', strides=[1, 1, 1, 1], name="Conv"+str(i)))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[5], name="Bias"+str(i)))
    conv_result_fpf = get_fpf(inputs[-1], setting_fpf_conv)
    data_conv_result_fixp = float_to_fpf(inputs[-1], conv_result_fpf)
    inputs[-1] = quantize(inputs[-1], setting_fpf_conv)
    coeff_fpf = get_fpf(filter_kernel[5], setting_fpf_kernel)
    data_weight_fixp = float_to_fpf(filter_kernel[5], coeff_fpf)
    bias_fpf = get_fpf(bias_values[5], setting_fpf_bias)
    data_bias_fixp = float_to_fpf(bias_values[5], bias_fpf)
    conv_result_shift_right = input_fpf[1] + coeff_fpf[1] - conv_result_fpf[1]  # to fit into RF (24)
    bias_load_shift_right   = -(conv_result_fpf[1] - bias_fpf[1]) # to match fpf of conv result in RF (24)
    inputs.append(tf.nn.leaky_relu(inputs[-1], alpha=_LEAKY_RELU, name="Relu"+str(i)))
    store_fpf = get_fpf(inputs[-1], setting_fpf_output)
    data_store_fixp = float_to_fpf(inputs[-1], store_fpf)
    bias_store_shift_right  = conv_result_fpf[1] - store_fpf[1] # after relu, store to fit into LM (16)
    inputs[-1] = quantize(inputs[-1], setting_fpf_output)
    vpro_res = calc_fixp("C5 fixpoint",
                    data_input_fixp, data_weight_fixp, data_bias_fixp,  # fix point values
                    conv_result_shift_right, bias_load_shift_right, bias_store_shift_right,
                    relu=-0.1,  # 6 = RELU6, -0.1 = LEAKY
                    maxpool=0,  # 1 = max pooling
                    stride=1)
    diff_max = np.max(np.abs(vpro_res - float_to_fpf(inputs[-1], store_fpf)))
    if diff_max > 10:
        print("VPRO ERROR on Layer ", 5)
        print("\tDiff is: ", diff_max)
        print("\tFloat to fpf is: min: ", np.min(float_to_fpf(inputs[-1], store_fpf)), " - max ", np.max(float_to_fpf(inputs[-1], store_fpf)))
        print("\tVPRO is: min: ", np.min(vpro_res), " - max ", np.max(vpro_res))
    if PRINT_FORMATS:
        print_formats(input_fpf, coeff_fpf, conv_result_shift_right, bias_fpf, bias_load_shift_right, store_fpf, bias_store_shift_right, "Layer5")
    if WRITE_WEIGHTS_FILE:
        writer.addLayer(5, input_fpf, data_input_fixp, coeff_fpf, data_weight_fixp, conv_result_shift_right, bias_fpf, data_bias_fixp, bias_load_shift_right, store_fpf, data_store_fixp, bias_store_shift_right, "Layer_5")

    # Layer 6. (final index)
    input_fpf = get_fpf(inputs[-1], setting_fpf_input)
    data_input_fixp = float_to_fpf(inputs[-1], input_fpf)
    inputs[-1] = quantize(inputs[-1], setting_fpf_input)  # continue with fixpoint values
    print(inputs[-1].shape)
    inputs.append(tf.nn.conv2d(inputs[-1], filters=filter_kernel[6], padding='SAME', strides=[1, 1, 1, 1], name="Conv" + str(i)))
    inputs.append(tf.nn.bias_add(inputs[-1], bias=bias_values[6], name="Bias" + str(i)))
    conv_result_fpf = get_fpf(inputs[-1], setting_fpf_conv)
    data_conv_result_fixp = float_to_fpf(inputs[-1], conv_result_fpf)
    inputs[-1] = quantize(inputs[-1], setting_fpf_conv)
    coeff_fpf = get_fpf(filter_kernel[6], setting_fpf_kernel)
    data_weight_fixp = float_to_fpf(filter_kernel[6], coeff_fpf)
    bias_fpf = get_fpf(bias_values[6], setting_fpf_bias)
    data_bias_fixp = float_to_fpf(bias_values[6], bias_fpf)
    conv_result_shift_right = input_fpf[1] + coeff_fpf[1] - conv_result_fpf[1]  # to fit into RF (24)
    bias_load_shift_right = -(conv_result_fpf[1] - bias_fpf[1])  # to match fpf of conv result in RF (24)
    store_fpf = get_fpf(inputs[-1], setting_fpf_output)
    data_store_fixp = float_to_fpf(inputs[-1], store_fpf)
    bias_store_shift_right = conv_result_fpf[1] - store_fpf[1]  # after relu, store to fit into LM (16)
    inputs[-1] = quantize(inputs[-1], setting_fpf_output)
    vpro_res = calc_fixp("C6 fixpoint",
                         data_input_fixp, data_weight_fixp, data_bias_fixp,  # fix point values
                         conv_result_shift_right, bias_load_shift_right, bias_store_shift_right,
                         relu=0,  # 6 = RELU6, -0.1 = LEAKY
                         maxpool=0,  # 1 = max pooling
                         stride=1)
    diff_max = np.max(np.abs(vpro_res - float_to_fpf(inputs[-1], store_fpf)))
    if diff_max > 10:
        print("VPRO ERROR on Layer ", 6)
        print("\tDiff is: ", diff_max)
        print("\tFloat to fpf is: min: ", np.min(float_to_fpf(inputs[-1], store_fpf)), " - max ",
              np.max(float_to_fpf(inputs[-1], store_fpf)))
        print("\tVPRO is: min: ", np.min(vpro_res), " - max ", np.max(vpro_res))
    if PRINT_FORMATS:
        print_formats(input_fpf, coeff_fpf, conv_result_shift_right, bias_fpf, bias_load_shift_right, store_fpf, bias_store_shift_right, "Layer6")
    if WRITE_WEIGHTS_FILE:
        writer.addLayer(6, input_fpf, data_input_fixp, coeff_fpf, data_weight_fixp, conv_result_shift_right, bias_fpf, data_bias_fixp, bias_load_shift_right, store_fpf, data_store_fixp, bias_store_shift_right, "Layer_6")
    print(inputs[-1].shape)

    # create final notes in c++ headers
    if WRITE_WEIGHTS_FILE:
        writer.finish()
    print("VPRO execution done!")


    # perform post processing on array of fixp (7x7x125)
    print("PERFORMING POST PROCESSING (Fixpoint / VPRO)")
    print("Converting result arrays back to float format...")
    result = fpf_to_float(vpro_res, store_fpf)

    print("Result DType: ", result.dtype)
    print("Result Shape: ", result.shape)
    print("Result Min: ", np.min(result), ", max:", np.max(result))

    image_out = postprocessing(result, INPUT_IMAGE, 0.5, 0.3, 224, 224)

    cv2.imshow("Result Fixpoint", image_out)
    cv2.waitKey(500) # wait 500ms
