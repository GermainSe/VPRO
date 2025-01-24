#include "memory.h"
#include <eisv.h>
#include <cstring>
#include "constants.h"
#include "helper.h"

/**
 * MM: 8-bit
 * LM: 16-bit x VPRO_CFG::LM_SIZE
 * RF: 24-bit x VPRO_CFG::RF_SIZE
 */

namespace LocalMemory {
/**
 * @brief Initialize all vpro local memories with different input data
 */
void initialize_vpro() {
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            uint32_t mm_base = MMDatadumpLayout::INPUT_DATA_RANDOM +
                               c * VPRO_CFG::UNITS * VPRO_CFG::LM_SIZE * 2 +
                               u * VPRO_CFG::LM_SIZE * 2;
            dma_e2l_1d(1 << c, 1 << u, mm_base, 0, VPRO_CFG::LM_SIZE);
        }
    }

    vpro_sync();
}
/**
 * @brief like int16_t lm[VPRO_CFG::CLUSTERS][VPRO_CFG::UNITS][VPRO_CFG::LM_SIZE] to avoid initializing array with dynamic expressions
 *
 * @param lm empty created pointer to riscv local memory
 */
int16_t*** initialize_riscv() {
    auto lm = new int16_t**[VPRO_CFG::CLUSTERS];
    for (size_t i = 0; i < VPRO_CFG::CLUSTERS; i++) {
        lm[i] = new int16_t*[VPRO_CFG::UNITS];
        for (size_t j = 0; j < VPRO_CFG::UNITS; j++) {
            lm[i][j] = new int16_t[VPRO_CFG::LM_SIZE];
        }
    }
    return lm;
}
/**
 * @brief store vpro local memories contents to main memory
 */
void store_to_main_memory() {
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            uint32_t mm_base = MMDatadumpLayout::RESULT_DATA_LM +
                               c * VPRO_CFG::UNITS * VPRO_CFG::LM_SIZE * 2 +
                               u * VPRO_CFG::LM_SIZE * 2;

            dma_l2e_1d(1 << c, 1 << u, mm_base, 0, VPRO_CFG::LM_SIZE);
        }
    }

    vpro_sync();
}

/**
 * @brief compare if content of local memory of riscv and vpro computation are equal
 *
 * @param mm main memory where vpro local memory is stored
 * @param lm riscv local memory
 * @return true both local memories are equal
 * @return false the local memories are not equal
 */
bool compare_lm(uint8_t* mm, int16_t*** lm, bool silent) {
#ifndef SIMULATION
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
#if SAFE_BUT_SLOW == 0
    uint32_t RESULT_DATA_LM_CACHED = 0x06000000;
    uint32_t copy_size = VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * VPRO_CFG::LM_SIZE * 2;
    MainMemory::unsafe_copy_to_cached_region(
        RESULT_DATA_LM_CACHED, MMDatadumpLayout::RESULT_DATA_LM, copy_size);
#endif
#endif
    bool lm_fail = false;
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
#if defined(SIMULATION) or SAFE_BUT_SLOW == 1
            uint8_t* mm_base =
                &(mm[MMDatadumpLayout::RESULT_DATA_LM +
                     c * VPRO_CFG::UNITS * VPRO_CFG::LM_SIZE * 2 + u * VPRO_CFG::LM_SIZE * 2]);
#else
            // compare of cached region
            uint8_t* mm_base =
                &(mm[RESULT_DATA_LM_CACHED + c * VPRO_CFG::UNITS * VPRO_CFG::LM_SIZE * 2 +
                     u * VPRO_CFG::LM_SIZE * 2]);
#endif
            bool this_fail = false;
            for (size_t i = 0; i < VPRO_CFG::LM_SIZE; i++) {
                int16_t vpro_res =
                    int16_t(mm_base[i * 2]) + int16_t(int16_t(mm_base[i * 2 + 1]) << 8);
                int16_t& rv_res = lm[c][u][i];
                if (vpro_res != rv_res) {
                    this_fail = true;
                }
                //                if (i < 10){
                //                    printf_warning("compare LM[%i] VPRO: %x | %i, RV: %x | %i\n", i, vpro_res, vpro_res, rv_res, rv_res);
                //                }
            }
            if (this_fail) {
                lm_fail |= this_fail;
                if (!silent)
                    printf_error("LM (C: %i, U: %i) Not Equal!\n", c, u);
            }
        }
    }
    return lm_fail;
}
}  // namespace LocalMemory

