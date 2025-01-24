# Verification Framework for VPRO System

Goal: Run all VPRO Instructions with all possible parameters
  - instruction functions (opcode)
  - addressing parameters (complex addressing parameters + end)
  - chaining (stalls)
  - special registers with configuration

Verification by corresponding code on EIS-V
  - Simulated VPRO instruction execution
  - Compare of VPRO results with this reference (self checking testbench)



## Code Documentation

Convoy defines Instructions to test (fixed parameters, sequence)




## TODOs

1. chaining order of instructions in convoy not yet full flexible (requires generating instruction always first)
    - extend verification (Risc-V based VPRO simulation)
    - allow vector cmd chain order randomization
    - allow sub vector commands
    - allow chaining over convoy
2. all instructions with reference code
3. generation of random convoys
    - random instructions, random parameters [or test all possibilities instead of randomization]
    - indirect addressing operands
    - limitation detection in (random generated) convoys (e.g. filter endless loops)
        - avoid of endless loops / vpro endless execution
4. randomize of input data



## performance improvement ideas

memory:: reference_calculation_init
    -> use dma to copy?

memory:: compare
    -> copy vpro results to buffer by dma, then compare (low address -> in dcache)

memory:: initialize_rf_32/16 -> initialite -> cut
    -> inside a single loop (use dcache locality)
    -> instead blocks of all

coverage runs:
    - remove data copy to extern, EIS-V reference calc, compare
    -> only vpro code 