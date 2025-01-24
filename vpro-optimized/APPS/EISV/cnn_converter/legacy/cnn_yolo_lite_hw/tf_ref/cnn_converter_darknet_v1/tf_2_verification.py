# TensorFlow 1.14.0

#import tensorflow as tf
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()

import warnings
import argparse
import numpy as np
import cv2
import sys
import re
import inspect
import shutil
import os
import net_yolo_lite_fpf_2
import weights_loader_yolo_lite_fpf_2

warnings.filterwarnings('ignore')


# resize and split image ---> rgb
def tf_preprocessing(input_img_path, input_height, input_width): # random img input

	# OpenCV reading order B,G,R
    input_img = cv2.imread(input_img_path)
    # OpenCV reading order R,G,B                
    input_img = cv2.cvtColor(input_img, cv2.COLOR_BGR2RGB)

    # Resize the image and convert to array of float32
    # shape = CHW
    resized_img = cv2.resize(input_img, (input_height, input_width), interpolation=cv2.INTER_CUBIC)

    # split to RGB channels

    # ------------------------------------------------------------ #
    # --------------- input image process for TF ----------------- #
    # ------------------------------------------------------------ #

    img_data = np.array(resized_img, dtype='f')

    # Normalization [0,255] -> [0,1]
    # image_data /= 255.

    # Add the dimension relative to the batch size N
    # shape = NCHW
    img_data = img_data.astype('int16')
    
    image_array = np.expand_dims(img_data, axis=0)  # Add batch dimension

    #################################
    # save out the split images

    r_path = '../data/tf_reference/ref_in_0.png'  # r
    g_path = '../data/tf_reference/ref_in_1.png'  # g
    b_path = '../data/tf_reference/ref_in_2.png'  # b

    cv2.imwrite(r_path, resized_img[:, :, 0])
    cv2.imwrite(g_path, resized_img[:, :, 1])
    cv2.imwrite(b_path, resized_img[:, :, 2])


    fr = open("../data/tf_reference/ref_in_0.bin", 'wb')  # write binary
    fg = open("../data/tf_reference/ref_in_1.bin", 'wb')  # write binary
    fb = open("../data/tf_reference/ref_in_2.bin", 'wb')  # write binary
    img_data[:, :, 0].tofile(fr)
    img_data[:, :, 1].tofile(fg)
    img_data[:, :, 2].tofile(fb)
    fr.close()
    fg.close()
    fb.close()
    
    return image_array
'''
def img_load(input_r, input_g, input_b):  # default r, g, b gray img input with size of 224x224

	input_0 = cv2.imread(input_r, cv2.IMREAD_GRAYSCALE)
	input_1 = cv2.imread(input_g, cv2.IMREAD_GRAYSCALE)
	input_2 = cv2.imread(input_b, cv2.IMREAD_GRAYSCALE)
	input_0 = input_0.tolist(input_0)
	input_1 = input_1.tolist(input_1)
	input_2 = input_2.tolist(input_2)
	img_data = input_0.append(input_1).append(input_2)
	img_data = np.array(input_data)
	img_data = img_data.astype('int16')
    image_array = np.expand_dims(img_data, axis=0)
    
	return image_array
'''
# Inference utilizing TensorFlow

def tf_inference(input_width, input_height, input_img_path, tf_wghts_path, out_node):
# def tf_inference(input_r, input_g, input_b, tf_wghts_path, out_node):
    # Definition of the session for TensorFlow
    # Check for an existing checkpoint
    # Load the weights for TensorFlow
    # Definition of the paths of weights for TF

    ckpt_folder_path = './ckpt_yolo_lite/'

    sess = tf.compat.v1.InteractiveSession()
    tf.compat.v1.global_variables_initializer().run()
    # print('Looking for a checkpoint...')
    saver = tf.compat.v1.train.Saver()
    _ = weights_loader_yolo_lite_fpf_2.load_fpf(sess, tf_wghts_path, ckpt_folder_path, saver)

    preprocessed_image = tf_preprocessing(input_img_path, input_height, input_width)
    
	# preprocessed_image = img_load(input_r, input_g, input_b)
	
    # Forward pass of the preprocessed image into the network defined in the net_yolov2_tiny.py file
    predictions = sess.run(out_node, feed_dict={net_yolo_lite_fpf_2.x: preprocessed_image})

    return predictions


