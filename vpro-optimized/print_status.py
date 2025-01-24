#!/usr/bin/env python3

import os
import git

repos=(
    "CORES/EISV/",
    "CORES/VPRO",
    "CORES/EISV_Specialization/",
    "CORES/VPRO_Specialization/",
    "TOOLS/VPRO/ISS",
    "APPS/EISV/cnn_converter/",
    "APPS/EISV/core_verification/",
    "APPS/EISV/nn_quantization",
    "ASIC/vpro-refflow-gf-22fdsoi_2_3/",
    "SYS/axi/")

folder_width = 40
branch_width = 40

print()
print("Folder".ljust(folder_width)+"Branch".ljust(branch_width)+"Dirty             Hash")
print("----------------------------------------------------------------------------------------------------------")
for repo in repos:
    branch = os.popen("cd " + repo + " && git rev-parse --abbrev-ref HEAD").read().strip()
    if git.Repo(repo).is_dirty():
        print(("\033[36m\033[4m"+repo+"\033[0m").ljust(folder_width + 4+9), end="")
        print(branch.ljust(branch_width), end="")
        print("dirty", end="")
        print(" ("+str(len(git.Repo(repo).index.diff(None))).rjust(3)+" files)", end="")
    else:
        print(("\033[36m"+repo+"\033[0m").ljust(folder_width+9), end="")
        print(branch.ljust(branch_width + 17), end="")
    print(" " + git.Repo(repo).head.object.hexsha[0:8])
print()