namespace RegisterFile {
/**
 * @brief Initialize all vpro register files with random input data from local memory
 */
void initialize_vpro() {
    /**
     * L0
     */
    VPRO::DIM3::LOADSTORE::loads(InitRandomOffsetInLM::L0, 0, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1);
    VPRO::DIM3::PROCESSING::mull(  // ~ shift left (16)
        L0_1,  // both to avoid chaining failures (sync to which lane takes the loaded data)
        DST_ADDR(0, 0, 0, 1),
        SRC1_LS_3D,
        SRC2_IMM_3D(1 << 16),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1);

    VPRO::DIM3::LOADSTORE::load(InitRandomOffsetInLM::L0, 1, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1);
    VPRO::DIM3::PROCESSING::or_(
        L0_1,  // both to avoid chaining failures (sync to which lane takes the loaded data)
        DST_ADDR(0, 0, 0, 1),
        SRC1_LS_3D,
        SRC2_ADDR(0, 0, 0, 1),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1,
        false,
        true,
        false);  // update flags

    /**
     * L1
     */
    VPRO::DIM3::LOADSTORE::loads(InitRandomOffsetInLM::L1, 0, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1);
    VPRO::DIM3::PROCESSING::mull(L1,  // ~ shift left (16)
        DST_ADDR(0, 0, 0, 1),
        SRC1_LS_3D,
        SRC2_IMM_3D(1 << 16),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1);

    VPRO::DIM3::LOADSTORE::load(InitRandomOffsetInLM::L1, 1, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1);
    VPRO::DIM3::PROCESSING::or_(
        L1,  // both to avoid chaining failures (sync to which lane takes the loaded data)
        DST_ADDR(0, 0, 0, 1),
        SRC1_LS_3D,
        SRC2_ADDR(0, 0, 0, 1),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1,
        false,
        true,
        false);  // update flags

    vpro_sync();
}
/**
 * @brief like int32_t rf[VPRO_CFG::CLUSTERS][VPRO_CFG::UNITS][VPRO_CFG::LANES][VPRO_CFG::RF_SIZE] to avoid initializing array with dynamic expressions
 *
 * @param rf empty created pointer to riscv register file
 */
int32_t**** initialize_riscv_32() {
    auto rf = new int32_t***[VPRO_CFG::CLUSTERS];
    for (size_t i = 0; i < VPRO_CFG::CLUSTERS; i++) {
        rf[i] = new int32_t**[VPRO_CFG::UNITS];
        for (size_t j = 0; j < VPRO_CFG::UNITS; j++) {
            rf[i][j] = new int32_t*[VPRO_CFG::LANES];
            for (size_t k = 0; k < VPRO_CFG::LANES; k++) {
                rf[i][j][k] = new int32_t[VPRO_CFG::RF_SIZE * 3]();  // *3 to store flags
            }
        }
    }
    return rf;
}

/**
 * @brief store data from vpro register file into the main memory. Flushes dmca at end
 */
void store_to_main_memory() {
    /**
     * RF 0     ->  LM
     * [0-VPRO_CFG::RF_SIZE - 1]     [0-2047]
     */
    VPRO::DIM3::PROCESSING::add(L0,
        DST_ADDR(0, 0, 0, 1),
        SRC1_ADDR(0, 0, 0, 1),
        SRC2_IMM_3D(0),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1,
        true);
    VPRO::DIM3::LOADSTORE::store(0, 0, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1, L0);  // every second
    VPRO::DIM3::PROCESSING::shift_ar(L0,
        DST_ADDR(0, 0, 0, 1),
        SRC1_ADDR(0, 0, 0, 1),
        SRC2_IMM_3D(16),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1,
        true);
    VPRO::DIM3::LOADSTORE::store(0, 1, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1, L0);  // msbs

    /**
     * RF 1     ->  LM
     * [0-VPRO_CFG::RF_SIZE - 1]     [2048-4095]
     */
    VPRO::DIM3::PROCESSING::add(L1,
        DST_ADDR(0, 0, 0, 1),
        SRC1_ADDR(0, 0, 0, 1),
        SRC2_IMM_3D(0),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1,
        true);
    VPRO::DIM3::LOADSTORE::store(2048, 0, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1, L1);
    VPRO::DIM3::PROCESSING::shift_ar(L1,
        DST_ADDR(0, 0, 0, 1),
        SRC1_ADDR(0, 0, 0, 1),
        SRC2_IMM_3D(16),
        0,
        0,
        VPRO_CFG::RF_SIZE - 1,
        true);
    VPRO::DIM3::LOADSTORE::store(2048, 1, 0, 0, 2, 0, 0, VPRO_CFG::RF_SIZE - 1, L1);

    vpro_sync();

    /**
     * LM -> MM
     */
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            uint32_t mm_base_l0 =
                MMDatadumpLayout::RESULT_DATA_RF +
                c * VPRO_CFG::UNITS * VPRO_CFG::RF_SIZE * 2 * 4 +  // ea, 2 Lanes, 4 Byte
                u * VPRO_CFG::RF_SIZE * 2 * 4 +                    // 2 Lanes, 4 Byte
                0;
            uint32_t mm_base_l1 =
                MMDatadumpLayout::RESULT_DATA_RF +
                c * VPRO_CFG::UNITS * VPRO_CFG::RF_SIZE * 2 * 4 +  // ea, 2 Lanes, 4 Byte
                u * VPRO_CFG::RF_SIZE * 2 * 4 +                    // 2 Lanes, 4 Byte
                VPRO_CFG::RF_SIZE * 4;
            dma_l2e_1d(1 << c, 1 << u, mm_base_l0, 0,
                VPRO_CFG::RF_SIZE * 2);  // Lane 0
            dma_l2e_1d(1 << c,
                1 << u,
                mm_base_l1,
                VPRO_CFG::RF_SIZE * 2,
                VPRO_CFG::RF_SIZE * 2);  // Lane 1
        }
    }

    vpro_sync();
}
/**
 * @brief compare if content of register files of riscv and vpro computation are equal
 *
 * @param mm main memory where vpro register file is stored
 * @param rf riscv register file
 * @return true both register files are equal
 * @return false the register files are not equal
 */
