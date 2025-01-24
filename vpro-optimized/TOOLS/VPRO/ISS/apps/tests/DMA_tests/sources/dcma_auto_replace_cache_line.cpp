#include "test_defines.h"
#include <iostream>

void dcma_auto_replace_cache_line(volatile int16_t *test_array_1, volatile int16_t *test_array_2,
                                  volatile int16_t *result_array) {
    sim_printf("Testing DCMA Auto Replace\n");

    // broadcast to all
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::X_INCREMENT);
    vpro_mac_h_bit_shift(0);
    vpro_mul_h_bit_shift(0);


    std::random_device dev;
    std::mt19937 rng(dev());
    std::uniform_int_distribution<std::mt19937::result_type> dist42(0, 42); // distribution in range [1, 42]

    dcma_reset();
    /**
     * Test Data Variables
     */

    // broadcast to all
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);

    for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
        test_array_1[i] = i;
//        test_array_2[i] = i;
        result_array[i] = 0xdead;
    }

    uint32_t base_addr = intptr_t(result_array);

    dma_ext1D_to_loc1D(0, intptr_t(test_array_1), LM_BASE_VU(0), NUM_TEST_ENTRIES);
    dma_loc1D_to_ext1D(0, base_addr, LM_BASE_VU(0), NUM_TEST_ENTRIES);
    dma_wait_to_finish(0xffffffff);
//    dcma_flush();

//    // DMA & VPRO Instructions
//    dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
//    dma_wait_to_finish(0xffffffff);

    uint32_t associativity = 8;

    // auto flush by loading data for the same set into the cache
    uint32_t addr_word_select_bitwidth = uint32_t(std::ceil(log2(VPRO_CFG::DCMA_LINE_SIZE)));
    uint32_t addr_set_bitwidth = uint32_t(
            std::ceil(log2(VPRO_CFG::DCMA_BRAM_SIZE * VPRO_CFG::DCMA_NR_BRAMS / (VPRO_CFG::DCMA_LINE_SIZE * associativity))));
    uint32_t same_tag_offset = 1 << (addr_word_select_bitwidth + addr_set_bitwidth);

    for (int i = 1; i <= associativity; ++i) {
        dma_ext1D_to_loc1D(0, base_addr + i * same_tag_offset, LM_BASE_VU(0), NUM_TEST_ENTRIES);
    }

    dma_wait_to_finish(0xffffffff);

//    dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
//    dma_loc1D_to_ext1D(0, intptr_t(result_array), LM_BASE_VU(0) + NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
//    dma_wait_to_finish(0xffffffff);


    /**
     * Check result correctnes (ISS)
     */
    // C-Code reference (MIPS executes this)
    auto reference_result = new int16_t[NUM_TEST_ENTRIES];
    for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
        reference_result[i] = test_array_1[i];
    }

    bool fail = false;
    for (int i = 0; i < 20; i++) {
        if (reference_result[i] != result_array[i]) {
            if (reference_result[i] != result_array[i]) {
                printf_error("Result is not same as reference! [iter: %i]\n", i);
                printf_error("Reference: %i, result: %i\n", reference_result[i], result_array[i]);
                fail = true;
            }
        }
    }

//    printf_info("\nResult Data: \n");
//    for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
//        printf_info("%6i, ", result_array[i]);
//    }
//    printf_info("\nReference Data: \n");
//    for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
//        printf_info("%6i, ", reference_result[i]);
//    }

    if (!fail)
        printf_success("TEST IS SUCCESSFUL\n");
    else
        printf_error("TEST IS NOT SUCCESSFUL\n");
}
