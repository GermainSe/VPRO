from termcolor import colored
import numpy as np
import os

TF_REFERENCE_FLOAT = "../data/reference/"
# LAYER_<>/channel_<>.bin
# float32

C_REFERENCE_INT16 = "../data/reference_c/binary/"
# LAYER_<>/channel_<>.bin
# int16

fractional_bits = [12, 12, 10, 12, 12, 10, 12, 12, 10,  0,
                   12, 12, 11, 12, 12, 11,  0, 12, 12, 11,
                    0, 12, 12, 11, 12, 12, 11,  0, 12, 12,
                   11,  0, 12, 12, 11 ]

layer = [1,2,3,4,5,6,7,8,9]
for l in layer:
    print("Checking Layer", l)

    sum_abs_diff = 0
    sum_diff = 0
    max_diff = 0
    channels = len(os.listdir(TF_REFERENCE_FLOAT + "Layer_" + str(l) + "/"))
    for c in range(channels):
        # print("Checking Channel", c)
        if fractional_bits[l-1] <= 0:
            print("Residual Layer? Skipped!")
            continue

        file = TF_REFERENCE_FLOAT + "Layer_" + str(l) + "/channel_" + str(c) + ".bin"
        tf_data = np.fromfile(file, dtype=np.float32)
        dim = int(np.sqrt(len(tf_data)))
        tf_data = np.reshape(tf_data, (dim, dim))

        file = C_REFERENCE_INT16 + "Layer_" + str(l) + "/channel_" + str(c) + ".bin"
        c_data = np.fromfile(file, dtype=np.int16)
        c_data = c_data.byteswap(True)
        c_data = np.reshape(c_data, (dim, dim)).astype(np.float32)
        c_data = c_data / (1 << fractional_bits[l-1])

        diff = tf_data - c_data
        correct = 0
        error = 0
        max_diff = max(np.max(diff), max_diff)
        treshold = 0 #0.01 * np.max(tf_data)
        for x in range(dim):
            for y in range(dim):
                sum_abs_diff += abs(diff[x, y])
                sum_diff += diff[x, y]
                if abs(diff[x, y]) > treshold:
                    # print("Error > 0.1! (", x,"|", y,") TF:",tf_data[x,y], ", C:", c_data[x,y], ", Diff:", diff[x, y])
                    error += 1
                else:
                    correct += 1
        # if error > 0:
            # print("Channel", c, ", Errors:", error,"(",error/(error+correct),") Correct Values:", correct)

    print("Max Error:", max_diff, "Sum All Errors:", sum_diff, "Abs Sum:", sum_abs_diff)