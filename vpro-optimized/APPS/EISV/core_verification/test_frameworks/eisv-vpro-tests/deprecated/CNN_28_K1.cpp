#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "test_defines.h"
#include "vpro_test_functions.h"

// .nobss = uninitialized! (speed up sim), .vpro sections the risc access with dma (uninitialized as well)
volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) result_array[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_zeros[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_large[1024 * 1024];



// no initialization data for those region!
int16_t kernel[] __attribute__ ((section (".vpro"))) = {1, 2, 1, 2, 4, 2, 1, 2, 1};
int16_t kernel2[] __attribute__ ((section (".vpro"))) = {2, 4, 2, 4, 8, 4, 2, 4, 2};
int16_t bias[] __attribute__ ((section (".vpro"))) = {10};
int16_t bias2[] __attribute__ ((section (".vpro"))) = {20};

int main(int argc, char *argv[]) {
    INIT();
    printf("Start\n");
    int16_t count = 0;

    // reset result array
    for (volatile int16_t &i : result_array){
        i = 0xdead;
        if (++count > NUM_TEST_ENTRIES) break;
    }
    (count = 0);
    // input data generation
    for (volatile int16_t &i : test_array_1){
        i = count;
        count = (abs(count)+1)*(-1);
    }
    count = NUM_TEST_ENTRIES - 1;
    for (volatile int16_t &i : test_array_2){
        i = count;
        count--;
    }
    // set LM to 0 value

    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(result_array_zeros[0]))), 128, NUM_TEST_ENTRIES);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(result_array_zeros[0]))), 0, NUM_TEST_ENTRIES);
    // set whole RF to dead / error value
    __vpro(L0_1, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 32),
           SRC2_IMM_2D(0), SRC2_IMM_2D(0xdead), 31, 31);
    // reset shift registers
#if BITWIDTH_REDUCE_TO_16_BIT == 1
    vpro_mac_h_bit_shift(16);
    vpro_mul_h_bit_shift(16);
#else
    vpro_mac_h_bit_shift(24);
    vpro_mul_h_bit_shift(24);
#endif
    vpro_wait_busy(0xffffffff, 0xffffffff);
    dma_wait_to_finish(0xffffffff);

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    // execute test

    kernel[0] =   623;          // 0
    kernel[1] =   555;          // 1
    kernel[2] =   -51;          // 2
    kernel[3] =   -59;          // 0 + in_w (30/9)  = 30
    kernel[4] =    52;          // 1 + in_w (30/9)  = 31
    kernel[5] =  5599;          // 2 + in_w (30/9)  = 32
    kernel[6] = -8711;          // 0 + 2*in_w (30/9)  = 60
    kernel[7] =  -125;          // 1 + 2*in_w (30/9)  = 61
    kernel[8] = -2117;          // 2 + 2*in_w (30/9)  = 62
//    kernel[0] = 1;
//    kernel[1] = 0;
//    kernel[2] = 0;
//    kernel[3] = 0;
//    kernel[4] = 0;
//    kernel[5] = 0;
//    kernel[6] = 0;
//    kernel[7] = 0;
//    kernel[8] = 0;
    bias[0] = 10;
    kernel2[0] = 2;
    kernel2[1] = 4;
    kernel2[2] = 2;
    kernel2[3] = 4;
    kernel2[4] = 8;
    kernel2[5] = 4;
    kernel2[6] = 2;
    kernel2[7] = 4;
    kernel2[8] = 2;
    bias2[0] = 20;

    int kernel_x, kernel_y;
    int seg_out_h, seg_out_w;
    kernel_x = 1, kernel_y = 1;
    seg_out_h = 28, seg_out_w = 28;

    int kernel_load_shift_right = 1;
    int conv_result_shift_right = 3;
    int bias_shift_right = -1;
    int store_shift_right = 1;

    int buffer = 0; // LM Base input
    int out_buffer = 2048; // LM Base output
    int out_buffer2 = 2048+1024; // LM Base output

    constexpr int RF_KERNEL_BASE = 1015;
    constexpr int RF_BIAS_BASE = 1014;
    constexpr int RF_KERNEL_BASE2 = 1015-10;
    constexpr int RF_BIAS_BASE2 = 1014-10;

    // set LM to 0
    for (int i = 0; i < 1024 / NUM_TEST_ENTRIES; ++i) {
        dma_ext1D_to_loc1D(0, uint64_t(intptr_t(&(result_array_zeros[0]))),
                           LM_BASE_VU(0) + i * NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
    }
    dma_wait_to_finish(0xffffffff);
    aux_clr_sys_time();
    aux_clr_cycle_cnt();

    // set LM to contain OPA + OPB
    dma_ext1D_to_loc1D(0, uint64_t(intptr_t(&(test_array_1[0]))), LM_BASE_VU(0) + 0, NUM_TEST_ENTRIES);
    dma_ext1D_to_loc1D(0, uint64_t(intptr_t(&(test_array_2[0]))), LM_BASE_VU(0) + NUM_TEST_ENTRIES,
                       NUM_TEST_ENTRIES);

    // set LM to contain kernel 3x3
    // set LM to contain bias
    dma_ext1D_to_loc1D(0, uint64_t(intptr_t(&(kernel[0]))), LM_BASE_VU(0) + RF_KERNEL_BASE, 9);
    dma_ext1D_to_loc1D(0, uint64_t(intptr_t(&(bias[0]))), LM_BASE_VU(0) + RF_BIAS_BASE, 1);
    dma_ext1D_to_loc1D(0, uint64_t(intptr_t(&(kernel2[0]))), LM_BASE_VU(0) + RF_KERNEL_BASE2, 9);
    dma_ext1D_to_loc1D(0, uint64_t(intptr_t(&(bias2[0]))), LM_BASE_VU(0) + RF_BIAS_BASE2, 1);

    dma_wait_to_finish(0xffffffff);
    int seg_in_h, seg_in_w;
    seg_in_h = seg_out_h + (kernel_x - 1), seg_in_w = seg_out_w + (kernel_x - 1);
    vpro_mac_h_bit_shift(conv_result_shift_right);
    vpro_mul_h_bit_shift(conv_result_shift_right);

    /**
     *  to both (1)
     */
    // LOAD KERNEL
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
           DST_ADDR(0, 0, 0),
           SRC1_ADDR(0, 1, kernel_y),
           SRC2_IMM_2D(RF_KERNEL_BASE2),
           kernel_x - 1, kernel_y - 1);
    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(RF_KERNEL_BASE, 1, kernel_y),
           SRC1_LS_2D,
           SRC2_IMM_2D(kernel_load_shift_right),
           kernel_x - 1,
           kernel_y - 1);
