#include "test_defines.h"

void
padding_bottom_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array) {
    sim_printf("Testing Padding Bottom DMA Instructions\n");

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

    uint32_t seg_size = 18;
    uint32_t nr_test_var = seg_size * seg_size;

    std::random_device dev;
    std::mt19937 rng(dev());
    std::uniform_int_distribution<std::mt19937::result_type> dist6(0, 42); // distribution in range [1, 6]
    std::uniform_int_distribution<std::mt19937::result_type> dist_ext_addr(0, NUM_TEST_ENTRIES / 2 - 1);

    bool pad_flags[4] = {false, false, false, false};  // for dma padding

    bool fail = false;

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    dcma_reset();

    for (int i = 0; i < NUM_TEST_ENTRIES / 2; ++i) {
        uint32_t loc_base_offset = dist6(rng);
        uint32_t ext_base_offset = i;

        intptr_t ext_base_addr = intptr_t(test_array_1) + 2 * ext_base_offset;
        intptr_t loc_base_addr = nr_test_var + loc_base_offset;

        // execute test
        dma_set_pad_widths(1, 1, 1, 1);
        dma_set_pad_value(0xbaaa);

        pad_flags[COMMAND_DMA::PAD::BOTTOM] = true;

        dma_ext2D_to_loc1D(0, intptr_t(ext_base_addr), loc_base_addr, 1,
                           seg_size,
                           seg_size,
                           pad_flags);
        dma_wait_to_finish(0xffffffff);

        // clean up
        dma_set_pad_widths(0, 0, 0, 0);
        dma_set_pad_value(0xaffe);
        // wb
        dma_loc1D_to_ext1D(0, intptr_t(result_array), LM_BASE_VU(0) + loc_base_addr, nr_test_var);
        dma_wait_to_finish(0xffffffff);

        // DCMA Flush
        dcma_flush();

        /**
         * Check result correctnes (ISS)
         */

        // result generation
        int32_t x, y;
        int index = ext_base_offset;
        auto reference_result = new int16_t[nr_test_var];
        for (int i = 0; i < nr_test_var; ++i) {
            x = i % seg_size; // col
            y = i / seg_size; // row
            if (y == seg_size - 1) {
                reference_result[i] = 0xbaaa; // pad value
            } else {
                reference_result[i] = test_array_1[index];
                index++;
            }
        }

        // C-Code reference (MIPS executes this)
        for (int i = 0; i < nr_test_var; i++) {
            if (reference_result[i] != result_array[i]) {
                printf_error("Result is not same as reference! [Index: %i]\n", i);
                printf_error("Reference: %i, result: %i\n", reference_result[i],
                             result_array[i]);
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
//    for (int i = 0; i < 100; ++i) {
//        uint32_t loc_base_offset = dist6(rng);
//
//        // DMA & VPRO Instructions
//        dma_ext1D_to_loc1D(0, intptr_t(test_array_1), LM_BASE_VU(0) + 0,
//                           nr_test_var);
//        dma_ext1D_to_loc1D(0, intptr_t(test_array_2),
//                           LM_BASE_VU(0) + nr_test_var + 3, nr_test_var);
//        dma_wait_to_finish(0xffffffff);
//
//        intptr_t ext_base_addr = intptr_t(test_array_2);
//        intptr_t loc_base_addr = nr_test_var + loc_base_offset;
//
//        for (int i = 0; i < offset_length; ++i) {
//            dma_ext1D_to_loc1D(0, ext_base_addr,
//                               LM_BASE_VU(0) + loc_base_addr + nr_test_var, nr_test_var);
//            dma_wait_to_finish(0xffffffff);
//            dma_loc1D_to_ext1D(0, ext_base_addr + 2 * (nr_test_var),
//                               LM_BASE_VU(0) + loc_base_addr + nr_test_var, nr_test_var);
//            dma_wait_to_finish(0xffffffff);
//            ext_base_addr += 2 * (nr_test_var);
//            loc_base_addr += nr_test_var;
//        }
//
//        dma_loc1D_to_ext1D(0, intptr_t(result_array),
//                           LM_BASE_VU(0) + loc_base_addr, nr_test_var);
//        dma_wait_to_finish(0xffffffff);
//
//        dcma_flush();
////    sim_printf("after flush\n");
//
//        /**
//         * Check result correctnes (ISS)
//         */
//        // C-Code reference (MIPS executes this)
//        auto reference_result = new int16_t[nr_test_var];
//        for (int i = 0; i < nr_test_var; i++) {
//            reference_result[i] = test_array_2[i];
//        }
//        for (int i = 0; i < nr_test_var; i++) {
//            if (reference_result[i] != result_array[i]) {
//                printf_error("Result is not same as reference! [Index: %i]\n", i);
//                printf_error("Reference: %i, result: %i\n", reference_result[i],
//                             result_array[i]);
//                fail = true;
//            }
//        }
//        if (fail) {
//            printf_error("TEST IS NOT SUCCESSFUL with LOC_BASE_OFFSET = %d\n", loc_base_offset);
//            break;
//        }
//    }

    if (!fail)
        printf_success("TEST IS SUCCESSFUL\n");
}
