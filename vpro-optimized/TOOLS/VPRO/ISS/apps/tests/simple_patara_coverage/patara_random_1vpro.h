//
// Created by gesper on 15.04.24.
//

#ifndef SIMPLE_PATARA_COVERAGE_PATARA_RANDOM_1VPRO_H
#define SIMPLE_PATARA_COVERAGE_PATARA_RANDOM_1VPRO_H

#include <vpro.h>

static void vpro_random_1(){
    dcma_flush();
    dcma_reset();
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::NONE);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::Z_INCREMENT);
    vpro_mac_h_bit_shift(17);
    vpro_mul_h_bit_shift(20);
    dma_e2l_2d(0x1, 0x1, 0x10000000, 0x0, 8192, 1, 1);
    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);
    VPRO::DIM3::LOADSTORE::loads(2222, 0, 0, 0, 2, 0, 0, 1023);
    VPRO::DIM3::PROCESSING::mull(L0_1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_IMM_3D(65536), 0, 0, 1023);
    VPRO::DIM3::LOADSTORE::load(2222, 1, 0, 0, 2, 0, 0, 1023);
    VPRO::DIM3::PROCESSING::or_(L0_1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_ADDR(0, 0, 0, 1), 0, 0, 1023, false, true, false);
    VPRO::DIM3::LOADSTORE::loads(4444, 0, 0, 0, 2, 0, 0, 1023);
    VPRO::DIM3::PROCESSING::mull(L1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_IMM_3D(65536), 0, 0, 1023);
    VPRO::DIM3::LOADSTORE::load(4444, 1, 0, 0, 2, 0, 0, 1023);
    VPRO::DIM3::PROCESSING::or_(L1, SRC_ADDR(0, 0, 0, 1), SRC_LS_3D, SRC_ADDR(0, 0, 0, 1), 0, 0, 1023, false, true, false);
    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);
    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);
    VPRO::DIM3::PROCESSING::and_(L0_1, SRC_ADDR(100, 35, 11, 2), SRC_ADDR(378, 13, 8, 23), SRC_ADDR(594, 9, 5, 6), 1, 13, 22, false, true, false);
    VPRO::DIM3::PROCESSING::mull(L0, SRC_ADDR(183, 25, 36, 2), SRC_IMM_3D(2398121), SRC_ADDR(399, 19, 46, 5), 0, 3, 88);
    VPRO::DIM3::PROCESSING::macl(L1, SRC_ADDR(132, 1, 2, 0), SRC_ADDR(7, 2, 0, 0), SRC_ADDR(459, 0, 2, 0), 0, 0, 838, false, true, false);
    VPRO::DIM3::PROCESSING::xnor(L0, SRC_ADDR(299, 5, 18, 18), SRC_ADDR(715, 4, 15, 15), SRC_ADDR(450, 8, 25, 12), 58, 0, 3, true, false, false);
    VPRO::DIM3::PROCESSING::add(L1, SRC_ADDR(80, 18, 5, 31), SRC_CHAINING_NEIGHBOR_LANE, SRC_ADDR(62, 52, 27, 10), 8, 1, 0);
    VPRO::DIM3::PROCESSING::mull_neg(L1, SRC_ADDR(87, 4, 15, 3), SRC_ADDR(344, 3, 18, 4), SRC_ADDR(86, 2, 16, 0), 1, 0, 133, true, false, false);
    VPRO::DIM3::LOADSTORE::store(489, 146, 16, 32, 18, 0, 12, 42, L0);
    VPRO::DIM3::PROCESSING::add(L0, SRC_ADDR(252, 38, 19, 2), SRC_CHAINING_NEIGHBOR_LANE, SRC_ADDR(750, 17, 21, 1), 0, 0, 267);
    VPRO::DIM3::PROCESSING::mull_neg(L0, SRC_ADDR(506, 15, 5, 3), SRC_ADDR(56, 20, 10, 9), SRC_IMM_3D(266090712), 10, 0, 30, true, false, false);
    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);
    dma_l2e_2d(0x1, 0x1, 0x30000000, 0x0, 8192, 1, 1);
    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);
    VPRO::DIM3::PROCESSING::add(L0, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(0), 0, 0, 1023, true, false, false);
    VPRO::DIM3::LOADSTORE::store(0, 0, 0, 0, 2, 0, 0, 1023, L0);
    VPRO::DIM3::PROCESSING::shift_ar(L0, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(16), 0, 0, 1023, true, false, false);
    VPRO::DIM3::LOADSTORE::store(0, 1, 0, 0, 2, 0, 0, 1023, L0);
    VPRO::DIM3::PROCESSING::add(L1, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(0), 0, 0, 1023, true, false, false);
    VPRO::DIM3::LOADSTORE::store(2048, 0, 0, 0, 2, 0, 0, 1023, L1);
    VPRO::DIM3::PROCESSING::shift_ar(L1, SRC_ADDR(0, 0, 0, 1), SRC_ADDR(0, 0, 0, 1), SRC_IMM_3D(16), 0, 0, 1023, true, false, false);
    VPRO::DIM3::LOADSTORE::store(2048, 1, 0, 0, 2, 0, 0, 1023, L1);
    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);
    dma_l2e_2d(0x1, 0x1, 0x30004000, 0x0, 2048, 1, 1);
    dma_l2e_2d(0x1, 0x1, 0x30005000, 0x800, 2048, 1, 1);

    vpro_sync(); // dma_wait_to_finish(0xffffffff);


    VPRO::DIM3::PROCESSING::nop(L0_1, DST_ADDR(1,0,0,0), SRC_IMM_3D(0), SRC_IMM_3D(0), 0, 0, 150);
    VPRO::DIM3::PROCESSING::add(L1, DST_ADDR(0,0,0,0), SRC_IMM_3D(0), SRC_IMM_3D(0), 0, 0, 3, true);    // chain data in x cycles...
    __vpro(LS, BLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
           SRC_CHAINING_3D(1),
           SRC1_ADDR(0, 0, 0, 0),
           SRC2_IMM_3D(0),
           0, 0, 0);
    VPRO::DIM3::PROCESSING::nop(L0, DST_ADDR(1,0,0,0), SRC_IMM_3D(0), SRC_IMM_3D(0), 0, 0, 1);
    __vpro(LS, BLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
           SRC_CHAINING_3D(1),
           SRC1_ADDR(0, 0, 0, 0),
           SRC2_IMM_3D(1),
           0, 0, 0);
    __vpro(LS, BLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
           SRC_CHAINING_3D(1),
           SRC1_ADDR(0, 0, 0, 0),
           SRC2_IMM_3D(2),
           0, 0, 0);
    __vpro(LS, BLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
           SRC_CHAINING_3D(1),
           SRC1_ADDR(0, 0, 0, 0),
           SRC2_IMM_3D(3),
           0, 0, 0);



    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);
    dcma_flush();
}

#endif  //SIMPLE_PATARA_COVERAGE_PATARA_RANDOM_1VPRO_H
