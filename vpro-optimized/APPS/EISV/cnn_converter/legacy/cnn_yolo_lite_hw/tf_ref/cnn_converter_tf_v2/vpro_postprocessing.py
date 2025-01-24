import cv2
import time
import numpy as np
from postprocessing import postprocessing
from load_model import fpf_to_float, float_to_fpf, get_fpf, INPUT_IMAGE

height = 7
width = 7
channels = 125
fpf = (5, 9)

bin_root_path = "../../data/simulation_output/Layer_7/channel_"
#bin_root_path = "../../data/reference_c/binary/Layer_7/channel_"

###
## Load VPRO RESULTS
###
bin_path = []
for i in range(0, channels):
    bin_path.append(i)
    bin_path[i] = bin_root_path + str(i) + '.bin'

# IMPORTANT: binary read as HEX, "byteswap" is important
for i in range(0, channels):
    next = np.fromfile(bin_path[i], "int16").reshape((1, height, width, 1)).byteswap(inplace=True)
    if 'vpro_res' not in locals():
        vpro_res = next
    else:
        vpro_res = np.concatenate((vpro_res, next), axis=3)

print("\tLoaded ", channels, " Channels")
print("\tShape of Loaded Result: ", vpro_res.shape)
print("\tMinimum: ", np.min(vpro_res))
print("\tMaximum: ", np.max(vpro_res))

###
# perform post processing on array of fpf (7x7x125)
###
print("PERFORMING POST PROCESSING (Fixpoint / VPRO)")

print("Converting back to float format...  Format: (", fpf[0], ", ", fpf[1], ")")
result = fpf_to_float(vpro_res, fpf)

print("\tResult DType: ", result.dtype)
print("\tResult Shape: ", result.shape)
print("\tResult Min: ", np.min(result), ", max:", np.max(result))

image_out = postprocessing(result, INPUT_IMAGE, 0.5, 0.3, 224, 224)

cv2.imshow("Result Fixpoint", image_out)
cv2.waitKey()
