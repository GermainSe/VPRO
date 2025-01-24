// ########################################################
// # example app for MIPS, using some IO/Data instruction #
// #                                                      #
// # Sven Gesper, EIS, Tu Braunschweig, 2021              #
// ########################################################

#include <stdint.h>
#include <algorithm>
#include <vpro.h>
#include "riscv/eisV_hardware_info.hpp"

/**
 * Main
 */
int main(int argc, char *argv[]) {
    sim_init(main, argc, argv);
    // MM Layout: (segments with 256 MB)
    // 0x0000_0000 - 0x0FFF_FFFF: Application (Do not use!)
    // 0x1000_0000 - 0x1FFF_FFFF: Input Data (Randomized)
    // 0x2000_0000 - 0x2FFF_FFFF: Temp Data (During Execution)
    // 0x3000_0000 - 0x3FFF_FFFF: Dump Data (After Execution: LMs, RFs)
    struct DataDumpLayout {
        uint32_t input_data_random = 0x10000000;
        uint32_t result_data_lms = 0x30000000;
        uint32_t result_data_rfs = 0x30000000 + VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * 8192 * 2;
    } mm_datadump_layout;

    aux_print_hardware_info("Verification App");

    // Set Default Confiuration Modes
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::Z_INCREMENT);
    vpro_mac_h_bit_shift(0);
    vpro_mul_h_bit_shift(0);
    printf_info("Default Configuration Set\n");

    /**
     * Initialize all LMs with different input data
     */
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            dma_ext1D_to_loc1D(c, mm_datadump_layout.input_data_random + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2,
                               LM_BASE_VU(u), 4096);
            dma_ext1D_to_loc1D(c,
                               mm_datadump_layout.input_data_random + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2 + 4096 * 2,
                               LM_BASE_VU(u) + 4096, 4096);
        }
    }
    dma_wait_to_finish();
    printf_info("LM Initialized from MM (random input data start: 0x%08x)\n", mm_datadump_layout.input_data_random);

    /**
     * Initialize all RFs with those input data
     */
    const uint init_random_offset_in_lm_l0 = 2222;
    const uint init_random_offset_in_lm_l1 = 4444;
    VPRO::DIM3::LOADSTORE::loads(init_random_offset_in_lm_l0,
                                 0, 1, 32, 0,
                                 31, 31, 0);

    VPRO::DIM3::PROCESSING::add(L0_1,   // both to avoid chaining failures (sync to which lane takes the loaded data)
                                DST_ADDR(0, 1, 32, 0), SRC1_LS_3D, SRC2_IMM_3D(0),
                                31, 31, 0);

    VPRO::DIM3::LOADSTORE::loads(init_random_offset_in_lm_l1,
                                 0, 1, 32, 0,
                                 31, 31, 0);

    VPRO::DIM3::PROCESSING::add(L1,
                                DST_ADDR(0, 1, 32, 0), SRC1_LS_3D, SRC2_IMM_3D(0),
                                31, 31, 0);
    vpro_wait_busy();
    printf_info("RF Initialized from LM\n");

    /**
     * Test Code within VPRO
     */
    printf_info("[start] VPRO Test Instructions\n");

    // simple (add with 0)
