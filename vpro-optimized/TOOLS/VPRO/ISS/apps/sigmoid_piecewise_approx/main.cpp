// ########################################################
// # example app for MIPS, using some IO/Data instruction #
// #                                                      #
// # Sven Gesper, EIS, Tu Braunschweig, 2021              #
// ########################################################

#include <stdint.h>
#include <algorithm>
#include <math.h>
#include <vpro.h>
#include <eisv.h>
#include "riscv/eisV_hardware_info.hpp"

#include "sigmoid.h"

/**
 * Test Data Variables
 */
volatile int16_t __attribute__ ((section (".vpro"))) input_data[1024], result_data[1024];

/**
 * Main
 */
int main(int argc, char *argv[]) {
    sim_init(main, argc, argv);
    aux_print_hardware_info("Sigmoid Test App");

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

    // reference of sigmoid + input generation
    int16_t reference_result[input_block_size];

    int16_t step = 12. / input_block_size * (1 << mem_input_fractional_bits);
    int16_t neg_limit = -6 * (1 << mem_input_fractional_bits);
    for (int16_t i = 0; i < input_block_size; i++) {
        input_data[i] = 10*1024+i; //int16_t(neg_limit + i * step);    // -6 - 6
        // C-Code reference (MIPS executes this)
#define SIGMOID(x) (float )(1/(1 + exp((float)(-x))))
        reference_result[i] = int16_t(
                SIGMOID(float(input_data[i]) / (1 << mem_input_fractional_bits)) * (1 << mem_store_fractional_bits));

        printf("[Input] %i: sigmoid(%f) = %f, fix-point input: %i\n", i,
               float(input_data[i]) / (1 << mem_input_fractional_bits),
               SIGMOID(float(input_data[i]) / (1 << mem_input_fractional_bits)), input_data[i]);
    }

    uint64_t cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    printf_success("[RISC-V Reference] Sys-Time (Risc-V Cycles): %llu (%llu ms)\n",
                   (unsigned long long) cnt, (unsigned long long) (1000 * cnt / get_gpr_risc_freq()));


    // DMA & VPRO Instructions
    dma_ext1D_to_loc1D(0, intptr_t(input_data), LM_BASE_VU(0) + 0, input_block_size);
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

    dma_loc1D_to_ext1D(0, intptr_t(result_data), LM_BASE_VU(0) + lm_out_buffer, input_block_size);
    vpro_dma_sync();

    dcma_flush();

    cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    printf_success("[VPRO SIGMOID] Sys-Time (Risc-V Cycles): %llu (%llu ms)\n",
                   (unsigned long long) cnt, (unsigned long long) (1000 * cnt / get_gpr_risc_freq()));

    aux_print_statistics();

    sim_stat_reset();
    aux_clr_sys_time();
    aux_reset_all_stats();

    /**
     * Check result correctnes (ISS)
     */
    bool fail = false;
    for (int i = 0; i < input_block_size; i++) {
        if (abs(reference_result[i] - result_data[i]) > 25) {
            printf_error("Result is not same as reference! [Index: %4i] ", i);
            printf_error("Reference: sigmoid(%5i = %1.4f) = %5i = %1.4f, VPRO result: %5i = %1.4f\n",
                         input_data[i],
                         float(input_data[i]) / (1 << mem_input_fractional_bits),
                         reference_result[i],
                         float(reference_result[i]) / (1 << mem_store_fractional_bits),
                         result_data[i],
                         float(result_data[i]) / (1 << mem_store_fractional_bits));
            fail = true;
        } else {
            //printf_success("Reference: %i  = result: %i\n", reference_result[i], result_data[i]);
            printf_success("Reference: sigmoid(%5i = %1.4f) = %5i = %1.4f, VPRO result: %5i = %1.4f\n",
                           input_data[i],
                           float(input_data[i]) / (1 << mem_input_fractional_bits),
                           reference_result[i],
                           float(reference_result[i]) / (1 << mem_store_fractional_bits),
                           result_data[i],
                           float(result_data[i]) / (1 << mem_store_fractional_bits));
        }
    }
    if (!fail){
        printf_success("ALL Correct!\n");
    } else {
        printf_error("FAIL!\n");
    }

    aux_print_debugfifo(0xcafeaffe);
    aux_print_debugfifo(aux_get_sys_time_hi());
    aux_print_debugfifo(aux_get_sys_time_lo());

    cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    printf_success("[RISC-V Verify] Sys-Time (Risc-V Cycles): %llu (%llu ms)\n",
                   (unsigned long long) cnt, (unsigned long long) (1000 * cnt / get_gpr_risc_freq()));

    sim_stop();
    return 0;
}
