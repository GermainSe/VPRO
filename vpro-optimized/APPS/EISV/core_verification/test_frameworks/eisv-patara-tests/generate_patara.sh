#!/bin/bash
NONE='\033[00m'
RED='\033[01;31m'
GREEN='\033[01;32m'
YELLOW='\033[01;33m'
PURPLE='\033[01;35m'
CYAN='\033[01;36m'
WHITE='\033[01;37m'
BOLD='\033[1m'
UNDERLINE='\033[4m'

PATARA_DIR=`pwd`/../patara
SRC_DIR=`pwd`/eisv-patara-tests/

# basic                   - 6983    asm lines - 5min    ( all instr. + reverse )
# complete                - 9722    asm lines - 5-10min ( + op switch )
# interleaving-reversi-1  - 17294   asm lines - 5-10min ( + interleaving chains, no cache misses/consequtive! )
# interleaving-1          - 17294   asm lines - 5-10min ( see above, with cache misses/see cache config )
# sequence                - 1851852 asm lines - 2-3h    ( + all forwarding chains tested )
# excessive               - 6732901 asm lines - >12h    ( + chache misses, all, ... )

REPETITION=5

echo -e "${BOLD}${CYAN}"
echo -e "############################################################"
echo -e " Generating PATARA Test Files (ASM: .S)"
echo -e "############################################################"
echo -e "${NONE}"
# generate Assemlbly with REVERSI
cd ${PATARA_DIR}
rm -rf reversiAssembly
# debugging purposes
#python3 main.py -c -r 1
#RESULT_DIR="${SRC_DIR}/results"

