//
// Created by gesper on 09.09.20.
//

#include "test_defines.h"

#include <stdint.h>
#include <inttypes.h>

#include "signature_dump.h"




inline void __attribute__((always_inline)) loadTestDataLM(int cluster, int16_t *data, int size, int offset = 0, int unit = 0){
    dma_e2l_1d(1 << cluster, 1 << unit, uint64_t(intptr_t(data)), offset, size);
}


void vpro_set_rf_increment_values(){
    for (int i = 0; i < 64; ++i) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(i, 1, 8),
               SRC2_IMM_2D(i), SRC2_IMM_2D(0), 0, 0);
    }
//        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(63, 1, 8),
//                                        SRC2_IMM_2D(63), SRC2_IMM_2D(0), 0, 0);
}

void dma_loc_to_ext(bool overwrite_to_use_single_transfers = false){
    if (!overwrite_to_use_single_transfers) {
        dma_l2e_1d(0b1, 0b1, uint64_t(intptr_t(result_array)), 128, NUM_TEST_ENTRIES);
    } else {
        for(int i = 0 ; i < 64 ; ++i){
            dma_l2e_1d(0b1, 0b1, uint64_t(intptr_t(&(result_array[i]))), 128 + i, 1);
        }
    }
}

void dma_reset_lm(){
    dma_e2l_1d(0xff, 0xff, uint64_t(intptr_t(result_array_zeros)), 128, NUM_TEST_ENTRIES);
    vpro_wait_busy(0xffffffff, 0xffffffff);
}

void vpro_test_load_src1_op_src2_store(uint32_t opclass, uint32_t opcode) {

    // DMA load 1 to 0 [+64]
    loadTestDataLM(0, const_cast<int16_t *>(test_array_1), NUM_TEST_ENTRIES);
    // DMA load 2 to 512 [+64]
    loadTestDataLM(0, const_cast<int16_t *>(test_array_2), NUM_TEST_ENTRIES, 512);
    dma_wait_to_finish(0xffffffff);
    // aux_print_debugfifo(SIGNAL_DONE | 0x00000001);

    if (opclass == CLASS_TRANSFER) {
        //LD (from: 512, size: 64, to: 512)
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(512), 7, 7);
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(512, 1, 8),
               SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);
        //LD (from: 0, size: 64, to: 0)
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
    } else {
        //LD (from: 512, size: 64, to: 512)
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(512), 7, 7);
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(512, 1, 8),
               SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);

        //LD (from: 0, size: 64, to: 0)
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
    }

    //XOR (from: 0 & 512, size: 64, to: 128)
    if (opclass == CLASS_ALU && opcode == OPCODE_ADD) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_SUB) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SUB, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MULL) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULL, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MULH) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULH, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACL) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACL, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACH) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACH, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACL_PRE) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACL_PRE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACH_PRE) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACH_PRE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_XOR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_XOR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_XNOR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_XNOR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_AND) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_AND, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_NAND) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_NAND, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_OR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_OR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_NOR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_NOR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_SHIFT_LR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_LR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_SHIFT_AR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_MIN) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MIN, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_MAX) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MAX, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_ABS) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ABS, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    }
        // these require flags
    else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_ZE) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_ZE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_NZ) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_NZ, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_MI) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_MI, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_PL) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_PL, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULL_NEG) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULL_NEG, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULL_POS) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULL_POS, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULH_NEG) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULH_NEG, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULH_POS) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULH_POS, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_SHIFT_AR_NEG) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR_NEG, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_SHIFT_AR_POS) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR_POS, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_ADDR(512, 1, 8), 7, 7);
    } else {
        aux_print_debugfifo(0xdeadaabb);
    }

    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
           SRC1_ADDR(128, 1, 8), SRC2_IMM_2D(0), 7, 7);
    //ST (from: 128, size: 64, to: 128)
    VPRO::DIM2::LOADSTORE::store(0,
                                 128, 1, 8,
                                 7, 7,
                                 L0);
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
//           SRC1_CHAINING_2D(0), SRC2_IMM_2D(0), 7, 7);

    vpro_wait_busy(0xffffffff, 0xffffffff);

    // DMA store from 128 to result [+64]
    dma_loc_to_ext();
//    dma_l2e_1d(0b1, 0b1, uint64_t(intptr_t(result_array)), 128, NUM_TEST_ENTRIES);
    dma_wait_to_finish(0xffffffff);
}
void vpro_test_load_src1_op_src2_store(uint32_t func) {
	uint32_t opclass = (func >> 4) & 0b11;
	uint32_t opcode = func & 0b1111;
	vpro_test_load_src1_op_src2_store(opclass, opcode);
}

void vpro_test_load_src1_op_imm_store(uint32_t opclass, uint32_t opcode) {

    // DMA load 1 to 0 [+64]
    loadTestDataLM(0, const_cast<int16_t *>(test_array_1), NUM_TEST_ENTRIES);
    dma_wait_to_finish(0xffffffff);
    // aux_print_debugfifo(SIGNAL_DONE | 0x00000001);

    if (opclass == CLASS_TRANSFER) {
        //LD (from: 0, size: 64, to: 0)
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
    } else {
        //LD (from: 0, size: 64, to: 0)
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
    }

    //XOR (from: 0 & 512, size: 64, to: 128)
    if (opclass == CLASS_ALU && opcode == OPCODE_ADD) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_SUB) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SUB, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MULL) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULL, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MULH) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULH, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACL) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACL, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACH) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACH, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACL_PRE) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACL_PRE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_MACH_PRE) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MACH_PRE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_XOR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_XOR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_XNOR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_XNOR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_AND) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_AND, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_NAND) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_NAND, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_OR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_OR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_ALU && opcode == OPCODE_NOR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_NOR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_SHIFT_LR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_LR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_SHIFT_AR) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_MIN) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MIN, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_MAX) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MAX, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_SPECIAL && opcode == OPCODE_ABS) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ABS, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    }
        // these require flags
    else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_ZE) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_ZE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_NZ) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_NZ, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_MI) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_MI, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MV_PL) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MV_PL, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULL_NEG) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULL_NEG, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULL_POS) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULL_POS, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULH_NEG) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULH_NEG, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else if (opclass == CLASS_TRANSFER && opcode == OPCODE_MULH_POS) {
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULH_POS, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_LS_2D, SRC2_IMM_2D(0x1234), 7, 7);
    } else
        aux_print_debugfifo(0xdead1234);

    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
           SRC1_ADDR(128, 1, 8), SRC2_IMM_2D(0), 7, 7);
    //ST (from: 128, size: 64, to: 128)
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
//           SRC1_CHAINING_2D(0), SRC2_IMM_2D(0), 7, 7);
    VPRO::DIM2::LOADSTORE::store(0,
                                 128, 1, 8,
                                 7, 7,
                                 L0);

    vpro_wait_busy(0xffffffff, 0xffffffff);

    // DMA store from 128 to result [+64]
    dma_loc_to_ext();
//    dma_l2e_1d(0b1, 0b1, uint64_t(intptr_t(result_array)), 128, NUM_TEST_ENTRIES);
    dma_wait_to_finish(0xffffffff);
}
void vpro_test_load_src1_op_imm_store(uint32_t func) {
	uint32_t opclass = (func >> 4) & 0b11;
	uint32_t opcode = func & 0b1111;
	vpro_test_load_src1_op_imm_store(opclass, opcode);
}

