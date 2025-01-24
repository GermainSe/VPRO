
#include <stdint.h>
#include <algorithm>
#include <eisv.h>
#include <vpro.h>
#include <vpro/dma_cmd_struct.h>

#include "test_defines.h"
#include "vpro_test_functions.h"

/**
 * Test Data Variables
 */
volatile int16_t __attribute__ ((section (".vpro"))) test_array_tmp[1024*2];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_tmp2[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array[1024];

volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
//volatile int16_t __attribute__ ((section (".vpro"))) result_array[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_zeros[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_large[1024 * 1024];

volatile COMMAND_DMA::COMMAND_DMA __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) dmas[NUM_TEST_ENTRIES]; 

int main(int argc, char *argv[]) {
    printf("Start\n");
    
    INIT();
    
    // broadcast to all
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::X_INCREMENT);
    vpro_mac_h_bit_shift(0);
    vpro_mul_h_bit_shift(0);

    for (int16_t i = 0; i < 1024; i++) {
        test_array_tmp[i] = i;
        test_array_tmp2[i] = i;
    }

    for (int16_t i = 0; i < 1024; i++) {
        dma_e2l_1d(0b1, 0b11, intptr_t(&(test_array_tmp[i])), i, 1024);
    }

    // DMA & VPRO Instructions
//    dma_block_size(1024);
//    dma_block_addr_trigger((void *)(dmas));   
    
           
    dma_e2l_1d(0b1, 0b1, intptr_t(test_array_tmp2), 1024, 1024);
    dma_wait_to_finish(0xffffffff);

    VPRO::DIM3::LOADSTORE::loads(0,
                                 0, 0, 0, 1,
                                 0, 0, 1023);

    VPRO::DIM3::PROCESSING::add(L0,
                                DST_ADDR(0, 0, 0, 1), SRC1_LS_3D, SRC2_IMM_3D(0),
                                0, 0, 1023);

    VPRO::DIM3::LOADSTORE::loads(1024,
                                 0, 0, 0, 1,
                                 0, 0, 1023);

    VPRO::DIM3::PROCESSING::add(L0,
                              DST_ADDR(0, 0, 0, 1), SRC1_LS_3D, SRC2_ADDR(0, 0, 0, 1),
                              0, 0, 1023);

    VPRO::DIM3::PROCESSING::add(L0,
                                DST_ADDR(0, 0, 0, 1), SRC1_ADDR(0, 0, 0, 1), SRC2_IMM_3D(0),
                                0, 0, 1023, true);

    VPRO::DIM3::LOADSTORE::store(1024 * 2,
                                 0, 0, 0, 1,
                                 0, 0, 1023,
                                 L0);

    vpro_wait_busy();

    dma_l2e_1d(0b1, 0b1, intptr_t(result_array), 1024 * 2, 1024);
    vpro_sync();

    // DCMA
    dcma_flush();

    // printf runtime (cycle counters in subsystem)
    uint64_t sys_time = aux_get_sys_time_lo();
    sys_time += (uint64_t(aux_get_sys_time_hi()) << 32);
    printf("SYS_TIME: %lu\n", sys_time);

    // verify framework: dump result
    dump(result_array, 1024);
    
    printf("\nEnd");
    return 0;
}
