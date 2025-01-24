import argparse
import os

if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument("-p", "--path", help="Path to Execution Log.", required=True)

    args = parser.parse_args()
    file = open(os.path.join(args.path, "instruction.log"), "r")
    lines = file.readlines()
    file.close()

    testInstrString = "Test Instructions executed  :"
    TOTAL_INSTR = "Total Instructions Generated:"
    instrCount = 0
    totalInstr = 0
    for line in lines:
        if testInstrString in line:
            instrCount += int(line.split(testInstrString)[1])
        if TOTAL_INSTR in line:
            totalInstr += int(line.split(TOTAL_INSTR)[1])

    file = open(os.path.join(args.path, "TestInstructionCount.log"), "w")
    file.write("Test-cases executed: " + str(instrCount))
    file.write("\nTotal Instructions : " + str(totalInstr))
    file.close()
