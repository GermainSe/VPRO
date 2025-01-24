//
// Created by thieu on 02.06.22.
//

#include "tests/features/dma_tester.h"

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
bool dma_tester::perform_tests() {
    uint32_t base_addr = 0x00045678; // byte addr
//    for (uint32_t base_addr = 0; base_addr < 0x00045678; base_addr += 2)
    //
    // EXT to LOC 1D + LOC to EXT 1D
    //
    {
        {
            dcma_reset();
            /**
             * Test Data Variables
             */
            int NUM_TEST_ENTRIES = 4096;
            volatile int16_t test_array_1[NUM_TEST_ENTRIES];
            volatile int16_t result_array[NUM_TEST_ENTRIES];

//    uint32_t base_addr = 0; // byte addr

            // broadcast to all
            vpro_set_cluster_mask(0xFFFFFFFF);
            vpro_set_unit_mask(0xFFFFFFFF);

            uint8_t wdata_low, wdata_high;
            for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
                test_array_1[i] = i;

//        int16_t rdata = rdata_low + (uint16_t(rdata_high) << 8);
                wdata_low = i % 256;
                wdata_high = i >> 8;
                core_->dbgMemWrite(base_addr + 2 * i, &wdata_low);
                core_->dbgMemWrite(base_addr + 2 * i + 1, &wdata_high);
            }

            // DMA & VPRO Instructions
            dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0), NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);

            dma_loc1D_to_ext1D(0, base_addr + NUM_TEST_ENTRIES, LM_BASE_VU(0), NUM_TEST_ENTRIES);
//    dma_loc1D_to_ext1D(0, base_addr, LM_BASE_VU(0), NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);
            dcma_flush();

            // read result from main memory to result array
            for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
                uint8_t rdata_low, rdata_high;
                core_->dbgMemRead(base_addr + 2 * i + NUM_TEST_ENTRIES, &rdata_low);
                core_->dbgMemRead(base_addr + 2 * i + 1 + NUM_TEST_ENTRIES, &rdata_high);
                result_array[i] = rdata_low + (uint16_t(rdata_high) << 8);
            }

            /**
             * Check result correctnes (ISS)
             */
            // C-Code reference (MIPS executes this)
            auto reference_result = new int16_t[NUM_TEST_ENTRIES];
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                reference_result[i] = test_array_1[i];
            }

            bool fail = false;
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                if (reference_result[i] != result_array[i]) {
                    fail = true;
                }
            }

            if (fail) {
                printf_info("\nResult Data: \n");
                for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                    printf_info("%6i, ", result_array[i]);
                }
                printf_info("\nReference Data: \n");
                for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                    printf_info("%6i, ", reference_result[i]);
                }
            }
            if (fail)
                printf("\n\e[91mDMA EXT1D to LOC and LOC to EXT1D Test failed\e[0m\n");
            else
                printf("\n\e[32mDMA EXT1D to LOC and LOC to EXT1D Test succeeded\e[0m\n");
        }

        //
        // EXT to LOC 2D + LOC to EXT 2D with Stride
        //
        {
            dcma_reset();
            /**
             * Test Data Variables
             */
            int x_size = 64;
            int y_size = 64;
            int NUM_TEST_ENTRIES = x_size * y_size;
            volatile int16_t test_array_1[NUM_TEST_ENTRIES];
            volatile int16_t result_array[NUM_TEST_ENTRIES];

            int stride = 20;

//    uint32_t base_addr = 0; // byte addr

            // broadcast to all
            vpro_set_cluster_mask(0xFFFFFFFF);
            vpro_set_unit_mask(0xFFFFFFFF);

            uint8_t wdata_low, wdata_high;
            for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
                test_array_1[i] = i;
            }
            int counter = 0;
            for (int16_t row = 0; row < x_size; row++) {
                for (int16_t col = 0; col < y_size; col++) {
//        int16_t rdata = rdata_low + (uint16_t(rdata_high) << 8);
                    int16_t data = row * y_size + col;
                    wdata_low = data % 256;
                    wdata_high = data >> 8;
                    core_->dbgMemWrite(base_addr + 2 * counter, &wdata_low);
                    core_->dbgMemWrite(base_addr + 2 * counter + 1, &wdata_high);
                    counter++;
                }
                for (int16_t strider = 1; strider < stride; strider++) {
                    int16_t data = -1;
                    wdata_low = data % 256;
                    wdata_high = data >> 8;
                    core_->dbgMemWrite(base_addr + 2 * counter, &wdata_low);
                    core_->dbgMemWrite(base_addr + 2 * counter + 1, &wdata_high);
                    counter++;
                }
            }

            // DMA & VPRO Instructions
            dma_ext2D_to_loc1D(0, base_addr, LM_BASE_VU(0), stride, 64, 64);
//                dma_ext1D_to_loc1D(0, base_addr, LM_BASE_VU(0), NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);

            dma_loc1D_to_ext2D(0, base_addr + NUM_TEST_ENTRIES, LM_BASE_VU(0), stride, 64, 64);
//                dma_loc1D_to_ext1D(0, base_addr + NUM_TEST_ENTRIES, LM_BASE_VU(0), NUM_TEST_ENTRIES);
//    dma_loc1D_to_ext1D(0, base_addr, LM_BASE_VU(0), NUM_TEST_ENTRIES);
            dma_wait_to_finish(0xffffffff);
            dcma_flush();

//            // read result from main memory to result array
//            for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
//                uint8_t rdata_low, rdata_high;
//                core_->dbgMemRead(base_addr + 2 * i + NUM_TEST_ENTRIES, &rdata_low);
//                core_->dbgMemRead(base_addr + 2 * i + 1 + NUM_TEST_ENTRIES, &rdata_high);
//                result_array[i] = rdata_low + (uint16_t(rdata_high) << 8);
//            }

            int addr_counter = 0;
            int result_counter = 0;
            for (int16_t row = 0; row < x_size; row++) {
                for (int16_t col = 0; col < y_size; col++) {
                    uint8_t rdata_low, rdata_high;
                    core_->dbgMemRead(base_addr + 2 * addr_counter + NUM_TEST_ENTRIES, &rdata_low);
                    core_->dbgMemRead(base_addr + 2 * addr_counter + 1 + NUM_TEST_ENTRIES, &rdata_high);
                    result_array[result_counter] = rdata_low + (uint16_t(rdata_high) << 8);
                    result_counter++;
                    addr_counter++;
                }
                for (int16_t strider = 1; strider < stride; strider++) {
                    addr_counter++;
                }
            }

            /**
             * Check result correctnes (ISS)
             */
            // C-Code reference (MIPS executes this)
            auto reference_result = new int16_t[NUM_TEST_ENTRIES];
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                reference_result[i] = test_array_1[i];
            }

            bool fail = false;
            for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                if (reference_result[i] != result_array[i]) {
                    fail = true;
                }
            }

            if (fail) {
                printf_info("\nResult Data: \n");
                for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                    printf_info("%6i, ", result_array[i]);
                }
                printf_info("\nReference Data: \n");
                for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
                    printf_info("%6i, ", reference_result[i]);
                }
            }
            if (fail)
                printf("\n\e[91mDMA EXT2D to LOC and LOC to EXT2D Test with Stride failed\e[0m\n");
            else
                printf("\n\e[32mDMA EXT2D to LOC and LOC to EXT2D Test with Stride succeeded\e[0m\n");
        }
    }
    return true;
}
