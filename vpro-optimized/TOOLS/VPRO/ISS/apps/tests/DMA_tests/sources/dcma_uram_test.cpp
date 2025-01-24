#include "test_defines.h"

void dcma_uram_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array) {
    sim_printf("Testing DCMA URAM\n");

    // broadcast to all
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::X_INCREMENT);
    vpro_mac_h_bit_shift(0);
    vpro_mul_h_bit_shift(0);

    for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
        test_array_1[i] = i;
        test_array_2[i] = i;
    }

    uint32_t cache_line_size = VPRO_CFG::DCMA_LINE_SIZE; //in bytes
    uint32_t nr_cache_lines = 10 * VPRO_CFG::DCMA_BRAM_SIZE * VPRO_CFG::DCMA_NR_BRAMS / VPRO_CFG::DCMA_LINE_SIZE;
    uint32_t nr_words_in_cache_line = cache_line_size / 2 - 34;

    bool fail = false;

    for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
        test_array_1[i] = i;
    }

    dcma_reset();

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    dma_ext1D_to_loc1D(0, intptr_t(test_array_1), LM_BASE_VU(0), nr_words_in_cache_line);

    uint32_t base_addr = 0x11000000 + 12;

    for (int i = 0; i < nr_cache_lines; ++i) {
        dma_loc1D_to_ext1D(0, base_addr + i * 2 * nr_words_in_cache_line, LM_BASE_VU(0), nr_words_in_cache_line);
        dma_wait_to_finish(0xffffffff);
    }

    dcma_flush();

    for (int i = 0; i < nr_cache_lines; ++i) {
        for (int j = 0; j < nr_words_in_cache_line; ++j) {
            int16_t *cur_data_ptr = (int16_t *) (base_addr + i * 2 * nr_words_in_cache_line);
            if (cur_data_ptr[j] != test_array_1[j] && j < 10) {
                printf_error("Result is not same as reference! [Cache Line: %d, Index: %d]\n", i, j);
                printf_error("Reference: %i, result: %i\n", test_array_1[j], cur_data_ptr[j]);
                fail = true;
            }
        }
    }

    if (!fail)
        printf_success("TEST IS SUCCESSFUL\n");
    else
        printf_error("TEST IS NOT SUCCESSFUL\n");
}
