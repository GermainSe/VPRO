
DIR:=$(shell pwd)
install_dir?=install_dir
arch:=rv32im
dollarsign:=\$

help:
	@echo ""
	@echo "Makefile for cloning, configuring and compiling the GNU Compiler Toolchain (GCC)"
	@echo "	 Target: RISC-V ISA ${arch}"
	@echo "    Newlib Included in Build Process (soft-float)"
	@echo "    TODO: Patch to add VPRO Extension to RISC-V"
	@echo "  Current Dir: ${DIR}"
	@echo "  Install Dir: ${DIR}/${install_dir}"
	@echo ""
	@echo "Start: make install_prereq build"
	@echo ""
	@echo "  After Compilation, extend Path:"
	@echo "    export PATH=${dollarsign}PATH:${DIR}/${install_dir}/bin"
	@echo "  For cnn_converter:"
	@echo "    export RISCV=${DIR}/${install_dir} # set RISCV location (PATH not required)"
	@echo "    export -n RV_VPRO_EXT # enable EISV extensions"

clean_all:
	rm -rf riscv-gnu-toolchain
	rm -rf $(install_dir)

clean:
	make -C riscv-gnu-toolchain clean

# RISC-V GNU Toolchain
# required submodules are fetched dynamically by make; fetch binutils here for patching
clone_repos:
	git clone --depth 1 https://github.com/riscv/riscv-gnu-toolchain --branch master --single-branch --recurse-submodules=binutils
	mkdir ${install_dir}

# from https://github.com/riscv-collab/riscv-gnu-toolchain
install_prereq:
	sudo apt-get install autoconf automake autotools-dev curl python3 libmpc-dev libmpfr-dev libgmp-dev gawk build-essential bison flex texinfo gperf libtool patchutils bc zlib1g-dev libexpat-dev ninja-build

# TODO: check --disable-linux + make linux, works without A extensions? full support of c++ std | embedded: newlib is smaller [internet]
compile:
	cd riscv-gnu-toolchain && ./configure --prefix=${DIR}/${install_dir} --with-arch=${arch} --with-abi=ilp32 --enable-multilib --with-multilib-generator="rv32im-ilp32--"
	cd riscv-gnu-toolchain && make -j

apply_vpro_ext:
	cd riscv-gnu-toolchain/binutils && git apply ../../000-VPRO_EXT.patch

build: clone_repos apply_vpro_ext compile
all: build




upgrade_to_latest_sources:
	@echo "!!!! Unstable versions included?"
	cd riscv-gnu-toolchain && git submodule update --remote
