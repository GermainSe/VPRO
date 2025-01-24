cmake_minimum_required(VERSION 3.14)

project("LocalMemory and LaneMemory Checks")
set(module LMyRM)

include(../CMakeInc.txt)

add_executable(${module} main.cpp)
message(STATUS "using SCRIPTED=${SCRIPTED}")

# include dirs for libs
target_include_directories(${module} PUBLIC ${PlainIncludeDirs})
target_link_libraries(${module} VPRO_SIMULATOR_LIB)
target_link_libraries(${module} VPRO_AUX_LIB)

# these are all global variables -> assign to addres above main_memory max address
target_link_options(${module} PUBLIC -Wl,--no-relax,--section-start=.rodata=0x0000000040000000)

target_compile_definitions(${module} PUBLIC SCRIPTED=${SCRIPTED} NUM_VU_PER_CLUSTER=${UNITS} NUM_CLUSTERS=${CLUSTERS} STAT_COMMENT=\"${PROJECT}\" SIMULATION=1)
