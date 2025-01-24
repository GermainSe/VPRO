#!/usr/bin/python3
import cv2
import numpy as np
import sys


if len(sys.argv) < 6:
    print("bin2img: Invalid input arguments!")
    print("1st: Input binary file")
    print("2nd: Input image X resolution (width)")
    print("3rd: Input image Y resolution (height)")
    print("4th: Output image file")
    print("5th: Bytes per pixel (1,2)")
    print("6th: number of channels")

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

x = int(sys.argv[2])
y = int(sys.argv[3])

if str(sys.argv[5]) == "1":
	img = np.fromfile(str(sys.argv[1]), "uint8")
else:
	img = np.fromfile(str(sys.argv[1]), "uint16")
#    img.byteswap(inplace=True) # switch endianess

channels = int(sys.argv[6])

try:
	img = img.reshape((y, x, channels))
	cv2.imwrite(str(sys.argv[4])+'.png', img)
except ValueError as e:
	print(bcolors.FAIL, end = '')
	print("[ERROR] ", end = '')
	print(str(sys.argv[1]), end = '')
	print(" -> ", end = '')
	print(str(sys.argv[4]), end = '')
	print(".png ", end = '')
	print(e, end = '')
	print(bcolors.ENDC)

