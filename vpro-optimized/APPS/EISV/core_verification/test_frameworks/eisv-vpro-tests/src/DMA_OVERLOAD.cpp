#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <vector>
#include <random>
#include <algorithm>

#define NUM_TEST_ENTRIES 144
#define X_Y 12 // xend = yend = sqrt(NUM_TEST_...)

#include "test_defines.h"
#include "vpro_test_functions.h"


// .nobss = uninitialized! (speed up sim), .vpro sections the risc access with dma (uninitialized as well)
volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) result_array[NUM_TEST_ENTRIES*2*8*4];  // two independent lanes
volatile int16_t __attribute__ ((section (".vpro"))) result_array_zeros[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_large[1024 * 1024];

int main(int argc, char *argv[]) {

    //!SIMULATION
    //HW.UNITS = 8;
    //HW.CLUSTERS = 4;
    //@NOTE Maybe further sim min req required
    INIT();


    printf("Assuming %i Clusters, each with %i Units\n", VPRO_CFG::CLUSTERS, VPRO_CFG::UNITS);

    printf("In  0x%x[%i]\n    0x%x[%i]\n", uint32_t(intptr_t(test_array_1)), NUM_TEST_ENTRIES, uint32_t(intptr_t(test_array_2)), NUM_TEST_ENTRIES);
    printf("Out 0x%x[%i]\n", uint32_t(intptr_t(result_array)), NUM_TEST_ENTRIES*2*8*4);

    printf("Start\n");

    /**
     * Prepare
     */
    int16_t count = 0;
    // reset result array
    for (volatile int16_t &i : result_array){
        i = 0xdead;
        if (++count > NUM_TEST_ENTRIES*2) break;
    }
    count = -NUM_TEST_ENTRIES;
    // input data generation
    for (volatile int16_t &i : test_array_1){
        i = count;
        count++;
        count++;
    }
    count = NUM_TEST_ENTRIES;
    for (volatile int16_t &i : test_array_2){
        i = count;
        count--;
    }
    // result: 0 - 1 - 2 - 3 - 4 - ...

    // set LM to 0 value
    for (int c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
        for (int u = 0; u < VPRO_CFG::UNITS; ++u) {
            // input section
            dma_e2l_1d(1<<c, 1<<b, uint64_t(intptr_t(&(result_array_zeros[0]))), 0, NUM_TEST_ENTRIES);
            dma_e2l_1d(1<<c, 1<<b, uint64_t(intptr_t(&(result_array_zeros[0]))), NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
            // output section
            dma_e2l_1d(1<<c, 1<<b, uint64_t(intptr_t(&(result_array_zeros[0]))), 2*NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
        }
    }

    // set whole RF to dead / error value
    __vpro(L0_1, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
           SRC2_IMM_2D(0), SRC2_IMM_2D(0xdead), X_Y-1, X_Y-1);

    // reset shift registers
#if BITWIDTH_REDUCE_TO_16_BIT == 1
    vpro_mac_h_bit_shift(16);
    vpro_mul_h_bit_shift(16);
#else
    vpro_mac_h_bit_shift(24);
    vpro_mul_h_bit_shift(24);
#endif

    // Sync
    vpro_wait_busy(0xffffffff, 0xffffffff);
    dma_wait_to_finish(0xffffffff);

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    std::mt19937 g(1562);
    struct DMA{
        uint32_t c;
        uint32_t u;
        uint32_t loc;
        uint64_t ext;
    };

    /**
     * Test
     */
    // set LM to inputs
    // input load
    std::vector<DMA> dma_input_work;
    for (int c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
        for (int u = 0; u < VPRO_CFG::UNITS; ++u) {
            DMA d1, d2;

            d1.c = c;
            d1.u = u;
            d1.loc = 0;
            d1.ext = uint64_t(intptr_t(&(test_array_1[0])));

            d2.c = c;
            d2.u = u;
            d2.loc = NUM_TEST_ENTRIES;
            d2.ext = uint64_t(intptr_t(&(test_array_2[0])));

            dma_input_work.push_back(d1);
            dma_input_work.push_back(d2);
        }
    }


    std::shuffle(std::begin(dma_input_work), std::end(dma_input_work), g);

    for (DMA d : dma_input_work){
        dma_e2l_1d(1 << d.c, 1 << d.u, d.ext, d.loc, NUM_TEST_ENTRIES);
    }

    dma_wait_to_finish(0xffffffff);

    // load 0
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOAD, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
           SRC1_ADDR(0, 1, X_Y), SRC2_IMM_2D(0), X_Y-1, X_Y-1);

    // store 0 to RF
    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
           SRC1_IMM_2D(0), SRC2_LS_2D, X_Y-1, X_Y-1);

    // load 1
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOAD, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
           SRC1_ADDR(0, 1, X_Y), SRC2_IMM_2D(NUM_TEST_ENTRIES), X_Y-1, X_Y-1);

    // add to RF
    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
           SRC1_ADDR(0, 1, X_Y), SRC2_LS_2D, X_Y-1, X_Y-1);

    // chain
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
           SRC1_ADDR(0, 1, X_Y), SRC2_IMM_2D(0), X_Y-1, X_Y-1);
    VPRO::DIM2::LOADSTORE::store(NUM_TEST_ENTRIES*2,
                                 0, 1, X_Y,
                                 X_Y - 1, X_Y - 1,
                                 L0);
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
//           SRC1_CHAINING_2D(0), SRC2_IMM_2D(NUM_TEST_ENTRIES*2), X_Y-1, X_Y-1);

    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
           SRC1_ADDR(0, 1, X_Y), SRC2_IMM_2D(0), X_Y-1, X_Y-1);
    VPRO::DIM2::LOADSTORE::store(NUM_TEST_ENTRIES*2+NUM_TEST_ENTRIES,
                                 0, 1, X_Y,
                                 X_Y - 1, X_Y - 1,
                                 L1);
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE, DST_ADDR(0, 1, X_Y),
//           SRC1_CHAINING_2D(1), SRC2_IMM_2D(NUM_TEST_ENTRIES*2+NUM_TEST_ENTRIES), X_Y-1, X_Y-1);

    vpro_wait_busy(0xffffffff, 0xffffffff);

    // store result
    std::vector<DMA> dma_output_work;
    for (int c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
        for (int u = 0; u < VPRO_CFG::UNITS; ++u) {
            DMA d1, d2;

            d1.c = c;
            d1.u = u;
            d1.loc = 2*NUM_TEST_ENTRIES;
            d1.ext = uint64_t(intptr_t(&(result_array[0+c*VPRO_CFG::UNITS*2*NUM_TEST_ENTRIES+u*2*NUM_TEST_ENTRIES])));

            d2.c = c;
            d2.u = u;
            d2.ext = uint64_t(intptr_t(&(result_array[NUM_TEST_ENTRIES+c*VPRO_CFG::UNITS*2*NUM_TEST_ENTRIES+u*2*NUM_TEST_ENTRIES])));
            d2.loc = 2*NUM_TEST_ENTRIES+NUM_TEST_ENTRIES;

            dma_output_work.push_back(d1);
            dma_output_work.push_back(d2);
        }
    }

    std::shuffle(std::begin(dma_output_work), std::end(dma_output_work), g);

    for (DMA d : dma_output_work){
        dma_l2e_1d(1 << d.c, 1 << d.u, d.ext, d.loc, NUM_TEST_ENTRIES);
    }

    dma_wait_to_finish(0xffffffff);
    /**
     * DUMP
     */
    vpro_wait_busy(0xffffffff, 0xffffffff);
    dma_wait_to_finish(0xffffffff);

    // DCMA
    dcma_flush();

// printf runtime (cycle counters in subsystem)
    uint64_t sys_time = aux_get_sys_time_lo();
    sys_time += (uint64_t(aux_get_sys_time_hi()) << 32);
    printf("SYS_TIME: %lu\n", sys_time);

    // verify framework: dump result
    dump(result_array, NUM_TEST_ENTRIES);
    printf("\nEnd");
    return 0;
}