//    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//           DST_ADDR(962, 0, 0),
//           SRC1_ADDR(962, 0, 0),
//           SRC2_IMM_2D(0),
//           4, 0);

    // LOAD BIAS
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
           DST_ADDR(0, 0, 0),
           SRC1_ADDR(0, 0, 0),
           SRC2_IMM_2D(RF_BIAS_BASE2),
           0, 0);

    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_MULL, NO_FLAG_UPDATE,
           DST_ADDR(RF_BIAS_BASE, 0, 0),
           SRC1_IMM_2D(1u << (-bias_shift_right)),
           SRC2_LS_2D,
           0,
           0);
//    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//           DST_ADDR(962, 0, 0),
//           SRC1_ADDR(962, 0, 0),
//           SRC2_IMM_2D(0),
//           4, 0);

    /**
     *  to L0 (0)
     */
    // LOAD KERNEL
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
           DST_ADDR(0, 0, 0),
           SRC1_ADDR(0, 1, kernel_y),
           SRC2_IMM_2D(RF_KERNEL_BASE),
           kernel_x - 1, kernel_y - 1);
    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(RF_KERNEL_BASE, 1, kernel_y),
           SRC1_LS_2D,
           SRC2_IMM_2D(kernel_load_shift_right),
           kernel_x - 1,
           kernel_y - 1);
//    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//           DST_ADDR(962, 0, 0),
//           SRC1_ADDR(962, 0, 0),
//           SRC2_IMM_2D(0),
//           4, 0);

    // LOAD BIAS
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
           DST_ADDR(0, 0, 0),
           SRC1_ADDR(0, 0, 0),
           SRC2_IMM_2D(RF_BIAS_BASE),
           0, 0);

    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULL, NO_FLAG_UPDATE,
           DST_ADDR(RF_BIAS_BASE, 0, 0),
           SRC1_IMM_2D(1u << (-bias_shift_right)),
           SRC2_LS_2D,
           0,
           0);
//    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//           DST_ADDR(962, 0, 0),
//           SRC1_ADDR(962, 0, 0),
//           SRC2_IMM_2D(0),
//           4, 0);

    // CONV (+bias)
    if (kernel_x == 3 && kernel_y == 3){
        for (uint32_t y = 0; y < seg_out_h; y += 1) {
            vpro_loop_start(0, seg_out_w - 1, 1);  // x
            {
                auto offset = buffer + y * seg_in_w;
                vpro_loop_mask(0b01, 0b00, 0b01);
#ifdef SIMULATION
                __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
                                                DST_ADDR(0, 0, 0),
                                                SRC1_ADDR(0, 1, seg_in_w),
                                                SRC2_IMM_2D(offset),
                                                2, 2);
                vpro_loop_mask(0b00, 0b00, 0b01);
                __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_MACH_PRE, NO_FLAG_UPDATE,
                                                DST_ADDR(y * seg_out_w, 0, 0),
                                                SRC1_ADDR(RF_BIAS_BASE, 0, 0),
                                                SRC2_IMM_2D((1u << conv_result_shift_right)),
                                                0, 0);

                __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_MACH, FLAG_UPDATE,
                                                DST_ADDR(y * seg_out_w, 0, 0),
                                                SRC1_LS_2D,
                                                SRC2_ADDR(RF_KERNEL_BASE, 1, 3),
                                                2, 2);