bool compare_rf(uint8_t* mm, int32_t**** rf, bool silent) {
#ifndef SIMULATION
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
#if SAFE_BUT_SLOW == 0
    uint32_t RESULT_DATA_RF_CACHED =
        0x06000000 + VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * VPRO_CFG::LM_SIZE * 2;
    uint32_t copy_size = VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * 2 * VPRO_CFG::RF_SIZE * 4;
    MainMemory::unsafe_copy_to_cached_region(
        RESULT_DATA_RF_CACHED, MMDatadumpLayout::RESULT_DATA_RF, copy_size);
#endif
#endif
    bool rf_fail = false;
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
#if defined(SIMULATION) or SAFE_BUT_SLOW == 1
            uint32_t mm_base =
                MMDatadumpLayout::RESULT_DATA_RF +
                c * VPRO_CFG::UNITS * VPRO_CFG::RF_SIZE * 2 * 4 +  // ea, 2 Lanes, 4 Byte
                u * VPRO_CFG::RF_SIZE * 2 * 4;
#else
            // compare of cached region
            uint32_t mm_base =
                RESULT_DATA_RF_CACHED +
                c * VPRO_CFG::UNITS * VPRO_CFG::RF_SIZE * 2 * 4 +  // ea, 2 Lanes, 4 Byte
                u * VPRO_CFG::RF_SIZE * 2 * 4;
#endif
            // LANE 0
            bool this_fail = false;
            for (size_t i = 0; i < VPRO_CFG::RF_SIZE; i++) {
                auto rf_cut = uint32_t(rf[c][u][0][i] & 0xffffff);  // cut to 24-bit
                auto mm_data = uint32_t(mm[mm_base + 4 * i + 0]) +
                               (uint32_t(mm[mm_base + 4 * i + 1]) << 8) +
                               (uint32_t(mm[mm_base + 4 * i + 2]) << 16);
                // ignore 4th byte
                //                if (i < 10 || i > 1014)
                //                    printf_warning(
                //                        "\033[36m[RF0]\033[0m c: %2zu, u: %2zu, addr: %3zu "
                //                        "\033[32mVPRO: \033[0m 0x%06x, \033[91mRISCV: \033[0m 0x%06x \n",
                //                        c, u, i, mm_data, rf_cut);
                if (mm_data != rf_cut)  // compare the lower and higher 8-bits individually
                {
                    this_fail = true;
                    if (!silent)
                        printf(
                            "\033[36m[RF0]\033[0m c: %2zu, u: %2zu, addr: %3zu "
                            "\033[32mVPRO: \033[0m 0x%06x, \033[91mRISCV: \033[0m 0x%06x \n",
                            c,
                            u,
                            i,
                            mm_data,
                            rf_cut);
                }
            }
            if (this_fail) {
                rf_fail |= this_fail;
                if (!silent)
                    printf_error("RF0 (C: %i, U: %i) Not Equal!\n", c, u);
            }

            // LANE 1
            this_fail = false;
            for (size_t i = 0; i < VPRO_CFG::RF_SIZE; i++) {
                auto rf_cut = uint32_t(rf[c][u][1][i] & 0xffffff);  // cut to 24-bit!
                auto mm_data = uint32_t(mm[mm_base + VPRO_CFG::RF_SIZE * 4 + 4 * i + 0]) +
                               uint32_t(mm[mm_base + VPRO_CFG::RF_SIZE * 4 + 4 * i + 1] << 8) +
                               uint32_t(mm[mm_base + VPRO_CFG::RF_SIZE * 4 + 4 * i + 2] << 16);
                // ignore 4th byte
                //                if (i < 10 || i > 1014)
                //                    printf_warning(
                //                        "\033[36m[RF1]\033[0m c: %2zu, u: %2zu, addr: %3zu "
                //                        "\033[32mVPRO: \033[0m 0x%06x, \033[91mRISCV: \033[0m 0x%06x \n",
                //                        c, u, i, mm_data, rf_cut);
                if (mm_data != rf_cut)  // compare the lower and higher 8-bits individually
                {
                    this_fail = true;
                    if (!silent)
                        printf(
                            "\033[36m[RF1]\033[0m c: %2zu, u: %2zu, addr: %3zu "
                            "\033[32mVPRO: \033[0m 0x%06x, \033[91mRISCV: \033[0m 0x%06x \n",
                            c,
                            u,
                            i,
                            mm_data,
                            rf_cut);
                }
            }
            if (this_fail) {
                rf_fail |= this_fail;
                if (!silent)
                    printf_error("RF1 (C: %i, U: %i) Not Equal!\n", c, u);
            }
        }
    }
    return rf_fail;
}
}  // namespace RegisterFile

