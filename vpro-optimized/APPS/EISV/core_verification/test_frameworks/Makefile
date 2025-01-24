
default: all

SHELL:=/bin/bash

# defines the number of parallel simulations to be executed
PARALLEL_RUNS?=8

#SYSTEM_SIM_PROJECT_DIR?=SYS/axi/scripts/axi_eisv_system_zu19eg/
SYSTEM_SIM_PROJECT_DIR?=SYS/axi/scripts/axi_eisv_system_zu19eg_behave/

# 16/24-bit:
#   use 16-bit datawidth when running behavioral simulation
#   generate correct reference data
BITWIDTH_REDUCE_TO_16_BIT = $(shell bash -c "if [[ \"${SYSTEM_SIM_PROJECT_DIR}\" == *\"behave\"* || \"${SYSTEM_SIM_PROJECT_DIR}\" == *\"asic\"* ]]; then echo 1; else echo 0; fi;")
$(info BITWIDTH_REDUCE_TO_16_BIT: ${BITWIDTH_REDUCE_TO_16_BIT})

prepare:
	cd .. && ./init.sh && cd -
	make -C ../../../../${SYSTEM_SIM_PROJECT_DIR} sim_export
	make -C ../../../../SYS/axi/scripts/axi_eisv_bram sim_export

all: i c m
# Zifencei privilege

i:
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance RISCV_TARGET=eisv RISCV_DEVICE=I JOBS=-j${PARALLEL_RUNS}
c:
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance RISCV_TARGET=eisv RISCV_DEVICE=C JOBS=-j${PARALLEL_RUNS}
m:
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance RISCV_TARGET=eisv RISCV_DEVICE=M JOBS=-j${PARALLEL_RUNS}
own:
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance RISCV_TARGET=eisv RISCV_DEVICE=Own JOBS=-j${PARALLEL_RUNS}

patara: clean_patara
	./eisv-patara-tests/generate_patara.sh complete
	./eisv-patara-tests/patara_run_script.sh complete

patara-excessive: clean_patara
	# for coverage extract, check patara_run_script.sh
	./eisv-patara-tests/generate_patara.sh excessive
	eisv-patara-tests/patara_run_script.sh excessive


patara-minibatch:
	# used for interal usage
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance RISCV_TARGET=eisv RISCV_DEVICE=Patara JOBS=-j${PARALLEL_RUNS}

patara-sources:
	# run all assembly files in src
	eisv-patara-tests/patara_run_script.sh