#else
                VPRO_CMD_REGISTER_SRC1BETA_SRC2IMM = ((seg_in_w << 20u) | offset);
                __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
                                                DST_ADDR(0, 0, 0),
                                                SRC1_ADDR(0, 1, 0),
                                                SRC2_IMM_2D(0),
                                                2, 2);
                vpro_loop_mask(0b00, 0b00, 0b01);
                VPRO_CMD_REGISTER_DSTOFFSET_SRC2IMM = ((y * seg_out_w << 20u) |
                                                       (1u << conv_result_shift_right));
                __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_MACH_PRE, NO_FLAG_UPDATE,
                                                DST_ADDR(0, 0, 0),
                                                SRC1_ADDR(RF_BIAS_BASE, 0, 0),
                                                SRC2_IMM_2D(0),
                                                0, 0);

                VPRO_CMD_REGISTER_DSTOFFSET = y * seg_out_w;
                __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_MACH, FLAG_UPDATE,
                                                DST_ADDR(0, 0, 0),
                                                SRC1_LS_2D,
                                                SRC2_ADDR(RF_KERNEL_BASE, 1, 3),
                                                2, 2);
#endif
            }
            vpro_loop_end();
        }
    } else {
        assert(seg_out_w - 1 <= MAX_X_END);
        assert(seg_out_h - 1 <= MAX_Y_END);
        assert(seg_in_w <= MAX_BETA);
        assert(seg_out_w <= MAX_BETA);
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
               DST_ADDR(0, 0, 0),
               SRC1_ADDR(0, 1, seg_in_w),
               SRC2_IMM_2D(buffer),
               seg_out_w - 1, seg_out_h - 1);
        // mul
        __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_MULH, NO_FLAG_UPDATE,
               DST_ADDR(0, 1, seg_out_w),
               SRC1_LS_2D,
               SRC2_ADDR(RF_KERNEL_BASE, 0, 0),
               seg_out_w - 1, seg_out_h - 1);

        // add bias
        __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
               DST_ADDR(0, 1, seg_out_w),
               SRC1_ADDR(0, 1, seg_out_w),
               SRC2_ADDR(RF_BIAS_BASE, 0, 0),
               seg_out_w - 1, seg_out_h - 1);
    }

    // STORE L0
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, seg_out_w),
           SRC1_ADDR(0, 1, seg_out_w),
           SRC2_IMM_2D(store_shift_right),
           seg_out_w - 1,
           seg_out_h - 1);
    VPRO::DIM2::LOADSTORE::store(out_buffer,
                                 0, 1, seg_out_w,
                                 seg_out_w - 1, seg_out_h - 1,
                                 L0);
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
//           DST_ADDR(0, 1, seg_out_w),
//           SRC1_CHAINING_2D(0),
//           SRC2_IMM_2D(out_buffer),
//           seg_out_w - 1,
//           seg_out_h - 1);

    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE,
           DST_ADDR(0, 1, seg_out_w),
           SRC1_ADDR(0, 1, seg_out_w),
           SRC2_IMM_2D(store_shift_right),
           seg_out_w - 1,
           seg_out_h - 1);
    VPRO::DIM2::LOADSTORE::store(out_buffer2,
                                 0, 1, seg_out_w,
                                 seg_out_w - 1, seg_out_h - 1,
                                 L1);
//    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
//           DST_ADDR(0, 1, seg_out_w),
//           SRC1_CHAINING_2D(1),
//           SRC2_IMM_2D(out_buffer2),
//           seg_out_w - 1,
//           seg_out_h - 1);
    vpro_wait_busy(0xffffffff, 0xffffffff);

    dma_loc1D_to_ext1D(0, uint64_t(intptr_t(&(result_array[0]))), LM_BASE_VU(0) + out_buffer,
                       seg_out_w*seg_out_h);
    assert (seg_out_w*seg_out_h+180 <= 1024);   // avoid overflow of result_array (size: 1024)
    dma_loc1D_to_ext1D(0, uint64_t(intptr_t(&(result_array[180]))), LM_BASE_VU(0) + out_buffer2,
                       seg_out_w*seg_out_h);

    dma_wait_to_finish(0xffffffff);

    // DCMA
    dcma_flush();

// printf runtime (cycle counters in subsystem)
    uint64_t sys_time = aux_get_sys_time_lo();
    sys_time += (uint64_t(aux_get_sys_time_hi()) << 32);
    printf("SYS_TIME: %lu\n", sys_time);

    // verify framework: dump result
    dump(result_array, NUM_TEST_ENTRIES);

    printf("\nEnd");
    return 0;
}
