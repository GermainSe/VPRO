
#include "../includes/vpro_functions.h"

uint32_t RF_KERNEL_BASE;
uint32_t RF_BIAS_BASE;
uint32_t RF_RELU_6_BASE;
uint32_t kernel_x, kernel_y;
uint32_t vector_length, vector_length_compensate;

auto check_segment = [](const SEGMENT &segment) {
    return (segment.x_seg == 1 && segment.y_seg == 0 && segment.out_channel == 0);
};

#define RV_VPRO_EXT 0
#if not defined(SIMULATION) and RV_VPRO_EXT == 1

#include <vpro.h>
#include <vpro/vpro_asm.h>
#include <vpro/dma_asm.h>
#include <vpro/dma_cmd_struct.h>

using namespace VPRO_RISC_EXT_VPRO;
using namespace VPRO_RISC_EXT_DMA;

template <int n>
void reset_dma(){
    c_dma_lw<n, DMA_PARAMETER_INDIZES::ext_addr, DMA_PARAMETER_INDIZES::int_addr, NoTrigger>(0, 0);
    c_dma_lw<n, DMA_PARAMETER_INDIZES::y_size, DMA_PARAMETER_INDIZES::type, NoTrigger>(0, 0);
    c_dma_lw<n, DMA_PARAMETER_INDIZES::x_size, DMA_PARAMETER_INDIZES::x_stride, NoTrigger>(0, 0);
    c_dma_lw<n, DMA_PARAMETER_INDIZES::cluster, DMA_PARAMETER_INDIZES::broadcast_mask, NoTrigger>(0, 0);
    c_dma_lw<n, DMA_PARAMETER_INDIZES::pad_flags, DMA_PARAMETER_INDIZES::nowhere, NoTrigger>(0, 0);
//    if ( n > 0 )
//        reset_dma<n - 1>();
}

void reset_all_dma(){
    reset_dma<0>();
    reset_dma<1>();
    reset_dma<2>();
    reset_dma<3>();
    reset_dma<4>();
    reset_dma<5>();
    reset_dma<6>();
    reset_dma<7>();
}

void reset_all_vpro(){
    c_vpro_li<0, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<1, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<2, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<3, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<4, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<5, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<6, 0b1111111111111, NoTrigger>(0);
    c_vpro_li<7, 0b1111111111111, NoTrigger>(0);
}

void create_conv_template_functions(const LAYER_WRAPPER &layer) {

    // all to 0
    reset_all_dma();
    reset_all_vpro();

//    // VPRO LOADS Bias //dst = dont care
//    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE, DST_ADDR(0, 0, 0), SRC1_ADDR(0, 0, 0), SRC2_IMM_2D(bias_base), 0, 0);
    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 0, 0, 0), SRC1_ADDR(0, 0, 0, 0));
    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b100, 0);

//    // VPRO SHIFT_ Bias (shift al/ar) [one of the | depend on layer]
    if (layer.bias_shift_right <= 0){
    //    __vpro((lane == 0) ? L0 : L1, NONBLOCKING, NO_CHAIN, FUNC_MULL, NO_FLAG_UPDATE, DST_ADDR(RF_BIAS_BASE, 0, 0), SRC1_LS_2D, SRC2_IMM_2D(1u << (-layer.bias_shift_right)), 0, 0);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::func, NoTrigger>(0, FUNC_MULL);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(RF_BIAS_BASE, 0, 0, 0), SRC1_LS_3D);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(SRC2_IMM_2D(1u << (-layer.bias_shift_right)), 0);
//        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src2_all, NoTrigger>(DST_ADDR(RF_BIAS_BASE, 0, 0, 0), SRC2_LS_3D);
//        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::src1_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(SRC1_IMM_2D(1u << (-layer.bias_shift_right)), 0);
    } else {
    //    __vpro((lane == 0) ? L0 : L1, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE, DST_ADDR(RF_BIAS_BASE, 0, 0), SRC1_LS_2D, SRC2_IMM_2D(layer.bias_shift_right), 0, 0);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::func, NoTrigger>(0, FUNC_SHIFT_AR);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(RF_BIAS_BASE, 0, 0, 0), SRC1_LS_3D);
        c_vpro_lw<1, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(SRC2_IMM_2D(layer.bias_shift_right), 0);
    }

//    // VPRO LOADS Kernel  //dst = dont care
//    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE, DST_ADDR(0, 0, 0), SRC1_ADDR(0, 1, kernel_y), SRC2_IMM_2D(kernel_base), kernel_x - 1, kernel_y - 1);
    c_vpro_lw<2, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
    c_vpro_lw<2, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(0, 0, 0, 0), SRC1_ADDR(0, 1, kernel_y, 0));
    c_vpro_lw<2, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0b100, (kernel_x - 1) << (10+6) | (kernel_y - 1) << 10);

