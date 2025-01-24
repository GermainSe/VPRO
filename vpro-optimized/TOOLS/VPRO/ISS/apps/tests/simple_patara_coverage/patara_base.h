//
// Created by gesper on 15.04.24.
//

#ifndef SIMPLE_PATARA_COVERAGE_PATARA_BASE_H
#define SIMPLE_PATARA_COVERAGE_PATARA_BASE_H

#include <vpro.h>

static void vpro_patara_base() {
    dcma_flush();
    dcma_reset();

    vpro_sync();
    dma_e2l_2d(0x7, 0x1, 0x10000000, 0x0, 8192, 1, 1);
    dma_l2e_2d(0x1, 0x1, 0x30000000, 0x0, 8192, 1, 1);
    vpro_sync();
    dma_e2l_2d(0x7, 0x1, 0x10000000, 0x0, 8192, 1, 1);
    vpro_sync();
//for(int i = 0; i < 8192; i += 1024){
//VPRO::DIM3::LOADSTORE::loads(i, 0, 0, 0, 1, 0, 0, 1023);
//VPRO::DIM3::PROCESSING::or_(L0_1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_ADDR(0, 0, 0, 1), 0, 0, 1023, false, true, false);
//}
//vpro_sync();
//for(int i = 0; i < 8192; i += 1024){
//VPRO::DIM3::PROCESSING::or_(L0, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), 0, 0, 1023, true);
//VPRO::DIM3::LOADSTORE::store(i, 0, 0, 0, 1, 0, 0, 1023, L0);
//}
//vpro_sync();
//VPRO::DIM3::LOADSTORE::loads(2222, 0, 0, 0, 2, 0, 0, 1023);
//VPRO::DIM3::PROCESSING::mull(L0_1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_IMM_3D(65536), 0, 0, 1023);
//VPRO::DIM3::LOADSTORE::load(2222, 1, 0, 0, 2, 0, 0, 1023);
//VPRO::DIM3::PROCESSING::or_(L0_1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_ADDR(0, 0, 0, 1), 0, 0, 1023, false, true, false);
//VPRO::DIM3::LOADSTORE::loads(4444, 0, 0, 0, 2, 0, 0, 1023);
//VPRO::DIM3::PROCESSING::mull(L1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_IMM_3D(65536), 0, 0, 1023);
//VPRO::DIM3::LOADSTORE::load(4444, 1, 0, 0, 2, 0, 0, 1023);
//VPRO::DIM3::PROCESSING::or_(L1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_ADDR(0, 0, 0, 1), 0, 0, 1023, false, true, false);
//vpro_sync(); // dma_wait_to_finish(0xffffffff);
//dma_l2e_2d(0x1, 0x1, 0x30000000, 0x0, 8192, 1, 1);
//vpro_sync(); // dma_wait_to_finish(0xffffffff);
//VPRO::DIM3::PROCESSING::add(L0, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(0), 0, 0, 1023, true, false, false);
//VPRO::DIM3::LOADSTORE::store(0, 0, 0, 0, 2, 0, 0, 1023, L0);
//VPRO::DIM3::PROCESSING::shift_ar(L0, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(16), 0, 0, 1023, true, false, false);
//VPRO::DIM3::LOADSTORE::store(0, 1, 0, 0, 2, 0, 0, 1023, L0);
//VPRO::DIM3::PROCESSING::add(L1, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(0), 0, 0, 1023, true, false, false);
//VPRO::DIM3::LOADSTORE::store(2048, 0, 0, 0, 2, 0, 0, 1023, L1);
//VPRO::DIM3::PROCESSING::shift_ar(L1, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(16), 0, 0, 1023, true, false, false);
//VPRO::DIM3::LOADSTORE::store(2048, 1, 0, 0, 2, 0, 0, 1023, L1);
//vpro_sync(); // dma_wait_to_finish(0xffffffff);
//dma_l2e_2d(0x1, 0x1, 0x30004000, 0x0, 2048, 1, 1);
//dma_l2e_2d(0x1, 0x1, 0x30005000, 0x800, 2048, 1, 1);
    vpro_sync(); // dma_wait_to_finish(0xffffffff);
    dcma_flush();

// IO Invalids
    vpro_set_mac_init_source(static_cast<VPRO::MAC_INIT_SOURCE>(7));
    vpro_set_mac_reset_mode(static_cast<VPRO::MAC_RESET_MODE>(7));
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::NONE);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::NEVER);
    VPRO::DIM3::PROCESSING::mach(L0_1, DST_ADDR(0, 1, 2, 4), SRC_ADDR(0, 1, 2, 4), SRC_ADDR(0, 1, 2, 4), 1, 1, 1);  // TODO: LS + SRC2; SRC_IMM_3D(0, SRC_SEL_LS)
    VPRO::DIM3::PROCESSING::nop(L0_1, 10);
// IO Busy reads
    dma_wait_to_finish(0xffffffff);
    vpro_wait_busy(0xffffffff, 0xffffffff);
// No Mask active
    vpro_set_unit_mask(0);
    vpro_set_cluster_mask(0);
    VPRO::DIM3::PROCESSING::nop(L0_1, 10);
    dma_wait_to_finish(0x1);
    vpro_wait_busy(0x1);
    [[maybe_unused]] volatile int tmp;
    VPRO_BUSY_MASK_CL = 0xffffffff;
    tmp = VPRO_BUSY_MASK_CL;
    VPRO_BUSY_MASKED_DMA = 0xffffffff;
    tmp = VPRO_BUSY_MASKED_DMA;
    VPRO_BUSY_MASKED_VPRO = 0xffffffff;
    tmp = VPRO_BUSY_MASKED_VPRO;
    tmp = VPRO_LANE_SYNC;
    tmp = VPRO_DMA_SYNC;
    tmp = VPRO_SYNC;
    tmp = IDMA_STATUS_BUSY;
    tmp = VPRO_UNIT_MASK;
    tmp = VPRO_CLUSTER_MASK;
    vpro_lane_sync();
    vpro_dma_sync();
    vpro_sync();
// unit not active
    vpro_set_cluster_mask(0xffffffff);
    vpro_set_unit_mask(0);
    VPRO::DIM3::PROCESSING::nop(L0_1, 100);
    dma_wait_to_finish(0xffffffff);
    vpro_wait_busy(0xffffffff, 0xffffffff);
    for (uint i = 0; i < 8192; i++) {
        tmp = *((volatile int *) (intptr_t) (0xFFFE0000 + i * 4));
    }
    tmp = *((volatile int *) (VPRO_BUSY_MASK_CL_ADDR + 0x100));
    tmp = *((volatile int *) (VPRO_BUSY_MASK_CL_ADDR + 0x000));
    tmp = *((volatile int *) (VPRO_BUSY_BASE_ADDR + 0x100));
    tmp = *((volatile int *) (VPRO_BUSY_BASE_ADDR + 0x000));

    vpro_set_cluster_mask(0xffffffff);
    vpro_set_unit_mask(0xffffffff);
}

#endif //SIMPLE_PATARA_COVERAGE_PATARA_BASE_H
