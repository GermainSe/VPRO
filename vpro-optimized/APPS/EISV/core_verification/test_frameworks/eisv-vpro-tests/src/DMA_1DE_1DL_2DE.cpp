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
    // Load 1D
    // left half of mm to top 1D in lm    
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[0]))), 128, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[8]))), 128+4, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[16]))), 128+8, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[24]))), 128+12, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[32]))), 128+16, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[40]))), 128+20, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[48]))), 128+24, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[56]))), 128+28, 4);
    
    // right half of mm to top 1D in lm
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+0]))), 128+32, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+8]))), 128+32+4, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+16]))), 128+32+8, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+24]))), 128+32+12, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+32]))), 128+32+16, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+40]))), 128+32+20, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+48]))), 128+32+24, 4);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(test_array_1[4+56]))), 128+32+28, 4);
    dma_wait_to_finish(0xffffffff);

    // Writeback 2D
    dma_l2e_2d(0b1, 0b1, uint64_t(intptr_t(&(result_array[0]))), 128, 4, 8, 4 + 1);  // left part in mm
    dma_l2e_2d(0b1, 0b1, uint64_t(intptr_t(&(result_array[4]))), 128 + 32, 4, 8, 4 + 1);  // right part in mm // same content: 16 * 0x1000, 16 * 0x2000
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
