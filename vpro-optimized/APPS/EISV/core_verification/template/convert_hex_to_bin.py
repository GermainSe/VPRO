

with open('fibonacci.32bin', 'w') as outputfile:
	with open('fibonacci.32hex', 'r') as inputfile:
		for line in inputfile.readlines():
			d = int(line, 16)
			outputfile.write(bin(d)[2:].zfill(32))
			outputfile.write("\n")
			
