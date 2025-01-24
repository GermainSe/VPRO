#!/usr/bin/python3
import os, shutil
import subprocess
import time
import re
import shutil
from array import array

# config of this script
clusters = 8
units = 20
maxParallelRuns = 32

basepath = "/localtemp2/gesper/cnn_eval_tmp"
LIB_DIR = "/home/gesper/repositories/TOOLS/VPRO/ISS/common_lib/riscv/lib_ddr_sys/"

if __name__ == "__main__":
    try:
        shutil.rmtree(basepath + "/log", ignore_errors=True)
        os.makedirs(basepath + "/log")
    except:
        print("error create log folder in " + basepath)
        exit()
    try:
        shutil.rmtree(basepath + "/error_log", ignore_errors=True)
        os.makedirs(basepath + "/error_log")
    except:
        print("error create error_log folder in " + basepath)
        exit()
    try:
        shutil.rmtree(basepath + "/builds", ignore_errors=True)
        os.makedirs(basepath + "/builds")
    except Exception as e:
        print("error create builds folder in " + basepath)
        print(e)
        exit()
    try:
        shutil.copytree("../../cnn_converter", basepath + "/builds/cnn_converter")
    except Exception as e:
        print("error create cnn_converter folder in " + basepath)
        print(e)
        exit()
    try:
        shutil.rmtree(basepath + "/builds/init", ignore_errors=True)
        shutil.copytree("../init", basepath + "/builds/init")
    except Exception as e:
        print("error copy init folder to " + basepath)
        print(e)
        exit()
    try:
        shutil.rmtree(basepath + "/builds/exit", ignore_errors=True)
        shutil.copytree("../exit", basepath + "/builds/exit")
    except Exception as e:
        print("error copy exit folder to " + basepath)
        print(e)
        exit()
    try:
        shutil.rmtree(basepath + "/builds/data", ignore_errors=True)
        shutil.copytree("../data", basepath + "/builds/data")
    except Exception as e:
        print("error copy data folder to " + basepath)
        print(e)
        exit()

    # call "make clean_all"
    process = subprocess.Popen(["make", "clean"], cwd="../", stdout=open("./cleanup.log", "w"), stderr=subprocess.STDOUT)
    print("[Start] Clean all")
    if process.wait() != 0:
        print("retcode =", process.returncode)
        print(process.communicate()[1])
        print("ERROR on cleanup")
        exit(1)
    print("[Done] Clean all")

    try:
        shutil.rmtree(basepath + "/builds/src", ignore_errors=True)
        os.makedirs(basepath + "/builds/src")
        shutil.copytree("../configuration_generation", basepath + "/builds/src/configuration_generation")
        shutil.copytree("../configuration_loader", basepath + "/builds/src/configuration_loader")
        shutil.copytree("../includes", basepath + "/builds/src/includes")
        shutil.copytree("../sources", basepath + "/builds/src/sources")
        shutil.copy("../main.cpp", basepath + "/builds/src/main.cpp")
        shutil.copy("../Makefile", basepath + "/builds/src/Makefile")
        shutil.copy("../Makefile.segsplit.inc", basepath + "/builds/src/Makefile.segsplit.inc")
        shutil.copy("../CMakeLists.txt", basepath + "/builds/src/CMakeLists.txt")
        shutil.copy("../lib.cnf", basepath + "/builds/src/lib.cnf")
        shutil.copy("../_lib.cnf", basepath + "/builds/src/_lib.cnf")
    except Exception as e:
        print("error copy sources to " + basepath)
        print(e)
        exit()

    # init
    print("\n[Init] Clusters: [1-" + str(clusters) + "], Units: [1-" + str(units) + "]\n")
    runnings = []
    starts = 0


    # create list of configurations to be evaluated
    configlist = []
    for c in range(1, clusters + 1):
        for u in range(1, units + 1):
            if (u * c) < 200:
                configlist.append((c, u))

    # loop over configurations to evaluate
    while (not (len(configlist) == 0)) or (len(runnings) > 0):
        # check if one finished
        for i in range(0, len(runnings)):
            if runnings[i][2].poll() != None:  # process is not alive
                print("[Done " + str(i) + "/" + str(len(runnings)) + "] Cluster: " + str(runnings[i][0]) + ", Unit: " + str(
                    runnings[i][1]))
                retcode = runnings[i][2].wait()
                if retcode != 0 and retcode != 200:
                    print("  Error: Cluster(" + str(runnings[i][0]) + ") & Unit(" + str(runnings[i][1]) + ")")
                    print(runnings[i][2].communicate()[0])
                    print(runnings[i][2].communicate()[1])
                shutil.rmtree(basepath + "/builds/build_release_c" + str(runnings[i][0]) + "u" + str(runnings[i][1]),
                              ignore_errors=True)
                print("Removing: " + basepath + "/builds/build_release_c" + str(runnings[i][0]) + "u" + str(runnings[i][1]))
                try:
                    shutil.copyfile(basepath + "/builds/data/statistic_detail_"+str(runnings[i][0])+"C"+str(
                        runnings[i][1])+"U2L.log", "./statistic_detail_"+str(runnings[i][0])+"C"+str(
                        runnings[i][1])+"U2L.log")
                except:
                    print("result data copy failed")
                # remove from runnings list
                try:
                    del runnings[i]
                except IndexError:
                    print("Index " + str(i) + " Out of Range [0-" + str(len(runnings)) + "]")
                # rm temp build dir and cp data
                break

        # start freeruns new configs
        time.sleep(0.1)
        freeRuns = maxParallelRuns - len(runnings)
        for i in range(0, min(maxParallelRuns, freeRuns)):
            if len(configlist) > 0:
                config = configlist.pop(0)
                c = config[0]
                u = config[1]
                shutil.rmtree(basepath + "/builds/src_C" + str(c) + "U" + str(u), ignore_errors=True)
                shutil.copytree(basepath + "/builds/src/", basepath + "/builds/src_C" + str(c) + "U" + str(u) + "/")
                process = subprocess.Popen(["make",
                                            "build_release=" + basepath + "/builds/build_release_c" + str(c) + "u" + str(u),
                                            "APP_NAME=\"CNN\"", "CLUSTERS=" + str(c), "UNITS=" + str(u),
                                            "LIB_DIR=" + LIB_DIR, "scripted"],
                                           cwd=basepath + "/builds/src_C" + str(c) + "U" + str(u) + "/",  # "../",
                                           stdout=open(basepath + "/log/C" + str(c) + "U" + str(u) + ".log", "w"),
                                           stderr=open(basepath + "/error_log/C" + str(c) + "U" + str(u) + ".log", "w"))
                starts += 1
                runnings.append((c, u, process))
                print("[Start " + str(starts) + "/" + str(clusters * units) + "] Cluster: " + str(c) + ", Unit: " + str(
                    u) + " [Running processes: " + str(len(runnings)) + "]")

    # finished. cp data
    try:
        shutil.copyfile(basepath + "/builds/data/statistic_detail_*", "./")
    except:
        print("data copy failed")
    print("[Script Finished]")
