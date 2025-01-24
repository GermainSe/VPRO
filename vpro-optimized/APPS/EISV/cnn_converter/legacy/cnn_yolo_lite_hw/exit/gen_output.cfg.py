



base = 286304000

for i in range(0, 125):
	addr = base + 7*7*2
	print("../data/vpro_final/output_"+str(i)+".bin "+str(addr)+" "+str(7*7*2)+"")
	base = addr
