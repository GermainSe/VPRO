
NPROCS:=$(shell grep -c ^processor /proc/cpuinfo)

UNITS?=2
CLUSTERS?=2

iss:
	mkdir -p build_iss
	cmake -B build_iss iss_lib/
	mkdir -p build_aux
	cmake -B build_aux common_lib/ -DUNITS=${UNITS} -DCLUSTERS=${CLUSTERS}
	make -C build_iss -s -j ${NPROCS}
	make -C build_aux -s -j ${NPROCS}
	cp build_iss/libVPRO_SIMULATOR_LIB.so .
	cp build_iss/libVPRO_SIMULATOR_LIB_ISS.so .
	cp build_aux/libVPRO_AUX_LIB.a .
	@echo "\n Generated \e[1m\e[91m libVPRO_SIMULATOR_LIB.so \e[0m for use in Virtual Prototype!\n"
	@echo " Generated \e[1m\e[91m libVPRO_SIMULATOR_LIB_ISS.so \e[0m for use as ISS shared Lib!\n"
	@echo " Generated \e[1m\e[91m VPRO_AUX_LIB.a \e[0m for use as AUX static Lib!\n"




.PHONY: clean
clean:
	rm -rf build* *.a CMakeFiles CMakeCache.txt *.so
