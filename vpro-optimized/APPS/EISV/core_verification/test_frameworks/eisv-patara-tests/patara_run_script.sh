#!/bin/bash

# files / folder = batch_size
batch_size=210

#REPO_DIR="/localtemp2/coverage_share_tmp/vpro_sys_optimized"
REPO_DIR=`pwd`/../../../../
#PATARA_DIR=`pwd`/patara

simulate () {
    cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/

    make clean_sim
    make clean_results

    make patara-minibatch

    #uncomment for coverage
    make coverage_report_gen

    # copy errors
    ./eisv-patara-tests/check-errors.py
}




#uncomment for coverage
# remove old coverage files
#rm ${REPO_DIR}/SYS/axi/scripts/axi_eisv_system_zu19eg_behave/coverage.ucdb
#rm ${REPO_DIR}/SYS/axi/scripts/axi_eisv_system_zu19eg_behave/.backup.cov.ucdb





echo -e "${BOLD}${CYAN}"
echo -e "############################################################"
echo -e " Cleaning Simulation Environment"
echo -e "############################################################"
echo -e "${NONE}"
# clean simulation
cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks
make clean_results

cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests
rm -r references
mkdir references
rm Makefrag
cp Makefrag.ref Makefrag



echo -e "${BOLD}${CYAN}"
echo -e "############################################################"
echo -e " Appending all PATARA Tests to the Simulation Lists"
echo -e "############################################################"
echo -e "${NONE}"



cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests/src
i=0
for f in *.S
do
    echo "00000000" > "../references/${f%%.*}.reference_output";
    sed -i "32i \\${f%%.*} \\\\" ../Makefrag
    i=$i+1

    # if a batch is ready, simulate, generate coverage data and repeat process, otherwise linux breaks XD
    if [[ "$((i % ${batch_size}))" -eq "0" ]] ; then
        sed -i 's/* \\//g' ../Makefrag
        cat ../Makefrag

        simulate

        cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests
        rm Makefrag
        cp Makefrag.ref Makefrag
        cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests/src

    fi
done



sed -i 's/* \\//g' ../Makefrag
cat ../Makefrag

simulate
cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests
rm Makefrag
cp Makefrag.ref Makefrag
cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests


echo "HTML Report Index inside: ${REPO_DIR}/SYS/axi/scripts/axi_eisv_system_zu19eg_behave/html_coverage/index.html"

if [[ -n "$1" ]] ; then
    #uncomment for coverage
    cd ${REPO_DIR}/SYS/axi/scripts/axi_eisv_system_zu19eg_behave
    python3 extractMetrics.py
    cp latexExport.tex ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests/coverage/${1}
    cd ${REPO_DIR}/APPS/EISV/core_verification/test_frameworks/eisv-patara-tests
    python3 TestInstructionCount.py -p coverage/${1}
fi
