
import os
import argparse

parser = argparse.ArgumentParser(description='Compile a assembly for RISC-V and counts the number of instructions',
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-file', '--testfile', default='add_test.S',
                    help='the assembly test case file')
parser.add_argument('-result', '--resultsfile', default='instruction_count_results.csv',
                    help='the result file')
args = parser.parse_args()

print("Compiling:        ", args.testfile)
print("Running in:       ", os.getcwd())
print("Result Append to: ", args.resultsfile)

tmp_dir = os.getcwd()+"/riscv-compliance/work/"

test = args.testfile.split(".S")[0].split("/")[-1]
source_file = args.testfile
elf_file =  tmp_dir + test + ".elf"
objdump_file = tmp_dir + test + ".elf.objdump"
size_file = tmp_dir + test + ".size"

compile_s = "/opt/riscv/gcc-rv32im-vpro/bin/riscv32-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 -DXLEN=32 -static -mcmodel=medany -fvisibility=hidden -nostdlib -nostartfiles " + \
    "-DBITWIDTH_REDUCE_TO_16_BIT=0 -DPRIV_MISA_S=0 -DPRIV_MISA_U=0 " + \
	"-I" + os.getcwd() + "/riscv-compliance/riscv-test-env/ " + \
	"-I" + os.getcwd() + "/riscv-compliance/riscv-test-env/p/ " + \
	"-I" + os.getcwd() + "/riscv-compliance/riscv-target/eisv/ " + \
    "-I../../../TOOLS/VPRO/ISS/iss_lib/ " + \
    "-T" + os.getcwd() + "/riscv-compliance/riscv-target/eisv/device/rv32imc/link.ld " + \
    source_file + " " + \
    "-o " + elf_file

#    "-DTRAPHANDLER=\"riscv-compliance/riscv-target/eisv/device/rv32imc/handler.S\" " + \

compile_cpp = "/opt/riscv/gcc-rv32im-vpro//bin/riscv32-unknown-elf-g++ -march=rv32im_zicsr -mabi=ilp32 -DXLEN=32 -O3 -static -mabi=ilp32 -march=rv32im -Wall -pedantic -nostartfiles -DNDEBUG -finline-functions -fdata-sections -ffunction-sections " + \
    "-T" + os.getcwd() + "/riscv-compliance/../../../../../TOOLS/VPRO/ISS/common_lib/riscv/lib_ddr_sys/link.ld "+ \
	"-L " +	os.getcwd() + "/riscv-compliance/../../../../../TOOLS/VPRO/ISS/common_lib/riscv/lib_ddr_sys -lcv-verif " + \
	"-I/opt/riscv/gcc-rv32im-vpro//riscv32-unknown-elf/include/ " + \
	"-I../../../../../TOOLS/VPRO/ISS/common_lib/ " + \
	"-I../../../../../TOOLS/VPRO/ISS/iss_lib/ " + \
	"-Wno-array-bounds -DBITWIDTH_REDUCE_TO_16_BIT=0 -std=c++2a -std=gnu++20 " + source_file + \
    " -o " + elf_file + \
    "-Wl,--gc-sections"

gen_objdump = "/opt/riscv/gcc-rv32im-vpro//bin/riscv32-unknown-elf-objdump -d "+ elf_file + " > " + objdump_file

gen_size = "/opt/riscv/gcc-rv32im-vpro//bin/riscv32-unknown-elf-size "+ elf_file + " > " + size_file

#print(compile_s)
#print(gen_objdump)
#print(gen_size)

os.system(compile_s + " > compile_log 2>&1")
#os.system(gen_objdump)
os.system(gen_size)

#print("Reading generated Instructions (size)")
with open(size_file, 'r') as f:
	last_line = f.readlines()[-1].strip()
	test_size = last_line.split(" ")[0]

	instruction_count = int(int(test_size) / 4)

	print("Instructions:     ", instruction_count)

	with open(args.resultsfile, "a") as o:
		o.write(args.testfile)
		o.write("\t")
		o.write(str(instruction_count))
		o.write("\n")
