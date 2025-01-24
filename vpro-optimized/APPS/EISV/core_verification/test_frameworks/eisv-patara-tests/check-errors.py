#!/usr/bin/env python3

from distutils.log import ERROR
import time
import os
import glob
from datetime import timedelta
import subprocess


NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'

dir_path = os.path.dirname(os.path.realpath(__file__))

originalPath = dir_path
# get to REPOSITORY BASE DIR
for i in range(5):
    dir_path = os.path.dirname(dir_path)


REPO_DIR=dir_path#"/localtemp2/coverage_share_tmp/vpro_sys_optimized"
PATARA_DIR=os.path.join(originalPath, "src")#"patara/reversiAssembly"
VERIFICATION_DIR=os.path.join(REPO_DIR, "APPS/EISV/core_verification/test_frameworks/riscv-compliance/work/rv32i_m/Patara")
ERROR_DIR=os.path.join(originalPath, "errors")#"/localtemp2/coverage_share_tmp/errors/"


success_files = glob.glob(VERIFICATION_DIR+'/*.signature.output')
all_files = glob.glob(VERIFICATION_DIR+'/*.elf')


rel = 0
if len(all_files) > 0:
	rel = len(success_files) / len(all_files)
else:
	print("No Simulation files found!")
	exit(1)


succ = []
fail = []

count_f = 0 # fail
count_r = 0 # running
count_s = 0 # success
running_files = []



for f in success_files:
    if os.path.getsize(f) <= 0:
        running_files.append(f)
        count_r += 1


first_time = time.time()
last_time = time.time() - 100000

print("Simulation Errors:")
for f in success_files:
    if os.path.getsize(f) > 0:
        touch_time = os.path.getmtime(f)
        if touch_time > last_time:
            last_time = touch_time
        if touch_time < first_time:
            first_time = touch_time
        with open(f) as file:
            line = file.readline()
            if "1" in line:
                fail.append(f)
                count_f += 1
                print(RED, count_f, "Fail", line.replace("\n", ""), ": ", f, NONE)
            else:
                count_s += 1
                succ.append(f)
                #print("SUC", line)

print("Total Failed: ", count_f)
print("Total Success: ", count_s)

print("\nRuntime: ")
print("First Result: ", time.ctime(first_time))
print("Last Result:  ", time.ctime(last_time))
print("Duration: ", timedelta(seconds = (last_time-first_time)), " HH:MM:SS")

if not os.path.exists(ERROR_DIR):
    os.makedirs(ERROR_DIR)

print("Moving Errors into " + ERROR_DIR)

for file in fail:
    baseFileName = os.path.basename(file)
    base = baseFileName.split(".")[0]
    reversiFile = os.path.join(PATARA_DIR, base + ".S")
    command = "cp " + reversiFile + " " + ERROR_DIR
    subprocess.run(command, shell=True)