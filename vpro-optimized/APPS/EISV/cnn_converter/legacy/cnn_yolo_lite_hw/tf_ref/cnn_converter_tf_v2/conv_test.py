
import tensorflow as tf
import numpy as np
from termcolor import colored
from bit_width import bit_width

shift = 1 # fixp format

h = 5   # y
w = 5   # x
data_input = np.ones((1,h,w,1)) # NHWC
data_input *= (1 << shift)    # fixp x.shift
data_input[0,1,1,0] = 5
data_input[0,0,0,0] = 100
data_input[0,1,0,0] = 100
data_input[0,0,1,0] = 100
data_input[0,0,w-1,0] = 100
data_input[0,1,w-1,0] = 100

data_weight = np.ones((3,3,1,1)) # HWIO
data_weight[1,1,0,0] = 1
data_weight *= (1 << shift)    # fixp x.shift

s = (2,2) # stride

with tf.Session(graph=tf.Graph()) as sess:
    data_input = tf.dtypes.cast(data_input, tf.float64)  # NHWC
    data_weight = tf.dtypes.cast(data_weight, tf.float64)  # HWIO

    c = tf.nn.conv2d(data_input, data_weight, [1, s[0], s[1], 1], "SAME")
    c = tf.dtypes.cast(c, tf.int64)
    mac = tf.bitwise.right_shift(c, shift)

    cw = tf.nn.conv2d(data_input, data_weight, [1, 1, 1, 1], "SAME")
    cw = tf.dtypes.cast(cw, tf.int64)
    macw = tf.bitwise.right_shift(cw, shift)

    (mac, c, data_input, data_weight, cw, macw) = sess.run([mac, c, data_input, data_weight,cw, macw])

print(data_input[0,:,:,0])
print("*")
print(data_weight[:,:,0,0])

print("Results in")
# NHWC
print(c[0,:,:,0])

print("Without stride:")
print(cw[0,:,:,0])