//    VPRO::DIM3::LOADSTORE::loads(0,
//                                 0, 0, 0, 1,
//                                 0, 0, 1023);
//    VPRO::DIM3::PROCESSING::add(L0_1,
//                                DST_ADDR(0, 0, 0, 1), SRC1_LS_3D, SRC2_IMM_3D(0),
//                                0, 0, 1023);

    VPRO::DIM3::LOADSTORE::loads(0,
                                 0, 1, 3, 1,
                                 2, 2, 29);
    // init accu to 0 when z increments
    VPRO::DIM3::PROCESSING::mach(L0,
                                 DST_ADDR(0, 0, 0, 1), SRC1_LS_3D, SRC2_ADDR(1000, 1, 3, 0),
                                 2, 2, 29, true);
    VPRO::DIM3::PROCESSING::add(L1,
                                DST_ADDR(0, 0, 0, 1), SRC1_CHAINING_LEFT_3D, SRC2_ADDR(1000, 0, 0, 0),
                                2, 2, 29);

    // 2nd instruction
    VPRO::DIM3::PROCESSING::mull(L0_1,
                                 DST_ADDR(0, 0, 0, 1), SRC1_ADDR(0, 0, 0, 1), SRC2_IMM_3D(2),
                                 0, 0, 1023);
    vpro_wait_busy();
    printf_info("[done] VPRO Test Instructions\n");

    /**
     * Store Contents to MM
     */
    // LM
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            dma_loc1D_to_ext1D(c, mm_datadump_layout.result_data_lms + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2,
                               LM_BASE_VU(u), 4096);
            dma_loc1D_to_ext1D(c,
                               mm_datadump_layout.result_data_lms + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2 + 4096 * 2,
                               LM_BASE_VU(u) + 4096, 4096);
        }
    }
    dma_wait_to_finish();
    printf_info("[done] LMs Stored to MM (start: 0x%08x)\n", mm_datadump_layout.result_data_lms);

    // RF
    VPRO::DIM3::PROCESSING::add(L0,
                                DST_ADDR(0, 0, 0, 1), SRC1_ADDR(0, 0, 0, 1), SRC2_IMM_3D(0),
                                0, 0, 1023, true);

    VPRO::DIM3::LOADSTORE::store(0,
                                 0, 0, 0, 1,
                                 0, 0, 1023,
                                 L0);

    VPRO::DIM3::PROCESSING::add(L1,
                                DST_ADDR(0, 0, 0, 1), SRC1_ADDR(0, 0, 0, 1), SRC2_IMM_3D(0),
                                0, 0, 1023, true);

    VPRO::DIM3::LOADSTORE::store(1024,
                                 0, 0, 0, 1,
                                 0, 0, 1023,
                                 L1);
    vpro_wait_busy();

    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            dma_loc1D_to_ext1D(c, mm_datadump_layout.result_data_rfs + c * VPRO_CFG::UNITS * 1024 * 2 * 2 + u * 1024 * 2 * 2,
                               LM_BASE_VU(u), 1024);
            dma_loc1D_to_ext1D(c, mm_datadump_layout.result_data_rfs + c * VPRO_CFG::UNITS * 1024 * 2 * 2 + u * 1024 * 2 * 2 +
                                  1024 * 2, LM_BASE_VU(u) + 1024, 1024);
        }
    }
    dma_wait_to_finish();
    printf_info("[done] RFs Stored to MM (start: 0x%08x)\n", mm_datadump_layout.result_data_rfs);
    dcma_flush();

    /**
     * Calculate with RISC-V C-Code
     */
    // Initialize Memories
#ifndef SIMULATION
    uint8_t *mm = ((volatile uint8_t *) 0);
#else
    auto *mm = new uint8_t[0x40000000];
    for (int i = 0; i < 0x40000000; i++) {
        core_->dbgMemRead(i, &(mm[i]));
    }
