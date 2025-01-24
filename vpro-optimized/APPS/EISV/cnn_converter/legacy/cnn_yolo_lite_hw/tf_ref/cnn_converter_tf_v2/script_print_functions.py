import numpy as np
import cv2
import time
from termcolor import cprint


def print_fpf(fpf):
    cprint(str(fpf[0])+"."+str(fpf[1]), color="red", end="")

def print_formats(input_fpf, coeff_fpf, conv_result_shift_right, bias_fpf, bias_load_shift_right, store_fpf, bias_store_shift_right, name=""):
    print("============================================================ ")
    print("=== ", end="")
    cprint("Fixpoint  FORMAT &", color="red", end="")
    cprint(" Shift-amount", color="blue", end="")
    cprint(" ("+name+"): ")
    print("=== \t\t\t\tInput : ", end="")
    print_fpf(input_fpf)
    print("")
    print("=== \t\t\t\tCoeff : ", end="")
    print_fpf(coeff_fpf)
    print("")
    print("===              shift mac result right by: ", end="")
    cprint(str(conv_result_shift_right), color="blue")
    print("=== \t\t\t\tBias  : ", end="")
    print_fpf(bias_fpf)
    print("")
    print("===           shift bias load data left by: ", end="")
    cprint(str(-bias_load_shift_right), color="blue")
    print("===  shift result after pool/relu right by: ", end="")
    cprint(str(bias_store_shift_right), color="blue")
    print("=== \t\t\t\tResult: ", end="")
    print_fpf(store_fpf)
    print("")
    print("============================================================ ")