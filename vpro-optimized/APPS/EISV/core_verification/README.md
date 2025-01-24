# Modules
module load questasim/2021.3 riscv-toolchain/gcc-rv32im-vpro

# core_verification

Python VPRO ISS Verification example call
> python run_iss_tests.py --sim-lib-dir ~/iss/iss_lib --aux-lib-dir ~/iss/common_lib (-t ADD.cpp)

## Setup 
* clone this repo to APPS/EISV/core_verification
* cd core_verification/test_frameworks
    * git clone https://github.com/riscv-non-isa/riscv-arch-test.git riscv-compliance
    * cd riscv-compliance
    * git checkout 9141cf9274b610d059199e8aa2e21f54a0bc6a6e
* you need riscv toolchain:
    * corev-openhw-gcc-ubuntu2004-20211104
    * wget https://buildbot.embecosm.com/job/corev-gcc-ubuntu2004/3/artifact/corev-openhw-gcc-ubuntu2004-20211104.tar.gz
    * oder auf compute-gpu-bum: module load riscv-toolchain
* cd core_verification
    * ./init.sh
    * repeat ./init.sh until this message comes: 
        * ln: failed to create symbolic link 'eisv/eisv-target': File exists
* cd core_verification/test_frameworks/eisv-target/device/rv32i_m/VPRO
    * edit Makefile.include 
        * line 19/20: set path to riscv toolchain 

## Running
* setup your EISV/VPRO config at SYS/axi/scripts/axi_eisv_subsystem/.env
* cd core_verification/test_frameworks
    * make prepare
        * this will call the export simulation script at SYS/axi/scripts/axi_eisv_subsystem
    * make clean
    * make vpro
