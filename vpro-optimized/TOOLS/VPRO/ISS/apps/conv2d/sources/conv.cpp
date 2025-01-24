
#include "conv.h"


// .nobss = uninitialized! (speed up sim), .vpro sections the risc access with dma (uninitialized as well)
int16_t __attribute__ ((section (".vpro"))) test_array_1[input.dim_x*input.dim_y];
int16_t __attribute__ ((section (".vpro"))) result_array[output.dim_x*output.dim_y];
int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];

// no initialization data for those region!
int16_t __attribute__ ((section (".vpro"))) kernel[kernel_size*kernel_size];

int calc_buffer = 0;
int load_buffer = 0;
int calc_buffer_out = 2048; // LM Base output

#if not defined(SIMULATION) && RV_EXT == 1
#include <vpro.h>
#include <vpro/vpro_asm.h>
//#include <vpro/dma_asm.h>

using namespace VPRO_RISC_EXT_VPRO;
//using namespace VPRO_RISC_EXT_DMA;
#endif

//template <int n>
//void reset_dma(){
//    c_dma_lw<n, DMA_PARAMETER_INDIZES::ext_addr, DMA_PARAMETER_INDIZES::int_addr, NoTrigger>(0, 0);
//    c_dma_lw<n, DMA_PARAMETER_INDIZES::y_size, DMA_PARAMETER_INDIZES::type, NoTrigger>(0, 0);
//    c_dma_lw<n, DMA_PARAMETER_INDIZES::x_size, DMA_PARAMETER_INDIZES::x_stride, NoTrigger>(0, 0);
//    c_dma_lw<n, DMA_PARAMETER_INDIZES::cluster, DMA_PARAMETER_INDIZES::broadcast_mask, NoTrigger>(0, 0);
//    c_dma_lw<n, DMA_PARAMETER_INDIZES::pad_flags, DMA_PARAMETER_INDIZES::nowhere, NoTrigger>(0, 0);
////    if ( n > 0 )
////        reset_dma<n - 1>();
//}
//
//void reset_all_dma(){
//    reset_dma<0>();
//    reset_dma<1>();
//    reset_dma<2>();
//    reset_dma<3>();
//    reset_dma<4>();
//    reset_dma<5>();
//    reset_dma<6>();
//    reset_dma<7>();
//}

void reset_all_vpro(){
#if not defined(SIMULATION) && RV_EXT == 1
    c_vpro_li<0, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<1, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<2, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<3, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<4, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<5, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<6, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<7, 0b1111111111111, NoTrigger>(0);
#endif
}

void vpro_ext_init(){
#if not defined(SIMULATION) && RV_EXT == 1
    if (!vpro_ext){
        printf_error("VPRO Ext is disabled - init should not get called!");
        exit(1);
    }
    reset_all_vpro();

    if (do_opt){
        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0_1, FUNC_ADD);
        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::src1_all, VPRO_PARAMETER_INDIZES::src2_all, NoTrigger>(SRC1_IMM_3D(0), SRC2_IMM_3D(0));
        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(DST_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0), (kernel_size - 1) << (10+6) | ((kernel_size - 1 )/ 2) << 10); // one line of '0'
//        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);

        // LOAD KERNEL
        uint offset_src = ((kernel_size+1)/2)*kernel_size;
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 0, 0, 0), SRC1_ADDR(offset_src, 1, kernel_size, 0));
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b100, (kernel_size - 1) << (10+6) | (((kernel_size-1)/2) - 1) << 10);
//        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer + LM_KERNEL_BASE, 0);

        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0_1, FUNC_SHIFT_AR);
        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(RF_KERNEL_BASE + 1*kernel_size, 1, kernel_size, 0), SRC1_LS_3D);
        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(kernel_load_shift_right, (kernel_size - 1) << (10+6) | (((kernel_size-1)/2) - 1) << 10);  // lower half
//        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);

        // LOAD KERNEL
        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 0, 0, 0), SRC1_ADDR(0, 1, kernel_size, 0));
        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b100, (kernel_size - 1) << (10+6) | (((kernel_size+1)/2) - 1) << 10);
//        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer + LM_KERNEL_BASE, 0);

        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0, FUNC_SHIFT_AR);
        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0), SRC1_LS_3D);
        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(kernel_load_shift_right, (kernel_size - 1) << (10+6) | (((kernel_size+1)/2) - 1) << 10);  // lower half
//        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::nowhere, NoTrigger>(0b000, 0);

        // convolution
        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 0, 0, 0), SRC1_ADDR(0, 1, segment.dim_in_x, 1));
        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b100, (kernel_size - 1) << (10+6) | (((kernel_size+1)/2)-1) << 10 | segment.dim_out_x - 1); // larger half of the kernel is loaded