#endif
    int16_t lm[VPRO_CFG::CLUSTERS][VPRO_CFG::UNITS][8192];
    int32_t rf[VPRO_CFG::CLUSTERS][VPRO_CFG::UNITS][VPRO_CFG::LANES][1024];

    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            memcpy(lm[c][u], &mm[mm_datadump_layout.input_data_random + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2],
                   8192 * 2);
            memcpy(rf[c][u][0], &mm[mm_datadump_layout.input_data_random + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2 +
                                    init_random_offset_in_lm_l0 * 2], 1024 * 2);
            // do sign extension (init from lm 16-bit loads -> 24-bit)
            for (int i = 1023; i >= 0; --i) {
                rf[c][u][0][i] = ((int16_t *) (rf[c][u][0]))[i];
            }
            memcpy(rf[c][u][1], &mm[mm_datadump_layout.input_data_random + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2 +
                                    init_random_offset_in_lm_l1 * 2], 1024 * 2);
            // do sign extension (init from lm 16-bit loads -> 24-bit)
            for (int i = 1023; i >= 0; --i) {
                rf[c][u][1][i] = ((int16_t *) (rf[c][u][1]))[i];
            }
        }
    }
    printf_info("[done] MM initialized for Reference Calculation\n");

    // Calculate Modification
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            int64_t accu0 = 0;
            int64_t accu1 = 0;
            for (size_t z = 0; z <= 29; z++) {
                for (size_t y = 0; y <= 2; y++) {
                    for (size_t x = 0; x <= 2; x++) {
                        /**
                        * LOADS
                        */
                        int32_t loaded_data = lm[c][u][0 + x * 1 + y * 3 + z * 1];

                        loaded_data = loaded_data & 0xffff; // load of 16-bit!
                        if ((loaded_data & 0x8000) != 0)  // sign extension for loads
                            loaded_data = loaded_data | 0xffff0000; // the value is negative

                            // simple add (+0)
//                        // store dst
//                        rf[c][u][0][0 + x * 0 + y * 0 + z * 1] = loaded_data;
//                        rf[c][u][1][0 + x * 0 + y * 0 + z * 1] = loaded_data;

                        /**
                        * MACH
                        */
                        int32_t src1_data = loaded_data;
                        int32_t src2_data = rf[c][u][0][1000 + x * 1 + y * 3 + z * 0];  // stored values in RF are already sign extended (24-bit!)

                        // MAC uses 24 x 18-bit
                        if ((src2_data & 0x00020000) != 0)  // sign extension for src2 (18-bit)
                            src2_data = src2_data | 0xfffc0000; // the value is negative
                        // mac will store result in accumulation register
                        accu0 = accu0 + src1_data * src2_data;

                        int32_t result0 = (accu0 >> 0);  // result of macl is accu lower part
                        if ((result0 & 0x00800000) != 0)  // sign extension for 24-bit
                            result0 = result0 | 0xff000000; // the value is negative

                        // store dst
                        rf[c][u][0][0 + x * 0 + y * 0 + z * 1] = result0;

                        /**
                        * ADD
                        */
                        src1_data = result0;    // chained from neighbor
                        src2_data = rf[c][u][1][1000 + x * 0 + y * 0 + z * 0];  // stored values in RF are already sign extended (24-bit!)

                        int32_t result1 = src1_data + src2_data;
                        if ((result1 & 0x00800000) != 0)  // sign extension for 24-bit
                            result1 = result1 | 0xff000000; // the value is negative

                        // store dst
                        rf[c][u][1][0 + x * 0 + y * 0 + z * 1] = result1;
                    }
                }
                // MACH -> accu reset if mode: VPRO::MAC_RESET_MODE::Z_INCREMENT
                // MACH -> reset to 0 if mode: VPRO::MAC_INIT_SOURCE::ZERO
                accu0 = 0;
            }
        }
    }
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            int64_t accu0 = 0;
            int64_t accu1 = 0;
            for (size_t z = 0; z <= 1023; z++) {
                for (size_t y = 0; y <= 0; y++) {
                    for (size_t x = 0; x <= 0; x++) {
                        int32_t src1_data = rf[c][u][0][0 + x * 0 + y * 0 + z * 1];  // stored values in RF are already sign extended (24-bit!)
                        int32_t src2_data = 2; // immediate

                        // MUL uses 24 x 18-bit
                        if ((src2_data & 0x00020000) != 0)  // sign extension for src2 (18-bit)
                            src2_data = src2_data | 0xfffc0000; // the value is negative

                        accu0 = src1_data * src2_data;  // result of mull is accu lower part
                        int32_t result0 = (accu0 >> 0);  // result of macl is accu lower part
                        if ((result0 & 0x00800000) != 0)  // sign extension for 24-bit
                            result0 = result0 | 0xff000000; // the value is negative

                        rf[c][u][0][0 + x * 0 + y * 0 + z * 1] = result0;

                        src1_data = rf[c][u][1][0 + x * 0 + y * 0 + z * 1];  // stored values in RF are already sign extended (24-bit!)
                        src2_data = 2; // immediate
                        // same instruction + data on L1
                        accu1 = src1_data * src2_data;  // result of mull is accu lower part
                        int32_t result1 = (accu1 >> 0);  // result of macl is accu lower part
                        if ((result1 & 0x00800000) != 0)  // sign extension for 24-bit
                            result1 = result1 | 0xff000000; // the value is negative

                        rf[c][u][1][0 + x * 0 + y * 0 + z * 1] = result1;
                    }
                }
            }
        }
    }
    printf_info("[done] Reference Caluclation\n");

    /**
     * Compare for Verification
     */
    // VPRO Results:
