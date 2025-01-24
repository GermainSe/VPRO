import os
import filecmp
import glob

#dir1 = "/public/ZuSE-KI-AVF/fpga_eval/yololite_app_ref/"
dir1 = "../../legacy/cnn_yolo_lite_hw/data/reference_c/binary"
dir2 = "./sim_results"

reference_zip_dir = "../../legacy/cnn_yolo_lite_hw/data/"

if not os.path.isfile(dir1 + "/Layer_7/channel_0.bin"):
	os.system("unzip " + reference_zip_dir + "reference_c_.zip -d " + reference_zip_dir + " &> /dev/null")
#exit()

emu_fails = 0
for filename in sorted(glob.glob(dir1 + '/**/*.bin', recursive=True)):
    if os.path.isfile(filename):
        path = os.path.dirname(filename)
        file = os.path.basename(filename)

        # check emu result
        if not filecmp.cmp(path + "/" + file, path.replace(dir1, dir2) + '/' + file):
            emu_fails += 1
            if emu_fails < 10:
                print("Sim Error: ", path.replace(dir1, dir2) + "/" + file)

if emu_fails > 0:
    print("Sim Fails: ", emu_fails)
else:
    print("Sim correct!")

if emu_fails > 0:
    print("... exit(1)")
    exit(1)
exit(0)