//        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(offset_in, 0);

        c_vpro_lw<6, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0_1, FUNC_MACH);
        c_vpro_lw<6, VPRO_PARAMETER_INDIZES::src2_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(SRC2_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0), SRC_IMM_3D(0, SRC_SEL_LS));  // SRC2 : Imm to reset accu
        c_vpro_lw<6, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b001, (kernel_size - 1) << (10+6) | (((kernel_size+1)/2)-1) << 10 | segment.dim_out_x - 1);
//        c_vpro_lw<6, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(DST_ADDR(offset_out, 0, 0, 1), 0);

    } else {    // unoptimized
        // LOAD KERNEL
        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 0, 0, 0), SRC1_ADDR(0, 1, kernel_size, 0));
        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b100, (kernel_size - 1) << (10+6) | (kernel_size - 1) << 10);
//        c_vpro_lw<0, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer + LM_KERNEL_BASE, 0);

        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0, FUNC_SHIFT_AR);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0), SRC1_LS_3D);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(kernel_load_shift_right, (kernel_size - 1) << (10+6) | (kernel_size - 1) << 10);
//        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::nowhere, NoTrigger>(0b010, 0);

        // convolution
        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 0, 0, 0), SRC1_ADDR(0, 1, segment.dim_in_x, 1));
        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b100, (kernel_size - 1) << (10+6) | (kernel_size - 1) << 10 | segment.dim_out_x - 1);
//        c_vpro_lw<2, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(offset_in, 0);

        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0, FUNC_MACH);
        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::src2_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(SRC2_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0), SRC_IMM_3D(0, SRC_SEL_LS));  // SRC2 : Imm to reset accu
        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b001, (kernel_size - 1) << (10+6) | (kernel_size - 1) << 10 | segment.dim_out_x - 1);
//        c_vpro_lw<3, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(DST_ADDR(offset_out, 0, 0, 1), 0);

        // STORE
        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0, FUNC_SHIFT_AR);
        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 1, segment.dim_out_x, 0), SRC1_ADDR(0, 1, segment.dim_out_x, 0));
        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(store_shift_right, (segment.dim_out_x - 1) << (10+6) | (segment.dim_out_y - 1) << 10);
        c_vpro_lw<4, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::nowhere, NoTrigger>(0b100, 0);

        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_STORE);
        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 1, segment.dim_out_x, 0), SRC1_CHAINING_3D(0));
        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0, (segment.dim_out_x - 1) << (10+6) | (segment.dim_out_y - 1) << 10);
//        c_vpro_lw<5, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer_out, 0);
    }
#endif
}


