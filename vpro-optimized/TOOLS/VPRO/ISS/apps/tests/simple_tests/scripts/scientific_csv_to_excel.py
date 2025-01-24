#!/usr/bin/python3

import pandas as pd
import sys

if len(sys.argv) <= 1:
	print("Call with name of inputfile as parameter!")
	exit(0)

data = pd.read_csv(sys.argv[1], sep='\t')
data.to_csv(sys.argv[1]+"_excel.csv",sep=',', float_format='%li', index=False)
