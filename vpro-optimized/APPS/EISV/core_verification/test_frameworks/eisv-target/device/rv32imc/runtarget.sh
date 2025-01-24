#!/bin/bash

#if [ -z "${CORE_V_VERIF}" ]; then
#    echo "CORE_V_VERIF is unset- exiting"
#    exit 1
#fi

TEST=$1
WORK=$2/OpenHW-REF

TESTDIR=$(dirname ${TEST})/sim

# create an empty signature file at start
touch ${TEST}.signature.output

#echo -e "\n\tTEST: \e[7;49;96m$(basename $TEST)\e[0m\n"

filesize=$(stat -c%s "$TEST.signature.output")
#echo "Signature Dump FILESIZE: $filesize"
if (( filesize > 0 )); then
  exit 0

  # if needed ....
  read -p "Enter [Y] to execute $TEST again" -n 1 -r
  echo    # (optional) move to a new line
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Skipping execution..."
    exit 0
  fi
#else
    #echo "First Simulation Run for this app"
fi

try=1
while [ $filesize -le 0 ]
do

  #echo "Running: $TEST.elf.hex \nCurrent Dir: ${PWD}"

  init_dir=${PWD}

  single_risc_subsystem=0
  if [[ ${RISCV_DEVICE} == *"I"*  ]]; then
    single_risc_subsystem=1
  elif [[ ${RISCV_DEVICE} == *"M"*  ]]; then
    single_risc_subsystem=1
  elif [[ ${RISCV_DEVICE} == *"C"*  ]]; then
    single_risc_subsystem=1
  elif [[ ${RISCV_DEVICE} == *"Own"*  ]]; then
    single_risc_subsystem=1
  fi

  # Overwrite Subsys selection! TODO: remove!
  single_risc_subsystem=0

  # check if exist. then use SYSTEM_SIM_PROJECT_DIR environment variable
  if [[ -z "${SYSTEM_SIM_PROJECT_DIR}" ]]; then
    if [[ ${single_risc_subsystem} == *"0"* ]]; then
      sys_dir="SYS/axi/scripts/axi_eisv_system_zu19eg_behave/"
    else # single_risc_subsystem == 1
      sys_dir="SYS/axi/scripts/axi_eisv_bram/"
    fi
  else
    if [[ ${single_risc_subsystem} == *"0"* ]]; then
      sys_dir="${SYSTEM_SIM_PROJECT_DIR}"
    else # single_risc_subsystem == 1
      searchStr="axi_eisv_system_zu19eg_behave"
      replaceStr="axi_eisv_bram"
      sys_dir=`echo "${SYSTEM_SIM_PROJECT_DIR/"$searchStr"/"$replaceStr"}"`
      searchStr="axi_eisv_system_zu19eg"
      sys_dir=`echo "${sys_dir/"$searchStr"/"$replaceStr"}"`
    fi
  fi

  echo -e "\n\tTEST: \e[7;49;96m$(basename $TEST)\e[0m\n\t\tRunning: \e[96m$TEST.elf.hex\e[0m \n\t\tCurrent Dir: ${PWD}\n\t\tRISCV_DEVICE: ${RISCV_DEVICE} => Using Subsystem inside $sys_dir!\n\t\tSim Log: $TEST.sim.log"
  if [[ ${PWD} == *"eisv-vpro-tests"* ]]; then
    cd ../../../../../${sys_dir}
  elif [[ ${PWD} == *"eisv-custom-tests"* ]]; then
    cd ../../../../../${sys_dir}
  elif [[ ${PWD} == *"eisv-patara-tests"* ]]; then
    cd ../../../../../${sys_dir}
  else
    cd ../../../../../../../../${sys_dir}
  fi

  source .env.sim
  cd simulation
  dir=questa

  # parallel run uses lock to avoid conflicts -> during copy of sim folder
  LOCKFILE=.risc-verify-app.pid.exclusivelock
  # lock it
  exec 200>$LOCKFILE    # opens file handle
  flock -w 10 -x 200 || exit 1  # lock exclusive
  echo $$ 1>&200      # save pid
  # do stuff
  newdir=${dir}$(( `printf "%s\n" ${dir}* | wc -l` + 1 ))
  cp -r ${dir} ${newdir}
  #echo -e "\n\tTEST: $(basename $TEST) -> will run in Simulation DIR: ${PWD}/simulation/${newdir}\n\n"
  # unlock it
  flock -u 200 || exit 1

  rm -rf ${newdir}/questa_lib
  rm -rf ${newdir}/printf_uart_output.txt
  rm -rf ${newdir}/*.output
  rm -rf ${newdir}/output_*.bin
  rm -rf ${newdir}/*.ucdb


  if [[ ${single_risc_subsystem} == *"0"* ]]; then
    cp .${VIVADO_PROJECT_DIR}/${PROJECT_NAME}.ip_user_files/bd/vpro_axi_subsys/ip/vpro_axi_subsys_block_ram_0_0/sim/vpro_axi_subsys_block_ram_0_0.vhd ${newdir}/block_ram_.vhd
    cd ..
    make -s override_app OVERRIDE_APP=$TEST.elf.hex OVERRIDE_APP_FILE=simulation/${newdir}/block_ram_.vhd > $TEST.sim.log 2>&1
    sed -i "s+../.${VIVADO_PROJECT_DIR}/${PROJECT_NAME}.ip_user_files/bd/vpro_axi_subsys/ip/vpro_axi_subsys_block_ram_0_0/sim/vpro_axi_subsys_block_ram_0_0.vhd+./block_ram_.vhd+g" simulation/${newdir}/compile.do.corrected
  else
    SOURCE="../../../../../CORES/EISV/rtl/subsystem/single_memory.vhd"
    DST="${newdir}/_single_memory.vhd"
    #cp .${VIVADO_PROJECT_DIR}/${PROJECT_NAME}.ip_user_files/bd/eisv_subsys/ip/eisv_subsys_eisv_single_0_0/sim/eisv_subsys_eisv_single_0_0.vhd ${newdir}/subsys_ram_.vhd
    cp ${SOURCE} ${DST}
    cd ..
    make -s override_app OVERRIDE_APP=$TEST.elf.hex OVERRIDE_APP_FILE=simulation/${DST} > $TEST.sim.log 2>&1
    sed -i "s+${SOURCE}+${DST}+g" simulation/${newdir}/compile.do.corrected
  fi

  # MIG copy of executable binary
  #cp $TEST.elf.bin simulation/${newdir}/instr.bin
  #cp $TEST.elf.corrected.bin simulation/${newdir}/instr.bin
  sed 's/ /\n/g' $TEST.elf.hex > simulation/${newdir}/instr.bin

  #echo "${PWD}"

  # run
  #echo "Starting Simulation: $TEST.sim.log"
  # for parallel runs:

  cd simulation/${newdir}
  export SIMULATE_CONSOLE=true && export TESTNAME=$(basename $TEST) && ./tb.sh -reset_run   >> $TEST.sim.log && ./tb.sh   >> $TEST.sim.log
  cd ../..

  # copy result
  cp simulation/${newdir}/signature.output ${TEST}.signature.output

  # in case of hardware parameter IS_SIMULATION=False output needs to be parsed from uart output
  # cut first 2 and last 2 lines from print uart and append to signature.output
  #sed '1d;2d' simulation/${newdir}/printf_uart_output.txt | head -n -2 >> ${TEST}.signature.output
  cat simulation/${newdir}/printf_uart_output.txt | awk 'length($0) == 8' >> ${TEST}.signature.output

  WORK_DIR=`dirname ${TEST}`
  WORK_TEST=`basename ${TEST}`
  WORK_DIR_BASE=`basename ${WORK_DIR}`

 # echo -e "\e[92m WORK_DIR ${WORK_DIR}, WORK_TEST ${WORK_TEST}, WORK_DIR_BASE ${WORK_DIR_BASE} \e[0m"

  # if [[ "${WORK_DIR_BASE}" == "VPRO" ]]; then
  #   diff ${TEST}.signature.output ${WORK_DIR}/../../../../eisv-vpro-tests/references/${WORK_TEST}.reference_output > /dev/null 2>&1
  # elif [[ "${WORK_DIR_BASE}" == "Patara" ]]; then
  #   diff ${TEST}.signature.output ${WORK_DIR}/../../../../eisv-patara-tests/references/${WORK_TEST}.reference_output > /dev/null 2>&1
  # elif [[ "${WORK_DIR_BASE}" == "Own" ]]; then
  #   diff ${TEST}.signature.output ${WORK_DIR}/../../../../eisv-custom-tests/references/${WORK_TEST}.reference_output > /dev/null 2>&1
  # else  # I M C
    diff -i ${TEST}.signature.output ${WORK_DIR}/../../../riscv-test-suite/rv32i_m/${WORK_DIR_BASE}/references/${WORK_TEST}.reference_output > /dev/null 2>&1
  # fi

  error=$?
  if [ $error -eq 0 ]
  then
     echo -e "\e[92mTest ${WORK_TEST}: Output Correct!\e[0m"
  elif [ $error -eq 1 ]
  then
     echo -e "\e[91mTest ${WORK_TEST}: Output FAIL!\e[0m"
     echo "    diff ${TEST}.signature.output ${WORK_DIR}/../../../riscv-test-suite/rv32i_m/${WORK_DIR_BASE}/references/${WORK_TEST}.reference_output"
     echo -e "\e[91m${WORK_TEST}\e[0m " >> ${WORK_DIR}/fails
     echo "All fails: (${WORK_DIR}/fails)"
     cat ${WORK_DIR}/fails
  else
     echo -e "There was something wrong with the diff command"
  fi

  # reset to defaults
#  make -s ignore_uart IGNORE_UART=false &> /dev/null
#  make -s override_app OVERRIDE_APP=../../../../../../APPS/EISV/core_verification/template/fibonacci.hex  &> /dev/null
  #cp ../../../../APPS/EISV/core_verification/template/fibonacci.bin simulation/${newdir}/instr.bin

  cd ${init_dir}
  filesize=$(stat -c%s "$TEST.signature.output")
  if (( filesize <= 0 )); then
    echo -e "Still not yet simulated successfull! | Test: \e[7;49;96m$(basename $TEST)\e[0m"
    try=$(( $try + 1 ))
    echo -e "Repeating simulation script for Try: $try | TEST: \e[7;49;96m$(basename $TEST)\e[0m"
    echo
  # else
  #   #echo -e "Simulation succeeded after Try: $try | TEST: \e[7;49;96m$(basename $TEST)\e[0m"
  fi

  # no 2nd try
  break
done

exit 0
