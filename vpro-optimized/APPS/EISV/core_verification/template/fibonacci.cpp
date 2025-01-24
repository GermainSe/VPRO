/*
 *
 * Copyright (c) 2005-2020 Imperas Software Ltd., www.imperas.com
 *
 * The contents of this file are provided under the Software License
 * Agreement that you accepted before downloading this file.
 *
 * This source forms part of the Software and can be used for educational,
 * training, and demonstration purposes but cannot be used for derivative
 * works except in cases where the derivative works require OVP technology
 * to run.
 *
 * For open source models released under licenses that you can use for
 * derivative works, please visit www.OVPworld.org or www.imperas.com
 * for the location of the open source models.
 *
 */

#include <stdio.h>
#include <stdlib.h>

#include "eisv.h"
// .nobss = uninitialized! (speed up sim), .vpro sections the risc access with dma (uninitialized as well)

/*
#define IGNORE_PRINTF
#ifdef IGNORE_PRINTF
#define printf(fmt, ...) (0)
#endif
*/

//#include <vpro.h>
//#include <vpro/vpro_asm.h>
//#include <vpro/dma_asm.h>
//#include <vpro/dma_cmd_struct.h>

static int fib(int i) {
    return (i > 1) ? fib(i - 1) + fib(i - 2) : i;
}

//using namespace VPRO_RISC_EXT_VPRO;
//using namespace VPRO_RISC_EXT_DMA;
//
//int16_t input[256];

int main() {
    aux_reset_all_stats();

    int i;
    int num = 8;

    printf("starting fib(%d)...\n", num);

    for (i = 0; i < num; i++) {
        printf("fib(%d) = %d\n", i, fib(i));
        // aux_print_debugfifo(fib(i));
    }

    printf("finishing...\n");

/**
 *  GPR Test
 */
//    printf("-GPR-\n");
//    for (int i = 14; i < 64; i++) {
//        GPR::write32(i*4, 0);
//    }
//    for (int i = 0; i < 64; i++) {
//        printf("GPR[%d] = 0x%08lx\n", i*4, GPR::read32(i*4));
//    }
//    printf("-----\n");
//    for (int i = 0; i < 64; i++) {
//        GPR::write32(i*4, i);
//        printf("GPR[%d] written\n", i*4);
//    }
//    printf("-----\n");
//    for (int i = 0; i < 64; i++) {
//        printf("GPR[%d] = 0x%08lx\n", i*4, GPR::read32(i*4));
//    }
//    printf("-----\n");


/**
 *  Signature Dump Test
 */
//    printf("sig:\n");
//#define SIGNAUTRE_DUMP_ADDR 0xffffffc4
//#define SIGNAUTRE_DUMP (*((volatile uint32_t*) (SIGNAUTRE_DUMP_ADDR)))
//    for(i=0; i<num; i++) {
//        SIGNAUTRE_DUMP = uint32_t(i);
//        SIGNAUTRE_DUMP = fib(i);
//    }
//    printf("sig!\n");


/**
 *  VPRO Issue Test
 */
//    for (int16_t j = 0; j < 256; ++j) {
//        input[j] = j;
//    }
//    // set all to 0
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::ext_addr, DMA_PARAMETER_INDIZES::int_addr, NoTrigger>(0, 0);
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::y_size, DMA_PARAMETER_INDIZES::type, NoTrigger>(0, 0);
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::x_size, DMA_PARAMETER_INDIZES::x_stride, NoTrigger>(0, 0);
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::cluster, DMA_PARAMETER_INDIZES::broadcast_mask, NoTrigger>(0, 0);
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::pad_flags, DMA_PARAMETER_INDIZES::nowhere, NoTrigger>(0, 0);
//
//    // transfer init array to LM 0
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::ext_addr, DMA_PARAMETER_INDIZES::int_addr, NoTrigger>(intptr_t(input),
//                                                                                             LM_BASE_VU(0) + 0);
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::y_size, DMA_PARAMETER_INDIZES::x_stride, NoTrigger>(1, 1);
//    c_dma_lw<0, DMA_PARAMETER_INDIZES::x_size, DMA_PARAMETER_INDIZES::type, Trigger>(256, COMMAND_DMA::DMA_DIRECTION::e2l1D);
//
//
//    // set all to 0
//    c_vpro_li<0, 0b1111111111111, NoTrigger>(0);
//
//    // to VPRO[0]: 0...8 <= add (0..8) + 0x123
//    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0_1, FUNC_ADD);
//    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::nowhere, NoTrigger>(0b001, 0);
//    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::src1_all, VPRO_PARAMETER_INDIZES::src2_all, NoTrigger>(
//            SRC1_ADDR(0, 1, 3, 0),SRC2_IMM_3D(0x123));
//    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::x_y_z_end, Trigger>(
//            DST_ADDR(0, 1, 3, 0), (2<<(10+6)) | (2<<(10)) | (0));
//
//    c_vpro_trigger<0>();
//    c_vpro_trigger<0>();


/**
 *  Simulation RAM Dump Test
 */
    // using block ram's dump feature
//    *((volatile uint32_t *)(0x11000000)) = 0xaffedead;
//    *((volatile uint32_t *)(0x11000004)) = 0xcafedada;
//
//    *((volatile uint32_t *)(0x3ffffff8)) = 0x11000000;
//    *((volatile uint32_t *)(0x3ffffffc)) = 8;

    aux_print_statistics();
    aux_print_debugfifo(0xcafeaffe);
    return 0;
}
