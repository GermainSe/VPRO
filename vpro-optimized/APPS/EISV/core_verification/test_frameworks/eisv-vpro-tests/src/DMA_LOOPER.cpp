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


volatile COMMAND_DMA::COMMAND_DMA dma_struct[6]  __attribute__ ((aligned (16)));

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
    int i_count = 0;
    for (volatile int16_t &i : test_array_1){
        i = count;
        count = (abs(count)+1)*(-1);
        
//        printf("init data %08lx [%i] = %i \n", &i, i_count, i);
        i_count++;
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
    
    vpro_wait_busy(0xffffffff, 0xffffffff);
    dma_wait_to_finish(0xffffffff);

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    // execute test
    // Load 1D -> LOOP
    auto loop = (COMMAND_DMA::COMMAND_DMA_LOOP *)&dma_struct[0];
    
    loop->direction = COMMAND_DMA::DMA_DIRECTION::loop;
    loop->cluster_loop_len = 0;
    loop->cluster_loop_shift_incr = 0;
    loop->unit_loop_len = 0;
    loop->unit_loop_shift_incr = 0;  // '1.
    loop->inter_unit_loop_len = NUM_TEST_ENTRIES - 1;
    loop->lm_incr = 1;  // 13-bit signed! // '2.
    loop->mm_incr = 2; // '3.
    loop->dma_cmd_count = NUM_TEST_ENTRIES - 1;

    dma_struct[1].cluster = 1;
    dma_struct[1].unit_mask = 0x00000001;
    dma_struct[1].direction = COMMAND_DMA::DMA_DIRECTION::e2l1D;
    dma_struct[1].padding = 0;
    dma_struct[1].lm_addr = 128;
    dma_struct[1].mm_addr_64 = uint32_t(intptr_t(test_array_1) >> 32);
    dma_struct[1].mm_addr = uint32_t(intptr_t(test_array_1));
    dma_struct[1].isBiasOffset = false;
    dma_struct[1].isKernelOffset = false;
    dma_struct[1].y_leap = 1;
    dma_struct[1].x_size = 1;   // by loop
    dma_struct[1].y_size = 1;

    dma_block_size(2);
    dma_block_addr_trigger((const void *)&dma_struct[0]);

    dma_struct[2].cluster = 1;
    dma_struct[2].unit_mask = 0x00000001;
    dma_struct[2].direction = COMMAND_DMA::DMA_DIRECTION::e2l1D;
    dma_struct[2].padding = 0;
    dma_struct[2].lm_addr = 128+NUM_TEST_ENTRIES- 1;
    dma_struct[2].mm_addr_64 = uint32_t(intptr_t(&test_array_1[NUM_TEST_ENTRIES - 1]) >> 32);
    dma_struct[2].mm_addr = uint32_t(intptr_t(&test_array_1[NUM_TEST_ENTRIES - 1]));
    dma_struct[2].isBiasOffset = false;
    dma_struct[2].isKernelOffset = false;
    dma_struct[2].y_leap = 1;
    dma_struct[2].x_size = 1;
    dma_struct[2].y_size = 1;

    dma_dcache_short_command((const void *) &(dma_struct[2]));
    

//    dma_struct[4].cluster = 0;
//    dma_struct[4].unit_mask = 0x00000000;
//    dma_struct[4].direction = COMMAND_DMA::DMA_DIRECTION::e2l1D;
//    dma_struct[4].padding = 0;
//    dma_struct[4].lm_addr = 128;
//    dma_struct[4].mm_addr = uint32_t(intptr_t(test_array_1));
//    dma_struct[4].isBiasOffset = false;
//    dma_struct[4].isKernelOffset = false;
//    dma_struct[4].y_leap = 1;
//    dma_struct[4].x_size = NUM_TEST_ENTRIES;
//    dma_struct[4].y_size = 1;


    dma_wait_to_finish(0xffffffff);

    // Writeback 1D
    //dma_l2e_1d(0b1, 0b1, uint64_t(intptr_t(result_array)), 128, NUM_TEST_ENTRIES);
    dma_struct[5].cluster = 1;
    dma_struct[5].unit_mask = 0x00000001;
    dma_struct[5].direction = COMMAND_DMA::DMA_DIRECTION::l2e1D;
    dma_struct[5].padding = 0;
    dma_struct[5].lm_addr = 128;
    dma_struct[5].mm_addr_64 = uint32_t(intptr_t(result_array) >> 32);
    dma_struct[5].mm_addr = uint32_t(intptr_t(result_array));
    dma_struct[5].isBiasOffset = false;
    dma_struct[5].isKernelOffset = false;
    dma_struct[5].y_leap = 1;
    dma_struct[5].x_size = NUM_TEST_ENTRIES;
    dma_struct[5].y_size = 1;
    dma_dcache_short_command((const void *) &(dma_struct[5]));

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
