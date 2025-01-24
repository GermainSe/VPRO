//
// Created by thieu on 02.06.22.
//

#include "tests/features/dcma_flush_tester.h"

// ########################################################
// # example app for EISV, using some IO/Data instruction #
// # for testing DCMA                                     #
// # Gia Bao Thieu, EIS, Tu Braunschweig, 2022            #
// ########################################################

#include <stdint.h>
#include <algorithm>
#include <vpro.h>


/**
 * Main
 */
bool dcma_flush_tester::perform_tests() {
    uint32_t base_addr = 0x12345678 - 2; // byte addr
//    for (uint32_t base_addr = 0; base_addr < 0x00045678; base_addr += 2)
        // Manual Flush Test, by using flush command
    {
        {
            dcma_reset();
            /**
             * Test Data Variables
             */
            constexpr int NUM_TEST_ENTRIES = 64;
            volatile int16_t test_array_1[NUM_TEST_ENTRIES];
            volatile int16_t test_array_2[NUM_TEST_ENTRIES];
            volatile int16_t result_array[NUM_TEST_ENTRIES];

            // broadcast to all
            vpro_set_cluster_mask(0xFFFFFFFF);
            vpro_set_unit_mask(0xFFFFFFFF);

            uint8_t wdata_low, wdata_high;
            for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
                test_array_1[i] = i;
                test_array_2[i] = i;
            }

            dma_ext1D_to_loc1D(0, intptr_t(test_array_1), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 10, NUM_TEST_ENTRIES);
            dma_ext1D_to_loc1D(0, intptr_t(test_array_2), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 11, NUM_TEST_ENTRIES);
            dma_loc1D_to_ext1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 10, NUM_TEST_ENTRIES);
            dma_loc1D_to_ext1D(0, base_addr + NUM_TEST_ENTRIES * 2, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 11, NUM_TEST_ENTRIES);
            dcma_flush();
            dma_wait_to_finish(0xffffffff);

            // DMA & VPRO Instructions
            dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + 0, NUM_TEST_ENTRIES);
            dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);

            VPRO::DIM2::LOADSTORE::loads(0,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0),
                                        7, 7);

            VPRO::DIM2::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_ADDR(0, 1, 8),
                                        7, 7);

            VPRO::DIM2::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0),
                                        7, 7, true);

            VPRO::DIM2::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8,
                                         7, 7,
                                         L0);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            VPRO::DIM2::LOADSTORE::loads(0,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0),
                                        7, 7);

            VPRO::DIM2::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_ADDR(0, 1, 8),
                                        7, 7);

            VPRO::DIM2::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0),
                                        7, 7, true);

            VPRO::DIM2::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8,
                                         7, 7,
                                         L1);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            VPRO::DIM3::LOADSTORE::loads(0,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_IMM_3D(0),
                                        7, 3, 1);

            VPRO::DIM3::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_ADDR(0, 1, 8, 32),
                                        7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8, 32), SRC1_ADDR(0, 1, 8, 32), SRC2_IMM_3D(0),
                                        7, 3, 1, true);

            VPRO::DIM3::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8, 32,
                                         7, 3, 1,
                                         L0);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            VPRO::DIM3::LOADSTORE::loads(0,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_IMM_3D(0),
                                        7, 3, 1);

            VPRO::DIM3::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_ADDR(0, 1, 8, 32),
                                        7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8, 32), SRC1_ADDR(0, 1, 8, 32), SRC2_IMM_3D(0),
                                        7, 3, 1, true);

            VPRO::DIM3::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8, 32,
                                         7, 3, 1,
                                         L1);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            dma_loc1D_to_ext1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 2, NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);
            dcma_flush();
            dma_wait_to_finish(0xffffffff);

            dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 12, NUM_TEST_ENTRIES);
            dma_loc1D_to_ext1D(0, intptr_t(result_array), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 12, NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);

            /**
             * Check result correctnes (ISS)
             */
            // C-Code reference (MIPS executes this)
            auto reference_result = new int16_t[NUM_TEST_ENTRIES];
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                reference_result[i] = test_array_1[i] + test_array_2[i];
            }

            bool fail = false;
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                if (reference_result[i] != result_array[i]) {
                    fail = true;
                }
            }


            printf_info("\nResult Data: \n");
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                printf_info("%6i, ", result_array[i]);
            }
            printf_info("\nReference Data: \n");
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                printf_info("%6i, ", reference_result[i]);
            }
            if (fail)
                printf("\n\e[91mDCMA Manual Flush Test failed:\e[0m\n");
            else
                printf("\n\e[32mDCMA Manual Flush Test succeeded\e[0m\n");
        }


        // Auto Flush Test, by overwriting dirty lines
        {
            dcma_reset();
            /**
             * Test Data Variables
             */
            constexpr int NUM_TEST_ENTRIES = 64;
            volatile int16_t test_array_1[NUM_TEST_ENTRIES];
            volatile int16_t test_array_2[NUM_TEST_ENTRIES];
            volatile int16_t result_array[NUM_TEST_ENTRIES];

            // broadcast to all
            vpro_set_cluster_mask(0xFFFFFFFF);
            vpro_set_unit_mask(0xFFFFFFFF);

            uint8_t wdata_low, wdata_high;
            for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
                test_array_1[i] = i;
                test_array_2[i] = i;
            }

            dma_ext1D_to_loc1D(0, intptr_t(test_array_1), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 10, NUM_TEST_ENTRIES);
            dma_ext1D_to_loc1D(0, intptr_t(test_array_2), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 11, NUM_TEST_ENTRIES);
            dma_loc1D_to_ext1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 10, NUM_TEST_ENTRIES);
            dma_loc1D_to_ext1D(0, base_addr + NUM_TEST_ENTRIES * 2, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 11, NUM_TEST_ENTRIES);
            dcma_flush();
            dma_wait_to_finish(0xffffffff);

            // DMA & VPRO Instructions
            dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + 0, NUM_TEST_ENTRIES);
            dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);

            VPRO::DIM2::LOADSTORE::loads(0,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0),
                                        7, 7);

            VPRO::DIM2::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_ADDR(0, 1, 8),
                                        7, 7);

            VPRO::DIM2::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0),
                                        7, 7, true);

            VPRO::DIM2::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8,
                                         7, 7,
                                         L0);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            VPRO::DIM2::LOADSTORE::loads(0,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0),
                                        7, 7);

            VPRO::DIM2::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8,
                                         7, 7);

            VPRO::DIM2::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_ADDR(0, 1, 8),
                                        7, 7);

            VPRO::DIM2::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0),
                                        7, 7, true);

            VPRO::DIM2::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8,
                                         7, 7,
                                         L1);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            VPRO::DIM3::LOADSTORE::loads(0,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_IMM_3D(0),
                                        7, 3, 1);

            VPRO::DIM3::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_ADDR(0, 1, 8, 32),
                                        7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L0,
                                        DST_ADDR(0, 1, 8, 32), SRC1_ADDR(0, 1, 8, 32), SRC2_IMM_3D(0),
                                        7, 3, 1, true);

            VPRO::DIM3::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8, 32,
                                         7, 3, 1,
                                         L0);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            VPRO::DIM3::LOADSTORE::loads(0,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_IMM_3D(0),
                                        7, 3, 1);

            VPRO::DIM3::LOADSTORE::loads(NUM_TEST_ENTRIES,
                                         0, 1, 8, 32,
                                         7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8, 32), SRC1_LS_3D, SRC2_ADDR(0, 1, 8, 32),
                                        7, 3, 1);

            VPRO::DIM3::PROCESSING::add(L1,
                                        DST_ADDR(0, 1, 8, 32), SRC1_ADDR(0, 1, 8, 32), SRC2_IMM_3D(0),
                                        7, 3, 1, true);

            VPRO::DIM3::LOADSTORE::store(NUM_TEST_ENTRIES * 2,
                                         0, 1, 8, 32,
                                         7, 3, 1,
                                         L1);

            vpro_wait_busy(0xffffffff, 0xffffffff);

            dma_loc1D_to_ext1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 2, NUM_TEST_ENTRIES);

            // auto flush by loading data for the same set into the cache
            uint32_t addr_word_select_bitwidth = uint32_t(std::ceil(log2(VPRO_CFG::DCMA_LINE_SIZE)));
            uint32_t addr_set_bitwidth = uint32_t(
                    std::ceil(
                            log2(VPRO_CFG::DCMA_BRAM_SIZE * VPRO_CFG::DCMA_NR_BRAMS / (VPRO_CFG::DCMA_LINE_SIZE * VPRO_CFG::DCMA_ASSOCIATIVITY))));
            uint32_t same_tag_offset = 1 << (addr_word_select_bitwidth + addr_set_bitwidth);

            for (int i = 1; i <= VPRO_CFG::DCMA_ASSOCIATIVITY; ++i) {
                dma_ext1D_to_loc1D(0, base_addr + i * same_tag_offset, LM_BASE_VU(0) + 0, NUM_TEST_ENTRIES);
            }

            dma_wait_to_finish(0xffffffff);

            dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0) + NUM_TEST_ENTRIES * 12, NUM_TEST_ENTRIES);
            dma_loc1D_to_ext1D(0, intptr_t(result_array), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 12, NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);

            /**
             * Check result correctnes (ISS)
             */
            // C-Code reference (MIPS executes this)
            auto reference_result = new int16_t[NUM_TEST_ENTRIES];
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                reference_result[i] = test_array_1[i] + test_array_2[i];
            }

            bool fail = false;
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                if (reference_result[i] != result_array[i]) {
                    fail = true;
                }
            }

            printf_info("\nResult Data: \n");
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                printf_info("%6i, ", result_array[i]);
            }
            printf_info("\nReference Data: \n");
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                printf_info("%6i, ", reference_result[i]);
            }

            if (fail)
                printf("\n\e[91mDCMA Auto Flush Test failed:\e[0m\n");
            else
                printf("\n\e[32mDCMA Auto Flush Test succeeded\e[0m\n");
        }
    }
    return true;
}
