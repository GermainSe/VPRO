#!/bin/bash


# see comments which test cases are generated
./eisv-patara-tests/generate_patara.sh complete


# using Makefile parallelism
./eisv-patara-tests/patara_run_script.sh complete
