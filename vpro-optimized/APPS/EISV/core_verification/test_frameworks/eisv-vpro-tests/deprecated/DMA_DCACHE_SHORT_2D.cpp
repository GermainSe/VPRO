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



volatile COMMAND_DMA::COMMAND_DMA dma_struct[5]  __attribute__ ((aligned (16)));

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
    dma_struct[0].cluster = 1;
    dma_struct[0].unit_mask = 0x00000001;
    dma_struct[0].direction = COMMAND_DMA::DMA_DIRECTION::e2l1D;
    dma_struct[0].padding = 0;
    dma_struct[0].lm_addr = 128;
    dma_struct[0].mm_addr = uint32_t(intptr_t(test_array_1));
    dma_struct[0].isBiasOffset = false;
    dma_struct[0].isKernelOffset = false;
    dma_struct[0].y_leap = 1;
    dma_struct[0].x_size = NUM_TEST_ENTRIES;
    dma_struct[0].y_size = 1;

//    dma_struct[0].cluster = 0xad;
//    dma_struct[0].unit_mask = 0xffffffff;
//    dma_struct[0].direction = COMMAND_DMA::DMA_DIRECTION::e2l1D;
//    dma_struct[0].pad_0 = 1;
//    dma_struct[0].pad_1 = 0;
//    dma_struct[0].pad_2 = 0;
//    dma_struct[0].pad_3 = 0;
//    dma_struct[0].lm_addr = 0xffffffff;
//    dma_struct[0].mm_addr = 0xffffffff;
//    dma_struct[0].isBiasOffset = 00;
//    dma_struct[0].isKernelOffset = true;
//    dma_struct[0].x_stride = 0xffff;
//    dma_struct[0].x_size = 0xffff;
//    dma_struct[0].y_size = 0xffff;

    dma_dcache_short_command((const void *) &(dma_struct[0]));

    dma_wait_to_finish(0xffffffff);
    // Writeback 1D
    //dma_l2e_1d(0b1, 0b1, uint64_t(intptr_t(result_array)), 128, NUM_TEST_ENTRIES);
    dma_struct[1].cluster = 1;
    dma_struct[1].unit_mask = 0x00000001;
    dma_struct[1].direction = COMMAND_DMA::DMA_DIRECTION::l2e1D;
    dma_struct[1].padding = 0;
    dma_struct[1].lm_addr = 128;
    dma_struct[1].mm_addr = uint32_t(intptr_t(result_array));
    dma_struct[1].isBiasOffset = false;
    dma_struct[1].isKernelOffset = false;
    dma_struct[1].y_leap = 1;
    dma_struct[1].x_size = NUM_TEST_ENTRIES;
    dma_struct[1].y_size = 1;
    dma_dcache_short_command((const void *) &(dma_struct[1]));

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