REF_COUNT=$(shell ls eisv-vpro-tests/references/*.reference_output | wc -l)
vpro: vpro_ref
	@echo "Correcting Makefile for VPRO C-Sources"
	@if ! grep -q "from .c" riscv-compliance/riscv-test-suite/Makefile.include; then sed -i '/^\.PRECIOUS.*/i\$$\(work_dir_isa\)\/\%\.elf:\ \$$\(src_dir\)\/\%\.cpp\n\t\$$\(V\) echo -e \"Compile \$$\$$\(\@\)\ \[\\e\[96mfrom \.c\\e\[39m\]\"\n\t\	@mkdir -p \$$\$$\(\@D\)\n\t\$$\(V\) \$$\(COMPILE_TARGET_FROM_CPP\)\n\n\$$\(work_dir_isa\)\/\%\.elf\: \$$\(src_dir\)\/\%\.c\n\t\$$\(V\) echo -e \"Compile \$$\$$\(\@\) \[\\e\[96mfrom \.c\\e\[39m\]\"\n\t\	@mkdir -p \$$\$$\(\@D\)\n\t\$$\(V\) \$$\(COMPILE_TARGET_FROM_C\)\n\n' riscv-compliance/riscv-test-suite/Makefile.include; else echo -e "\tskipped modify of Makefile for c-Codes"; fi
	@echo "Running VPRO Test Cases"
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance BITWIDTH_REDUCE_TO_16_BIT=${BITWIDTH_REDUCE_TO_16_BIT} RISCV_TARGET=eisv RISCV_DEVICE=VPRO JOBS=-j${PARALLEL_RUNS}

vpro_ref:
	@echo "Generating References"
	#@if [[ ${REF_COUNT} -lt 10 ]] ; then make -C eisv-vpro-tests/references BITWIDTH_REDUCE_TO_16_BIT=${BITWIDTH_REDUCE_TO_16_BIT}; else echo -e "\t${REF_COUNT} Reference files already exit!"; fi
	make -C eisv-vpro-tests/references BITWIDTH_REDUCE_TO_16_BIT=${BITWIDTH_REDUCE_TO_16_BIT}
    
VERBOSE?=0
VERBOSE_FLAG=$(shell bash -c "if [[ ${VERBOSE} -eq 1 ]]; then echo \"-v\"; fi;")
$(info VERBOSE_FLAG: ${VERBOSE_FLAG})
vpro_iss:
	@echo "Generating References"
	@if [[ ${REF_COUNT} -lt 10 ]] ; then make -C eisv-vpro-tests/references BITWIDTH_REDUCE_TO_16_BIT=${BITWIDTH_REDUCE_TO_16_BIT}; else echo -e "\t${REF_COUNT} Reference files already exit!"; fi
	@python3 run_iss_tests.py --sim-lib-dir `pwd`/../../../../TOOLS/VPRO/ISS/iss_lib --aux-lib-dir `pwd`/../../../../TOOLS/VPRO/ISS/common_lib ${VERBOSE_FLAG}


.PHONY: copy copy_ref
copy:
	-scp riscv-compliance/work/rv32i_m/Own/*.corrected.bin aldec:/home/xilinx/EIS-V_bin/test_framework/Own/corrected.bin/
	-scp riscv-compliance/work/rv32i_m/I/*.corrected.bin aldec:/home/xilinx/EIS-V_bin/test_framework/I/corrected.bin/
	-scp riscv-compliance/work/rv32i_m/M/*.corrected.bin aldec:/home/xilinx/EIS-V_bin/test_framework/M/corrected.bin/
	-scp riscv-compliance/work/rv32i_m/VPRO/*.corrected.bin aldec:/home/xilinx/EIS-V_bin/test_framework/VPRO/corrected.bin/
#	scp riscv-compliance/work/rv32i_m/C/*.corrected.bin aldec:/home/xilinx/EIS-V_bin/test_framework/C/corrected.bin/
copy_ref:
	-scp riscv-compliance/riscv-test-suite/rv32i_m/Own/references/*.reference_output aldec:/home/xilinx/EIS-V_bin/test_framework/Own/reference/
	-scp riscv-compliance/riscv-test-suite/rv32i_m/I/references/*.reference_output aldec:/home/xilinx/EIS-V_bin/test_framework/I/reference/
	-scp riscv-compliance/riscv-test-suite/rv32i_m/M/references/*.reference_output aldec:/home/xilinx/EIS-V_bin/test_framework/M/reference/
	-scp riscv-compliance/riscv-test-suite/rv32i_m/VPRO/references/*.reference_output aldec:/home/xilinx/EIS-V_bin/test_framework/VPRO/reference/
#	scp riscv-compliance/riscv-test-suite/rv32i_m/C/references/*.reference_output aldec:/home/xilinx/EIS-V_bin/test_framework/C/reference/


# added following to Makefile (sub git):
#$(work_dir_isa)/%.elf: $(src_dir)/%.cpp
#        $(V) echo -e "Compile $$(@) [\e[96mfrom .c\e[39m]"
#        @mkdir -p $$(@D)
#        $(V) $(COMPILE_TARGET_FROM_CPP)
#
#$(work_dir_isa)/%.elf: $(src_dir)/%.c
#        $(V) echo -e "Compile $$(@) [\e[96mfrom .c\e[39m]"
#        @mkdir -p $$(@D)
#        $(V) $(COMPILE_TARGET_FROM_C)


Zifencei:
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance RISCV_TARGET=eisv RISCV_DEVICE=Zifencei JOBS=-j${PARALLEL_RUNS}
privilege:
	-export SYSTEM_SIM_PROJECT_DIR=${SYSTEM_SIM_PROJECT_DIR} && make -C riscv-compliance RISCV_TARGET=eisv RISCV_DEVICE=privilege JOBS=-j${PARALLEL_RUNS}


clean: clean_sim clean_results clean_patara
	rm -f riscv-compliance/work/rv32i_m/VPRO/fails
	-make -C eisv-vpro-tests/references clean

clean_sim:
	mv ../../../../${SYSTEM_SIM_PROJECT_DIR}/simulation/questa ../../../../${SYSTEM_SIM_PROJECT_DIR}/simulation/keep
	rm -rf ../../../../${SYSTEM_SIM_PROJECT_DIR}/simulation/questa*
	mv ../../../../${SYSTEM_SIM_PROJECT_DIR}/simulation/keep ../../../../${SYSTEM_SIM_PROJECT_DIR}/simulation/questa

clean_results:
	-make -C riscv-compliance clean RISCV_TARGET=eisv RISCV_DEVICE=I
	-make -C riscv-compliance clean RISCV_TARGET=eisv RISCV_DEVICE=M
	-make -C riscv-compliance clean RISCV_TARGET=eisv RISCV_DEVICE=Own
	-make -C riscv-compliance clean RISCV_TARGET=eisv RISCV_DEVICE=C
	-make -C riscv-compliance clean RISCV_TARGET=eisv RISCV_DEVICE=VPRO
	-make -C riscv-compliance clean RISCV_TARGET=eisv RISCV_DEVICE=Patara



small_clean:
	rm -rf riscv-compliance/work/rv32i_m/I/add-*
	rm -rf riscv-compliance/work/rv32i_m/I/jalr*
	rm -rf riscv-compliance/work/rv32i_m/I/srli*
	rm -rf riscv-compliance/work/rv32i_m/I/sw*
	rm -rf riscv-compliance/work/rv32i_m/I/lw*
	rm -rf riscv-compliance/work/rv32i_m/I/lh*
	rm -rf riscv-compliance/work/rv32i_m/I/beq*



clean_patara:
	rm -rf eisv-patara-tests/src
	rm -rf eisv-patara-tests/errors
	rm -rf eisv-patara-tests/coverage
	cp eisv-patara-tests/Makefrag.ref eisv-patara-tests/Makefrag
	rm -f ../../../../SYS/axi/scripts/axi_eisv_system_zu19eg_behave/coverage.ucdb
	rm -f ../../../../SYS/axi/scripts/axi_eisv_system_zu19eg_behave/.backup.cov.ucdb
	rm -fr eisv-patara-tests/reversiAssembly/
