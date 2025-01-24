import tensorflow as tf
import os
import warnings
import numpy as np
import os.path
import net_yolo_lite

tf.compat.v1.logging.set_verbosity(tf.compat.v1.logging.FATAL)  # DEBUG,ERROR,FATAL,INFO,WARN
warnings.filterwarnings('ignore')


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
    kernel_weights = np.reshape(kernel_weights,(shape[3],shape[2],shape[0],shape[1]),order='C')
    kernel_weights = np.transpose(kernel_weights,[2,3,1,0])
    # or: nchw - > hwcn
    # kernel_weights = kernel_weights.transpose((3, 2, 0, 1))

    return biases,kernel_weights,offset


def load(sess, weights_path, ckpt_folder_path, saver):

    if os.path.exists(ckpt_folder_path):
        checkpoint_files_path = os.path.join(ckpt_folder_path, "model.ckpt")
        saver.restore(sess, checkpoint_files_path)
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

    print('Total number of params to load = {}'.format(len(loaded_weights)))

    # IMPORTANT: starting from offset=0, layer by layer,
    # we will get the exact number of parameters required and assign them!
    layer = 0 # include max pooling
    offset = 0
    count = 0 # only to count conv layer
    while layer < len(net_yolo_lite.network_structure):
        if len(net_yolo_lite.network_structure[layer]) > 2:
            biases,kernel_weights,offset = load_conv_layer('conv'+str(layer),loaded_weights,
                       [net_yolo_lite.network_structure[layer][0],net_yolo_lite.network_structure[layer][1],
                        net_yolo_lite.network_structure[layer][2],net_yolo_lite.network_structure[layer][3]],
                       offset)
            sess.run(tf.assign(net_yolo_lite.bias_weights[count], biases))
            sess.run(tf.assign(net_yolo_lite.conv_weights[count], kernel_weights))
            count += 1
        layer += 1

    # These two numbers MUST be equal! 
    print('Final offset = {}'.format(offset))
    print('Total number of params in the weight file = {}'.format(len(loaded_weights)))

    # Saving checkpoint!
    if not os.path.exists(ckpt_folder_path):
        print('Saving new checkpoint to the new checkpoint directory ./ckpt/ !')
        os.makedirs(ckpt_folder_path)
        checkpoint_files_path = os.path.join(ckpt_folder_path, "model.ckpt")
        saver.save(sess, checkpoint_files_path)
