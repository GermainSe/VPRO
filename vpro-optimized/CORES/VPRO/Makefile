#  SPDX-License-Identifier: MIT
#  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
#  SPDX-FileCopyrightText: 2024, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis

VERBOSE ?= 0

ifeq ($(VERBOSE),1)
    SHELL := /bin/bash -x
else
    SHELL := /bin/bash
endif

INSTRUCTION ?=
ifeq ($(INSTRUCTION),)
    INSTRUCTION_ARG :=
else
    INSTRUCTION_ARG := INSTRUCTION=$(INSTRUCTION)
endif

PATARA_OPTS ?=
# create patara asm files and clean patara directory, enable with 1
# to use existing asm files from patara/indata, use 0
PATARA_CREATE_AND_CLEAN ?= 1

## interleaving options
# repetitions of the whole ISA within a single assembly file
ISA_REPETITION?=10
# for debugging, limit number of maximum instructions in interlaving
INTERLEAVING_MAX_INSTRUCTIONS?=100
# Number of files
FILES?=1

GITLAB_CI ?= 0

TESTNAME?=default

#################################################
# 00. Help
#################################################
help:
	@echo "-------------------------------------------------------------------------  "
	@echo "-- Compile KAVUAKA Application --"
	@echo "check-core-kavuaka_64           -> check kavuaka 64-bit configuration"
	@echo "check-core-kavuaka_64_X2        -> check kavuaka 64-bit (X2) configuration"
	@echo "check-core-kavuaka-all          -> check kavuaka 64-bit (with/without X2) configuration"
	@echo "check-core-kavuaka-clean        -> cleaning generated files"

	@echo "  "
	@echo "-------------------------------------------------------------------------  "
	@echo "-- Simulation (ONLY KAVUAKA CORE) --"
	@echo "com-questa-core-hdl             -> Compiling Questa Project"
	@echo "sim-questa-core-hdl             -> Simulating Questa Project (Console)"
	@echo "sim-questa-core-hdl-gui         -> Simulating Questa Project (GUI)"
	@echo "sim-questa-clean                -> Cleaning generated files"
	@echo "  "
	@echo "-- Verification (ONLY KAVUAKA CORE) --"
	@echo "sim-questa-core-hdl-parata      -> Verification using PATARA"
	@echo "  "
	@echo "-------------------------------------------------------------------------  "
	@echo "-- Simulation (SYSTEM KAVUAKA CORE) --"
	@echo "  "
	@echo "  "
	@echo "-------------------------------------------------------------------------  "
	@echo "-- Synthesis --"
	@echo "  "
	@echo "  "


#################################################
# 00. Check core Kavuaka (Single Tests)
#################################################
check-core-kavuaka_64: check-core-kavuaka-clean
	@echo "Starting CORE Kavauka 64 verification ..."
	@cd test/kavuaka_test_gen ; make clean kavuaka64_CMMU VERBOSE=${VERBOSE}; cd -
	@cd test/checker ; ./checker.sh | tee ../../app/kavuaka_64_error.log ; cd --
	@find test/kavuaka_test_gen/outdata -name '*.ucdb' -exec vcover merge coverage.ucdb {} \+
	@python3 has_test_passed.py -i app/kavuaka_64_error.log -s test/kavuaka_test_gen/outdata/kavuaka64 | tee test/kavuaka_test_gen/exec_core_kavuaka_64.log

check-core-kavuaka_64_X2: check-core-kavuaka-clean
	@echo "Starting CORE Kavauka 64 verification ..."
	@cd test/kavuaka_test_gen ; make clean kavuaka64_X2_CMMU X2=1 VERBOSE=${VERBOSE}; cd -
	@cd test/checker ; ./checker.sh | tee ../../app/kavuaka_64_X2_error.log ; cd -
	@find test/kavuaka_test_gen/outdata -name '*.ucdb' -exec vcover merge coverage.ucdb {} \+
	@python3 has_test_passed.py -i app/kavuaka_64_X2_error.log -s test/kavuaka_test_gen/outdata/kavuaka64_x2 | tee test/kavuaka_test_gen/exec_core_kavuaka_64_X2.log