void vpro_conv(){
    if (do_opt){
        // CONV
        uint32_t offset_in = calc_buffer;
        uint32_t offset_out = 0;

//    /**
//     * first lines padding (y = 0, 6 kernel elements) not multiplied on L1
//     */
//    VPRO::DIM3::LOADSTORE::loads(offset_in,
//                                 0, 1, segment.dim_in_x, 1,
//                                 kernel_size-1, ((kernel_size+1)/2)-1, segment.dim_out_x - 1);
//    VPRO::DIM3::PROCESSING::mach_init_imm(L0_1,  // shift right by 3
//                                          DST_ADDR(offset_out, 0, 0, 1),
//                                          SRC1_LS_3D,
//                                          SRC2_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0),    // 1015
//                                          kernel_size-1, ((kernel_size+1)/2)-1, segment.dim_out_x - 1,
//                                          0,
//                                          false, true);
//    offset_in += segment.dim_in_x;
//    offset_out += segment.dim_out_x;

        /**
         * (begin and) middle lines (y = 1+, 6 kernel elements)
         */
        for (size_t y = 0; y < segment.dim_out_y; ++y) {
            if (vpro_ext) {
#if not defined(SIMULATION) && RV_EXT == 1
                c_vpro_lw<5, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(offset_in, 0);
                c_vpro_lw<6, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(DST_ADDR(offset_out, 0, 0, 1), 0);
#endif
            } else {
                VPRO::DIM3::LOADSTORE::loads(offset_in,
                                             0, 1, segment.dim_in_x, 1,
                                             kernel_size-1, ((kernel_size+1)/2)-1, segment.dim_out_x - 1);    // larger half of the kernel is loaded
                VPRO::DIM3::PROCESSING::mach_init_imm(L0_1,  // shift right by 3
                                                      DST_ADDR(offset_out, 0, 0, 1),
                                                      SRC1_LS_3D,
                                                      SRC2_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0),    // 1015
                                                      kernel_size-1, ((kernel_size+1)/2)-1, segment.dim_out_x - 1,     // larger half of the kernel is used
                                                      0,
                                                      false, true);
            }
            offset_in += segment.dim_in_x;
            offset_out += segment.dim_out_x;
        }

        VPRO::DIM2::PROCESSING::shift_ar(L0,
                                         DST_ADDR(0, 1, segment.dim_out_x),
                                         SRC1_ADDR(0, 1, segment.dim_out_x),
                                         SRC2_IMM_2D(store_shift_right),
                                         segment.dim_out_x - 1,
                                         segment.dim_out_y - 1);

        /**
         * final lines padding for L1 only
         */
        for (size_t y = 0; y < (kernel_size-1)/2; ++y) {
            VPRO::DIM3::LOADSTORE::loads(offset_in,
                                         0, 1, segment.dim_in_x, 1,
                                         kernel_size-1, ((kernel_size+1)/2)-1, segment.dim_out_x - 1);
            VPRO::DIM3::PROCESSING::mach_init_imm(L1,  // shift right by 3
                                                  DST_ADDR(offset_out, 0, 0, 1),
                                                  SRC1_LS_3D,
                                                  SRC2_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0),    // 1015
                                                  kernel_size-1, ((kernel_size+1)/2)-1, segment.dim_out_x - 1,
                                                  0,
                                                  false, true);
            offset_in += segment.dim_in_x;
            offset_out += segment.dim_out_x;
        }

        /**
         * Store
         */
        constexpr uint32_t offset = ((kernel_size-1)/2) * segment.dim_out_x; // padding lines offset (odd parts)
        // Add l0 to l1 to store
        VPRO::DIM2::PROCESSING::shift_ar(L1,
                                         DST_ADDR(offset, 1, segment.dim_out_x),
                                         SRC1_ADDR(offset, 1, segment.dim_out_x),
                                         SRC2_IMM_2D(store_shift_right),
                                         segment.dim_out_x - 1,
                                         segment.dim_out_y - 1, true);

        VPRO::DIM2::PROCESSING::add(L0,
                                    DST_ADDR(0, 1, segment.dim_out_x),
                                    SRC1_ADDR(0, 1, segment.dim_out_x),
                                    SRC2_CHAINING_LEFT_2D,
                                    segment.dim_out_x - 1,
                                    segment.dim_out_y - 1, true);

        VPRO::DIM2::LOADSTORE::store(calc_buffer_out,
                                     0, 1, segment.dim_out_x,
                                     segment.dim_out_x - 1,
                                     segment.dim_out_y - 1,
                                     L0);
    } else {
        // CONV
        assert(segment.dim_out_x - 1 <= MAX_X_END);
        assert(segment.dim_out_y - 1 <= MAX_Y_END);
        assert(segment.dim_in_x <= MAX_BETA);
        assert(segment.dim_out_x <= MAX_BETA);
        if (kernel_size != 1 && kernel_size != 1) {
            uint32_t offset_in = calc_buffer;
            uint32_t offset_out = 0;

            for (size_t y = 0; y < segment.dim_out_y; ++y) {
                if (vpro_ext){
#if not defined(SIMULATION) && RV_EXT == 1
                    c_vpro_lw<2, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(offset_in, 0);
                    c_vpro_lw<3, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(DST_ADDR(offset_out, 0, 0, 1), 0);
#endif
                } else {
                    VPRO::DIM3::LOADSTORE::loads(offset_in,
                                                 0, 1, segment.dim_in_x, 1,
                                                 kernel_size-1, kernel_size-1, segment.dim_out_x - 1);

                    // convolution (including accu reset to 0, when z increments)
                    VPRO::DIM3::PROCESSING::mach_init_imm(L0,  // shift right by 3
                                                 DST_ADDR(offset_out, 0, 0, 1),
                                                 SRC1_LS_3D,
                                                 SRC2_ADDR(RF_KERNEL_BASE, 1, kernel_size, 0),    // 1015
                                                 kernel_size-1, kernel_size-1, segment.dim_out_x - 1,
                                                 0,
                                                 false, true);
                }
                offset_in += segment.dim_in_x;
                offset_out += segment.dim_out_x;
            }
        } else {  // kernel_w/h != 3
            assert(kernel_size == 1 && kernel_size == 1);
            __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE,
                   DST_ADDR(0, 0, 0),
                   SRC1_ADDR(0, 1, segment.dim_in_x),
                   SRC2_IMM_2D(calc_buffer),
                   segment.dim_out_x - 1, segment.dim_out_y - 1);
            // mul
            __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_MULH, NO_FLAG_UPDATE,
                   DST_ADDR(0, 1, segment.dim_out_x),
                   SRC1_LS_2D,
                   SRC2_ADDR(RF_KERNEL_BASE, 0, 0),
                   segment.dim_out_x - 1, segment.dim_out_y - 1);
        }

        if (vpro_ext){
#if not defined(SIMULATION) && RV_EXT == 1
            c_vpro_lw<4, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);
            c_vpro_lw<5, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer_out, 0);
