
#include <vpro.h>
#include <algorithm>
#include <cstdint>
#include <cstring>
#include <fstream>
#include <iostream>
#include <string>
#include "constants.h"
#include "includes/memory.h"
#include "random/patara_data_init.h"
#include "random/random_lib.h"
#include "riscv/eisV_hardware_info.hpp"
#include "riscv/eisv_aux.h"
#include "test_env.h"
#include "testsequences/InstructionSequenceGenerator.h"
#include "testsequences/RandomSequenceGenerator.h"


#include "instructions/loadstore/load.h"
#include "instructions/loadstore/loadb.h"
#include "instructions/loadstore/loadbs.h"
#include "instructions/loadstore/loads.h"
#include "instructions/loadstore/store.h"
#include "instructions/processing/abs.h"
#include "instructions/processing/add.h"
#include "instructions/processing/and.h"
#include "instructions/processing/mach.h"
#include "instructions/processing/mach_pre.h"
#include "instructions/processing/macl.h"
#include "instructions/processing/macl_pre.h"
#include "instructions/processing/max.h"
#include "instructions/processing/min.h"
#include "instructions/processing/mulh.h"
#include "instructions/processing/mull.h"
#include "instructions/processing/mulh_neg.h"
#include "instructions/processing/mulh_pos.h"
#include "instructions/processing/mull_neg.h"
#include "instructions/processing/mull_pos.h"
#include "instructions/processing/nand.h"
#include "instructions/processing/nop.h"
#include "instructions/processing/nor.h"
#include "instructions/processing/or.h"
#include "instructions/processing/shift_ar.h"
#include "instructions/processing/shift_ar_neg.h"
#include "instructions/processing/shift_ar_pos.h"
#include "instructions/processing/shift_lr.h"
#include "instructions/processing/sub.h"
#include "instructions/processing/xnor.h"
#include "instructions/processing/xor.h"
#include "instructions/processing/mv_mi.h"
#include "instructions/processing/mv_pl.h"
#include "instructions/processing/mv_nz.h"
#include "instructions/processing/mv_ze.h"


void print_heap_addr(const char* prefix = "...", const char* postfix = "\n") {
    char* a = new char;
    printf_warning("%s HEAP: %x %s", prefix, (int)(intptr_t)(a), postfix);
    delete a;
}

