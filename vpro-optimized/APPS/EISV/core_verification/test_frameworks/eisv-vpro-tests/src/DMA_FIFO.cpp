
#include <stdint.h>
#include <algorithm>
#include <eisv.h>
#include <vpro.h>
#include "riscv/eisV_hardware_info.hpp"
#include <vpro/dma_cmd_struct.h>

#include "test_defines.h"

#define SIGNATURE_ADDRESS       (*((volatile uint32_t*) (0xffffffc4)))   // r/w

/**
 * Test Data Variables
 */
constexpr int NUM_TEST_ENTRIES_2 = 1024;
volatile int16_t __attribute__ ((section (".vpro"))) test_array_1a[NUM_TEST_ENTRIES_2];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2a[NUM_TEST_ENTRIES_2];
volatile int16_t __attribute__ ((section (".vpro"))) result_arraya[NUM_TEST_ENTRIES_2];

volatile COMMAND_DMA::COMMAND_DMA __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) dmas[NUM_TEST_ENTRIES_2]; 

int main(int argc, char *argv[]) {
    INIT();
    printf("Start\n");
    
    // broadcast to all
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::X_INCREMENT);
    vpro_mac_h_bit_shift(0);
    vpro_mul_h_bit_shift(0);

    for (int16_t i = 0; i < NUM_TEST_ENTRIES_2; i++) {
        test_array_1a[i] = i;
        test_array_2a[i] = i;
        
        dmas[i].direction = COMMAND_DMA::DMA_DIRECTION::e2l1D;
        dmas[i].cluster = 0b1;
        dmas[i].unit_mask = 0b11;
        dmas[i].mm_addr = intptr_t(&(test_array_1a[i]));
        dmas[i].lm_addr = i;
        dmas[i].y_leap = 1;
        dmas[i].x_size = 1;
        dmas[i].y_size = 1;
        dmas[i].padding = 0;
    }


    // DMA & VPRO Instructions
    dma_block_size(NUM_TEST_ENTRIES_2);
    dma_block_addr_trigger((void *)(dmas));          
    dma_e2l_1d(0b1, 0b1, intptr_t(test_array_2a), NUM_TEST_ENTRIES_2, NUM_TEST_ENTRIES_2);
    dma_wait_to_finish(0xffffffff);

    VPRO::DIM3::LOADSTORE::loads(0,
                                 0, 0, 0, 1,
                                 0, 0, 1023);

    VPRO::DIM3::PROCESSING::add(L0,
                                DST_ADDR(0, 0, 0, 1), SRC1_LS_3D, SRC2_IMM_3D(0),
                                0, 0, 1023);

    VPRO::DIM3::LOADSTORE::loads(NUM_TEST_ENTRIES_2,
                                 0, 0, 0, 1,
                                 0, 0, 1023);

    VPRO::DIM3::PROCESSING::add(L0,
                              DST_ADDR(0, 0, 0, 1), SRC1_LS_3D, SRC2_ADDR(0, 0, 0, 1),
                              0, 0, 1023);

    VPRO::DIM3::PROCESSING::add(L0,
                                DST_ADDR(0, 0, 0, 1), SRC1_ADDR(0, 0, 0, 1), SRC2_IMM_3D(0),
                                0, 0, 1023, true);

    VPRO::DIM3::LOADSTORE::store(NUM_TEST_ENTRIES_2 * 2,
                                 0, 0, 0, 1,
                                 0, 0, 1023,
                                 L0);

    vpro_wait_busy();

    dma_l2e_1d(0b1, 0b1, intptr_t(result_arraya), NUM_TEST_ENTRIES_2 * 2, NUM_TEST_ENTRIES_2);
    dma_wait_to_finish();

    // DCMA
    dcma_flush();

    // printf runtime (cycle counters in subsystem)
    uint64_t sys_time = aux_get_sys_time_lo();
    sys_time += (uint64_t(aux_get_sys_time_hi()) << 32);
    printf("SYS_TIME: %lu\n", sys_time);

    // verify framework: dump result
    for (volatile int16_t &i : result_arraya){
        SIGNATURE_ADDRESS = i;
    }
    printf("\nEnd");
    return 0;
}
