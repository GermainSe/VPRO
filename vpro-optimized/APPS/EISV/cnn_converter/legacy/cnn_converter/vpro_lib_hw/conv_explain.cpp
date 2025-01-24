//
// Created by gesper on 14.03.22.
#include "../../../../common/vpro/isa_intrinsic_aux_lib.h"
#include "../../../cnn_yolo_lite_hw/yolo_configuration.h"
#include "../../../../../TOOLS/VPRO/ISS/isa_intrinsic_lib/core_class_wrapper.h"
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/core/utility.hpp>



void explain(){

    // DMA:
    // load input data to LM
    // load kernel to LM

    // sync

    // VPRO:
    // load kernels to RFs
    // load vectorized input to conv (initalize Accumulator | add to previous out channel data)

    uint LM_INPUT_BASE = 0;
    uint RF_KERNEL_BASE = 0;

    // initialize MAC - Accumulator Register
    for (int y = 0; y < 22; ++y) {
        for (int x = 0; x < 22; ++x) {

            __vpro(LS, NONBLOCKING, IS_CHAIN,
                   FUNC_LOADS, NO_FLAG_UPDATE,
                   DST_ADDR(0, 0, 0),
                   SRC1_ADDR(x+y*22, 1, 22),
                   SRC2_IMM(LM_INPUT_BASE ),
                   2, 2);

            __vpro(L0_1, NONBLOCKING, NO_CHAIN,
                   FUNC_MACH_PRE, FLAG_UPDATE,
                   DST_ADDR(y*22+x, 0, 0),
                   SRC1_LS,
                   SRC2_ADDR(RF_KERNEL_BASE, 1, 3),
                   2, 2);
        }
    }







    // add to previous data in RF
    for (int y = 0; y < 22; ++y) {
        for (int x = 0; x < 22; ++x) {

            __vpro(LS, NONBLOCKING, IS_CHAIN,
                   FUNC_LOADS, NO_FLAG_UPDATE,
                   DST_ADDR(0, 0, 0),
                   SRC1_ADDR(x+y*22, 1, 22),
                   SRC2_IMM(LM_INPUT_BASE ),
                   2, 2);

            __vpro(L0_1, NONBLOCKING, NO_CHAIN,
                   FUNC_MACH_PRE, NO_FLAG_UPDATE,
                   DST_ADDR(x+y*22, 0, 0),
                   SRC1_ADDR(x+y*22, 0, 0),
                   SRC2_IMM(1),
                   0, 0);

            __vpro(L0_1, NONBLOCKING, NO_CHAIN,
                   FUNC_MACH, FLAG_UPDATE,
                   DST_ADDR(y*22+x, 1, 22),
                   SRC1_LS,
                   SRC2_ADDR(RF_KERNEL_BASE, 1, 3),
                   2, 2);
        }
    }











    // SIMD Version: each element contains 2 input channel data / output channel data / kernel data
    // instead 16-bit data load -> 2 x 8-bit elements

    // either load SIMD elements (previous SIMD store)
    // concat elements by loaded DMA data
    // concat elements in processing lane (RF read from two ports)
    // concat elements in LS-Lane (hardware change requires (or two cycle reading), as the LM only has one read port for the LS-Lane):

    // initialize MAC - Accumulator Register -subwords- to 0
    for (int y = 0; y < 22; ++y) {
        for (int x = 0; x < 22; ++x) {

            // element generation (data from extern already vectorized? -> kernel)
            // vectorization in DMA?

            // load of vectorized elements by LS-Lane concat
            __vpro_ls(LS, FUNC_LOADS.V2,
                                                // use of bits inside command for LS Lane
                   SRC1_ADDR(x+y*22, 1, 22),    // first
                   SRC1_BASE(LM_INPUT_BASE),

                   SRC2_ADDR(x+y*22, 1, 22),    // second
                   SRC2_BASE(LM_INPUT_BASE2),

                   2, 2);

            __vpro(L0_1, NONBLOCKING, NO_CHAIN,
                   FUNC_MACH_PRE.V2, FLAG_UPDATE,
                   DST_ADDR(y*22+x, 1, 22),
                   SRC1_LS,
                   SRC2_ADDR(RF_KERNEL_BASE, 1, 3),
                   2, 2);
        }
    }




    /**
     * regular Store of RF Data to LM
     */

    uint LM_OUTPUT_BASE = 0;

    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_ADDR(0, 1, 21),
           SRC2_IMM(3),
           21, 21);
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_CHAINING(0),
           SRC2_IMM(LM_OUTPUT_BASE),
           21,
           21);

    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_ADDR(0, 1, 21),
           SRC2_IMM(3),
           21, 21);
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_CHAINING(1),
           SRC2_IMM(LM_OUTPUT_BASE),
           21,
           21);



    /**
     * store of vectorized SIMD Data to LM
     */

    // either store SIMD elements (multiple output channels per address -> difficulties when loaded later)
    // split elements in DMA
    // split elements in processing lane (RF read)
    // split elements in LS-Lane (stored to single LM address):

    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_ADDR(0, 1, 21),
           SRC2_IMM(3),
           21, 21);
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE.V2.0, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_CHAINING(0),
           SRC2_IMM(LM_OUTPUT_BASE),
           21,
           21);

    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_ADDR(0, 1, 21),
           SRC2_IMM(3),
           21, 21);
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE.V2.1, NO_FLAG_UPDATE,
            DST_ADDR(0, 1, 22),
            SRC1_CHAINING(0),
            SRC2_IMM(LM_OUTPUT_BASE_2),
            21,
            21);

    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_ADDR(0, 1, 21),
           SRC2_IMM(3),
           21, 21);
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE.V2.0, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_CHAINING(1),
           SRC2_IMM(LM_OUTPUT_BASE),
           21,
           21);

    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_ADDR(0, 1, 21),
           SRC2_IMM(3),
           21, 21);
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE.V2.1, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, 22),
           SRC1_CHAINING(1),
           SRC2_IMM(LM_OUTPUT_BASE),
           21,
           21);

}