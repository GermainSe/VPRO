#!/usr/bin/python3
import os, shutil
import subprocess
import time
import re
import shutil
from array import array

# config of this script
clusters = 32
units = 57
maxParallelRuns = 16

# create log dir
#if not os.path.exists("log"):
#	os.mkdir("log")
try:
	shutil.rmtree("/localtemp/gesper/log")
	os.makedirs("/localtemp/gesper/log")
except:
	print("error create log folder in localtemp")
	exit()
try:
	shutil.rmtree("/localtemp/gesper/error_log")
	os.makedirs("/localtemp/gesper/error_log")
except:
	print("error create error_log folder in localtemp")
	exit()
try:
	shutil.rmtree("/localtemp/gesper/builds")
	os.makedirs("/localtemp/gesper/builds")
except Exception as e:
	print("error create builds folder in localtemp")
	print(e)
	exit()
try:
	#os.makedirs("/localtemp/gesper/builds/init")
	shutil.copytree("../init", "/localtemp/gesper/builds/init")
except Exception as e:
	print("error copy init folder to localtemp")
	print(e)
	exit()
try:
	#os.makedirs("/localtemp/gesper/builds/exit")
	shutil.copytree("../exit/", "/localtemp/gesper/builds/exit/")
except Exception as e:
	print("error copy exit folder to localtemp")
	print(e)
	exit()
try:
	#os.makedirs("/localtemp/gesper/builds/data")
	shutil.copytree("../data/", "/localtemp/gesper/builds/data/")
except Exception as e:
	print("error copy data folder to localtemp")
	print(e)
	exit()

# call "make clean_all"
process = subprocess.Popen(["make", "clean_all"], cwd="../", stdout=open("./log/cleanup", "w"), stderr=subprocess.STDOUT)
print("[Start] Clean all")
if process.wait() != 0:
	print("retcode =", process.returncode)
	print(process.communicate()[1])
	print("ERROR on cleanup")
	exit(1)
print("[Done] Clean all")


# init
print("\n[Init] Clusters: [0-" + str(clusters) + "], Units: [0-"+ str(units)+"]\n")
runnings = []
starts = 0

# create list of configurations to be evaluated
configlist = []
for c in range(1, clusters+1):
	for u in range(1, units+1):
#		if (u * c) < 400: #200
			configlist.append((c, u))

# loop over configurations to evaluate
while (not (len(configlist) == 0)) or (len(runnings) > 0):

	# check if one finished
	for i in range(0, len(runnings)):
		if runnings[i][2].poll() != None: # process is not alive
			print("[Done "+str(i)+"/"+str(len(runnings))+"] Cluster: "+str(runnings[i][0])+", Unit: "+str(runnings[i][1]))
			if runnings[i][2].wait() != 0:
				print("  Error: Cluster("+str(runnings[i][0])+") & Unit("+str(runnings[i][1])+")")
				print(runnings[i][2].communicate()[0])
				print(runnings[i][2].communicate()[1])
			shutil.rmtree("/localtemp/gesper/builds/build_release_c"+str(runnings[i][0])+"u"+str(runnings[i][1]), ignore_errors=True)
			print("Removing: /localtemp/gesper/builds/build_release_c"+str(runnings[i][0])+"u"+str(runnings[i][1]))
			# remove from runnings list
			try :
			    del runnings[i]
			except IndexError:
			    print("Index "+str(i)+" Out of Range [0-"+str(len(runnings))+"]")
			# rm temp build dir and cp data
			try: shutil.copyfile("/localtemp/gesper/builds/data/statistic_out.csv", "./results.csv")
			except: print("data copy failed")
			break

	# start freeruns new configs
	time.sleep(0.1)
	freeRuns = maxParallelRuns - len(runnings)
	for i in range (0, min(maxParallelRuns, freeRuns)):
		if len(configlist) > 0:
			config = configlist.pop(0)
			c = config[0]
			u = config[1]
			process = subprocess.Popen(["make", "build_release=/localtemp/gesper/builds/build_release_c"+str(c)+"u"+str(u), "COMMENT=\"CNN_YOLO_LITE_DMA_BROADCAST\"", "CLUSTERS="+str(c), "UNITS="+str(u), "scripted"], cwd="../", stdout=open("/localtemp/gesper/log/C"+str(c)+"U"+str(u)+".log", "w"), stderr=open("/localtemp/gesper/error_log/C"+str(c)+"U"+str(u)+".log", "w"))
			starts += 1
			runnings.append((c, u, process))
			print("[Start "+str(starts) + "/" + str(clusters*units)+"] Cluster: "+str(c)+", Unit: "+ str(u) + " [Running processes: " + str(len(runnings))+"]")

# finished. cp data
try: shutil.copyfile("/localtemp/gesper/builds/data/statistic_out.csv", "./results.csv")
except: print("data copy failed")
print("[Script Finished]")
