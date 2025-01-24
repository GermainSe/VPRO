import os, os.path
import io
from contextlib import redirect_stdout
import shutil
import sys
import socket
import time
import serial
import tempfile
from pathlib import Path
import logging

# Import VPRO library
VPRO_LIB_LOCATION='/home/xilinx'
sys.path.insert(0, VPRO_LIB_LOCATION)
import vprolib as vpro
from overlays.vpro_sys import BaseOverlay

# get hardware version
from pynq import MMIO

VPRO_LIB_LOCATION='/home/xilinx/vprolib/'
sys.path.insert(0, VPRO_LIB_LOCATION)
from typing import NamedTuple, Iterable, Dict, Tuple
from iolibs.tools import get_class, CfgLayerDescription
from iolibs.io_base_types import VPROInputProvider, VPROOutputHandler, VPROIODataHandler

HOST = "134.169.33.101"
PORT = 65432

TMP_DIR_PREFIX = '/tmp'

import signal
from contextlib import contextmanager

class TimeoutException(Exception): pass

@contextmanager
def time_limit(seconds):
    def signal_handler(signum, frame):
        raise TimeoutException("Timed out!")
    signal.signal(signal.SIGALRM, signal_handler)
    signal.alarm(seconds)
    try:
        yield
    finally:
        signal.alarm(0)
        
def open_socket(context):
    print('Starting cnn server')

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    
    old_state = server.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR) 
    print ("Old sock state: %s" %old_state) 
    
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1) 
    new_state = server.getsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR)
    print ("New sock state: %s" %new_state)      
         
    server.bind((HOST, PORT))
    server.listen(0)
    try:
        while True:
            conn, addr = server.accept()
            print(f'client {addr} connected')
            client_loop(conn, context)
            print("DONE!")
            conn.close()
    except KeyboardInterrupt:        # quit
        server.close()
        sys.exit()

class ClientDisConException(Exception):
    "Client disconnected before receiving response!"
    pass
    
    
# root = logging.getLogger()
# root.setLevel(logging.DEBUG)
#
# handler = logging.StreamHandler(sys.stdout)
# handler.setLevel(logging.DEBUG)
# formatter = logging.Formatter('%(asctime)s - %(name)s - %(levelname)s - %(message)s')
# handler.setFormatter(formatter)
# root.addHandler(handler)
    
def client_loop(conn, context):
    file = conn.makefile()
    while True:
        # TODO: what if command not finishes with \n -> do not hang up!
        line = file.readline()
        if len(line) == 0:
            return

        command = line.rstrip()
        print(f'received command "{command}"')

        command_parts = command.split()
        print(command_parts)

        if len(command_parts) == 0:
            continue

        verb = command_parts[0].strip() #.lower()
        
        try:
            if verb == 'stop':
                context.cleanup()
                exit(0)
            elif verb == 'init':
                bitstream = command_parts[1] # TODO: Maybe check if file exists
                output = context.initialize(bitstream)
                try:
                    conn.send(f'Initialized device with bitstream {bitstream}. Log: \n{output}\n'.encode())
                except Exception as e:
                    print(e)
                    raise ClientDisConException
            elif verb == 'initifnot':
                bitstream = command_parts[1].strip()
                if context.bitstream != bitstream:
                    output = context.initialize(bitstream)
                    try:
                        conn.send(f'Initialized device with bitstream {bitstream}. Log: \n{output}\n'.encode())
                    except Exception as e:
                        print(e)
                        raise ClientDisConException
            elif verb == 'getFPGA':
                conn.send(f'{context.bitstream}\n'.encode())
            elif verb == 'getUnits':
                conn.send(f'{context.units}\n'.encode())
            elif verb == 'getClusters':
                conn.send(f'{context.clusters}\n'.encode())
                print(context.bitstream)
            elif verb == 'executable':
                executable = command_parts[1] # TODO: Maybe check if file exists
                context.upload_executable(executable)
                try:
                    conn.send(f'Executable: {executable}\n'.encode())
                except Exception as e:
                    print(e)
                    raise ClientDisConException
            elif verb == 'input':
                input_file = command_parts[1]
                context.load_input(input_file)
                try:
                    conn.send(f'Input File: {input_file}\n'.encode())
                except Exception as e:
                    print(e)
                    raise ClientDisConException
            elif verb == 'output':
                output_file = command_parts[1]
                context.load_output(output_file)
                try:
                    conn.send(f'Output File: {output_file}\n'.encode())
                except Exception as e:
                    print(e)
                    raise ClientDisConException
            elif verb == 'run':
                duration = command_parts[1]
                try:
                    conn.send(context.run(duration).encode())
                except Exception as e:
                    print(e)
                    raise ClientDisConException
            elif verb == 'x':
                try:
                    conn.send(f'Exit.\n'.encode())
                except Exception as e:
                    print(e)
                    raise ClientDisConException
                return
            elif verb == 'mkdir':
                dir = tempfile.mkdtemp(dir=TMP_DIR_PREFIX)
                os.chmod(dir, 0o777)
                try:
                    conn.send(f'{dir}\n'.encode())
                except Exception as e:
                    print(e)
                    raise ClientDisConException
            elif verb == 'setdir':
                dir = command_parts[1]
                os.chdir(dir)
            elif verb == 'rmtmpdirs':
                os.system(f'rm -r {TMP_DIR_PREFIX}/*')
            elif verb == 'rmtmpdir':
                if len(command_parts) < 2:
                    print("[Error in CMD] rmtmpdir without dir!")
                    conn.send('[Error in CMD] rmtmpdir without dir!\n'.encode())
                    continue
                d = command_parts[1].strip().lower()
                assert(TMP_DIR_PREFIX != "")
                assert(d != "")
                os.system(f'rm -r {TMP_DIR_PREFIX}/{d}')
                conn.send(f'[Directory removed] {TMP_DIR_PREFIX}/{d}!\n'.encode())
            elif verb == 'clearFPGA':
                context.cleanup()
            else:
                pass
        except ClientDisConException:
            print("Client disconnected before receiving response!")