namespace MainMemory {

void unsafe_copy_to_cached_region(uint32_t dst, uint32_t src, uint32_t size) {
// TODO: unsafe copy of DMA -> DCACHE region. RESULT_DATA_LM_CACHED
//  Use of DMAs.
//  DCMA flushed afterwards.
//  DCACHE flush + clear beforehand
#ifndef SIMULATION
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
    aux_flush_dcache();
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
    aux_clr_dcache();
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
    uint32_t remaining_dma = size % (VPRO_CFG::LM_SIZE * 2);
    uint32_t full_dma_loops = size / (VPRO_CFG::LM_SIZE * 2);
    auto ext_src_base = src;
    auto ext_dst_base = dst;
    while (full_dma_loops > 0) {
        for (uint c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
            dma_e2l_1d(1 << c, 1, ext_src_base, 0, VPRO_CFG::LM_SIZE);
            ext_src_base += VPRO_CFG::LM_SIZE;
            dma_l2e_1d(1 << c, 1, ext_dst_base, 0, VPRO_CFG::LM_SIZE);
            ext_dst_base += VPRO_CFG::LM_SIZE;
            full_dma_loops--;
            if (full_dma_loops <= 0) break;
        }
    }
    dma_e2l_1d(1, 1, ext_src_base, 0, remaining_dma);
    dma_l2e_1d(1, 1, ext_dst_base, 0, remaining_dma);
    vpro_sync();
    vpro_sync();
    dcma_flush();
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
    aux_flush_dcache();
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
    aux_clr_dcache();
    asm volatile(
        "" ::
            : "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
#else
    printf_error(
        "[ERROR] unsafe_copy_to_cached_region() -- only for FPGA execution! Not for SIMULATION!");
    exit(1);
#endif
}

/**
 * @brief initialize main memory for simulation
 *
 * @param mm  empty created pointer to main memory
 */
uint8_t* initialize(uint8_t* mm) {
#ifdef SIMULATION
    if (mm == nullptr) mm = new uint8_t[0x40000000];
    for (int i = 0; i < 0x40000000; i++) {
        core_->dbgMemRead(i, &(mm[i]));
    }
#else
    mm = ((uint8_t*)0);
#endif
    return mm;
}

/**
 * @brief copy data of main memory into riscv local memory and riscv register file for simulation
 *
 * @param mm pointer to main memory, where vpro data of local memory and register file is stored.
 * @param lm pointer to initialized riscv local memory
 * @param rf ponter to initialize riscv register file
 */
void reference_calculation_init(uint8_t* mm, int16_t*** lm, int32_t**** rf) {
    for (size_t c = 0; c < VPRO_CFG::CLUSTERS; c++) {
        for (size_t u = 0; u < VPRO_CFG::UNITS; u++) {
            uint32_t mm_base_lm = MMDatadumpLayout::INPUT_DATA_RANDOM +
                                  c * VPRO_CFG::UNITS * VPRO_CFG::LM_SIZE * 2 +
                                  u * VPRO_CFG::LM_SIZE * 2;
            memcpy(lm[c][u], &mm[mm_base_lm], VPRO_CFG::LM_SIZE * 2);

            //RF for Lane 0
            for (int i = VPRO_CFG::RF_SIZE - 1; i >= 0; --i) {
                rf[c][u][0][i] = DataFormat::signed24Bit(int32_t(
                    (uint32_t(mm[mm_base_lm + 2 * InitRandomOffsetInLM::L0 + i * 4 + 0]) << 16) |
                    (uint32_t(mm[mm_base_lm + 2 * InitRandomOffsetInLM::L0 + i * 4 + 3]) << 8) |
                    mm[mm_base_lm + 2 * InitRandomOffsetInLM::L0 + i * 4 + 2]));
                // update flags
                rf[c][u][0][VPRO_CFG::RF_SIZE + i] = (rf[c][u][0][i] < 0) ? 1 : 0;
                rf[c][u][0][VPRO_CFG::RF_SIZE * 2 + i] = (rf[c][u][0][i] == 0) ? 1 : 0;
            }

            //RF for Lane 1
            for (int i = VPRO_CFG::RF_SIZE - 1; i >= 0; --i) {
                rf[c][u][1][i] = DataFormat::signed24Bit(int32_t(
                    (uint32_t(mm[mm_base_lm + 2 * InitRandomOffsetInLM::L1 + i * 4 + 0]) << 16) |
                    (uint32_t(mm[mm_base_lm + 2 * InitRandomOffsetInLM::L1 + i * 4 + 3]) << 8) |
                    mm[mm_base_lm + 2 * InitRandomOffsetInLM::L1 + i * 4 + 2]));
                // update flags
                rf[c][u][1][VPRO_CFG::RF_SIZE + i] = (rf[c][u][1][i] < 0) ? 1 : 0;
                rf[c][u][1][VPRO_CFG::RF_SIZE * 2 + i] = (rf[c][u][1][i] == 0) ? 1 : 0;
            }
        }
    }
}

}  // namespace MainMemory