#ifndef SIMULATION
    mm = ((volatile uint8_t *) 0);
#else
    mm = new uint8_t[0x40000000];
    for (int i = 0; i < 0x40000000; i++) {
        core_->dbgMemRead(i, &(mm[i]));
    }
#endif
    printf_info("[done] Verification fetched VPRO MM Result\n");

    bool lm_fail = false;
    bool rf_fail = false;

    // compare LMs
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            bool this_fail = false;
            for (size_t i = 0; i < 8192 * 2; i++) {
                if (mm[mm_datadump_layout.result_data_lms + c * VPRO_CFG::UNITS * 8192 * 2 + u * 8192 * 2 + i] !=
                    ((uint8_t *) lm[c][u])[i]) {
                    this_fail = true;
                }
            }
            if (this_fail) {
                lm_fail |= this_fail;
                printf_error("LM (C: %i, U: %i) Not Equal!\n", c, u);
            }
        }
    }
    if (lm_fail) {
        printf_error("LM Not Equal!\n");
    } else {
        printf_success("LM are all Equal!\n");
    }

    // TODO: also compare upper byte of RF (add region to store this in MM, store + compare with reference)
    int16_t rf_cut[VPRO_CFG::CLUSTERS][VPRO_CFG::UNITS][VPRO_CFG::LANES][1024];  // this contains the stored (16-bit) elements of the rf
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            for (int i = 1023; i >= 0; --i) {
                rf_cut[c][u][0][i] = int16_t(rf[c][u][0][i] & 0xffff);
                rf_cut[c][u][1][i] = int16_t(rf[c][u][1][i] & 0xffff);
            }
        }
    }
    // compare RFs
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            bool this_fail = false;
            for (size_t i = 0; i < 1024 * 2; i++) {
                if (mm[mm_datadump_layout.result_data_rfs + c * VPRO_CFG::UNITS * 2048 * 2 + u * 2048 * 2 + i] !=
                    ((uint8_t *) rf_cut[c][u][0])[i]) {
                    this_fail = true;
                }
            }
            if (this_fail) {
                rf_fail |= this_fail;
                printf_error("RF0 (C: %i, U: %i) Not Equal!\n", c, u);
            }
            this_fail = false;
            for (size_t i = 0; i < 1024 * 2; i++) {
                if (mm[mm_datadump_layout.result_data_rfs + c * VPRO_CFG::UNITS * 2048 * 2 + u * 2048 * 2 + 1024 * 2 + i] !=
                    ((uint8_t *) rf_cut[c][u][1])[i]) {
                    this_fail = true;
                }
            }
            if (this_fail) {
                rf_fail |= this_fail;
                printf_error("RF1 (C: %i, U: %i) Not Equal!\n", c, u);
            }
        }
    }
    if (rf_fail) {
        printf_error("RF Not Equal!\n");
    } else {
        printf_success("RF are all Equal!\n");
    }
    printf_info("[done] Verification\n");


    // return code: 0 is success
    sim_stop();
    return ((rf_fail || lm_fail) ? 1 : 0);
}