check-core-kavuaka-all: check-core-kavuaka_64 check-core-kavuaka_64_X2

check-core-kavuaka-clean: sim-questa-core-clean
	@-rm app/dump_v0rx.log app/dump_v1rx.log 
	@cd test/kavuaka_test_gen ; make clean ; cd -

#################################################
# 00. Check core Kavuaka (PATARA)
#################################################
check-core-kavuaka-patara-basic: check-core-kavuaka-patara-clean
	@echo "Starting PATARA (BASIC) verification ..."
	if [ "$(PATARA_CREATE_AND_CLEAN)" == "1" ]; \
	then cd test/patara ; make clean_all create_test_basic KAVUAKA_ASIC=0 ${INSTRUCTION_ARG} PATARA_OPTS="${PATARA_OPTS}" FILES=${FILES}; cd -; \
	fi
	@if [ "$(GITLAB_CI)" == "1" ]; \
	then cd test/patara ; make clean generate_test_basic KAVUAKA_ASIC=0 > compile_core_patara_basic.log ; cd -;\
	else cd test/patara ; make clean generate_test_basic KAVUAKA_ASIC=0 ; cd -;\
	fi
	@cd test/patara ; cp core_dump_ref.log dump_ref.log ; cd -
	@rm -f app/patara_core_basic_error.log
	@cd test/checker ; ./checker.sh | tee -a ../../app/patara_core_basic_error.log ; cd -
	@find test/patara/outdata -name '*.ucdb' -exec vcover merge coverage.ucdb {} \+
	@python3 has_test_passed.py -i app/patara_core_basic_error.log  -s test/patara/indata -t basic | tee test/patara/exec_core_patara_basic.log


check-core-kavuaka-patara-complete: check-core-kavuaka-patara-clean
	@echo "Starting PATARA (COMPLETE) verification ..."
	if [ "$(PATARA_CREATE_AND_CLEAN)" == "1" ]; \
	then cd test/patara ; make clean_all create_test_complete KAVUAKA_ASIC=0 ${INSTRUCTION_ARG} PATARA_OPTS="${PATARA_OPTS}" FILES=${FILES}; cd - ;\
	fi
	@if [ "$(GITLAB_CI)" == "1" ]; \
	then cd test/patara ; make clean generate_test_complete > compile_core_patara_complete.log; cd -;\
	else cd test/patara ; make clean generate_test_complete ; cd -;\
	fi
	@cd test/patara ; cp core_dump_ref.log dump_ref.log ; cd -
	@rm -f app/patara_core_complete_error.log
	@cd test/checker ;  ./checker.sh | tee -a ../../app/patara_core_complete_error.log ; cd -
	@find test/patara/outdata -name '*.ucdb' -exec vcover merge coverage.ucdb {} \+
	@python3 has_test_passed.py -i app/patara_core_complete_error.log -s test/patara/indata -t complete | tee test/patara/exec_core_patara_complete.log

check-core-kavuaka-patara-interleaving: check-core-kavuaka-patara-clean
	@echo "Starting PATARA (INTERLEAVING) verification ..."
	if [ "$(PATARA_CREATE_AND_CLEAN)" == "1" ]; \
	then cd test/patara ; make clean_all create_test_interleaving KAVUAKA_ASIC=0 ${INSTRUCTION_ARG} FILES=${FILES} ISA_REPETITION=${ISA_REPETITION} INTERLEAVING_MAX_INSTRUCTIONS=${INTERLEAVING_MAX_INSTRUCTIONS} PATARA_OPTS="${PATARA_OPTS}"; cd - ; \
	fi
	@if [ "$(GITLAB_CI)" == "1" ]; \
	then cd test/patara ; make clean generate_test_interleaving > compile_core_patara_interleaving.log ; cd -;\
	else cd test/patara ; make clean generate_test_interleaving ; cd -;\
	fi
	@cd test/patara ; cp core_dump_ref.log dump_ref.log ; cd -
	@rm -f app/patara_core_interleaving_error.log
	@cd test/checker ; ./checker.sh | tee -a ../../app/patara_core_interleaving_error.log ; cd -
	@find test/patara/outdata -name '*.ucdb' -exec vcover merge coverage.ucdb {} \+
	@python3 has_test_passed.py -i app/patara_core_interleaving_error.log -s test/patara/indata -t interleaving | tee test/patara/exce_core_patara_interleaving.log 


