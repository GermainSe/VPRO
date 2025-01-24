import os
from pathlib import Path

base_cmd = 'make release SILENT=--windowless'
output_folder = './dcma_exploration/'
Path(output_folder).mkdir(parents=True, exist_ok=True)

parallel_runs = 4

list_num_rams = [8, 16, 32, 64, 128]
list_line_size = [128, 256, 512, 1024, 2048, 4096, 8192, 16384]
list_associativity = [1, 2, 4, 8, 16, 32]

const_ram_size_bytes = 4096 * 64 / 8

list_cmd = []
for num_rams in list_num_rams:
    for line_size in list_line_size:
        for associativity in list_associativity:
            total_ram_size = const_ram_size_bytes * num_rams
            required_ram_size = line_size * associativity
            if total_ram_size >= required_ram_size:
                file_name = output_folder + str(num_rams) + '_' + str(line_size) + '_' + str(associativity) + '.txt'
                list_cmd.append(base_cmd + " NR_RAMS=" + str(num_rams) + ' LINE_SIZE=' + str(line_size)
                                + ' ASSOCIATIVITY=' + str(associativity) + ' build_release=build_dcma_'
                                + str(num_rams) + '_' + str(line_size) + '_' + str(associativity) + ' > ' + file_name)


def run(cmd):
    print("starting " + cmd)
    os.system(cmd)


from multiprocessing import Pool

pool = Pool(processes=parallel_runs)
pool.map(run, list_cmd)

print("cleaning ...")
os.system('rm -rf build_dcma*')
