#include "test_defines.h"

void normal_dma_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array) {
    sim_printf("Testing Normal DMA Instructions\n");

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

    uint32_t nr_test_var = 11;
    uint32_t offset_length = 128;

    std::random_device dev;
    std::mt19937 rng(dev());
    std::uniform_int_distribution<std::mt19937::result_type> dist42(0, 42); // distribution in range [1, 42]


    bool fail = false;

    dcma_reset();

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    for (int i = 0; i < NUM_TEST_ENTRIES / 2; ++i) {
        uint32_t loc_base_offset = dist42(rng);
        uint32_t ext_base_offset = 1 + i;

        // DMA & VPRO Instructions
        intptr_t ext_base_addr = intptr_t(test_array_1) + 2 * ext_base_offset;
        intptr_t loc_base_addr = nr_test_var + loc_base_offset;

        for (int j = 0; j < offset_length; ++j) {
            dma_ext1D_to_loc1D(0, ext_base_addr,
                               LM_BASE_VU(0) + loc_base_addr + nr_test_var, nr_test_var);
            dma_wait_to_finish(0xffffffff);
            dma_loc1D_to_ext1D(0, ext_base_addr + 2 * (nr_test_var),
                               LM_BASE_VU(0) + loc_base_addr + nr_test_var, nr_test_var);
            dma_wait_to_finish(0xffffffff);
            ext_base_addr += 2 * (nr_test_var);
            loc_base_addr += nr_test_var;
            if (ext_base_addr >= intptr_t(test_array_1) + 2 * NUM_TEST_ENTRIES) {
                break;
            }
        }

        dma_loc1D_to_ext1D(0, intptr_t(result_array),
                           LM_BASE_VU(0) + loc_base_addr, nr_test_var);
        dma_wait_to_finish(0xffffffff);

        dcma_flush();

        /**
         * Check result correctnes (ISS)
         */
        // C-Code reference (MIPS executes this)
        auto reference_result = new int16_t[nr_test_var];
        for (int k = 0; k < nr_test_var; k++) {
            reference_result[k] = test_array_1[k + ext_base_offset];
        }
        for (int l = 0; l < nr_test_var; l++) {
            if ((reference_result[l] != result_array[l]) && (l + ext_base_offset < NUM_TEST_ENTRIES)) {
                printf_error("Result is not same as reference! [Index: %i]\n", l);
                printf_error("Reference: %i, result: %i\n", reference_result[l], result_array[l]);
                fail = true;
            }
        }
        delete reference_result;
        if (fail) {
            printf_error("TEST IS NOT SUCCESSFUL with LOC_BASE_OFFSET = %d, EXT_BASE_OFFSET = %d, i = %d\n",
                         loc_base_offset, ext_base_offset, i);
            break;
        }
    }

    if (!fail)
        printf_success("TEST IS SUCCESSFUL\n");
}
