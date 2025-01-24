
PREFIX?=${RISCV}/bin/riscv32-unknown-elf

LIB_DIR=../../../../TOOLS/VPRO/ISS/common_lib/riscv/lib_ddr_sys/
#LIB_DIR=../../../../TOOLS/VPRO/ISS/common_lib/riscv/lib_bram_eisv/

HW_FLAGS= -O3 -static -mabi=ilp32 -march=rv32im_zicsr -Wall -pedantic
HW_FLAGS+= -std=c++2a -std=gnu++20	# std for use of C++20, gnu extensions for e.g. stdint (uint, ...)
HW_FLAGS+= -nostartfiles
HW_FLAGS+= -T ${LIB_DIR}/link.ld -L ${LIB_DIR} -lcv-verif
HW_FLAGS+= -I ${RISCV}/riscv32-unknown-elf/include/
HW_FLAGS+= -I ${LIB_DIR}/../../../common_lib/
HW_FLAGS+= -I ${LIB_DIR}/../../../iss_lib/
HW_FLAGS+= -I ./includes/

# remove unused sections
HW_FLAGS+= -fdata-sections -ffunction-sections
HW_LINK_FLAGS = -Wl,--gc-sections

CLUSTERS	?= 2
UNITS		?= 4
LANES		?= 2
VPRO_FLAGS = -DNUM_CLUSTERS=${CLUSTERS} -DNUM_VU_PER_CLUSTER=${UNITS} -DNUM_VECTORLANES=${LANES} -DSTAT_COMMENT=${APP_NAME}
HW_FLAGS+= ${VPRO_FLAGS}

C_FILES = fibonacci.cpp
#C_FILES += $(wildcard sources/*.cpp)
C_FILES += $(wildcard ${LIB_DIR}/../../../common_lib/vpro/*.cpp)
C_FILES += $(wildcard ${LIB_DIR}/../../../common_lib/riscv/*.cpp)

APP=fibonacci
OUT_DIR=.

all: clean hw-lib ${OUT_DIR}/${APP}.objdump ${OUT_DIR}/${APP}.readelf ${OUT_DIR}/${APP}.hex ${OUT_DIR}/${APP}.32hex copy

copy: ${APP}.bin
	scp $< aldec:/home/xilinx/EIS-V_bin/$<

${APP}.elf: ${OUT_DIR}/${APP}.elf
${APP}.hex: ${OUT_DIR}/${APP}.hex
${APP}.readelf: ${OUT_DIR}/${APP}.readelf
${APP}.objdump: ${OUT_DIR}/${APP}.objdump
${APP}.bin: ${OUT_DIR}/${APP}.bin

hw-lib:
	make -s -C ${LIB_DIR} clean
	make -C ${LIB_DIR} all

${OUT_DIR}/${APP}.elf: hw-lib
	mkdir -p ${OUT_DIR}
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
	mkdir -p ${OUT_DIR}
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


clean:
	rm -f *.hex
	rm -f *.bin
	rm -f *.elf
	rm -f *.readelf
	rm -f *.objdump
	rm -f *.32hex
	rm -f *.32bin
	make -C ${LIB_DIR} clean