int main(int argc, char* argv[]) {
    setvbuf(stdout, nullptr, _IONBF, 0);

    sim_init(main, argc, argv);
//    aux_print_hardware_info("PATARA-based verification");
    sim_min_req(VPRO_CFG::CLUSTERS, VPRO_CFG::UNITS, VPRO_CFG::LANES);
#ifdef SIMULATION
    printf_warning("Mode: Simulation\n");
#else
    printf_warning("Mode: No Simulation\n");
#endif

    /**
     * General PATARA Configuration
     * e.g.:
     *  - Verbosity
     *  - Test Cases to run [default: COMPLETE]
     *  - Test Data initialization strategy (random input data / incremental data)
     *  - Execution strategy (sections: data copy, vpro code, eis-v code, comparison)
     */
    enum VERBOSITY {
        ERROR = 0,  // only errors
        WARNING = 1,    // only errors + warnings
        INFO = 2, // each sequence start/end + time is printed
        DEBUG = 3,  // detailed sequence + processing step info
        DEBUG_MORE = 4, // add iss execution state prints
        DEBUG_EVEN_MORE = 5 // add risc-v instruction simulation prints
    };
    VERBOSITY verbose = INFO;  // DEBUG
    constexpr bool always_print_instruction = false;    // default on if > INFO

    // which set of test should be executed
    constexpr TEST_ENVS::ENV test_env = TEST_ENVS::COMPLETE;  //COMPLETE, DEBUG
    constexpr bool random_VPRO = true;  // if true, test_env is ignored
    constexpr int random_count = 100;    // if random + this value positive, limit executed sequences
    constexpr int random_seq_len = 7;    // if random
    constexpr int random_random_seed = 5;  // if random
                                             // seq{static_cast<uint64_t>(rand())};  //1804289383};
                                             //998

    // whether to use random data or increment values
    constexpr bool random_data = false;
    constexpr bool random_data_use_static_const_seed = true;  // only if random data is used

    // repeat selected test env with new input data (random). TODO: exit of endless run not yet defined
    constexpr bool endless = false;

    constexpr bool skip_basic_coverage = true;

    constexpr bool skip_vpro_execution = false;
    constexpr bool skip_vpro_data = false;
    constexpr bool skip_eisv_execution = false;
    constexpr bool skip_eisv_verification = false;

    constexpr bool print_timing = false;

    constexpr uint32_t accu_reset_val = 0x138d; // also RF[0] (in vpro init and rv init used)

    /**
     * to generate a specific TestSequence (at begin) modify this function:
     */
    auto createSequence = [=](int nr, TestSequence *sequence, InstructionChainGenerator *sequenceGenerator) -> TestSequence *{
        TestSequence &seq = *sequence;
        for (auto& i : sequence->getInstructions()) {
            delete i;
        }
        sequence->clear();
        switch (nr){
//            case 0:
//                DefaultConfiurationModes::MAC_INIT_SOURCE = VPRO::MAC_INIT_SOURCE::ZERO;
//                DefaultConfiurationModes::MAC_RESET_MODE = VPRO::MAC_RESET_MODE::Z_INCREMENT;
//                DefaultConfiurationModes::MAC_H_BIT_SHIFT = 16;
//                DefaultConfiurationModes::MUL_H_BIT_SHIFT = 8;
//
//                seq.append(new Xnor(L0, /*x*/ 0, /*y*/ 0, /*z*/ 10,
//                    /*DST*/  Addressing(129, 0, 0, 0, Address::Type::DST),
//                    /*SRC1*/ Addressing(-1331657, Address::Type::SRC1),
//                    /*SRC2*/ Addressing(187, 0, 0, 0, Address::Type::SRC2),
//                    /*chain*/ false, /*update*/ true, /*blocking*/ false));
//                seq.append(new Macl(L0, /*x*/ 0, /*y*/ 0, /*z*/ 0,
//                    /*DST*/  Addressing(681, 0, 0, 0, Address::Type::DST),
//                    /*SRC1*/ Addressing(129, 0, 0, 0, Address::Type::SRC1),
//                    /*SRC2*/ Addressing(129, 0, 0, 0, Address::Type::SRC2),
//                    /*chain*/ false, /*update*/ false, /*blocking*/ false));
//                break;
            default:
//                printf_warning("Gen out of range. manual mode. exit...\n");
//                exit(100);
                sequence = sequenceGenerator->next();     // this will delete last one if not null
                break;
        }
        return sequence;
    };

    /**
     * Helper functions
     */
    auto isPrintLevel = [=](VERBOSITY level) -> bool {
        return (verbose >= level);
    };

    /**
     * Check configuration
     */
    if (!skip_eisv_verification) {
        assert(!skip_eisv_execution);
        assert(!skip_vpro_data);
        assert(!skip_vpro_execution);
    }
    if (print_timing){
        assert(!isPrintLevel(DEBUG) && "Debug adds to many prints. reduce debug level to measure time!");
    }


   /**
     * Create Memories (for Risc-V reference calc)
     * MM is a reference to the main memory (if not simulation)
     */
    uint8_t* mm = nullptr;
    int16_t*** lm;  // [cluster][unit][8192]
    int32_t**** rf; // [cluster][unit][lane][1024]


    /**
     * Cycle counters for performance
     */
    uint64_t data_gen_cycles = 0;
    uint64_t random_gen_cycles = 0;
    uint64_t dma_in_copy_cycles = 0;
    uint64_t dma_out_copy_cycles = 0;
    uint64_t vpro_exec_cycles = 0;
    uint64_t rv_ref_calc_cycles = 0;
    uint64_t rv_compare_cycles = 0;

    /**
     * Generate Random Data in INPUT_DATA_RANDOM section
     */
    if (random_data) {
        uint64_t start_cycles = aux_get_sys_time_lo();
        start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

        gen_random_mm_data(random_data_use_static_const_seed);

        uint64_t end_cycles = aux_get_sys_time_lo();
        end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

        data_gen_cycles += (end_cycles - start_cycles);

        if (isPrintLevel(DEBUG))
            printf_info(
                "Random Data in INPUT_DATA_RANDOM generated. [constant xoroshiro128plus init seed: "
                "%i]\n",
                init_seed);
    } else {
        uint64_t start_cycles = aux_get_sys_time_lo();
        start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

        gen_incremented_mm_data();

        uint64_t end_cycles = aux_get_sys_time_lo();
        end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

        data_gen_cycles += (end_cycles - start_cycles);
    }


    if (!skip_basic_coverage) {   // some basic tests / coverage generating calls
        // AT least some DMA transfers
#ifndef SIMULATION
        LocalMemory::initialize_vpro();
        RegisterFile::initialize_vpro();
        LocalMemory::store_to_main_memory();
        RegisterFile::store_to_main_memory();
        dcma_flush();
        // IO Invalids
        vpro_set_mac_init_source(static_cast<VPRO::MAC_INIT_SOURCE>(7));
        vpro_set_mac_reset_mode(static_cast<VPRO::MAC_RESET_MODE>(7));
        vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
        vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::NEVER);
        VPRO::DIM3::PROCESSING::mach(L0_1, DST_ADDR(0, 1, 2, 4), SRC_ADDR(0, 1, 2, 4), SRC_ADDR(0, 1, 2, 4), 1, 1, 1);  // TODO: LS + SRC2; SRC_IMM_3D(0, SRC_SEL_LS)
        VPRO::DIM3::PROCESSING::nop(L0_1, 10);
        // IO Busy reads
        dma_wait_to_finish(0xffffffff);
        vpro_wait_busy(0xffffffff, 0xffffffff);
        // No Mask active
        vpro_set_unit_mask(0);
        vpro_set_cluster_mask(0);
        VPRO::DIM3::PROCESSING::nop(L0_1, 10);
        dma_wait_to_finish(0x1);
        vpro_wait_busy(0x1);
        [[maybe_unused]] volatile int tmp;
        VPRO_BUSY_MASK_CL = 0xffffffff;
        tmp = VPRO_BUSY_MASK_CL;
        VPRO_BUSY_MASKED_DMA = 0xffffffff;
        tmp = VPRO_BUSY_MASKED_DMA;
        VPRO_BUSY_MASKED_VPRO = 0xffffffff;
        tmp = VPRO_BUSY_MASKED_VPRO;
        tmp = VPRO_LANE_SYNC;
        tmp = VPRO_DMA_SYNC;
        tmp = VPRO_SYNC;
        tmp = IDMA_STATUS_BUSY;
        tmp = VPRO_UNIT_MASK;
        tmp = VPRO_CLUSTER_MASK;
        vpro_lane_sync();
        vpro_dma_sync();
        vpro_sync();
        // unit not active
        vpro_set_cluster_mask(0xffffffff);
        vpro_set_unit_mask(0);
        VPRO::DIM3::PROCESSING::nop(L0_1, 10);
        dma_wait_to_finish(0xffffffff);
        vpro_wait_busy(0xffffffff, 0xffffffff);
        // FILL CMD FIFO
        vpro_set_unit_mask(0xffffffff);
        vpro_set_cluster_mask(0xffffffff);
        aux_wait_cycles(100);
        VPRO::DIM3::PROCESSING::nop(L0_1, 1000);    // block fifo
        VPRO::DIM3::PROCESSING::nop(L0_1, 1000);
        VPRO::DIM3::PROCESSING::nop(L0_1, 1000);
        for (int i = 0; i < 1000; ++i) {
            VPRO::DIM3::PROCESSING::nop(L0_1, 2);  // TODO: use add opcode to generate some fixed data that can be verified (e.g. 1...1000)
        }
        dma_wait_to_finish(0xffffffff);
        vpro_wait_busy(0xffffffff, 0xffffffff);
#endif
    }

    /**
     * EIS-V based execution uses ChainMemory() and Lane() instances for execution
     */
    ChainMemory l0_chain{"  L0       output FIFO", isPrintLevel(DEBUG_EVEN_MORE)};
    ChainMemory l1_chain{"     L1    output FIFO", isPrintLevel(DEBUG_EVEN_MORE)};
    ChainMemory ls_chain{"        LS output FIFO", isPrintLevel(DEBUG_EVEN_MORE)};
    Lane lane_ls{LS, ls_chain, ls_chain, l0_chain, l1_chain, isPrintLevel(DEBUG_EVEN_MORE)};
    Lane lane_0{L0, l0_chain, ls_chain, l1_chain, l1_chain, isPrintLevel(DEBUG_EVEN_MORE)};
    Lane lane_1{L1, l1_chain, ls_chain, l0_chain, l0_chain, isPrintLevel(DEBUG_EVEN_MORE)};

    if (!skip_eisv_execution) {
        mm = MainMemory::initialize(mm);
        if (isPrintLevel(DEBUG)) printf_info("MM initialized\n");
        lm = LocalMemory::initialize_riscv();
        if (isPrintLevel(DEBUG)) printf_info("LM Initialized for Reference Calculation\n");
        rf = RegisterFile::initialize_riscv_32();
        if (isPrintLevel(DEBUG)) printf_info("riscv RF_32 Initialized\n");
    }

