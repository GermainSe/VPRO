#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "test_defines.h"
#include "vpro_test_functions.h"

// .nobss = uninitialized! (speed up sim), .vpro sections the risc access with dma (uninitialized as well)
volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) result_array[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_zeros[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_large[1024 * 1024];



int main(int argc, char *argv[]) {
    INIT();
    printf("Start\n");
    int16_t count = 0;

    // reset result array
    for (volatile int16_t &i : result_array){
        i = 0xdead;
        if (++count > NUM_TEST_ENTRIES) break;
    }
    (count = 0);
    // input data generation
    for (volatile int16_t &i : test_array_1){
        i = count;
        count = (abs(count)+1)*(-1);
    }
    count = NUM_TEST_ENTRIES - 1;
    for (volatile int16_t &i : test_array_2){
        i = count;
        count--;
    }
    // set LM to 0 value

    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(result_array_zeros[0]))), 128, NUM_TEST_ENTRIES);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(result_array_zeros[0]))), 0, NUM_TEST_ENTRIES);
    // set whole RF to dead / error value
    __vpro(L0_1, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 32),
           SRC2_IMM_2D(0), SRC2_IMM_2D(0xdead), 31, 31);
    // reset shift registers
#if BITWIDTH_REDUCE_TO_16_BIT == 1
    vpro_mac_h_bit_shift(16);
    vpro_mul_h_bit_shift(16);
#else
    vpro_mac_h_bit_shift(24);
    vpro_mul_h_bit_shift(24);
#endif
    vpro_wait_busy(0xffffffff, 0xffffffff);
    dma_wait_to_finish(0xffffffff);

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    // execute test
    // DMA load 1 to 0 [+64]
    for(int offset = 0; offset <= 1023-64; offset += 64){
        loadTestDataLM(0, const_cast<int16_t *>(test_array_1), NUM_TEST_ENTRIES, offset);
    }
    dma_wait_to_finish(0xffffffff);

// V0                //LD (from: 0, size: 1024, to: 0)
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE, DST_ADDR(0, 1, 32),
           SRC1_ADDR(0, 1, 32), SRC2_IMM_2D(0), 31, 31);
    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 32),
           SRC1_LS_2D, SRC2_IMM_2D(0), 31, 31);

// V2                // ADD
    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_AND, NO_FLAG_UPDATE, DST_ADDR(0, 63, 1),
           SRC1_ADDR(0, 63, 1), SRC2_IMM_2D(0x1234), 15, 62);
// V2.2              // ADD
    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_AND, NO_FLAG_UPDATE, DST_ADDR(1008, 63, 1),
           SRC1_ADDR(1008, 63, 1), SRC2_IMM_2D(0x1234), 0, 15);

// V3                //ST (from: 0, size: 64, to: 1024)
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 63),
           SRC1_ADDR(0, 1, 63), SRC2_IMM_2D(0), 62, 15);
    VPRO::DIM2::LOADSTORE::store(1024,
                                 0, 1, 63,
                                 62, 15,
                                 L0);
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE, DST_ADDR(0, 1, 63),
//           SRC1_CHAINING_2D(0), SRC2_IMM_2D(1024), 62, 15);
// V3.2              //ST (from: 0, size: 64, to: 1024)
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(1008, 1, 63),
           SRC1_ADDR(1008, 1, 63), SRC2_IMM_2D(0), 15, 0);
    VPRO::DIM2::LOADSTORE::store(1024,
                                 1008, 1, 63,
                                 15, 0,
                                 L0);
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE, DST_ADDR(1008, 1, 63),
//           SRC1_CHAINING_2D(0), SRC2_IMM_2D(1024), 15, 0);

    vpro_wait_busy(0xffffffff, 0xffffffff);
    // DMA store from 1024+x to result [+64]
    dma_l2e_1d(0b1, 0b1, uint64_t(intptr_t(result_array)), 1024+4*64, NUM_TEST_ENTRIES);
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
