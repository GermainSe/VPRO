#!/usr/bin/env python3
# coding: utf-8

import glob, os, sys
import argparse
import shutil
from datetime import date, datetime
import numpy as np


def dump_output_file(filename, address, byte_size):
    global input_buffer, cdma
    print("[Output] Transferring", filename, "from", address, "size", byte_size)

    # dump to bin
    vpro.transfer_pl_to_buffer(cdma, input_buffer, addr=0x10_0000_0000 + int(address, 0), size=int(byte_size, 0))
    os.makedirs(os.path.dirname(filename), exist_ok=True)
    newFile = open(filename, "wb+")
    newFileByteArray = bytearray(input_buffer.view(np.int16)[0:int(int(byte_size, 0) / 2)])
    # byteswapped = bytearray(len(newFileByteArray))
    # byteswapped[0::2] = newFileByteArray[1::2]
    # byteswapped[1::2] = newFileByteArray[0::2]
    newFile.write(newFileByteArray)
    newFile.close()


def load_input_file(filename, address, dataEndRev=True):
    global input_buffer, cdma
    byte_size = os.path.getsize(filename)
    if byte_size/1024 > 1024:
        byte_size = str(byte_size/1024/1024) + " MB"
    else:
        byte_size = str(byte_size/1024) + " KB"
    print("[Input] Transferring", filename, "to", hex(int(address, 0)), " Size:", byte_size)

    vpro.transfer_file_to_pl_mem_dma_large(cdma, filename, input_buffer, 0x10_0000_0000 + int(address, 0),
                                     endianessReverse=dataEndRev, print_SUMUP=False)

os.umask(2) # allow regular user to modify/delete files created by this script executed via sudo (parent dir group sticky bit must be set)

parser = argparse.ArgumentParser(description='Run an binary application on EIS-V',
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-bit', '--bitstream', default='/home/xilinx/overlays/8c8u_reference_slow.bit',
                    help='the FPGA bitstream file')
parser.add_argument('-bin', '--binary', default="/home/xilinx/EIS-V_bin/fibonacci.bin",
                    help='the application with complete path for RV32IM')
parser.add_argument('-pwd', '--working_directory', default="/home/xilinx/EIS-V_bin/",
                    help='the application working directory (for input/output relative paths)')
parser.add_argument('-no_iskip', '--no_input_skip', default=False, action='store_true',
                    help='do not skip input file parsing')
parser.add_argument('-in', '--input', default="/home/xilinx/EIS-V_bin/input.cfg",
                    help='the .cfg dile with additional input data segments to be loaded before execution. Format (# -> comment): str(filename), int(addr)')
parser.add_argument('-no_oskip', '--no_output_skip', default=False, action='store_true',
                    help='do not skip output file parsing')
parser.add_argument('-out', '--output', default="/home/xilinx/EIS-V_bin/output.cfg",
                    help='the .cfg dile with the result/output data segments to be dumped after execution. Format (# -> comment): str(filename), int(addr), int(byte_size)')
parser.add_argument('-t', '--execution_time', default=3,
                    help='the time to capture uart output (capped) in seconds. execution is stopped afterwards and output is copied')
parser.add_argument('-c', '--clusters', default=8,
                    help='the software uses this number of clusters')
parser.add_argument('-u', '--units', default=8,
                    help='the software uses this number of units')
args = parser.parse_args()

# use vpro lib (one folder above)
sys.path.insert(0, os.path.abspath('../../'))
import vprolib as vpro
from overlays.vpro_sys import BaseOverlay

overlay = BaseOverlay(args.bitstream, ignore_version=True)

input_buffer = vpro.try_allocate(128 * 1024 * 1024)
cdma = vpro.CDMA()
cdma.init(overlay.ip_dict['axi_cdma_0']['phys_addr'])
vpro.set_reset()
vpro.print_infos()

print("Changing Working Directory...")
os.chdir(args.working_directory)
print("\tPWD: ", os.getcwd())

print("Removing old results...")
for f in glob.glob("../*.log"):
    os.remove(f)
shutil.rmtree("../emu_results/", ignore_errors=True)

print("Transferring executable...")
executable_bin_file = args.binary
vpro.transfer_file_to_pl_mem_dma(cdma, executable_bin_file, input_buffer, 0x10_0000_0000)  # , True, True)
print("\tFile: ", args.binary)

if args.no_input_skip:
    print("Loading Input...")
    for line in open(args.input, "r"):
        line = line.strip()
        if line.startswith('#'):
            continue
        filename, address = line.split(' ')[:2]
        load_input_file(filename, address)

# serial output -> uart capture of prints of risc-v
import serial, time

ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=0.35)
time.sleep(0.1)  # I... am... slow,... need... more... time...
print("[UART] Using Serial: " + ser.name)  # check which port was really used
ser.reset_input_buffer()

# initialize semaphores as was done before in runtime.cpp for backwards compatability
gpr = {}
gpr["rv_input_parsed"] = 128
gpr["rv_output_ready"] = 132
gpr["arm_input_ready"] = 136
gpr["arm_output_parsed"] = 140
gpr["rv_running"] = 144
vpro.set_gpr(gpr["rv_output_ready"], 0x0)
vpro.set_gpr(gpr["rv_input_parsed"], 0x0)
vpro.set_gpr(gpr["rv_running"], 0x1)
vpro.set_gpr(gpr["arm_input_ready"], 0x1)
vpro.set_gpr(gpr["arm_output_parsed"], 0x1)

# Start VPRO
vpro.release_reset()
print("\tWait for ", args.execution_time, "seconds...")
# Give time for calculation
time.sleep(int(args.execution_time))

# capture output
max_buffer_uart = 6400000   # Bytes
byte = ser.read(max_buffer_uart)  # timeout (Serial() will end read)
result = "[Captured Output of the UART (printf) for the emulated V²PRO System. Capture Limit: " + str(max_buffer_uart) + " B!]\n"
result = result + byte.decode(encoding='ascii', errors='strict')

# get hardware version
from pynq import MMIO

vpro_axi_slave = MMIO(0x00_8003_0000, 0x1_0000)
clusters = int(vpro_axi_slave.read(12))
units = int(vpro_axi_slave.read(16))

# dump debug fifo entries
entries = 0
while vpro_axi_slave.read(44) != 0 and entries < 100:
    d = vpro_axi_slave.read(40)
    print("\t" + str(entries).ljust(3) + " Debug Fifo Entry: " + str(d).ljust(11) + "|" + hex(d))
    entries += 1
print("\tDebug Fifo Entries: " + str(entries).ljust(21))

# check hw
if units < int(args.units):
    print("Error, Sw uses ", args.units, "Units while Hw only has", units)
    exit(1)
if clusters < int(args.clusters):
    print("Error, Sw uses ", args.clusters, "Clusters while Hw only has", clusters)
    exit(1)

# save uart as log to named file
creation_day = date.today().strftime("%d/%m/%Y")
creation_time = datetime.now().strftime("%H:%M:%S")

filename = args.binary + str(args.clusters) + "c" + str(args.units) + "u_onHW_" + str(clusters) + "c" + str(
    units) + "u.log"
print("Saving log to: ", filename)
with open(filename, "w") as f:
    # f.write("Created on "+creation_day+" at "+creation_time+"\n")
    f.write(result)

if args.no_output_skip:
    print("Dumping Output...")
    # dump output as specified in cfg file
    for line in open(args.output, "r"):
        line = line.strip()
        if line.startswith('#'):
            continue
        filename, address, byte_size = line.split(' ')
        dump_output_file(filename, address, byte_size)

# set reset and exit
vpro.set_reset()