test_begin:

    // performance counters (e.g. runtime for prints)
    aux_clr_sys_time();
    uint64_t start_cycle = aux_get_sys_time_lo();
    start_cycle += (uint64_t(aux_get_sys_time_hi()) << 32);

    // Sequence iteration counters and the sequence generator
    int test_case_count = 0;
    int test_max_batches = getMaxBatches(test_env);
    InstructionChainGenerator *sequenceGenerator;

    if (random_VPRO) {
        sequenceGenerator = new RandomSequenceGenerator{random_seq_len, random_random_seed};
        test_max_batches = 1;
    } else {
        sequenceGenerator = new InstructionSequenceGenerator();
    }

    // get total number of sequences
    int total_test_Sequences = 0;
    for (int batch = 0; batch < test_max_batches; ++batch) {
        sequenceGenerator->init(getBatch(test_env, batch)); // init generator with selected config
        total_test_Sequences += sequenceGenerator->getTotalSequences();
    }
    if (isPrintLevel(INFO)) {
        printf_info("\033[0m\033[97m"
            "###########################################################\n"
            "There %s %i Sets with a total of \033[4m%i Test Sequences\033[0m\033[97m\n"
            "###########################################################\n",
            (test_max_batches == 1) ? "is" : "are", test_max_batches, total_test_Sequences);
    }

    for (int test_batch = 0; test_batch < test_max_batches; ++test_batch) {
        sequenceGenerator->init(getBatch(test_env, test_batch));
        if (isPrintLevel(INFO)) {
            printf_info("%i./%i Set (same _addr, _end, _operands) with %i Test Sequences\n",
                test_batch, test_max_batches, random_VPRO?random_count:sequenceGenerator->getTotalSequences());
#ifdef SIMULATION
            if (getBatch(test_env, test_batch).introduceChainDelayCommands){
                printf_error("Critical Warning [ISS simulation only]: long delay commands are part of this chain tests!"
                    "This can cause the ISS to throw an error of detected \"long\" stalls. \n"
                    "This behavior of stalling is intended! \n\t "
                    "-> Increase MAX_STALL_CYCLES_IN_ROW in VectorLaneDebug.cpp (e.g. +20000) to avoid the ISS error!\n");
            }
#endif
        }

        auto sequence = new TestSequence();

        {
            uint64_t start_cycles = aux_get_sys_time_lo();
            start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

            sequence = createSequence(0, sequence, sequenceGenerator);

            uint64_t end_cycles = aux_get_sys_time_lo();
            end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

            random_gen_cycles += (end_cycles - start_cycles);
        }

        while (sequence != nullptr) {

//            // DEBUG determinism / repeatability
//            uint32_t seed = rand();
//            seed = 0x327b23c6;
//            printf_warning("SEED init: 0x%x\n", seed);
//            init_rand_seed(seed);

            if (random_VPRO && random_count > 0) {
                // in random sequence generation, end random gen when this number of sequences has been executed
                if (test_case_count >= random_count) break;
            }
            sequenceGenerator->vproRegisterConfig(isPrintLevel(DEBUG));

            test_case_count++;
            char buffer[4096];
            if (isPrintLevel(INFO)) {
                uint64_t cycles = aux_get_sys_time_lo();
                cycles += (uint64_t(aux_get_sys_time_hi()) << 32);
                uint64_t delta = cycles - start_cycle;
                start_cycle = cycles;
                uint32_t freq_k = get_gpr_risc_freq() / 1000;
                uint32_t time = cycles / freq_k;
                uint32_t delta_time = delta / freq_k;
                printf_info("[Total Tests: %4i, cycle: %7" PRIu64 ", time: %u ms]",
                    test_case_count, cycles, time);
                printf(" +%u ms", delta_time);
                printf(", %s", sequence->c_str(buffer, true, true, true));
                printf("\n");
            }
            if (isPrintLevel(DEBUG) || always_print_instruction) {
                print_heap_addr("Sequence Start Heap", "\n");
                int size = sequence->getInstructions().size();
                printf_info("There %s %i instructions in this Sequences to be executed\n",
                    (size == 1) ? "is" : "are", size);
                sequence->printInstructions(" [RUNNING]   ");
                if (isPrintLevel(DEBUG_MORE))
                    printf("%s", sequence->c_str_seq_gen(buffer));
            }

//            exit(5);

            if (sequence->check()) {
                if (!skip_vpro_execution) {
                    // set memories to input data
                    if (!skip_vpro_data) {
                        uint64_t start_cycles = aux_get_sys_time_lo();
                        start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        LocalMemory::initialize_vpro();
                        if (isPrintLevel(DEBUG))
                            printf_info(
                                "LM Initialized from MM (random input data start: 0x%08x)\n",
                                MMDatadumpLayout::INPUT_DATA_RANDOM);
                        RegisterFile::initialize_vpro();
                        if (isPrintLevel(DEBUG)) printf_info("vpro RF Initialized from LM\n");
                        // reset accu (used for initialization...)
                        VPRO::DIM3::PROCESSING::mull(L0_1, DST_ADDR(0, 0, 0, 0), SRC1_IMM_3D(1), SRC2_IMM_3D(accu_reset_val), 0, 0, 0);
                        lane_0.resetAccu(accu_reset_val);
                        lane_1.resetAccu(accu_reset_val);

                        uint64_t end_cycles = aux_get_sys_time_lo();
                        end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        dma_in_copy_cycles += (end_cycles - start_cycles);
                    }

                    // Test Code within VPRO
                    if (isPrintLevel(DEBUG)) printf_info("[start] VPRO Test Instructions\n");
                    vpro_sync();
                    if (isPrintLevel(DEBUG_MORE)){
#ifdef SIMULATION
                        debug |= DEBUG_INSTRUCTIONS;
                        debug |= DEBUG_INSTRUCTION_DATA;
                        debug |= DEBUG_LANE_ACCU_RESET;
//                    sim_wait_step();
#endif
                    }
                    {
                        uint64_t start_cycles = aux_get_sys_time_lo();
                        start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        sequence->vproExec();
                        vpro_sync();

                        uint64_t end_cycles = aux_get_sys_time_lo();
                        end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        vpro_exec_cycles += (end_cycles - start_cycles);
                    }
                    if (isPrintLevel(DEBUG_MORE)){
#ifdef SIMULATION
                        debug &= ~DEBUG_INSTRUCTIONS;
                        debug &= ~DEBUG_INSTRUCTION_DATA;
                        debug &= ~DEBUG_LANE_ACCU_RESET;
//                    sim_wait_step();
#endif
                    }
                    if (isPrintLevel(DEBUG)) printf_info("[done] VPRO Test Instructions\n");

                    if (!skip_vpro_data) {
                        uint64_t start_cycles = aux_get_sys_time_lo();
                        start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        LocalMemory::store_to_main_memory();
                        if (isPrintLevel(DEBUG))
                            printf_info("LMs Stored to MM (start: 0x%08x)\n",
                                MMDatadumpLayout::RESULT_DATA_LM);
                        RegisterFile::store_to_main_memory();
                        if (isPrintLevel(DEBUG))
                            printf_info("RFs Stored to MM (start: 0x%08x)\n",
                                MMDatadumpLayout::RESULT_DATA_RF);
                        dcma_flush();
                        if (isPrintLevel(DEBUG)) printf_info("dcma flushed\n");

                        uint64_t end_cycles = aux_get_sys_time_lo();
                        end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        dma_out_copy_cycles += (end_cycles - start_cycles);
                    }
                }

                if (!skip_eisv_execution) {
                    MainMemory::reference_calculation_init(mm, lm, rf);
                    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
                        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
                            rf[c][u][0][0] = accu_reset_val;
                            rf[c][u][1][0] = accu_reset_val;
                        }
                    }
                    if (isPrintLevel(DEBUG))
                        printf_info("MM initialized for Reference Calculation\n");

                    // Calculate Modification
                    if (isPrintLevel(DEBUG)) printf_info("[start] Reference Calculation\n");

                    {
                        uint64_t start_cycles = aux_get_sys_time_lo();
                        start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        auto instructions = sequence->getInstructions();
                        int last_instr_position = (int)(instructions.size());
                        for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
                            for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
                                // start here
                                int instr_position = 0;
                                lane_0.reset();
                                lane_1.reset();
                                lane_ls.reset();

                                // there is a command to run -> or a lane is still busy
                                while (instr_position < last_instr_position || lane_ls.isBusy() ||
                                       lane_0.isBusy() || lane_1.isBusy()) {
                                    // next instr. to be executed or null (lane's probably still busy)
                                    Instruction* nxt_instr = (instr_position < last_instr_position)
                                                   ? instructions[instr_position]
                                                   : nullptr;

                                    // skip NOPs on Risc-V based execution!
                                    while (nxt_instr != nullptr && strcmp(nxt_instr->getInstructionName(), "NOP") == 0){
                                        if (isPrintLevel(DEBUG)) printf_warning("[RV Reference Calc] Skipping (NOP): %s \n", nxt_instr->getInstructionName());
                                        // fetch next if possible
                                        instr_position++;
                                        if (instr_position < last_instr_position){
                                            nxt_instr = (instr_position < last_instr_position)
                                                          ? instructions[instr_position]
                                                          : nullptr;
                                            // check for NOP again, execute no NOP
                                            continue;
                                        }
                                        // break if no further instruction
                                        nxt_instr = nullptr;
                                    }

                                    // check which lane to assign
                                    // requires command selected lanes to be rdy/idle
                                    if (nxt_instr != nullptr) {
                                        bool start_able = true;
                                        // check if selected lane(s) rdy
                                        if (nxt_instr->getLane() & lane_ls.m_id)
                                            start_able &= !lane_ls.isBusy();
                                        if (nxt_instr->getLane() & lane_0.m_id)
                                            start_able &= !lane_0.isBusy();
                                        if (nxt_instr->getLane() & lane_1.m_id)
                                            start_able &= !lane_1.isBusy();
                                        if (start_able) {
                                            // start on selected lane
                                            if (nxt_instr->getLane() & lane_ls.m_id)
                                                lane_ls.newInstruction(nxt_instr);
                                            if (nxt_instr->getLane() & lane_0.m_id)
                                                lane_0.newInstruction(nxt_instr);
                                            if (nxt_instr->getLane() & lane_1.m_id)
                                                lane_1.newInstruction(nxt_instr);
                                            // this one got started. continue with next instruction
                                            instr_position++;
                                        }
                                    }

                                    // run command until it stalls or finishes
                                    lane_0.iteration(rf[c][u][0], nullptr);
                                    lane_1.iteration(rf[c][u][1], nullptr);
                                    lane_ls.iteration(nullptr, lm[c][u]);

                                    // if iteration accessed chain fifo, tick those data
                                    l0_chain.tick();
                                    l1_chain.tick();
                                    ls_chain.tick();
                                }  // all instructions done, no lane busy any more

                                assert(ls_chain.isEmpty());
                                assert(l0_chain.isEmpty());
                                assert(l1_chain.isEmpty());
                            }  // next unit
                        }      // next cluster

                        uint64_t end_cycles = aux_get_sys_time_lo();
                        end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        rv_ref_calc_cycles += (end_cycles - start_cycles);
                    }
                    if (isPrintLevel(DEBUG)) printf_info("[done] Reference Calculation\n");
                    // in simulation, copy mm content
                    MainMemory::initialize(mm);
                    if (isPrintLevel(DEBUG)) printf_info("MM initialized\n");
                }

                if (!skip_eisv_verification) {
                    bool lm_fail, rf_fail;
                    {
                        uint64_t start_cycles = aux_get_sys_time_lo();
                        start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        lm_fail = LocalMemory::compare_lm((uint8_t*)mm, lm, !isprint(DEBUG));  // silent, print details if more >= DEBUG
                        if (lm_fail && isPrintLevel(ERROR))
                            printf_error("LM Not Equal!\n");
                        else if (isPrintLevel(DEBUG))
                            printf_success("LM are all Equal!\n");
                        rf_fail = RegisterFile::compare_rf((uint8_t*)mm, rf, false); //!isprint(DEBUG));  // silent, print details if more >= DEBUG
                        if (rf_fail && isPrintLevel(ERROR))
                            printf_error("RF Not Equal!\n");
                        else if (isPrintLevel(DEBUG))
                            printf_success("RF are all Equal!\n");

                        uint64_t end_cycles = aux_get_sys_time_lo();
                        end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                        rv_compare_cycles += (end_cycles - start_cycles);
                    }
                    if (isPrintLevel(DEBUG)) printf_info("[done] Verification\n");
                    if (rf_fail || lm_fail) {
                        char buf[4000];
                        if (isPrintLevel(ERROR)) {
                            sequence->printInstructions(" [FAIL]     ");
                            printf("#####################################################\n");
                            printf("%s", sequence->c_str_vpro(buf));
                            printf("#####################################################\n");
                            printf("%s", sequence->c_str_seq_gen(buf));
                            printf("#####################################################\n");

                            if (isPrintLevel(DEBUG)) {  // exit if debug
                                printf_error("Exiting due to fails...\n");

                                std::ofstream out(
                                    "apps/tests/PATARA-based_verification/statistics/"
                                    "failed_instruction.log");
                                out << sequence->c_str_all(buf);
                                out.close();
                                sim_stop();
                                return 1;
                            }
                            sim_stop();
                            return 1;
                        }
                    } else if (always_print_instruction && !isPrintLevel(DEBUG)) {
                        int size = sequence->getInstructions().size();
                        const char* msg = " [SUCCESS] ";
                        //#ifdef SIMULATION
                        for (int i = 0; i < size; ++i) {
                            // move up [A]
                            // print, move left [D]
                            printf_success(
                                "\033[1A%s\033[11D", msg);  // \033 - sizeof(msg) = 18 - D
                        }
                        for (int i = 0; i < size; ++i) {
                            // move down [B]
                            printf_success("\033[1B");
                        }
                        //#else
                        //                        printf_success("%s\n", msg);
                        //#endif
                    } else if (isPrintLevel(DEBUG)) {
                        const char* msg = " [SUCCESS] ";
                        printf_success("%s\n", msg);
                    }
                } else {
                    if (isPrintLevel(DEBUG) || always_print_instruction) {
                        printf_success("Execution Done\n");
                    }
                }
            }

            if (print_timing){
                printf("-------------------------------\n");
                printf("Time for %i Sequences: \n", test_case_count);
                printf("\tdata_gen_cycles: %" PRIu64 "\n", data_gen_cycles);
                printf("\trandom_gen_cycles: %" PRIu64 " (avg: %" PRIu64 ")\n", random_gen_cycles, random_gen_cycles/test_case_count);
                printf("\tdma_in_copy_cycles: %" PRIu64 " (avg: %" PRIu64 ")\n", dma_in_copy_cycles, dma_in_copy_cycles/test_case_count);
                printf("\tdma_out_copy_cycles: %" PRIu64 " (avg: %" PRIu64 ")\n", dma_out_copy_cycles, dma_out_copy_cycles/test_case_count);
                printf("\tvpro_exec_cycles: %" PRIu64 " (avg: %" PRIu64 ")\n", vpro_exec_cycles, vpro_exec_cycles/test_case_count);
                printf("\trv_ref_calc_cycles: %" PRIu64 " (avg: %" PRIu64 ")\n", rv_ref_calc_cycles, rv_ref_calc_cycles/test_case_count);
                printf("\trv_compare_cycles: %" PRIu64 " (avg: %" PRIu64 ")\n", rv_compare_cycles, rv_compare_cycles/test_case_count);
                printf("-------------------------------\n");
            }

            {
                uint64_t start_cycles = aux_get_sys_time_lo();
                start_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                // next Test case
                sequence = createSequence(test_case_count, sequence, sequenceGenerator);

                uint64_t end_cycles = aux_get_sys_time_lo();
                end_cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

                random_gen_cycles += (end_cycles - start_cycles);
            }
        }
    }

    if (endless) {
        gen_random_mm_data(false);
        goto test_begin;
    }

    uint64_t cycles = aux_get_sys_time_lo();
    cycles += (uint64_t(aux_get_sys_time_hi()) << 32);
    uint32_t freq_k = get_gpr_risc_freq() / 1000;
    uint32_t time = cycles / freq_k;
    printf_info("############\nEnd. Executed Instruction Sequences: %4i, Cycles: %" PRIu64
                ", Time: %u ms | %u s\n",
        test_case_count,
        cycles,
        time,
        time / 1000);

    printf_success("[PATARA FINISH]\n");
    printf_info("[PATARA FINISH]\n");
    printf_warning("[PATARA FINISH]\n");
    sim_stop();
    exit(0);
    return 0;
}