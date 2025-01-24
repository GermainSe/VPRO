import subprocess

# example command
# make release CLUSTERS=2 UNITS=2 build_release=asdf SILENT=--silent SAVE_OUTPUT=>output.txt

process_list = []

for clusters in range(2, 8 + 1, 2):
    for units in range(clusters, 2 * clusters + 1, clusters):
        build_folder = "build_" + str(clusters) + "_" + str(units)
        output_file = "output.txt"

        p1 = subprocess.Popen(
            ["make", "release", "CLUSTERS=" + str(clusters), "UNITS=" + str(units), "build_release=" + build_folder,
             "SILENT=--silent", "SAVE_OUTPUT=>" + output_file])
        process_list.append(p1)

for p in process_list:
    p.wait()

# copy output txt files
import shutil
import os

eval_folder = "eval"
if not os.path.exists(eval_folder):
    os.makedirs(eval_folder)

for clusters in range(2, 8 + 1, 2):
    for units in range(clusters, 2 * clusters + 1, clusters):
        build_folder = "build_" + str(clusters) + "_" + str(units)
        output_file = "output.txt"
        dst_file = str(clusters) + "_" + str(units) + ".txt"
        shutil.copyfile(build_folder + "/" + output_file, eval_folder + "/" + dst_file)
