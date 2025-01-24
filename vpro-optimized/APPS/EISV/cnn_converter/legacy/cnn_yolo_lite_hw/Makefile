# Helper for running cmake in the build folder "build"

#-------------------------------------------------------------------------------
# Make defaults
#-------------------------------------------------------------------------------
.SUFFIXES:
# .phony: always build these targets (no "is up to date" message)
.PHONY: help all allc  clean asm install install_local main.bin
.DEFAULT_GOAL := help

install:
	scp bin/*.bin aldec:/home/xilinx/EIS-V_bin/cnn/
	scp bin/data/*.bin aldec:/home/xilinx/EIS-V_bin/cnn/data/

#-------------------------------------------------------------------------------
# Hardware definitions
#-------------------------------------------------------------------------------
# VPRO
CLUSTERS	?= 8
UNITS		?= 8
LANES		?= 2
# DCMA
NR_RAMS		?= 16
LINE_SIZE	?= 1024
ASSOCIATIVITY	?= 4

APP_NAME	?= "TemplateApp"
STANDALONE	?= 1
SILENT ?=
SAVE_OUTPUT ?=

# Paths for HW
LIB_DIR?=../../../../../TOOLS/VPRO/ISS/common_lib/riscv/lib_ddr_sys/
#LIB_DIR=../../../../TOOLS/VPRO/ISS/common_lib/riscv/lib_bram_eisv/
PREFIX?=${RISCV}/bin/riscv32-unknown-elf

#-------------------------------------------------------------------------------
# Application definitions
#-------------------------------------------------------------------------------
build ?= build
build_release ?= build_release

current_dir = $(shell pwd)
PROJECT_NAME ?= $(current_dir)

# pass configuration as parameters to cmake script
ISS_FLAGS=-DCLUSTERS=${CLUSTERS} -DUNITS=${UNITS} -DLANES=${LANES} -DPROJECT=${PROJECT_NAME}
ISS_FLAGS += -DNR_RAMS=${NR_RAMS} -DLINE_SIZE=${LINE_SIZE} -DASSOCIATIVITY=${ASSOCIATIVITY}
ISS_FLAGS += -DAPP_NAME=${APP_NAME} -DREPO_DIR=${REPO_DIR}
ifeq (${STANDALONE},0)
	ISS_FLAGS+= -DISS_STANDALONE=0
else
	ISS_FLAGS+= -DISS_STANDALONE=1
endif

#-------------------------------------------------------------------------------
# Tools / Paths for RISC-V Compile
#-------------------------------------------------------------------------------
HW_FLAGS= -O3 -static -mabi=ilp32 -march=rv32im -Wall -pedantic # -mdiv <- no difference
#HW_FLAGS+= -mcpu=sifive-e31 <- no difference
#HW_FLAGS+= -misa-spec=2.2 <- no difference (default: 20191213)
HW_FLAGS+= -std=c++2a -std=gnu++20	# std for use of C++20, gnu extensions for e.g. stdint (uint, ...)
HW_FLAGS+= -nostartfiles	# -mbranch-cost=3 <- no difference in generated code 2 / 3 / none (0?)
#HW_FLAGS+= -DNDEBUG # removes asserts
HW_FLAGS+= -T ${LIB_DIR}/link.ld -L ${LIB_DIR} -lcv-verif
HW_FLAGS+= -I ${RISCV}/riscv32-unknown-elf/include/
HW_FLAGS+= -I ${LIB_DIR}/../../../common_lib/
HW_FLAGS+= -I ${LIB_DIR}/../../../iss_lib/
HW_FLAGS+= -I ./includes/
HW_FLAGS+= -I ../cnn_converter/vpro_lib_hw/includes/

# remove unused sections
HW_FLAGS+= -fdata-sections -ffunction-sections
HW_LINK_FLAGS = -Wl,--gc-sections

VPRO_FLAGS = -DNUM_CLUSTERS=${CLUSTERS} -DNUM_VU_PER_CLUSTER=${UNITS} -DNUM_VECTORLANES=${LANES} -DSTAT_COMMENT=${APP_NAME}
VPRO_FLAGS += -DNR_RAMS=${NR_RAMS} -DLINE_SIZE=${LINE_SIZE} -DASSOCIATIVITY=${ASSOCIATIVITY}
HW_FLAGS += ${VPRO_FLAGS}

C_FILES = main.cpp
#C_FILES += $(wildcard sources/*.cpp)
C_FILES += $(wildcard configuration_loader/yolo_configuration.cpp)
C_FILES += $(wildcard ../cnn_converter/vpro_lib_hw/sources/*.cpp)
C_FILES += $(wildcard ${LIB_DIR}/../../../common_lib/vpro/*.cpp)
C_FILES += $(wildcard ${LIB_DIR}/../../../common_lib/riscv/*.cpp)
#C_FILES += $(COMMON_LIB)/mips_aux.cpp $(COMMON_LIB)/vpro_globals.cpp $(COMMON_LIB)/mem_functions.cpp

APP=main
OUT_DIR=bin

#-------------------------------------------------------------------------------
# Help
#-------------------------------------------------------------------------------
# .phony: always build these targets (no "is up to date" message)
.PHONY: help
APP_DIR =	$(shell basename $(CURDIR))
help:
	@echo "VPRO \e[7m\e[1m ${APP_DIR} \e[0m\e[27m application compilation script"
	@echo "Makefile Targets:"
	@echo "--------------------------------------------------------------"
	@echo "Simulation Targets:"
	@echo "  \e[4mdir\e[0m            - creates (empty) build directories"
	@echo "  \e[4msim\e[0m            - compiles application with simulator (debug mode)"
	@echo "                   (gdb, etc. attachable to debug ISS functionality)"
	@echo "                   runs application with GUI"
	@echo "  \e[4mrelease\e[0m        - compiles application with simulator (release mode)"
	@echo "                   runs application with GUI"
	@echo "  \e[4mscripted\e[0m       - compiles application with maximum of 4 threads (release mode)"
	@echo "                   runs application in console mode (no GUI)"
	@echo "--------------------------------------------------------------"
	@echo "Hardware Build Targets (Machine Code):"
	@echo "  \e[4mmain.bin\e[0m       - Generate binary executable from main.elf"
	@echo "  \e[4mmain.objdump|elf|readelf\e[0m            - Print assembly listing from Machine Code (elf)"
	@echo "--------------------------------------------------------------"
	@echo "Hardware Debug:"
	@echo "  \e[4mtest\e[0m           - print input files list"
	@echo "  \e[4mlls\e[0m            - creates all ll files"
	@echo "  \e[4masms\e[0m           - creates all asm files"
	@echo "  \e[4melfs\e[0m           - creates all elf files"
	@echo "--------------------------------------------------------------"
	@echo "Other Targets:"
	@echo "  \e[4mclean\e[0m          - Clean up this directory"
	@echo "  \e[4mhelp\e[0m           - Show this text"
	@echo "--------------------------------------------------------------"

#-------------------------------------------------------------------------------
# Simulator (ISS) Targets
#-------------------------------------------------------------------------------
dir:
	mkdir -p ${build}
	mkdir -p ${build_release}

#	@$(MAKE) -s  -C ${build} sim -j

sim: dir
	cmake -B ${build} -DCMAKE_BUILD_TYPE=Debug ${ISS_FLAGS}
	@$(MAKE) -C ${build} sim -j
	cd ${build} && ./sim

release: dir
	cmake -B ${build_release} -Wno-dev -DCMAKE_BUILD_TYPE=Release ${ISS_FLAGS}
	$(MAKE) -s  -C ${build_release} sim -j
	cd ${build_release} && ./sim ${SILENT} ${SAVE_OUTPUT} && exit 200 || echo "Exit Code was: $? (Error if no 2/3 -> recompile for updated command segment config)"
	# if already successfully, makefile will return with code 200
	-mv configuration_loader/yolo_configuration.h.tmp configuration_loader/yolo_configuration.h
	cmake -B ${build_release} -Wno-dev -DCMAKE_BUILD_TYPE=Release ${ISS_FLAGS}
	$(MAKE) -s  -C ${build_release} sim -j
	cd ${build_release} && ./sim ${SILENT} ${SAVE_OUTPUT}  &&  echo "Execution Done"

# slow configuration. only 4 threads
# set in defines.h: calc vpro, compare
scripted: dir
	cmake -B ${build_release} -Wno-dev -DCMAKE_BUILD_TYPE=Release ${ISS_FLAGS}
	$(MAKE) -s  -C ${build_release} sim -j 4 && echo "Compile Done"
	cd ${build_release} && ./sim --windowless && exit 200 || echo "Exit Code was: $? (Error if no 2/3 -> recompile for updated command segment config)"
	# if already successfully, makefile will return with code 200
	-mv configuration_loader/yolo_configuration.h.tmp configuration_loader/yolo_configuration.h
	cmake -B ${build_release} -Wno-dev -DCMAKE_BUILD_TYPE=Release ${ISS_FLAGS}
	$(MAKE) -s  -C ${build_release} sim -j 4 &&  echo "Compile with updated config Done"
	cd ${build_release} && ./sim --windowless &&  echo "Execution Done"


#-------------------------------------------------------------------------------
# Special for CNN. Generation Application
#-------------------------------------------------------------------------------
config: dir main.readelf
	@mkdir -p bin/data
	@echo "\n\nMakefile: cnn vpro app (config), CLUSTERS: ${CLUSTERS}, UNITS: ${UNITS}\n\n"
	cmake -B ${build} ${ISS_FLAGS}
	@$(MAKE) -s  -C ${build} Generate_configuration -j
	cd ${build} && ./Generate_configuration


${OUT_DIR}/data/YOLO_config_segments.bin: config
${OUT_DIR}/data/YOLO_config_weights.bin: config
${OUT_DIR}/data/YOLO_config_layers.bin: config
${OUT_DIR}/data/input0.bin:
	cp data/input0.bin $@
${OUT_DIR}/data/input1.bin:
	cp data/input1.bin $@
${OUT_DIR}/data/input2.bin:
	cp data/input2.bin $@

include Makefile.segsplit.inc

#-------------------------------------------------------------------------------
# Application VPRO Hardware / Machine Code Targets
#-------------------------------------------------------------------------------

${APP}.elf: ${OUT_DIR}/${APP}.elf
${APP}.hex: ${OUT_DIR}/${APP}.hex
${APP}.32hex: ${OUT_DIR}/${APP}.32hex
${APP}.readelf: ${OUT_DIR}/${APP}.readelf
${APP}.bin: ${OUT_DIR}/${APP}.bin
${APP}.objdump: ${OUT_DIR}/${APP}.objdump

# to debug
test:
	@echo "#####################################################################"
	@echo "\e[7mInput Source Files to compile:\e[0m"
	@$(foreach file,$(C_FILES),echo $(file);)
	@echo ""
	@echo "#####################################################################"
	@echo "\e[7mHW Flags:\e[0m"
	@echo $(HW_FLAGS)
	@echo ""
	@echo "#####################################################################"
	@echo "\e[7mCreate Disassembly/asm by: $(PREFIX)-objdump -SlCwrd ${APP}.elf\e[0m"
	@echo "#####################################################################"

hw-lib:
	make -s -C ${LIB_DIR} clean
	make -C ${LIB_DIR} all

${OUT_DIR}/${APP}.elf: hw-lib
	mkdir -p ${OUT_DIR}
	rm -f configuration_loader/yolo_configuration.h.bak
	rm -f configuration_loader/yolo_configuration.h.tmp
	${PREFIX}-g++ ${HW_FLAGS} $(C_FILES) -o $@ ${HW_LINK_FLAGS}

${OUT_DIR}/${APP}.hex: ${OUT_DIR}/${APP}.bin
	mkdir -p ${OUT_DIR}
	xxd -g 4 $< | cut -d " " -f 2-5 > $@
#   -g 4 byte groups (32-bit) for imem word size
#   -e little endian byte order
#   cut removes address and ascii tranlsation
#
#	${RISCV}/bin/${PREFIX}-objcopy -O verilog $< $@
# [Info] dump of binary file in hex format to be loaded in simulation
#        .tcl Command: mem load -infile /.../fibonacci.hex -format hex -truncate /tb/design_1_i/InstructionRAM/U0/ram_inst/ram
# [Note] objcopy not used, due to address jumps (@...). Adress is byte-wise but interpreted element-wise by questa

${OUT_DIR}/${APP}.32hex: ${OUT_DIR}/${APP}.bin
	xxd -g 4 -c 4 $< | cut -d " " -f 2-2 > $@

${OUT_DIR}/${APP}.readelf: ${OUT_DIR}/${APP}.elf
	mkdir -p ${OUT_DIR}
	${PREFIX}-readelf --sym-base=16 -a $< > $@

${OUT_DIR}/${APP}.objdump: ${OUT_DIR}/${APP}.elf
	mkdir -p ${OUT_DIR}
	${PREFIX}-objdump -d -M no-aliases -M numeric -S $< > $@

${OUT_DIR}/${APP}.bin: ${OUT_DIR}/${APP}.elf
	mkdir -p ${OUT_DIR}
	${PREFIX}-objcopy -O binary -R .vproimage -R .nobss $< $@
	# swap endianness
	objcopy -I binary -O binary --reverse-bytes=4 $@ $@
	${PREFIX}-size $<


#-------------------------------------------------------------------------------
# all goals
#-------------------------------------------------------------------------------

all: mm_init_file mm_init_file.bin ${APP}.hex ${APP}.32hex ${APP}.bin ${APP}.readelf ${APP}.objdump
allc: clean all

#-------------------------------------------------------------------------------
# Clean-up
#-------------------------------------------------------------------------------
# .phony: always build these targets (no "is up to date" message)
.PHONY: clean clean_sim clean_hw clean_sim_all
clean: clean_sim_all clean_hw
clean_hw:
	@echo "\n\tCleaning up Hardware workspace..."
	rm -f configuration_loader/*.bak
	rm -f configuration_loader/*.tmp
	rm -rf bin/
	rm -f *.hex
	rm -f *.bin
	rm -f *.elf
	rm -f *.readelf
	rm -f *.objdump
	make -C ${LIB_DIR} clean

#	@echo "Cleaning up Simulator workspace..."
#	@$(MAKE) -s  -C ${build} clean

clean_sim_all:
	@echo "\n\tCleaning up Simulator workspace..."
	rm -rf ${build}
	rm -rf ${build_release}*
	rm -rf cmake-build-*
	rm -rf init/archive/*.cfg.old
	rm -rf exit/archive/*.cfg.old
	rm -rf data/statistic_out.csv
	rm -rf data/sim_cmd_history.log
	rm -rf data/out*.bin
	rm -rf data/out*.bmp
	rm -rf scripts/log/*.log

clean_sim: clean_sim_all cp

#-------------------------------------------------------------------------------
# eof