check-core-kavuaka-patara-all: check-core-kavuaka-patara-basic check-core-kavuaka-patara-complete check-core-kavuaka-patara-interleaving

check-core-kavuaka-patara-clean: sim-questa-core-clean
	@-rm app/dump.log
	if [ "$(PATARA_CREATE_AND_CLEAN)" == "1" ]; \
	then cd test/patara ; make clean; cd -; \
	fi

#########################

check-system-kavuaka-patara-basic: check-system-kavuaka-patara-clean
	@echo "Starting PATARA (BASIC) verification ..."
	if [ "$(PATARA_CREATE_AND_CLEAN)" == "1" ]; \
	then cd test/patara ; make clean_all create_test_basic KAVUAKA_ASIC=1 ${INSTRUCTION_ARG} PATARA_OPTS="${PATARA_OPTS}" FILES=${FILES}; cd - ; \
	fi 
	if [ "$(GITLAB_CI)" == "1" ]; \
	then cd test/patara ; make clean generate_test_basic KAVUAKA_ASIC=1 > compile_system_patara_basic.log ; cd - ; \
	else cd test/patara ; make clean generate_test_basic KAVUAKA_ASIC=1 ; cd - ; \
	fi
	@cd test/patara ; cp system_dump_ref.log dump_ref.log ; cd -
	@rm -f app/patara_system_basic_error.log
	@cd test/checker ;  ./checker.sh | tee -a ../../app/patara_system_basic_error.log ; cd -
	@python3 has_test_passed.py -i app/patara_system_basic_error.log  -s test/patara/indata -t basic | tee test/patara/exce_system_patara_basic.log


check-system-kavuaka-patara-complete: check-system-kavuaka-patara-clean
	@echo "Starting PATARA (BASIC) verification ..."
	if [ "$(PATARA_CREATE_AND_CLEAN)" == "1" ]; \
	then cd test/patara ; make clean_all create_test_complete KAVUAKA_ASIC=1 ${INSTRUCTION_ARG} PATARA_OPTS="${PATARA_OPTS}" FILES=${FILES}; cd - ; \
	fi 
	if [ "$(GITLAB_CI)" == "1" ]; \
	then cd test/patara ; make clean generate_test_complete KAVUAKA_ASIC=1 > compile_system_patara_complete.log ; cd - ; \
	else cd test/patara ; make clean generate_test_complete KAVUAKA_ASIC=1 ; cd - ; \
	fi
	@cd test/patara ; cp system_dump_ref.log dump_ref.log ; cd -
	@rm -f app/patara_system_complete_error.log
	@cd test/checker ;  ./checker.sh | tee -a ../../app/patara_system_complete_error.log ; cd -
	@python3 has_test_passed.py -i app/patara_system_complete_error.log -s test/patara/indata -t complete | tee test/patara/exce_system_patara_complete.log


check-system-kavuaka-patara-interleaving: check-system-kavuaka-patara-clean
	@echo "Starting PATARA (BASIC) verification ..."
	if [ "$(PATARA_CREATE_AND_CLEAN)" == "1" ]; \
	then cd test/patara ; make clean_all create_test_interleaving KAVUAKA_ASIC=1 ${INSTRUCTION_ARG} FILES=${FILES} ISA_REPETITION=${ISA_REPETITION} INTERLEAVING_MAX_INSTRUCTIONS=${INTERLEAVING_MAX_INSTRUCTIONS} PATARA_OPTS="${PATARA_OPTS}"; cd - ; \
	fi 
	if [ "$(GITLAB_CI)" == "1" ]; \
	then cd test/patara ; make clean generate_test_interleaving KAVUAKA_ASIC=1 > compile_system_patara_interleaving.log ; cd - ; \
	else cd test/patara ; make clean generate_test_interleaving KAVUAKA_ASIC=1 ; cd - ; \
	fi
	@cd test/patara ; cp system_dump_ref.log dump_ref.log ; cd -
	@rm -f app/patara_system_interleaving_error.log
	@cd test/checker ;  ./checker.sh | tee -a ../../app/patara_system_interleaving_error.log ; cd -
	@python3 has_test_passed.py -i app/patara_system_interleaving_error.log -s test/patara/indata -t interleaving | tee test/patara/exce_system_patara_interleaving.log


