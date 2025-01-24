// ########################################################
// # Sven Gesper, EIS, Tu Braunschweig, 2023              #
// ########################################################

#include <stdint.h>
#include <algorithm>
#include <math.h>
#include <vpro.h>
#include <eisv.h>
#include "riscv/eisV_hardware_info.hpp"

#include "test_defines.h"
#include "vpro_test_functions.h"
#include "SIGMOID.h"

/**
 * Test Data Variables
 */
volatile int16_t __attribute__ ((section (".vpro"))) input_data[1024], result_data[1024];


volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) result_array[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_zeros[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_large[1024 * 1024];

/**
 * Main
 */
int main(int argc, char *argv[]) {
    INIT();
    printf("Start\n");
    int16_t count = 0;
    // reset result array
    for (volatile int16_t &i : result_data){
        i = 0xdead;
//        if (++count > NUM_TEST_ENTRIES) break;
    }
    // set whole RF to dead / error value
    __vpro(L0_1, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 32),
           SRC2_IMM_2D(0), SRC2_IMM_2D(0xdead), 31, 31);
        
    vpro_sync();   
           
    // block input definitions
    const int16_t mem_input_fractional_bits = 11; // 11 bits for fraction
    const int16_t mem_store_fractional_bits = 11; // 14 bits for fraction
    const int32_t input_block_size = 1024;  // dividable by 2 (two lanes)
    const uint32_t lm_out_buffer = 4096;  // the address offset for output in LM

    // defaults: broadcast to all
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::X_INCREMENT);
    vpro_mac_h_bit_shift(0);
    vpro_mul_h_bit_shift(0);
    sim_stat_reset();
    aux_clr_sys_time();
    aux_reset_all_stats();

    const int16_t step = 12. / input_block_size * (1 << mem_input_fractional_bits);
    const int16_t neg_limit = -6 * (1 << mem_input_fractional_bits);
    for (int16_t i = 0; i < input_block_size; i++) {
        input_data[i] = int16_t(neg_limit + i * step);    // -6 - 6
    }

    // DMA & VPRO Instructions
    dma_e2l_1d(0b1, 0b1, intptr_t(input_data), 0, input_block_size);
    dma_wait_to_finish(0xffffffff);

    // data in RF
    VPRO::DIM3::LOADSTORE::loads(0,
                                 0, 0, 0, 1,
                                 0, 0, 1023);
    VPRO::DIM3::PROCESSING::add(L0_1,
                                DST_ADDR(0, 0, 0, 1),
                                SRC1_LS_3D,
                                SRC2_IMM_3D(0),
                                0, 0, 1023, false, true);
    vpro_sync();

    BIF::LAYER layer;
    layer.seg_out_w = 32;
    layer.seg_out_h = 32;

    sim_stat_reset();
    aux_clr_sys_time();
    aux_reset_all_stats();

    sigmoid_fast<11>(layer, lm_out_buffer);

    vpro_sync();

    dma_l2e_1d(0b1, 0b1, intptr_t(result_data), lm_out_buffer, input_block_size);
    vpro_dma_sync();

    dcma_flush();

// printf runtime (cycle counters in subsystem)
    uint64_t sys_time = aux_get_sys_time_lo();
    sys_time += (uint64_t(aux_get_sys_time_hi()) << 32);
    printf("SYS_TIME: %lu\n", sys_time);

    // verify framework: dump result
    dump(result_data, 1024);
    
    printf("\nEnd");

    sim_stop();
    return 0;
}