#endif
        } else {
            // STORE L0
            VPRO::DIM2::PROCESSING::shift_ar(L0,
                                             DST_ADDR(0, 1, segment.dim_out_x),
                                             SRC1_ADDR(0, 1, segment.dim_out_x),
                                             SRC2_IMM_2D(store_shift_right),  // 1
                                             segment.dim_out_x - 1,
                                             segment.dim_out_y - 1, true);

            VPRO::DIM2::LOADSTORE::store(calc_buffer_out,
                                         0, 1, segment.dim_out_x,
                                         segment.dim_out_x - 1,
                                         segment.dim_out_y - 1,
                                         L0);
        }
    }
}

void vpro_load_kernel(){
    if (do_opt){
        if (vpro_ext){
#if not defined(SIMULATION) && RV_EXT == 1
            c_vpro_lw<0, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);

            c_vpro_lw<1, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer + LM_KERNEL_BASE, 0);
            c_vpro_lw<2, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);

            c_vpro_lw<3, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer + LM_KERNEL_BASE, 0);
            c_vpro_lw<4, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);
#endif
        } else {
            /**
             * generate 0 for odd split of kernel
             */
            VPRO::DIM2::PROCESSING::add(L0_1,
                                        DST_ADDR(RF_KERNEL_BASE, 1, kernel_size),   // 1015
                                        SRC1_IMM_2D(0),
                                        SRC2_IMM_2D(0),
                                        kernel_size - 1,
                                        (kernel_size - 1) / 2); // one line of '0'

            /**
             *  to both (1)   -> 6.-8. (smaller half) 1*3   / 4*9   [req 0']
             */
            // LOAD KERNEL
            VPRO::DIM2::LOADSTORE::loads(calc_buffer + LM_KERNEL_BASE, //1015
                                         ((kernel_size + 1) / 2) * kernel_size, 1, kernel_size,    // start at 6.
                                         kernel_size - 1,
                                         ((kernel_size - 1) / 2) - 1);

            VPRO::DIM2::PROCESSING::shift_ar(L0_1,
                                             DST_ADDR(RF_KERNEL_BASE + 1 * kernel_size, 1,
                                                      kernel_size),   // 1015 // skip one line for uneven kernel size
                                             SRC1_LS_2D,
                                             SRC2_IMM_2D(kernel_load_shift_right),
                                             kernel_size - 1,
                                             ((kernel_size - 1) / 2) - 1); // lower half
            /**
             *  to L0 (0)   -> 0.-5. (larger half)  2*3 / 5*9
             */
            // LOAD KERNEL
            VPRO::DIM2::LOADSTORE::loads(calc_buffer + LM_KERNEL_BASE, // 1015
                                         0, 1, kernel_size,
                                         kernel_size - 1,
                                         ((kernel_size + 1) / 2) - 1);

            VPRO::DIM2::PROCESSING::shift_ar(L0,
                                             DST_ADDR(RF_KERNEL_BASE, 1, kernel_size),   // 1015
                                             SRC1_LS_2D,
                                             SRC2_IMM_2D(kernel_load_shift_right),
                                             kernel_size - 1,
                                             ((kernel_size + 1) / 2) - 1);  // upper half
        }
    } else {
        if (vpro_ext){
#if not defined(SIMULATION) && RV_EXT == 1
            c_vpro_lw<0, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(calc_buffer + LM_KERNEL_BASE, 0);
            c_vpro_lw<1, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);
#endif
        } else {
            /**
             *  to L0 only
             */
            // LOAD KERNEL
            VPRO::DIM2::LOADSTORE::loads(calc_buffer + LM_KERNEL_BASE, //1015
                                         0, 1, kernel_size,
                                         kernel_size - 1, kernel_size - 1);

            VPRO::DIM2::PROCESSING::shift_ar(L0,
                                             DST_ADDR(RF_KERNEL_BASE, 1, kernel_size),   // 1015
                                             SRC1_LS_2D,
                                             SRC2_IMM_2D(kernel_load_shift_right),
                                             kernel_size - 1,
                                             kernel_size - 1);
        }
    }
}
