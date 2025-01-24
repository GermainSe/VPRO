import os
from pathlib import Path
import re

output_folder = './dcma_exploration/'

pathlist = Path(output_folder).glob('**/*.txt')
result = []

const_ram_size_bytes = 4096 * 64 / 8

for path in pathlist:
    print(path)
    parameters = re.search('/(.*).txt', str(path)).group(1).split("_")
    nr_rams = int(parameters[0])
    cache_line_size_bytes = int(parameters[1])
    associativity = int(parameters[2])

    # string to search in file
    with open(path, 'r') as fp:
        # read all lines using readline()
        fps = 0
        lane_active = 0
        dma_active = 0
        both_active = 0
        eisv_active = 0
        bus_bandw = 0
        dma_bandw = 0
        busy = 0
        read_hit = 0
        write_hit = 0
        lines = fp.readlines()
        for row in lines:
            # check if string present on a current line
            fps_word = 'Risc-V Clock Cycles'
            fps_word2 = 'FPS'
            lane_word = "(any) Lane active:"
            dma_word = "(any) DMA active:"
            both_word = "(any) Lane AND (any) DMA active:"
            eisv_word = "Not Synchronizing VPRO:"
            bus_bandw_word = "Average DCMA <-> Bus Bandwidth"
            dma_bandw_word = "Average DCMA <-> DMA Bandwidth"
            busy_word = "Ext Mem Access Busy"
            read_hit_word = "Read Hit Rate"
            write_hit_word = "Write Hit Rate"

            if row.find(fps_word) != -1 and row.find(fps_word2) != -1:
                fps = float(re.search('ms, (.*) FPS', row).group(1).replace(',', '.'))
            if row.find(lane_word) != -1 and lane_active == 0:
                lane_active = float(re.search('Cycles \( (.*)%\)', row).group(1))
            if row.find(dma_word) != -1 and dma_active == 0:
                dma_active = float(re.search('Cycles \( (.*)%\)', row).group(1))
            if row.find(both_word) != -1 and both_active == 0:
                both_active = float(re.search('Cycles \( (.*)%\)', row).group(1))
            if row.find(eisv_word) != -1 and eisv_active == 0:
                eisv_active = float(re.search('Cycles \( (.*)% Busy', row).group(1))
            if row.find(bus_bandw_word) != -1 and bus_bandw == 0:
                bus_bandw = float(re.search(':(.*)\n', row).group(1))
            if row.find(dma_bandw_word) != -1 and dma_bandw == 0:
                dma_bandw = float(re.search(':(.*)\n', row).group(1))
            if row.find(busy_word) != -1 and busy == 0:
                busy = float(re.search(':(.*)%', row).group(1))
            if row.find(read_hit_word) != -1 and read_hit == 0:
                read_hit = float(re.search(':(.*)%', row).group(1))
            if row.find(write_hit_word) != -1 and write_hit == 0:
                write_hit = float(re.search(':(.*)%', row).group(1))

        nr_cache_lines = int(nr_rams * const_ram_size_bytes / cache_line_size_bytes)
        result.append(
            [nr_rams, cache_line_size_bytes, nr_cache_lines, associativity, fps, lane_active, dma_active, both_active,
             eisv_active, dma_bandw, bus_bandw, busy, read_hit, write_hit])

result.sort()
import csv

with open(output_folder + 'result.csv', 'w', newline='') as csvfile:
    writer = csv.writer(csvfile)
    writer.writerow(
        ['nr_rams', 'cache_line_size/bytes', 'nr_cache_lines', 'associativity', 'fps', 'lane_active/%', 'dma_active/%',
         'both_active/%',
         'eisv_active/%', 'dma_bandwidth/GB/s', 'bus_bandwidth/GB/s', 'busy/%', 'read hit rate/%', 'write hit rate/%'])
    for line in result:
        writer.writerow(line)
