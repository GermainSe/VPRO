##
# PROGRAM
##

Main.cpp includes
    #include headers of includes folder
    the calculation of the CNN with VPRO functions using the simulator
    maybe the verification of vpro's execution

includes/defines.h
    sets defines for execution of different functions
    constants..

includes/helper.h  & sources/helper.cpp
    some helper functions, like print of a progressbar/print int as bit/DMA linearize (cut edges upon data copy)

.cpp files are stored in sources/
.h files are stored in includes/




##
# Simulator Init/Exit
##

init/init.sh
    script called to convert input data, etc.

init/input.cfg
    data loaded into MM by simulator

exit/exit.sh
    script called to convert output data, etc.

exit/output.cfg
    data stored from MM by simulator





##
# MISC
##

data/
    folder for input/output files (used by input.cfg/output.cfg scripts)

lib/
    folder to store external libs (.so)
    used in CMakeList to link against

CmakeLists.txt (always copied from ../ref_cmakelists.txt by Makefile)
CmakeListsAdd.txt
    modifications for this programm

Makefile
    settings for HW configuration. Used to compile and execute programm

scripts/
    folder with scripts for parallel compile/run to evaluate different HW configurations
