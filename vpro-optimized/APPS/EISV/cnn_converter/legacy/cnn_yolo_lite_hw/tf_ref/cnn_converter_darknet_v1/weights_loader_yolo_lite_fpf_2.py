
import tensorflow.compat.v1 as tf
tf.disable_v2_behavior()
import os
import numpy as np
import os.path
import net_yolo_lite_fpf_2

# Load weights as Fixed point format
# dynamic_convfilter_fpf, dynamic_bias_fpf = cw.do_conversion(height, width, input_img, wghts)


def load_conv_layer(name, loaded_weights, shape, offset):
    # Conv layer without Batch norm

    n_kernel_weights = shape[0]*shape[1]*shape[2]*shape[3]
    n_output_channels = shape[-1]  # shape[3]
    n_biases = n_output_channels

    n_weights_conv = (n_kernel_weights + n_output_channels)
    # The number of weights is a conv layer without batchnorm is: (kernel_height*kernel_width + n_biases)
    # print('Loading '+str(n_weights_conv)+' weights of '+name+' ...')

    biases = loaded_weights[offset:offset+n_biases]
    offset = offset + n_biases
    kernel_weights = loaded_weights[offset:offset+n_kernel_weights]
    offset = offset + n_kernel_weights

    # DarkNet conv_weights are serialized Caffe-style: (out_dim, in_dim, height, width)
    # We would like to set these to Tensorflow order: (height, width, in_dim, out_dim)
    kernel_weights = np.reshape(kernel_weights, (shape[3], shape[2], shape[0], shape[1]), order='C')
    kernel_weights = np.transpose(kernel_weights, [2, 3, 1, 0])
    # or:
    # nchw - > hwcn
    # kernel_weights = kernel_weights.transpose((3, 2, 0, 1))

    return biases, kernel_weights, offset


def load_fpf(sess, weights_path, ckpt_folder_path, saver):

    if os.path.exists(ckpt_folder_path):
        # print('Found a checkpoint!')
        checkpoint_files_path = os.path.join(ckpt_folder_path, "model.ckpt")
        saver.restore(sess,checkpoint_files_path)
        # print('Loaded weights from checkpoint!')
        return True

    print('No checkpoint found!')
    print('Loading weights from file and creating new checkpoint...')

    # Get the size in bytes of the binary
    size = os.path.getsize(weights_path)

    # Load the binary to an array of float32
    loaded_weights = []
    loaded_weights = np.fromfile(weights_path, dtype='f')

    # Delete the first 4 that are not real params...
    loaded_weights = loaded_weights[4:]

    # print('Total number of params to load = {}'.format(len(loaded_weights)))

    # IMPORTANT: starting from offset=0, layer by layer,
    # we will get the exact number of parameters required and assign them!

    offset = 0

    # Conv0 , 3x3, 3->16
    biases, kernel_weights, offset = load_conv_layer('conv0', loaded_weights, [3, 3, 3, 16], offset)
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.b[0], biases))
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.w[0], kernel_weights))
    
    print("Bias 0:    ", np.min(biases), " - ", np.max(biases))
    print("Weights 0: ", np.min(kernel_weights), " - ", np.max(kernel_weights))

    # Conv1 , 3x3, 16->32
    biases, kernel_weights, offset = load_conv_layer('conv1', loaded_weights, [3, 3, 16, 32], offset)
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.b[1], biases))
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.w[1], kernel_weights))

    print("Bias 1:    ", np.min(biases), " - ", np.max(biases))
    print("Weights 1: ", np.min(kernel_weights), " - ", np.max(kernel_weights))
    
    # Conv2 , 3x3, 32->64
    biases, kernel_weights, offset = load_conv_layer('conv2', loaded_weights, [3, 3, 32, 64], offset)
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.b[2], biases))
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.w[2], kernel_weights))

    print("Bias 2:    ", np.min(biases), " - ", np.max(biases))
    print("Weights 2: ", np.min(kernel_weights), " - ", np.max(kernel_weights))
    
    # Conv3 , 3x3, 64->128
    biases, kernel_weights, offset = load_conv_layer('conv3', loaded_weights, [3, 3, 64, 128], offset)
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.b[3], biases))
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.w[3], kernel_weights))

    print("Bias 3:    ", np.min(biases), " - ", np.max(biases))
    print("Weights 3: ", np.min(kernel_weights), " - ", np.max(kernel_weights))
    
    # Conv4 , 3x3, 128->128
    biases, kernel_weights, offset = load_conv_layer('conv4', loaded_weights, [3, 3, 128, 128], offset)
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.b[4], biases))
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.w[4], kernel_weights))

    print("Bias 4:    ", np.min(biases), " - ", np.max(biases))
    print("Weights 4: ", np.min(kernel_weights), " - ", np.max(kernel_weights))
    
    # Conv5 , 3x3, 128->256
    biases, kernel_weights, offset = load_conv_layer('conv5', loaded_weights, [3, 3, 128, 256], offset)
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.b[5], biases))
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.w[5], kernel_weights))

    print("Bias 5:    ", np.min(biases), " - ", np.max(biases))
    print("Weights 5: ", np.min(kernel_weights), " - ", np.max(kernel_weights))
    
    # Conv6 , 1x1, 256->125
    biases, kernel_weights, offset = load_conv_layer('conv6', loaded_weights, [1, 1, 256, 125], offset)
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.b[6], biases))
    sess.run(tf.compat.v1.assign(net_yolo_lite_fpf_2.w[6], kernel_weights))

    print("Bias 6:    ", np.min(biases), " - ", np.max(biases))
    print("Weights 6: ", np.min(kernel_weights), " - ", np.max(kernel_weights))
    
    # These two numbers MUST be equal!
    # print('Final offset = {}'.format(offset))
    # print('Total number of params in the weight file = {}'.format(len(loaded_weights)))

    # Saving checkpoint!
    if not os.path.exists(ckpt_folder_path):
        # print('Saving new checkpoint to the new checkpoint directory ./ckpt/ !')
        os.makedirs(ckpt_folder_path)
        checkpoint_files_path = os.path.join(ckpt_folder_path, "model.ckpt")
        saver.save(sess, checkpoint_files_path)

    # These two numbers MUST be equal! 
    # print('Final offset = {}'.format(offset))
    # print('Total number of params in the weight file = {}'.format(len(loaded_weights)))
