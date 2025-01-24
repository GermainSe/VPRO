# cnn_yololite

## Requirements

##### Tools:
- build-tools
- cmake
- qt (GUI of ISS)
- gcc for risc-v (binary for hardware)



##### Repos:
- ISS (common_lib, linker script, ISS)
    Makefile (binary for hardware): LIB_DIR=../../../../TOOLS/VPRO/ISS/common_lib/riscv/lib_ddr_sys/
    CMakeLists (ISS): Path referenced from lib.cnf

## Compile and run ISS:

- `cd cnn_yolo_lite_hw`
- `make release`

## Compile and run on Hardware:

- `cd cnn_yolo_lite_hw`
- `make allc` (all clean)

## VPRO Array Parameters:
- cnn_yolo_lite_hw/Makefile (CLUSTERS/UNITS)
    Application uses arrays to store executed commands. If selected number of Clusters & Units is not yet adopted, the array dimensions have to be fixed. Configuration_generation (generates the content of the command arrays) will determine the needed array sizes and fills them with the commands for the vpro
- bin/... holds (binary/hex) files with initialization for hardware and command lists in text-format (for debug)
