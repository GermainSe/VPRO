#include <stdint.h>
#include <math.h>


#include <vpro.h>

// Intrinsic auxiliary library
#include "core_wrapper.h"

#include "includes/defines.h"
#include "includes/helper.h"

#include "includes/tests/features/chaining_tester.h"
#include "includes/tests/features/blocking_tester.h"
#include "includes/tests/features/chaining_ls_tester.h"
#include "includes/tests/instructions/min_max_vector_tester.h"
#include "includes/tests/features/dma_padding_tester.h"
#include "includes/tests/features/large_alpha.h"
#include "includes/tests/features/large_alpha_beta.h"
#include "includes/tests/features/large_beta.h"
#include "includes/tests/features/large_x_end.h"
#include "includes/tests/features/large_x_end_y_end.h"
#include "includes/tests/features/large_y_end.h"
#include "includes/tests/features/dcma_flush_tester.h"
#include "includes/tests/features/dma_tester.h"

void perform_tests_C1U1(int argc, char *argv[]);

void perform_tests_C1U2(int argc, char *argv[]);


/*
 *   create tests generally in a way, that the hardware can be tested as well
 *   dma_ext1D_to_loc1D(0, (uint32_t)((intptr_t)(&test_data)),   LM_TEST_ARRAY_IN_DATA,   NUM_TEST_ENTRIES*2*2);
 *   https://git.ims-as.uni-hannover.de/ASIP/CORES/CORE_VPRO/-/wikis/Tutorial(s)
 */

//----------------------------------------------------------------------------------
//----------------------------------Main--------------------------------------------
//----------------------------------------------------------------------------------
int main(int argc, char *argv[]) {

    perform_tests_C1U1(argc, argv);
    //perform_tests_C1U2(argc, argv);
    return 1;
}

void perform_tests_C1U1(int argc, char *argv[]) {
    printf("\ntest ..... with ");
    printf("HW-CONFIG: C%iU%iL%i\n", VPRO_CFG::CLUSTERS, VPRO_CFG::UNITS, VPRO_CFG::LANES);
    sim_init(main, argc, argv);
    sim_min_req(1, 1, 2);
    //core_->pauseSim();


    //debug |= DEBUG_PIPELINE;
    //debug |= DEBUG_LANE_STALLS;
    //debug |= DEBUG_GLOBAL_TICK;
    //debug |= DEBUG_INSTRUCTION_DATA;




    blockingTest::tester::perform_tests();
    printf("##################################################\n Chain Test with Vector Length 15 & Data check Finished!\n##################################################\n");

    large_x_end::perform_tests();
    large_y_end::perform_tests();
    large_x_end_y_end::perform_tests();
    printf("##################################################\n VPRO Instruction word length test Finished!\n##################################################\n");

    large_alpha::perform_tests();
    large_beta::perform_tests();
    large_alpha_beta::perform_tests();
    printf("##################################################\n VPRO Complex addressing parameter test Finished!\n##################################################\n");

    dma_padding_tester::perform_tests();
    printf("##################################################\n DMA Padding Test Finished!!\n##################################################\n");


    chaining_tester::TEST_VECTOR_LENGTH = 15;
    chaining_tester::SKIP_DATA = true;
    chaining_tester::perform_tests();
    printf("##################################################\n Chain Test with Vector Length 15 & Data check Finished!\n##################################################\n");

    chaining_tester::TEST_VECTOR_LENGTH = 15;
    chaining_tester::SKIP_DATA = false;
    chaining_tester::perform_tests();
    printf("##################################################\n Chain Test with Vector Length 15 & fast schedule Finished!\n##################################################\n");

    chaining_tester::TEST_VECTOR_LENGTH = 1;
    chaining_tester::SKIP_DATA = false;
    chaining_tester::perform_tests();
    printf("##################################################\n Chain Test with Vector Length 1 & Data check Finished!\n##################################################\n");

    chaining_tester::TEST_VECTOR_LENGTH = 1;
    chaining_tester::SKIP_DATA = true;
    chaining_tester::perform_tests();
    printf("##################################################\n Chain Test with Vector Length 1 & fast schedule Finished!\n##################################################\n");

    min_max_vector_tester::perform_tests();
    printf("##################################################\n Min Max Vector Test Finished!\n##################################################\n");

    dcma_flush_tester::perform_tests();
    printf("##################################################\n DCMA Flush Test Finished!\n##################################################\n");

    dma_tester::perform_tests();
    printf("##################################################\n DMA Test Finished!\n##################################################\n");

    sim_stop();
}

void perform_tests_C1U2(int argc, char *argv[]) {
    /*
    HW.LANES = NUM_VECTORLANES;
    HW.CLUSTERS = 1;    // NUM_CLUSTERS
    HW.UNITS = 2; // NUM_VU_PER_CLUSTER;
    HW.MM_SIZE = 1024 * 1024 * 512;
    HW.LM_SIZE = 8192;
    HW.RF_SIZE = 1024;*/

    printf("\ntest ..... with ");
    printf("HW-CONFIG: C%iU%iL%i\n", VPRO_CFG::CLUSTERS, VPRO_CFG::UNITS, VPRO_CFG::LANES);
    sim_init(main, argc, argv, VPRO_CFG::MM_SIZE, VPRO_CFG::LM_SIZE, VPRO_CFG::RF_SIZE, VPRO_CFG::CLUSTERS, VPRO_CFG::UNITS, VPRO_CFG::LANES, VPRO_CFG::DCMA_LINE_SIZE,
             VPRO_CFG::DCMA_ASSOCIATIVITY, VPRO_CFG::DCMA_NR_BRAMS, VPRO_CFG::DCMA_BRAM_SIZE);
    core_->pauseSim();

    //debug |= DEBUG_PIPELINE;
    //debug |= DEBUG_LANE_STALLS;
    //debug |= DEBUG_GLOBAL_TICK;
    debug |= DEBUG_INSTRUCTION_DATA;

    chaining_ls_tester::perform_tests();

    sim_stop();
}
