#!/usr/bin/python3
from __future__ import annotations
import os
import time
import re
from dataclasses import dataclass
import operator

result_directory = "./results/"


def lookahead(iterable):
    """Pass through all values from the given iterable, augmented by the
    information if there are more values to come after the current one
    (True), or if it is the last value (False).
    """
    # Get an iterator and pull the first value.
    it = iter(iterable)
    last = next(it)
    # Run the iterator to exhaustion (starting from the second value).
    for val in it:
        # Report the *previous* value (more to come).
        yield last, True
        last = val
    # Report the last value.
    yield last, False


@dataclass
class Result:
    file: str
    c: int
    u: int
    freq_vpro: int = 0
    freq_risc: int = 0
    freq_dma: int = 0
    cycles_vpro: int = 0
    cycles_risc: int = 0
    cycles_dma: int = 0
    parallel_dma: float = 99.9
    util_dma: float = 0.0
    util_l0: float = 0.0
    util_l1: float = 0.0
    util_ls: float = 0.0

    def __getitem__(self, key):
        return getattr(self, key)


def toFile(list, filename):
    with open(filename, "w") as output:
        field_order = []
        for field, has_more in lookahead(list[0].__dataclass_fields__):
            field_order.append(field)
            output.write(field)
            if has_more:
                output.write(",")
        output.write("\n")
        for result, res_has_more in lookahead(list):
            for field, has_more in lookahead(field_order):
                output.write(str(result[field]))
                if has_more:
                    output.write(",")
            if res_has_more:
                output.write("\n")
        print("[File Write] Done", filename)


results = []
for filename in os.listdir(result_directory):
    if filename.endswith("2L.log"):
        c = filename.split("C")[0].split("_")[-1]
        u = filename.split("U")[0].split("C")[-1]
        results.append(Result(file=result_directory + filename, c=int(c), u=int(u)))

for result in results:
    with open(result.file, 'r') as f:
        for line in f.readlines():
            if line.startswith("[VPRO] Statistics, Clock:"):
                clock = line.split("95m")[1].split("MHz")[0]
                cycles = line.split(", Total Clock Ticks:")[1]
                result.cycles_vpro = int(cycles)
                result.freq_vpro = int(clock)
            if line.startswith("[Risc] Statistics, Clock:"):
                clock = line.split("95m")[1].split("MHz")[0]
                cycles = line.split(", Total Clock Ticks:")[1]
                result.cycles_risc = int(cycles)
                result.freq_risc = int(clock)
            if line.startswith("[DMA]  Statistics, Clock:"):
                clock = line.split("95m")[1].split("MHz")[0]
                cycles = line.split(", Total Clock Ticks:")[1]
                result.cycles_dma = int(cycles)
                result.freq_dma = int(clock)
            if re.match(r'^\s*Lane 0:', line, re.M | re.I):
                result.util_l0 = float(line.split("Lane 0:")[1].split("%")[0])
            if re.match(r'^\s*Lane 1:', line, re.M | re.I):
                result.util_l1 = float(line.split("Lane 1:")[1].split("%")[0])
            if re.match(r'^\s*Lane LS:', line, re.M | re.I):
                result.util_ls = float(line.split("Lane LS:")[1].split("%")[0])
            if re.match(r'^\s*DMAs:(.*)not all DMAs are active together', line, re.M | re.I):
                result.parallel_dma = float(line.split("m")[1].split("%")[0])
            if re.match(r'^.*DMA:', line, re.M | re.I):
                result.util_dma = float(line.split(":")[1].split("%")[0])

# reverse=True
results.sort(key=operator.attrgetter('c', 'u'))
for result in results:
    print(result)

toFile(results, "results_tmp.csv")
