# CNN Server

Server for remote upload and execution of VPRO programs without reprogramming the bitstream after every execution.

## Installation

cp *.service /etc/systemd/system/python_fpga_server.service

sudo systemctl enable python_fpga_server.service




## Protocol and Interface

On startup the server creates a unix domain socket `cnn_server.s` which clients can connect to.

Only one connection is accepted at a time to avoid interleaving commands from different client. 
Should one client connect without shutting down the server, other clients can be serviced by the same server.

Commands are sent as single line space delimited strings.
The first part is a verb specifying the operation followed by one or more arguments. 
Because arguments are space delimited, arguments containing spaces themselves are not supported.

## Commands

### `stop`

Gracefully shut down the server, deleting the socket file.

### `init [bitstream]`

Program the PL with the specified bitstream file and initialize the CDMA for transfer.

### `executable [executable]`

Transfer the file executable to the base address.

### `input [input_file]`

Parse the input\_file for lines containing space delimited pairs of `[path] [address]` and upload the files at path to the address.

### `run`

Deasset rest running the application set prior using executable and wait for the GPR running status register ot return to 0 indicating completion of the executed binary.

Dump the output written to the UART by the executable.

### `mkdir`

Create a new temporary directory and returns the absolute path of it.

### `setdir [dir]`

Set the working directory to dir.

### `cleanup`

Delete all subdiretories in the tmp directory.