class VPROContext:

    def __init__(self):
        self.executable = "unknown"
        self.input_file = "unknown"
        self.output_file = "unknown"
        self.bitstream = "none"
        self.units = -1
        self.clusters = -1 
        pass
        
    def cleanup(self):
        del self.input_buffer
        self.bitstream = "none"

    def initialize(self, bitstream):
        '''
        Program the device with the specified bistream and perform initialization.
        '''
        try:
            self.cleanup()
        except Exception as e:
            print(e)
        self.bitstream = bitstream
        self.overlay = BaseOverlay(bitstream, ignore_version=True)
        self.input_buffer = vpro.try_allocate(128 * 1024 * 1024)
        self.cdma = vpro.CDMA()
        self.cdma.init(self.overlay.ip_dict['axi_cdma_0']['phys_addr'])
        self.clusters, self.units = vpro.get_vpro_clusters_and_units()
        
        output = ""
        with io.StringIO() as buf, redirect_stdout(buf):
            vpro.set_reset()
            vpro.print_infos()
            output = buf.getvalue()

        self.ser = None
        try:
            self.ser = serial.Serial('/dev/ttyUSB0', 115200, timeout=0.35)
            time.sleep(0.1)  # I... am... slow,... need... more... time...
            print("[UART] Using Serial: " + self.ser.name)  # check which port was really used
            self.ser.reset_input_buffer()
        except Exception as err:
            print('Could not open UART serial interface. No logging will be performed.')
            print(f"{err=}, {type(err)=}")
            
        return output;

    def upload_executable(self, executable):
        self.executable = executable

    def load_input(self, input_file):
        self.input_file = input_file

    def load_output(self, output_file):
        self.output_file = output_file

    def run(self, duration):
        '''
        After the specified maximal duration, read the uart output and activate the reset again.
        '''
           
        try:
            with time_limit(int(duration) + 15):     
                origin_dir = os.getcwd()
                #os.chdir("/home/xilinx/EIS-V_bin/cnn_generic/emu_results")
                
                # start the whole processing pipeline
                # create input_provider instance as defined by params
                # (check if we have params to pass to init call)
                input_provider_handler = get_class('iolibs.io_default_types.VPROInputFileLoader')
                vpro_input_provider : VPROInputProvider = input_provider_handler(**dict([['input_cfg_file_name',self.input_file]]))
                # create output_handler instance as defined by params
                # (check if we have params to pass to init call)
                output_handler_handler = get_class('iolibs.io_default_types.DefaultVPROOutputFileWriter')
                vpro_output_handler : VPROOutputHandler = output_handler_handler(**dict([['output_cfg_file_name',self.output_file]]))
                
                vpro_algo_demo = VPROIODataHandler(
                    vpro_input_provider,
                    [vpro_output_handler],
                    self.overlay,
                    self.executable,
                    self.input_file,
                    BASE_ADDR=0x10_0000_0000,
                    provide_clean_output=True,
                    max_execution_time=int(duration),
                    input_buffer=self.input_buffer,
                    output_buffer=self.input_buffer
                )
                vpro_algo_demo.run()

                vpro_axi_slave = MMIO(0x00_8003_0000, 0x1_0000)
                # clusters = int(vpro_axi_slave.read(12))
                # units = int(vpro_axi_slave.read(16))

                # dump debug fifo entries
                entries = 0
                debug_fifo_string = ""
                while vpro_axi_slave.read(44) != 0 and entries < 100:
                    d = vpro_axi_slave.read(40)
                    debug_fifo_string += "\t" + str(entries).ljust(3) + " Debug Fifo Entry: " + str(d).ljust(11) + "|" + hex(d)
                    entries += 1
                debug_fifo_string += "\tDebug Fifo Entries: " + str(entries).ljust(21)

                # save uart as log to named file
                # creation_day = date.today().strftime("%d/%m/%Y")
                # creation_time = datetime.now().strftime("%H:%M:%S")

                # capture output of serial interface
                byte = "[NO UART OUTPUT CAPTURED!]"
                if self.ser is not None:
                    byte = self.ser.read(6400000)  # timeout (Serial() will end read)
                    byte = byte.decode(errors='ignore') #(encoding='ascii', errors='strict')
            
                os.chdir(origin_dir)
        except TimeoutException as e:
            print("Run (Max Duration: "+str(duration)+"s) Timed out!")
            return "Run (Max Duration: "+str(duration)+"s) Timed out!"
        
        return str(byte) + str(debug_fifo_string)
    
if __name__ == '__main__':
    vpro_context = VPROContext()
    open_socket(vpro_context)