if [[ "$1" = "basic"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -rf ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "Basic Instruction Test (45)" > ${RESULT_DIR}/generate.log
python3 main.py --basicInstruction --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0  > "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

if [[ "$1" = "complete"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -fr ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "Basic Instruction Test (63)" > ${RESULT_DIR}/generate.log
python3 main.py -c --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0  > "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

if [[ "$1" = "interleaving-reversi-1"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -rf ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "REVERSI functionality" > ${RESULT_DIR}/generate.log
echo "Basic interleaving " >> ${RESULT_DIR}/generate.log
python3 main.py --basicInstruction --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 > "$RESULT_DIR/instruction.log"
python3 main.py -c --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 >> "$RESULT_DIR/instruction.log"
python3 main.py -i -l 1 --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

if [[ "$1" = "interleaving-reversi-10"  ]] ; then
rm -rf ${RESULT_DIR}
RESULT_DIR="${SRC_DIR}/coverage/${1}"
mkdir -p ${RESULT_DIR}
echo "REVERSI functionality" > ${RESULT_DIR}/generate.log
echo "Basic interleaving " >> ${RESULT_DIR}/generate.log
python3 main.py --basicInstruction --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 > "$RESULT_DIR/instruction.log"
python3 main.py -c --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 >> "$RESULT_DIR/instruction.log"
python3 main.py -i -l 10 --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

if [[ "$1" = "interleaving-reversi-rep10-10"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -fr ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "REVERSI functionality" > ${RESULT_DIR}/generate.log
echo "Basic interleaving " >> ${RESULT_DIR}/generate.log
python3 main.py --basicInstruction --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 > "$RESULT_DIR/instruction.log"
python3 main.py -c --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 >> "$RESULT_DIR/instruction.log"
python3 main.py -i -l 10 -r 10 --icacheMiss 0.0 --dcacheMiss 0.0 --newMemoryBlock 0.0 --switch 0.0 >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi


if [[ "$1" = "interleaving-1"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -fr ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "Basic interleaving length 1" > ${RESULT_DIR}/generate.log
python3 main.py --basicInstruction  > "$RESULT_DIR/instruction.log"
python3 main.py -c  >> "$RESULT_DIR/instruction.log"
python3 main.py -i -l 1  >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

if [[ "$1" = "interleaving-10"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -fr ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "Basic interleaving length 10" > ${RESULT_DIR}/generate.log
python3 main.py --basicInstruction > "$RESULT_DIR/instruction.log"
python3 main.py -c   >> "$RESULT_DIR/instruction.log"
python3 main.py -i -l 10  >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

if [[ "$1" = "interleaving-rep10-10"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -fr ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "Basic interleaving length 10; repetition 10" > ${RESULT_DIR}/generate.log
python3 main.py --basicInstruction  > "$RESULT_DIR/instruction.log"
python3 main.py -c  >> "$RESULT_DIR/instruction.log"
python3 main.py -i -l 10 -r 10 >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi


if [[ "$1" = "sequence"  ]] ; then
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -fr ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "complete + Basic interleaving + Sequences"  > ${RESULT_DIR}/generate.log
python3 main.py -c -i -l 10 > "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.5 -s   >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.5 -s -f 1  >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.5 -s -f 2 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.5 -s -f 3 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.5 -s -f 4 >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

if [[ "$1" = "excessive"  ]] ; then
# Excessive
RESULT_DIR="${SRC_DIR}/coverage/${1}"
rm -fr  ${RESULT_DIR}
mkdir -p ${RESULT_DIR}
echo "excessive Test" > ${RESULT_DIR}/generate.log
python3 main.py -c -i -r ${REPETITION} -l 20 >> "$RESULT_DIR/instruction.log"

echo "no operand switching in sequence, no DCache Miss" >> ${RESULT_DIR}/generate.log
python3 main.py --switch 0.0 -s  --dcacheMiss 0.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 1  --dcacheMiss 0.0  >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 2 --dcacheMiss 0.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 3  --dcacheMiss 0.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 4 --dcacheMiss 0.0 >> "$RESULT_DIR/instruction.log"

echo "no operand switching in sequence, enable DCache Miss" >> ${RESULT_DIR}/generate.log
python3 main.py --switch 0.0 -s  --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 1  --dcacheMiss 1.0  >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 2 --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 3  --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 4 --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"

echo "Enable operand switching in sequence, enable DCache Miss" >> ${RESULT_DIR}/generate.log
python3 main.py --switch 1.0 -s --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 1.0 -s -f 1  --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 1.0 -s -f 2 --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 1.0 -s -f 3 --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 1.0 -s -f 4  --dcacheMiss 1.0 >> "$RESULT_DIR/instruction.log"

echo "Enable operand switching in sequence, disable DCache Miss" >> ${RESULT_DIR}/generate.log
echo "LW + JALR conditions and checks (minimum)" >> ${RESULT_DIR}/generate.log
python3 main.py --switch 0.0 -s -f 1 --sequenceStall 1.0 --dcacheMiss 0.0  >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 1 --sequenceStall 1.0 --dcacheMiss 1.0  >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 2 --sequenceStall 1.0 --dcacheMiss 0.0  >> "$RESULT_DIR/instruction.log"
python3 main.py --switch 0.0 -s -f 2 --sequenceStall 1.0 --dcacheMiss 1.0  >> "$RESULT_DIR/instruction.log"

echo "dCache miss + Special Cases (Division by 0)" >> ${RESULT_DIR}/generate.log
python3 main.py -i -l 15 --dcacheMiss 1.0 -r ${REPETITION} --specialImmediates 1.0 >> "$RESULT_DIR/instruction.log"

echo "check multiple Cache lines (i- and dcache)" >> ${RESULT_DIR}/generate.log
python3 main.py -i -l 15 --dcacheMiss 1.0 -r ${REPETITION} --newMemoryBlock 0.5 >> "$RESULT_DIR/instruction.log"
python3 main.py -i -l 15 --dcacheMiss 1.0 --switch 0.0 -r ${REPETITION} --newMemoryBlock 0.5 >> "$RESULT_DIR/instruction.log"
cp -r ${PATARA_DIR}/reversiAssembly ${SRC_DIR}
mv ${SRC_DIR}/reversiAssembly ${SRC_DIR}/src
fi

echo -e "${BOLD}${CYAN}"
echo -e "############################################################"
echo -e " Finished generating all PATARA Tests"
echo -e "############################################################"
echo -e "${NONE}"