check-system-kavuaka-patara-all: check-system-kavuaka-patara-basic check-system-kavuaka-patara-complete check-system-kavuaka-patara-interleaving

check-system-kavuaka-patara-clean: sim-questa-system-clean

#########################
check-system-kavuaka-interface: check-system-kavuaka-interface-clean
	@echo "Starting INTERFACE verification ..."
	@cd test/kavuaka_system ; make clean only1 only2 ; cd -
	@cd test/patara ; cp system_dump_ref.log dump_ref.log ; cd -
	@cd test/checker ; ./checker.sh | tee ../../app/interface_system_error.log ; cd -
	@python3 has_test_passed.py -i app/interface_system_error.log -s test/kavuaka_system/outdata/kavuaka64 | tee test/kavuaka_system/exec_system_interface.log

check-system-kavuaka-uart: check-system-kavuaka-interface-clean
	@echo "Starting INTERFACE verification ..."
	@cd test/kavuaka_system ; make clean uart ; cd -
	@cd test/patara ; cp system_dump_ref.log dump_ref.log ; cd -
	@cd test/checker ; ./checker.sh | tee ../../app/uart_system_error.log ; cd -
	@python3 has_test_passed.py -i app/uart_system_error.log -s test/kavuaka_system/outdata/kavuaka64 | tee test/kavuaka_system/exec_system_uart.log


check-system-kavuaka-interface-clean: sim-questa-system-clean


#################################################
# 01. VHDL-Design Simulation (VECTOR UNIT)
#################################################
com-questa-hdl:
	@echo "Starting VHDL simulation ..."
	@vsim -c -do "source sim/questasim/simulate.tcl; start -O:compile; quit -f"
















sim-questa-core-hdl:
	@echo "Starting VHDL simulation ..."
	@vsim -c -do "source sim/questasim/kavuaka_core/simulate.tcl; start -O:simulate -T:${TESTNAME}; run -all;"
#	@vsim -do "source sim/questasim/kavuaka_core/simulate.tcl; start -O:simulate"

sim-questa-core-hdl-gui:
	@echo "Starting VHDL simulation ..."
#	@vsim -c -do "source sim/questasim/kavuaka_core/simulate.tcl; start -O:simulate; quit -f"
	@vsim -do "source sim/questasim/kavuaka_core/simulate.tcl; start -O:simulate -T:${TESTNAME};"

com-questa-core-hdl-patara:
	@echo "Starting VHDL simulation ..."
	@vsim -c -do "source sim/questasim/kavuaka_core/simulate.tcl; start -O:compile-patara; quit -f"

sim-questa-core-hdl-patara:
	@echo "Starting VHDL simulation ..."
	@vsim -c -do "source sim/questasim/kavuaka_core/simulate.tcl; start -O:simulate-patara -T:${TESTNAME}; run -all;"

sim-questa-core-hdl-patara-gui:
	@echo "Starting VHDL simulation ..."
	@vsim -do "source sim/questasim/kavuaka_core/simulate.tcl; start -O:simulate-patara -T:${TESTNAME};"


sim-questa-clean:
	@source init_tools; vsim -c -do "source sim/questasim/simulate.tcl; start -O:clean; quit -f"
	-rm -f transcript
	-rm -f vsim.wlf
	-rm -f vsim_stacktrace.vstf
	-rm -rf coverage* html_coverage

#################################################
# 01. VHDL-Design Simulation (SYSTEM)
#################################################
com-questa-system-hdl: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:compile; quit -f"