//    // VPRO MULL Kernel (shift al)
//    __vpro((lane == 0) ? L0_1 : L1, NONBLOCKING, NO_CHAIN, FUNC_SHIFT_AR, NO_FLAG_UPDATE, DST_ADDR(RF_KERNEL_BASE, 1, kernel_y), SRC1_LS_2D, SRC2_IMM_2D(0), kernel_x - 1, kernel_y - 1);
    c_vpro_lw<3, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::func, NoTrigger>(DST_ADDR(RF_KERNEL_BASE, 1, kernel_y, 0), FUNC_SHIFT_AR);
    c_vpro_lw<3, VPRO_PARAMETER_INDIZES::src1_all, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(SRC1_LS_3D, (kernel_x - 1) << (10+6) | (kernel_y - 1) << 10);
    c_vpro_lw<3, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::src2_imm, NoTrigger>(0, SRC2_IMM_2D(0));

//    // VPRO ADD (sync)
//    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(962, 1, 0), SRC1_ADDR(962, 1, 0), SRC2_IMM_2D(0), 4, 0);
    c_vpro_lw<4, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0_1, FUNC_ADD);
    c_vpro_lw<4, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, NoTrigger>(DST_ADDR(962, 1, 0, 0), SRC1_ADDR(962, 1, 0, 0));
    c_vpro_lw<4, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(SRC2_IMM_2D(0), (4) << (10+6) | (0) << 10);

//    // VPRO LOADS (conv loop)
//    VPRO::DIM3::LOADSTORE::loads(buffer, offset_in, 1, layer.seg_in_w, 1, 2, 2, layer.seg_out_w - 1);
    c_vpro_lw<5, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(LS, FUNC_LOADS);
    c_vpro_lw<5, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(0, (2) << (10+6) | (2) << 10 | layer.seg_out_w - 1);
    c_vpro_lw<5, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::nowhere, NoTrigger>(0b100, 0);

//    // VPRO MACH (conv loop)
//    VPRO::DIM3::PROCESSING::mach_init_addr(L0_1, DST_ADDR(offset_out, 0, 0, 1), SRC1_LS_3D, SRC2_ADDR(RF_KERNEL_BASE, 1, 3, 0), 2, 2, layer.seg_out_w - 1, RF_BIAS_BASE, 0, 0, 0, false, true);
    c_vpro_lw<6, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::func, NoTrigger>(L0_1, FUNC_MACH);
    c_vpro_lw<6, VPRO_PARAMETER_INDIZES::src2_all, VPRO_PARAMETER_INDIZES::x_y_z_end, NoTrigger>(SRC2_ADDR(RF_KERNEL_BASE, 1, 3, 0), (2) << (10+6) | (2) << 10 | layer.seg_out_w - 1);
    c_vpro_lw<6, VPRO_PARAMETER_INDIZES::chain_blocking_update_flag, VPRO_PARAMETER_INDIZES::nowhere, NoTrigger>(0b001, 0);

//    //  remaining have long vectors (relatively) and can be issued common way during last conv loop!
//    // VPRO MAX, VPRO MAX
//    assert(layer.seg_out_w * 2 <= MAX_BETA);
//    VPRO::DIM2::PROCESSING::max(L0_1, DST_ADDR(offset, 1, layer.seg_out_w * 2), SRC1_ADDR(offset, 1, layer.seg_out_w * 2), SRC2_ADDR(offset + layer.seg_out_w, 1, layer.seg_out_w * 2), x_end_1, y_end / 2, false, true);
//    VPRO::DIM2::PROCESSING::max(L0_1, DST_ADDR(offset, 2, layer.seg_out_w * 2), SRC1_ADDR(offset, 2, layer.seg_out_w * 2), SRC2_ADDR(offset + 1, 2, layer.seg_out_w * 2), x_end_2, y_end / 2, false, true);

//    // VPRO MULH_NEG, pooled
//    __vpro(L0_1, NONBLOCKING, NO_CHAIN, FUNC_MULH_NEG, NO_FLAG_UPDATE,
//           DST_ADDR(offset, 2, 2 * layer.seg_out_w),
//           SRC1_ADDR(offset, 2, 2 * layer.seg_out_w),
//           SRC2_IMM_2D(VPRO_CONST::leak[18]),
//           x_end,
//           y_end);

//    // VPRO SHIFT_AR, pooled
//    assert(2 * layer.seg_out_w <= MAX_BETA);
//    VPRO::DIM2::PROCESSING::shift_ar((lane == 0) ? L0 : L1,
//                                     DST_ADDR(src1_offset, 2, 2 * layer.seg_out_w),
//                                     SRC1_ADDR(src1_offset, 2, 2 * layer.seg_out_w),
//                                     SRC2_IMM_2D(layer.store_shift_right),  // 1
//                                     x_end,
//                                     y_end, true);

//    // VPRO STORE, pooled
//    VPRO::DIM2::LOADSTORE::store(buffer,
//                                 dst_offset, 1, layer.seg_out_w / 2,
//                                 x_end,
//                                 y_end,
//                                 (lane == 0) ? L0 : L1);
}

#endif