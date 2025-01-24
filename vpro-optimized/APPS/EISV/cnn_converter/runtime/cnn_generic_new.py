#!/usr/bin/env python3
# coding: utf-8
import glob, os, sys
# use vpro lib (one folder above)
sys.path.insert(0, os.path.abspath('../../'))
import vprolib as vpro
from overlays.vpro_sys import BaseOverlay
import argparse
import shutil
from datetime import date, datetime
import numpy as np
from typing import NamedTuple, Iterable, Dict, Tuple
from iolibs.tools import get_class, CfgLayerDescription


if __name__ == '__main__':
    os.umask(2) # allow regular user to modify/delete files created by this script executed via sudo (parent dir group sticky bit must be set)

    parser = argparse.ArgumentParser(description='Run a binary application on EIS-V',
                                    formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('-bit', '--bitstream', default='/home/xilinx/overlays/8c8u_reference_slow.bit',
                        help='the FPGA bitstream file')
    parser.add_argument('-bin', '--binary', default="/home/xilinx/EIS-V_bin/fibonacci.bin",
                        help='the application with complete path for RV32IM')
    parser.add_argument('-pwd', '--working_directory', default="/home/xilinx/EIS-V_bin/",
                        help='the application working directory (for input/output relative paths)')
    parser.add_argument('-in', '--input', default="/home/xilinx/EIS-V_bin/cnn_generic/input/input.cfg",
                        help='the .cfg dile with additional input data segments to be loaded before execution. Format (# -> comment): str(filename), int(addr)')
    parser.add_argument('-out', '--output', default="/home/xilinx/EIS-V_bin/cnn_generic/output/output.cfg",
                        help='the .cfg dile with the result/output data segments to be dumped after execution. Format (# -> comment): str(filename), int(addr), int(byte_size)')
    parser.add_argument('-t', '--max_execution_time', default=10, type=int,
                        help='the time to capture uart output (capped) in seconds. execution is stopped afterwards and output is copied')
    parser.add_argument('-c', '--clusters', default=8,
                        help='the software uses this number of clusters')
    parser.add_argument('-u', '--units', default=8,
                        help='the software uses this number of units')
    parser.add_argument('--vpro_input_provider', type=str, default='iolibs.io_default_types.VPROInputFileLoader',
                        help='a fully qualified class name (including modules) of a VPROInputProvider subclass, that will be instantiated to provide inputs to the VPRO')
    parser.add_argument('-ipp', '--input_provider_params', nargs='*', type=lambda kv: kv.split("="), dest='input_provider_params',
                        # default=None,
                        default=[['input_cfg_file_name','/home/xilinx/EIS-V_bin/cnn_generic/input/input.cfg']],
                        help='An abitrary number of key=value pairs that will be passed to the vpro_input_provider\'s init call. Params need to be implemented by the given subtype.')
    parser.add_argument('--vpro_output_handler', type=str, default='iolibs.io_default_types.DefaultVPROOutputFileWriter',
                        help='a fully qualified class name (including modules) of a VPROOutputHandler subclass, that will handle the outputs computed by the VPRO')
    parser.add_argument('-ohp', '--output_handler_params', nargs='*', type=lambda kv: kv.split("="), dest='output_handler_params',
                        # default=None,
                        default=[['output_cfg_file_name','/home/xilinx/EIS-V_bin/cnn_generic/output/output.cfg']],
                        help='An abitrary number of key=value pairs that will be passed to the vpro_output_handler\'s init call. Params need to be implemented by the given subtype.')
    # TODO: to be removed?
    parser.add_argument('-no_oskip', '--no_output_skip', default=False, action='store_true',
                    help='do not skip output file parsing')
    # TODO: to be removed?
    parser.add_argument('-no_iskip', '--no_input_skip', default=False, action='store_true',
                    help='do not skip input file parsing')
    


    args = parser.parse_args()

    # base_addr to be added to all the inputs and outputs as is done in the
    # legacy cnn_generic.py script als well
    BASE_ADDR =  0x10_0000_0000 #

    overlay = BaseOverlay(args.bitstream, ignore_version=True)

    print("Changing Working Directory...")
    os.chdir(args.working_directory)
    print("\tPWD: ", os.getcwd())

    # clean up old working directory
    print("Removing old results...")
    for f in glob.glob("../*.log"):
        os.remove(f)
    shutil.rmtree("../emu_results/", ignore_errors=True)

    # open serial interface for logging
    # serial output -> uart capture of prints of risc-v
    import serial, time
    
    ser = None
    try:
        ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=0.35)
        time.sleep(0.1)  # I... am... slow,... need... more... time...
        print("[UART] Using Serial: " + ser.name)  # check which port was really used
        ser.reset_input_buffer()
    except Exception as err:
        print('Could not open UART serial interface. No logging will be performed.')
        print(f"{err=}, {type(err)=}")


    # start the whole processing pipeline
    from iolibs.io_base_types import VPROInputProvider, VPROOutputHandler, VPROIODataHandler
    # create input_provider instance as defined by params
    # (check if we have params to pass to init call)
    input_provider_handler = get_class(args.vpro_input_provider)
    vpro_input_provider : VPROInputProvider = input_provider_handler(**dict(args.input_provider_params)) if args.input_provider_params else input_provider_handler()
    # create output_handler instance as defined by params
    # (check if we have params to pass to init call)
    output_handler_handler = get_class(args.vpro_output_handler)
    vpro_output_handler : VPROOutputHandler = output_handler_handler(**dict(args.output_handler_params)) if args.output_handler_params else output_handler_handler()

    vpro_algo_demo = VPROIODataHandler(
        vpro_input_provider,
        [vpro_output_handler],
        overlay,
        args.binary,
        args.input,
        BASE_ADDR=BASE_ADDR,
        provide_clean_output=False,
        max_execution_time=args.max_execution_time
    )
    vpro_algo_demo.run()




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

    # capture output of serial interface
    if ser is not None:
        byte = ser.read(6400000)  # timeout (Serial() will end read)
        # result = byte.decode(encoding='ascii', errors='strict')
        filename = args.binary + str(args.clusters) + "c" + str(args.units) + "u_onHW_" + str(clusters) + "c" + str(
            units) + "u.log"
        print("Saving log to: ", filename)
        with open(filename, "wb") as f:
            # f.write("Created on "+creation_day+" at "+creation_time+"\n")
            f.write(byte)
            # f.write(result)