sim-questa-system-hdl: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@hexdump -v -e '1/1 "%02x\n"' app/imem.bin > app/imem.hex
	@echo '@0' > app/imem.hex
	@xxd -p app/imem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/imem.hex
	@echo '@20000' > app/dmem.hex
	@dd if=/dev/urandom of=app/dmem.bin bs=1K count=10
	@xxd -p app/dmem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/dmem.hex
	@vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate; run -all;"
#	@vsim -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate"

sim-questa-system-hdl-gui: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@hexdump -v -e '1/1 "%02x\n"' app/imem.bin > app/imem.hex 
	@echo '@0' > app/imem.hex
	@xxd -p app/imem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/imem.hex
	@echo '@20000' > app/dmem.hex
	@dd if=/dev/urandom of=app/dmem.bin bs=1K count=10
	@xxd -p app/dmem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/dmem.hex
#	@vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate; quit -f"
	@vsim -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate"

com-questa-system-hdl-patara: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:compile-patara; quit -f"

sim-questa-system-hdl-patara: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@hexdump -v -e '1/1 "%02x\n"' app/imem.bin > app/imem.hex 
	@echo '@0' > app/imem.hex
	@xxd -p app/imem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/imem.hex
	@echo '@20000' > app/dmem.hex
	@dd if=/dev/urandom of=app/dmem.bin bs=1K count=10
	@xxd -p app/dmem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/dmem.hex
	@vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate-patara; run -all;"

sim-questa-system-hdl-patara-gui: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@hexdump -v -e '1/1 "%02x\n"' app/imem.bin > app/imem.hex 
	@echo '@0' > app/imem.hex
	@xxd -p app/imem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/imem.hex
	@echo '@20000' > app/dmem.hex
	@dd if=/dev/urandom of=app/dmem.bin bs=1K count=10
	@xxd -p app/dmem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/dmem.hex
	@vsim -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate-patara"

com-questa-system-hdl-uart: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:compile-patara-uart; quit -f"

sim-questa-system-hdl-uart: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@hexdump -v -e '1/1 "%02x\n"' app/imem.bin > app/imem.hex 
	@echo '@0' > app/imem.hex
	@xxd -p app/imem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/imem.hex
	@echo '@20000' > app/dmem.hex
	@dd if=/dev/urandom of=app/dmem.bin bs=1K count=10
	@xxd -p app/dmem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/dmem.hex
	@vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate-patara-uart; run -all;"

sim-questa-system-hdl-uart-gui: sim-questa-system-clean
	@echo "Starting VHDL simulation ..."
	@hexdump -v -e '1/1 "%02x\n"' app/imem.bin > app/imem.hex 
	@echo '@0' > app/imem.hex
	@xxd -p app/imem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/imem.hex
	@echo '@20000' > app/dmem.hex
	@dd if=/dev/urandom of=app/dmem.bin bs=1K count=10
	@xxd -p app/dmem.bin | tr '[:lower:]' '[:upper:]' | sed 's/../& /g' >> app/dmem.hex
	@vsim -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:simulate-patara-uart"

sim-questa-system-clean:
	@source init_tools; vsim -c -do "source sim/questasim/kavuaka_system/simulate.tcl; start -O:clean; quit -f"
	-rm -f transcript
	-rm -f vsim.wlf
	-rm -f vsim_stacktrace.vstf
	-rm -rf coverage* html_coverage


#################################################
# 02. COVERAGE
#################################################
coverage_report_gen:
	vcover report -output html_coverage -details -html -threshL 50 -threshH 90 coverage.ucdb
	vcover report -output coverage.report -details coverage.ucdb
	@echo "Generated: coverage.ucdb + html report + coverage.report"

coverage_gui_open:
	vsim -viewcov coverage.ucdb



#################################################
# 03. NETLIST (SYNTHESIS) - Design Verification
#################################################
sim-net:
	@echo "Starting NETLIST (SYNTHESIS) verification ..."
	@source init_tools; vsim -c -do "source scr/simulate.tcl; start -O:simulate-net; quit -f"



