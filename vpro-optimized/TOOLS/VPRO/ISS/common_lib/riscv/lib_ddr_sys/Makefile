
PREFIX=riscv32-unknown-elf

SRC = crt0.S handlers.S syscalls.c vectors.S
OBJ = crt0.o handlers.o syscalls.o vectors.o
LIBCV-VERIF = libcv-verif.a
CFLAGS ?= -O3 -g -static -mabi=ilp32 -march=rv32im_zicsr -Wall -pedantic
CFLAGS += -DNDEBUG # removes asserts
# to disable warning: ...has a LOAD segment with RWX permissions
# add to specific application flags:
#   -Wl,--no-warn-execstack -Wl,--no-warn-rwx-segments


all: vars $(LIBCV-VERIF)

$(LIBCV-VERIF): $(OBJ)
	${RISCV}/bin/${PREFIX}-ar rcs $@ $(OBJ)

%.o : %.c
	${RISCV}/bin/${PREFIX}-gcc $(CFLAGS) -c $< -o $@

%.o : %.S
	${RISCV}/bin/${PREFIX}-gcc $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJ) $(LIBCV-VERIF)


vars:
	@echo "make RISC-V Library variables:"
	@echo "   CV_SW_TOOLCHAIN  = $(CV_SW_TOOLCHAIN)"
	@echo "   RISCV            = $(RISCV)"
	@echo "   RISCV_EXE_PREFIX = $(RISCV_EXE_PREFIX)"
	@echo "   RISCV_GCC        = $(RISCV_GCC)"