# tf_verification
# net_out: net_yolo_lite_fpf_2.layer_out
# def tf_reference_fpf(input_r, input_g, input_b, wghts_path, net_out):
def tf_reference_fpf(input_width, input_height, input_img_path, wghts_path, net_out):
    # print setting
    # np.set_printoptions(linewidth=60)
    np.set_printoptions(suppress=True)
    np.set_printoptions(formatter={'float': '{: 0.15f}'.format})
    np.set_printoptions(threshold=sys.maxsize)  # print truncation
    # TF outputs check
    tf_result = []
    ref_path = '../data/tf_reference'
    for i in range(len(net_out)):
        bin_path_lr = ref_path + '/binary/Layer_' + str(i)
        img_path_lr = ref_path + '/images/Layer_' + str(i)
        if not os.path.exists(bin_path_lr):
            os.makedirs(bin_path_lr)
            print('Make dir: {}'.format(bin_path_lr))
        else:
            shutil.rmtree(bin_path_lr)  # delete directory and all files and subdirectories below it
            os.makedirs(bin_path_lr)
            #print('Update dir: {}'.format(bin_path_lr))
        if not os.path.exists(img_path_lr):
            os.makedirs(img_path_lr)
            print('Make dir: {}'.format(img_path_lr))
        else:
            shutil.rmtree(img_path_lr)
            os.makedirs(img_path_lr)
            #print('Update dir: {}'.format(img_path_lr))
        tf_result.append(i)
        tf_result[i] = tf_inference(input_width, input_height, input_img_path, wghts_path,
                                    net_out[i])
                                    
        # tf_result[i] = tf_inference(input_r, input_g, input_b, wghts_path,
        #                            net_out[i])
        
        # print(tf_result[i].shape)
        # print(tf_result[i])
        tf_result[i] = tf_result[i].reshape(tf_result[i].shape[1], tf_result[i].shape[2], tf_result[i].shape[3])
        # print(tf_result[i].shape)
        tf_result[i] = tf_result[i].astype(np.int16)
        # TF format NCHW, axis 0 1 2 3
        # N: number of images in the batch (number of outputs)
        # C: number of channels of the image (number of inputs)(ex: 3 for RGB, 1 for grayscale...)
        # H: height of the image
        # W: width of the image
        tf_ref_split = np.split(tf_result[i], tf_result[i].shape[2], axis=2)  # split into list..sections along axis 2
        h = str(tf_result[i].shape[0])
        w = str(tf_result[i].shape[1])
        index = 0
        for s in tf_ref_split:
            array = np.array(s)
            array = array.reshape(array.shape[0], array.shape[1])
            # print(array.shape)
            # save to png
            img_filename = img_path_lr + '/' + 'tf_rf_' + h + 'x' + w + '_' + str(index) + '.png'
            cv2.imwrite(img_filename, array)

            # save to binary file
            bin_filename = bin_path_lr + '/' + 'tf_rf_' + h + 'x' + w + '_' + str(index) + '.bin'
            
            array = array.astype('int16')
            array = array.byteswap(inplace=True)
            
            f = open(bin_filename, 'wb')  # write binary
            array.tofile(bin_filename)
            f.close()
            ''''
            try:
                f = open(bin_filename, 'wb')  # write binary
                array.tofile(bin_filename)
                f.close()
            except (BrokenPipeError, IOError):
                print('BrokenPipeError caught', file=sys.stderr)
                print('Done', file=sys.stderr)
                sys.stderr.close()
            '''
            index = index + 1
            # print('binary file saved to {}'.format(bin_filename))
        
        print("min: ", np.min(tf_result[i]), " max: ", np.max(tf_result[i]))
        print('Layer_{} TF Reference {} saved'.format(i, tf_result[i].shape))
        # print('lr[{}]_tf_ref_shape= {}'.format(i, tf_result[i].shape))
        # print('lr[{}]_tf_ref_dtype={}'.format(i, tf_result[i].dtype))
        # print('lr[{}]_tf_ref_max={}'.format(i, tf_result[i].flatten().max()))
        # print('lr[{}]_tf_ref_min={}'.format(i, tf_result[i].flatten().min()))

    return


def input_args():

    parser = argparse.ArgumentParser(description='Dynamic Quantization of weights')
    parser.add_argument('--img_x', '-x', type=int, help='necessary arg, Input image width of network', required=True)
    parser.add_argument('--img_y', '-y', type=int, help='necessary arg, Input image height of network', required=True),
    parser.add_argument('--img', '-img', type=str, help='necessary arg, Input image path', required=True)
    parser.add_argument('--weights', '-wghts', type=str, help='necessary arg, xxx.weights file path', required=True)
    args = parser.parse_args()

    return args


def main(_):   # _: weights_loader

    #  python3 tf_verification.py -x 224 -y 224 -img ../data/test_img.png -wghts ../lib/yolo_files/yolo-lite.weights
    args = net_yolo_lite_fpf_2.input_args()
    input_height = args.img_x           # 224
    input_width = args.img_y            # 224
    input_img_path = args.img           # ./data/dog.jpg
    wghts_path = args.weights           # ./lib/yolo_files/yolo-lite.weights

    print("NET in fpf loaded!\n")

    num_conv = net_yolo_lite_fpf_2.n_kernel  # number of convolution
    num_bias = net_yolo_lite_fpf_2.n_bias  # number of bias

    # ------------------------------------------------------------ #
    # ------------------ Dynamic quantization ---------------------#
    # --------------- VPRO Weights Converter --------------------- #
    # ------------------- .weights ---> .h ----------------------- #
    # ------------------------------------------------------------ #

    # Quantization strategies and the trade - off between
    # The dynamic range of the outputs of each layer and
    # The different range of  weights and bias of each layer

    # The outputs(feature maps) dynamic value range of all computational steps
    # extract the bits width of feature maps BEFORE convolutiona and bias addition
    # representation as bits width

    layer_out = net_yolo_lite_fpf_2.layer_out
    print("Gonna Perform inference!!\n")
    tf_reference_fpf(input_width, input_height, input_img_path, wghts_path, layer_out)
    ''''
    conv2d_out = net_yolo_lite_fpf_2.conv2d_out
    biasadd_out = net_yolo_lite_fpf_2.biasadd_out
    relu_out = net_yolo_lite_fpf_2.relu_out
    pool_out = net_yolo_lite_fpf_2.pool_out

    tf_reference_fpf(input_width, input_height, input_img_path, wghts_path, conv2d_out)
    tf_reference_fpf(input_width, input_height, input_img_path, wghts_path, biasadd_out)
    tf_reference_fpf(input_width, input_height, input_img_path, wghts_path, relu_out)
    tf_reference_fpf(input_width, input_height, input_img_path, wghts_path, pool_out)
    '''


# current file is executed under a shell instead of imported as a module.
if __name__ == '__main__':
    try:
        net_yolo_lite_fpf_2.input_args()
    except Exception as e:
        print(e)
    print("Starting TF!\n")
    tf.compat.v1.app.run(main=main)
