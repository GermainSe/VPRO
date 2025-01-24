import socket
import os
import fileinput
import sys
import argparse
import signal
from contextlib import contextmanager

import functools
print = functools.partial(print, flush=True)

class TimeoutException(Exception): pass

HOST_IP = "134.169.33.101"
HOST = "aldec"
PORT = 65432

parser = argparse.ArgumentParser(description='Run an App on EIS-V',
                                formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-b', '--bin', default='./main.bin',
                    help='the Binary')
parser.add_argument('-c', '--clusters', default=8,
                    help='the APP config for number of clusters')
parser.add_argument('-u', '--units', default=8,
                    help='the APP config for number of units')
parser.add_argument('-bit', '--bitstream', default='/home/xilinx/overlays/8c8u_reference_fast.bit',
                    help='the FPGA bitstream file')
parser.add_argument('-t', '--max_execution_time', default=12, type=int,
                    help='the time to capture uart output (capped) in seconds. execution is stopped afterwards and output is copied')
parser.add_argument('-k', '--keep', default=1, type=int,
                    help='Keep the tmp folder (default is to delete it after execution)')

args = parser.parse_args()

BITSTREAM = args.bitstream #"/home/xilinx/overlays/8c8u_reference_fast.bit"
MAX_DURATION = args.max_execution_time  # 12
BIN = args.bin #"../nets/yololite"

# Receive a response from the server
def recvall(sock):
    BUFF_SIZE = 4096 # 4 KiB
    data = b''
    while True:
        part = sock.recv(BUFF_SIZE)
        data += part
        if len(part) < BUFF_SIZE:
            # either 0 or end of data
            break
    return data

client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
client.connect((HOST_IP, PORT))

client.sendall('mkdir\n'.encode())
tmp_dir = str(recvall(client).decode()).replace("\n","")
print("TMP Dir (@aldec):", tmp_dir)

print("Copy binary...")
os.system(f"rsync -avI {BIN} {HOST}:{tmp_dir}/main.bin")
os.system(f"ssh {HOST} 'cd {tmp_dir} && touch input.cfg && touch output.cfg'")
print("Copy Done!")

client.sendall('getFPGA\n'.encode())
current_bitstream = str(recvall(client).decode()).replace("\n","")

init = 'initifnot '+BITSTREAM+'\n'
exe = 'executable '+tmp_dir+'/main.bin\n'

# Send a message to the server
message = init+exe+'input '+tmp_dir+'/input.cfg\n'+ \
'output '+tmp_dir+'/output.cfg\n'+ \
'run '+str(MAX_DURATION)+'\n'+ \
'x\n'
client.sendall(message.encode())


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

try:
    try:
        with time_limit(30):
            response1 = recvall(client)
            print(f'init response: {response1.decode()}')

            response2 = recvall(client)
            print(f'executable response: {response2.decode()}')

            response3 = recvall(client)
            print(f'input response: {response3.decode()}')

            response4 = recvall(client)
            print(f'output response: {response4.decode()}')

            response5 = recvall(client)
            print(f'run response: {response5.decode()}')

    except TimeoutException as e:
        print("Timed out!")
except KeyboardInterrupt:
    print("[CTRL+C received] Exiting...")

#print("Copy Results...")
#os.system(f"rsync -avIrL {HOST}:{tmp_dir}/emu_results {NET}/")

client.sendall('getClusters\ngetUnits\n'.encode())
clusters = str(recvall(client).decode()).replace("\n","")
units = str(recvall(client).decode()).replace("\n","")

if args.keep == 0:
    tmp_folder = tmp_dir.split("/")[-1]
    print(f"Removing Tmp Dir (@aldec; {tmp_folder})...")
    client.shutdown(socket.SHUT_RDWR)
    client.close()
    client = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    client.connect((HOST_IP, PORT))
    client.sendall(f'rmtmpdir {tmp_folder}\n'.encode())
    #print("rmtmpdir command sent")
    try:
        try:
            with time_limit(30):
                response6 = recvall(client)
                print(f'rmdir response: {response6.decode()}')
        except TimeoutException as e:
            print("Timed out!")
    except KeyboardInterrupt:
        print("Exiting...")
else:
    print("Temp Folder with Results @aldec: ", tmp_dir)

logfilename = f"emu_{args.clusters}c{args.units}u_onHW_{clusters}c{units}u.log"
with open(f"{logfilename}", "w") as f:
    f.write(response1.decode())
    f.write(response2.decode())
    f.write(response3.decode())
    f.write(response4.decode())
    f.write(response5.decode())

net_name = NET.split("/")[-1].split(".")[0]
os.system(f"cp {NET}/emu_results/{logfilename} {NET}/emu_{net_name}.log")

# Close the connection
client.close()
