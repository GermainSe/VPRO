import os
import filecmp
import glob

dir1 = "./ref_fixed"
dir2 = "./emu_results"
dir3 = "./sim_results"

if len(glob.glob(dir1 + '/*.bin')) <= 0:
    print("ERROR: no files in ", dir1, "found!")

sim_fails = 0
sim_miss = 0
emu_fails = 0
emu_miss = 0
for filename in sorted(glob.glob(dir1 + '/*.bin')): #, recursive=True)):
    if os.path.isfile(filename):
        path = os.path.dirname(filename)
        file = os.path.basename(filename)

        # check sim result
        try:
            if not filecmp.cmp(path + "/" + file, path.replace(dir1, dir3) + '/' + file):
                sim_fails += 1
    #            if sim_fails <= 10:
                print("Sim Error: ", path + "/" + file)
        except FileNotFoundError:
            sim_miss += 1

        # check emu result
        try:
            if not filecmp.cmp(path + "/" + file, path.replace(dir1, dir2) + '/' + file):
                emu_fails += 1
     #           if emu_fails < 10:
                print("Emu Error: ", path.replace(dir1, dir2) + "/" + file)
        except FileNotFoundError:
            emu_miss += 1

if emu_fails > 0:
    print("EMU Fails: ", emu_fails)
elif emu_miss > 0:
    print("EMU skipped. No files found: ", emu_miss)
else:
    print("EMU correct!")

if sim_fails > 0:
    print("SIM Fails: ", sim_fails)
elif sim_miss > 0:
    print("SIM skipped. No files found: ", sim_miss)
else:
    print("SIM correct!")

if emu_fails > 0 or sim_fails > 0:
    print("... exit(1)")
    exit(1)
exit(0)
