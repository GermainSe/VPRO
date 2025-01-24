#!/usr/bin/python3
import cv2
import numpy as np
import sys, os


if len(sys.argv) < 6:
    print("img2bin: Invalid input arguments!")
    print("1st: Input image file")
    print("2nd: Input image X resolution (width)")
    print("3rd: Input image Y resolution (height)")
    print("4th: Output binary file")
    print("5th: Bytes per pixel (1,2)")
    print("[optional: 6th: channel to write out]")

    print(str(sys.argv))
    raise SystemExit

class bcolors:
    HEADER = '\033[95m'
    OKBLUE = '\033[94m'
    OKGREEN = '\033[92m'
    WARNING = '\033[93m'
    FAIL = '\033[91m'
    ENDC = '\033[0m'
    BOLD = '\033[1m'
    UNDERLINE = '\033[4m'

if not os.path.isfile(str(sys.argv[1])):
	print(bcolors.FAIL, end = '')
	print("ERROR: File " + str(sys.argv[1]) + " does not exist!")
	exit(1)

x = int(sys.argv[2])
y = int(sys.argv[3])

# OpenCV reading order B, G, R
img = cv2.imread(str(sys.argv[1]))  
# OpenCV reading order R,G,B
img = cv2.cvtColor(img, cv2.COLOR_BGR2RGB)   

# resized image
img = cv2.resize(img, (x, y), interpolation=cv2.INTER_CUBIC)

# save out the resized R, G, B images
cv2.imwrite(str(sys.argv[4])+'_0.png', img[:,:,0])
cv2.imwrite(str(sys.argv[4])+'_1.png', img[:,:,1])
cv2.imwrite(str(sys.argv[4])+'_2.png', img[:,:,2])


import math
# Returns the number of bits necessary to represent an integer in binary, 2-complement format
def bit_width(a, b):
    if a > b:
        min_value = b
        max_value = a
    else:
        min_value = a
        max_value = b

    value = max(abs(min_value), abs(max_value)+1)
    width = int(math.ceil(math.log2(value)) + 1)
    # print("min: ", min_value, ", max: ", max_value, " -> req bit width: ", width)
    return width

img = np.array(img, dtype='f')
# Normalization [0,255] -> [0,1]
img -= img.min()
img /= img.max()

int_bits = bit_width(img.min(), img.max())
print("Max: ", img.max(), ", min: ", img.min(), "\t -> bit width: ", int_bits, ".", 16-int_bits)

img = (img * (2 ** (16-int_bits))).astype(np.int64)
for d in img.flatten():
	if d > 2 ** 16 -1 or d < -2 ** 16:
		print("FPF Overflow!", d)

if str(sys.argv[5]) == "1":
    img = img = img.astype('int8')
else:
    img = img = img.astype('int16')
    img.byteswap(inplace=True) # switch endianess 

print("Max: ", img.max(), ", min: ", img.min(), "\t    datatype: ", img.dtype)

print("")
name = ["r", "g", "b"]
if len(sys.argv) > 6:
	channel = int(sys.argv[6])

	if channel == 0:
		f = open(str(sys.argv[4])+'_0.bin', "wb")
		f.write(img[:,:,0].flatten())
	elif channel == 1:
		f = open(str(sys.argv[4])+'_1.bin', "wb")
		f.write(img[:,:,1].flatten())
	elif channel == 2:
		f = open(str(sys.argv[4])+'_2.bin', "wb")
		f.write(img[:,:,2].flatten())
	else:
		f = open(str(sys.argv[4])+'.bin', "wb")
		f.write(img[:,:,0].flatten())
	f.close()
	print(bcolors.OKGREEN, end = '')
	print("Wrote out channel [" + str(channel) + " / "+name[channel]+"]: "+sys.argv[4]+'_'+str(channel)+'.bin')
else:
	f = open(str(sys.argv[4])+'.bin', "wb")
	f.write(img[:,:,0].flatten())
	f.close()

	print(bcolors.OKGREEN, end = '')
	print("Wrote out all (gray) channels: "+sys.argv[4]+'.bin')
