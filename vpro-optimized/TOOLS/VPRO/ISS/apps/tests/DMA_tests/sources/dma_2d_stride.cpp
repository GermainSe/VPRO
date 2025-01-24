#include "test_defines.h"

void
dma_2d_stride_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array) {
    sim_printf("Testing 2D DMA with Stride Instructions\n");

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


    std::random_device dev;
    std::mt19937 rng(dev());
    std::uniform_int_distribution<std::mt19937::result_type> dist42(0, 42); // distribution in range [1, 42]

    uint32_t seg_size = 19;
    uint32_t stride = 11;
    uint32_t nr_test_var = seg_size * seg_size;

    bool fail = false;

    dcma_reset();

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    for (int i = 0; i < 512; ++i) {
        uint32_t loc_base_offset = dist42(rng);
        uint32_t ext_base_offset = 1 + i;

        // DMA & VPRO Instructions
        intptr_t ext_base_addr = intptr_t(test_array_1) + 2 * ext_base_offset;
        intptr_t loc_base_addr = loc_base_offset;

        dma_ext2D_to_loc1D(0, ext_base_addr, loc_base_addr, stride, seg_size, seg_size);
//        for (int j = 0; j < offset_length; ++j) {
//            dma_ext1D_to_loc1D(0, ext_base_addr,
//                               LM_BASE_VU(0) + loc_base_addr + nr_test_var, nr_test_var);
//            dma_wait_to_finish(0xffffffff);
//            dma_loc1D_to_ext1D(0, ext_base_addr + 2 * (nr_test_var),
//                               LM_BASE_VU(0) + loc_base_addr + nr_test_var, nr_test_var);
//            dma_wait_to_finish(0xffffffff);
//            ext_base_addr += 2 * (nr_test_var);
//            loc_base_addr += nr_test_var;
//            if (ext_base_addr >= intptr_t(test_array_1) + 2 * NUM_TEST_ENTRIES) {
//                break;
//            }
//        }

        dma_loc1D_to_ext2D(0, intptr_t(result_array), loc_base_addr, stride, seg_size, seg_size);
        dma_wait_to_finish(0xffffffff);

        dcma_flush();

//        for (int j = 0; j < nr_test_var; ++j) {
//            uint32_t row, col, index;
//            row = j / seg_size;
//            col = j % seg_size;
//            index = row * (seg_size + stride - 1) + col;
//            printf_success("%d\t", result_array[index]);
//            if (col == seg_size - 1)
//                printf("\n");
//        }

        /**
         * Check result correctnes (ISS)
         */
        // C-Code reference (MIPS executes this)
        auto reference_result = new int16_t[nr_test_var];
        uint32_t index = ext_base_offset;
        uint32_t col_counter = 0;
        for (int k = 0; k < nr_test_var; k++) {
            reference_result[k] = test_array_1[index];
            col_counter++;
            index++;
            if (col_counter == seg_size) {
                col_counter = 0;
                index += stride - 1;
            }
        }

        uint32_t row, col;
        for (int l = 0; l < nr_test_var; l++) {
            row = l / seg_size;
            col = l % seg_size;
            index = row * (seg_size + stride - 1) + col;

            if (reference_result[l] != result_array[index]) {
                printf_error("Result is not same as reference! [iter: %i], index = %d, row = %d, col = %d\n", l, index,
                             row, col);
                printf_error("Reference: %i, result: %i\n", reference_result[l], result_array[index]);
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
