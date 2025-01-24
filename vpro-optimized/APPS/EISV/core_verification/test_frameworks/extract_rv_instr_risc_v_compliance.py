
import os
import argparse

parser = argparse.ArgumentParser(description='Count all number of instructions for all s in a directory',
                                 formatter_class=argparse.ArgumentDefaultsHelpFormatter)
parser.add_argument('-dir', '--directory', default='riscv-compliance/riscv-test-suite/rv32i_m/I/src',
                    help='the directory with the source files')
parser.add_argument('-result', '--resultsfile', default='instruction_count_results.csv',
                    help='the result file')
args = parser.parse_args()




for filename in os.scandir(args.directory):
    if filename.is_file():
        os.system("python3 extract_rv_instr_from_assembly.py --testfile "+filename.path+" --resultsfile "+args.resultsfile)
