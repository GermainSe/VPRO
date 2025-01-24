#
# main CMAKE file
#   includes libs (sim, aux, vpro_cnn, ...)
#   defines executable (sim)
#

cmake_minimum_required(VERSION 3.14)
cmake_policy(SET CMP0074 NEW)

if(NOT DEFINED PROJECT)
    get_filename_component(ProjectId ${CMAKE_CURRENT_SOURCE_DIR} NAME)
    string(REPLACE " " "_" ProjectId ${ProjectId})
    set(PROJECT ${ProjectId})
endif(NOT DEFINED PROJECT)
project(${PROJECT})

#############################################################################################
# Compiler FLAGS
#############################################################################################
macro(use_cxx11)
    if (CMAKE_VERSION VERSION_LESS "3.1")
        if (CMAKE_CXX_COMPILER_ID STREQUAL "GNU")
            set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -std=gnu++20")
        endif ()
    else ()
        set(CMAKE_CXX_STANDARD 20)
    endif ()
endmacro(use_cxx11)
use_cxx11()
set(GFLAG -std=c++2a)

set(CMAKE_CXX_FLAGS "-Wall -Wextra -Wno-unused-parameter")
set(CMAKE_CXX_FLAGS_DEBUG "-g")
set(CMAKE_CXX_FLAGS_RELEASE "-O3")

#############################################################################################
# Paths and Files
#############################################################################################
# libs
set(VPRO_SIMULATOR_LIB_dir "${ISS_DIR}")
set(VPRO_AUX_LIB_dir "${AUX_DIR}")

# check paths (cmake fails if this file is not found)
file(SIZE ${AUX_DIR}/vpro.h vpro_common_include_file)

# source files for executable
file(GLOB_RECURSE Sources
        "${SRC_FOLDER}/${C_FILES}"
        )

# source files for executable
file(GLOB_RECURSE Headers
        "${SRC_FOLDER}/*.h"
        )

set(PlainIncludeDirs
        includes/
        ${ISS_DIR}/
        ${AUX_DIR}/
        )

#############################################################################################
# Definitions
#############################################################################################
# set HW config via defines
if(NOT DEFINED CLUSTERS)
    set(CLUSTERS 1)
endif(NOT DEFINED CLUSTERS)
if(NOT DEFINED UNITS)
    set(UNITS 1)
endif(NOT DEFINED UNITS)
if(NOT DEFINED LANES)
    set(LANES 2)
endif(NOT DEFINED LANES)
if(NOT DEFINED SCRIPTED)
    set(SCRIPTED 1)
endif(NOT DEFINED SCRIPTED)
if(NOT DEFINED SIMULATION)
    set(SIMULATION 1)
endif(NOT DEFINED SIMULATION)

message(STATUS "using CLUSTERS=${CLUSTERS}")
message(STATUS "using UNITS=${UNITS}")
message(STATUS "using LANES=${LANES}")
message(STATUS "using COMMENT=${PROJECT}")
message(STATUS "using SCRIPTED=${SCRIPTED}")

set(ISS_STANDALONE 1)
message(STATUS "using ISS_STANDALONE=${ISS_STANDALONE}")

set(module sim)

#############################################################################################
# Executable (Standalone Sim App) or Library (Virtual Prototype App)
#############################################################################################
add_executable(${module} ${Sources} ${SRC_FOLDER}/${C_FILES} ${Headers})

target_compile_definitions(${module} PUBLIC -DNUM_VECTORLANES=${LANES} -DNUM_VU_PER_CLUSTER=${UNITS} -DNUM_CLUSTERS=${CLUSTERS} -DTEST=\"${TEST}\" -DDUMP_DIR=\"${DUMP_DIR}\")
add_definitions(-DSCRIPTED=${SCRIPTED} -DSTAT_COMMENT=\"${PROJECT}\" -DSIMULATION=${SIMULATION} -DISS_STANDALONE=${ISS_STANDALONE})
#target_compile_definitions(${module} PUBLIC SCRIPTED=${SCRIPTED} NUM_VU_PER_CLUSTER=${UNITS} NUM_CLUSTERS=${CLUSTERS} STAT_COMMENT=\"${PROJECT}\" SIMULATION=${SIMULATION} ISS_STANDALONE=${ISS_STANDALONE})

# include dirs for libs
target_include_directories(${module} PUBLIC ${PlainIncludeDirs})

link_directories("${VPRO_SIMULATOR_LIB_dir}/..")
message(STATUS "ISS DIR: ${VPRO_SIMULATOR_LIB_dir}")

file (SIZE ${VPRO_SIMULATOR_LIB_dir}/../libVPRO_SIMULATOR_LIB_ISS.so filesize)
message(STATUS ${filesize})

SET(CMAKE_EXE_LINKER_FLAGS
          "${CMAKE_EXE_LINKER_FLAGS} -Wl,-rpath -Wl,${VPRO_SIMULATOR_LIB_dir}/..")

# set(CMAKE_INSTALL_RPATH "${VPRO_SIMULATOR_LIB_dir}/../")
# set(CMAKE_INSTALL_RPATH_USE_LINK_PATH TRUE)


message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")
SET(CMAKE_PREFIX_PATH "${VPRO_SIMULATOR_LIB_dir}/..")
message(STATUS "CMAKE_PREFIX_PATH: ${CMAKE_PREFIX_PATH}")

find_library(ISS VPRO_SIMULATOR_LIB_ISS)
find_library(AUX VPRO_AUX_LIB)

message(STATUS "LIB: ${ISS}")
message(STATUS "AUX: ${AUX}")

target_link_libraries(${module} ${ISS})
target_link_libraries(${module} ${AUX})


#############################################################################################
# QT Linking (GUI + internals)
#############################################################################################
find_package(Qt5 COMPONENTS Core Widgets REQUIRED)
set(CMAKE_AUTOUIC ON)
set(CMAKE_AUTOMOC ON)
set(AUTOUIC_SEARCH_PATHS ${CMAKE_CURRENT_SOURCE_DIR}/simulator/windows/Commands)
set(CMAKE_INCLUDE_CURRENT_DIR ON)
set(CMAKE_CXX_FLAGS "${Qt5Widgets_EXECUTABLE_COMPILE_FLAGS}")

## This depends on QT
target_include_directories(${module} PUBLIC ${Qt5Core_INCLUDE_DIRS})
target_include_directories(${module} PUBLIC ${Qt5Widgets_INCLUDE_DIRS})
target_compile_definitions(${module} PUBLIC ${Qt5Widgets_DEFINITIONS})
#set(CMAKE_AUTOGEN_VERBOSE ON)
target_link_libraries(${module}  Qt5::Core Qt5::Widgets)
