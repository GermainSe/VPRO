#include "segment_scheduling.h"
#include "helper.h"
#include <algorithm>
#include <vpro.h>
//#include <includes/yolo_lite_tf2.h>

#ifdef SIMULATION

#include <core_wrapper.h>
#include <simulator/helper/debugHelper.h>
#include <simulator/helper/typeConversion.h>
#include <opencv2/highgui.hpp>
#include <opencv2/imgproc.hpp>
#include <opencv2/core/utility.hpp>

#else
#endif

#define RV_VPRO_EXT 0

#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
#include <vpro.h>
#include <vpro/vpro_asm.h>
#include <vpro/dma_asm.h>
#include <vpro/dma_cmd_struct.h>
using namespace VPRO_RISC_EXT_VPRO;
using namespace VPRO_RISC_EXT_DMA;
#endif

inline void _kernel_load_right(const uint16_t &kernel_base, const uint8_t &lane, const int shift) {
#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
    c_vpro_lw<2, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(SRC2_IMM_2D(kernel_base),
                                                                                             0);
    c_vpro_lw<3, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::nowhere, Trigger>((lane == 0) ? L0_1 : L1, 0);
    c_vpro_lw<4, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);
#else
    VPRO::DIM2::LOADSTORE::loads(kernel_base, 0, 1, kernel_y,
                                 kernel_x - 1, kernel_y - 1);

    // TODO: remove [what if async calc. current: lane 0 > lane 1]
    //  load to both if lane == 0
    //  else, if lane 1 is always dummy (Depthwise, residual ...), the remaining elements are used in later conv (broadcasted)
    //  (e.g. from a 1x1 kernel, the bias is still in kernel region, causing trouble due to MUL 18-bit constraint)
    //  the load to both for L0 is overwritten on L1 by following L1 load if it matters there
    VPRO::DIM2::PROCESSING::shift_ar((lane == 0) ? L0_1 : L1,
                                     DST_ADDR(RF_KERNEL_BASE, 1, kernel_y),
                                     SRC1_LS_2D,
                                     SRC2_IMM_2D(shift),
                                     kernel_x - 1,
                                     kernel_y - 1);

    // other lane sync // instead of blocking MULL
    VPRO::DIM2::PROCESSING::add(L0_1,
                                DST_ADDR(962, 1, 0),
                                SRC1_ADDR(962, 1, 0),
                                SRC2_IMM_2D(0),
                                4, 0);
#endif
}

inline void _conv(const LAYER_WRAPPER &layer, const uint16_t buffer) {
    assert(layer.stride == 1);
    if (kernel_x == 1) {
        assert((unsigned int) layer.seg_out_w - 1 <= MAX_X_END);
        assert((unsigned int) layer.seg_out_h - 1 <= MAX_Y_END);
        assert((unsigned int) layer.seg_in_w <= MAX_BETA);
        assert((unsigned int) layer.seg_out_w <= MAX_BETA);
        VPRO::DIM2::LOADSTORE::loads(buffer, 0, 1, layer.seg_in_w,
                                     layer.seg_out_w - 1, layer.seg_out_h - 1);
        // mul
        VPRO::DIM2::PROCESSING::mulh(L0_1,
                                     DST_ADDR(0, 1, layer.seg_out_w),
                                     SRC1_LS_2D,
                                     SRC2_ADDR(RF_KERNEL_BASE, 0, 0),
                                     layer.seg_out_w - 1, layer.seg_out_h - 1);

        if (vector_length_compensate > 0) {
            VPRO::DIM2::PROCESSING::add(L0_1,
                                        DST_ADDR(512, 1, 0),
                                        SRC1_ADDR(512, 1, 0),
                                        SRC2_IMM_2D(0),
                                        vector_length_compensate, 0);
        }
        // add bias
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(0, 1, layer.seg_out_w),
                                    SRC1_ADDR(0, 1, layer.seg_out_w),
                                    SRC2_ADDR(RF_BIAS_BASE, 0, 0),
                                    layer.seg_out_w - 1, layer.seg_out_h - 1);
    } else {
        assert(kernel_x == 3 && kernel_y == 3);
        auto offset_in = 0;
        auto offset_out = 0;
        for (size_t y = 0; y < layer.seg_out_h; ++y) {
#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
            c_vpro_lw<5, VPRO_PARAMETER_INDIZES::src1_all, VPRO_PARAMETER_INDIZES::src2_imm, Trigger>(
                    SRC1_ADDR(offset_in, 1, layer.seg_in_w, 1), SRC2_IMM_2D(buffer));
            c_vpro_lw<6, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, Trigger>(
                    DST_ADDR(offset_out, 0, 0, 1), complex_ADDR_3D(SRC_SEL_LS, RF_BIAS_BASE, 0, 0, 0));
#else
            VPRO::DIM3::LOADSTORE::loads(buffer,
                                         offset_in, 1, layer.seg_in_w, 1,
                                         2, 2, layer.seg_out_w - 1);
            VPRO::DIM3::PROCESSING::mach_init_addr(L0_1,  // shift right by 3
                                                   DST_ADDR(offset_out, 0, 0, 1),
                                                   SRC1_LS_3D,
                                                   SRC2_ADDR(RF_KERNEL_BASE, 1, 3, 0),    // 1015
                                                   2, 2, layer.seg_out_w - 1,
                                                   RF_BIAS_BASE, 0, 0, 0,  // 1014
                                                   false, true);
#endif
            offset_in += layer.seg_in_w;
            offset_out += layer.seg_out_w;
        }
    }
}

inline void _conv_add(const LAYER_WRAPPER &layer, const uint16_t buffer) {
    assert(layer.stride == 1);
    if (kernel_x == 1) {
        VPRO::DIM2::LOADSTORE::loads(buffer, 0, 1, layer.seg_in_w,
                                     layer.seg_out_w - 1, layer.seg_out_h - 1);
        // mul
        VPRO::DIM2::PROCESSING::mulh(L0_1,
                                     DST_ADDR(484, 1, layer.seg_out_w),
                                     SRC1_LS_2D,
                                     SRC2_ADDR(RF_KERNEL_BASE, 0, 0),
                                     layer.seg_out_w - 1, layer.seg_out_h - 1);
        if (vector_length_compensate > 0) {
            VPRO::DIM2::PROCESSING::add(L0_1,
                                        DST_ADDR(962, 1, 0),
                                        SRC1_ADDR(962, 1, 0),
                                        SRC2_IMM_2D(0),
                                        vector_length_compensate, 0);
        }
        // add to previous
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(0, 1, layer.seg_out_w),
                                    SRC1_ADDR(0, 1, layer.seg_out_w),
                                    SRC2_ADDR(484, 1, layer.seg_out_w),
                                    layer.seg_out_w - 1, layer.seg_out_h - 1);
    } else { // kernel > 1, kernel build vector
        assert(kernel_x == 3 && kernel_y == 3);
        auto offset_in = 0;
        auto offset_out = 0;
        for (size_t y = 0; y < layer.seg_out_h; ++y) {
#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
            c_vpro_lw<5, VPRO_PARAMETER_INDIZES::src1_all, VPRO_PARAMETER_INDIZES::src2_imm, Trigger>(
                    SRC1_ADDR(offset_in, 1, layer.seg_in_w, 1), SRC2_IMM_2D(buffer));
            c_vpro_lw<6, VPRO_PARAMETER_INDIZES::dst_all, VPRO_PARAMETER_INDIZES::src1_all, Trigger>(
                    DST_ADDR(offset_out, 0, 0, 1), complex_ADDR_3D(SRC_SEL_LS, offset_out, 0, 0, 1));
#else
            VPRO::DIM3::LOADSTORE::loads(buffer,
                                         offset_in, 1, layer.seg_in_w, 1,
                                         2, 2, layer.seg_out_w - 1);
            VPRO::DIM3::PROCESSING::mach_init_addr(L0_1,  // shift right by 3
                                                   DST_ADDR(offset_out, 0, 0, 1),
                                                   SRC1_LS_3D,
                                                   SRC2_ADDR(RF_KERNEL_BASE, 1, 3, 0),    // 1015
                                                   2, 2, layer.seg_out_w - 1,
                                                   offset_out, 0, 0, 1,  // previous value ( = dst )
                                                   false, true);    // update flags
#endif
            offset_in += layer.seg_in_w;
            offset_out += layer.seg_out_w;
        }
    }
}

inline void _bias_load_left(const LAYER_WRAPPER &layer, const uint16_t &bias_base, const uint8_t lane) {
#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(SRC2_IMM_2D(bias_base), 0);
    c_vpro_lw<1, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::nowhere, Trigger>((lane == 0) ? L0 : L1, 0);
    c_vpro_lw<4, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);
#else
    //    __load_shift_left(LS, LM_BIAS_BASE, 0, 0, 0, 0, 0, 0);
    VPRO::DIM2::LOADSTORE::loads(bias_base, 0, 0, 0, 0, 0);

    VPRO::DIM2::PROCESSING::mull((lane == 0) ? L0 : L1,
                                 DST_ADDR(RF_BIAS_BASE, 0, 0),
                                 SRC1_IMM_2D(1u << (-layer.bias_shift_right)),
                                 SRC2_LS_2D,
                                 0,
                                 0);

    // other lane sync // instead of blocking MULL
    VPRO::DIM2::PROCESSING::add(L0_1,
                                DST_ADDR(962, 1, 0),
                                SRC1_ADDR(962, 1, 0),
                                SRC2_IMM_2D(0),
                                4, 0);
    //    TODO: eval HW execution (MIPS shift always?) vs load_shift_left with -layer.bias_shift_right as shift value
#endif
}

inline void _bias_load_right(const LAYER_WRAPPER &layer, const uint16_t &bias_base, const uint8_t lane) { // > 0
#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
    c_vpro_lw<0, VPRO_PARAMETER_INDIZES::src2_imm, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(SRC2_IMM_2D(bias_base), 0);
    c_vpro_lw<1, VPRO_PARAMETER_INDIZES::id, VPRO_PARAMETER_INDIZES::nowhere, Trigger>((lane == 0) ? L0 : L1, 0);
    c_vpro_lw<4, VPRO_PARAMETER_INDIZES::nowhere, VPRO_PARAMETER_INDIZES::nowhere, Trigger>(0, 0);
#else
    //    __load_shift_right(LS, LM_BIAS_BASE, 0, 0, 0, 0, 0, 0);
    VPRO::DIM2::LOADSTORE::loads(bias_base, 0, 0, 0, 0, 0);
    VPRO::DIM2::PROCESSING::shift_ar((lane == 0) ? L0 : L1,
                                     DST_ADDR(RF_BIAS_BASE, 0, 0),
                                     SRC1_LS_2D,
                                     SRC2_IMM_2D(layer.bias_shift_right),
                                     0,
                                     0);

    // other lane sync // instead of blocking MULL
    VPRO::DIM2::PROCESSING::add(L0_1,
                                DST_ADDR(962, 1, 0),
                                SRC1_ADDR(962, 1, 0),
                                SRC2_IMM_2D(0),
                                4, 0);
#endif
}

inline void _bias(const LAYER_WRAPPER &layer, const uint32_t x_end, const uint32_t y_end, const uint32_t offset) {
    if (vector_length_compensate > 0) { // if pipeline not yet done
        int tmp_base = RF_RELU_6_BASE - vector_length_compensate - 2;
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(tmp_base, 1, 0),
                                    SRC1_ADDR(tmp_base, 1, 0),
                                    SRC2_IMM_2D(0),
                                    vector_length_compensate, 0);
    }
    VPRO::DIM2::PROCESSING::add(L0_1,
                                DST_ADDR(offset, 1, layer.seg_out_w),
                                SRC1_ADDR(offset, 1, layer.seg_out_w),
                                SRC2_ADDR(RF_BIAS_BASE, 0, 0),
                                x_end,
                                y_end);
}

inline void _relu_leaky(const LAYER_WRAPPER &layer) {
    VPRO::DIM2::PROCESSING::mulh_neg(L0_1,
                                     DST_ADDR(0, 1, layer.seg_out_w),
                                     SRC1_ADDR(0, 1, layer.seg_out_w),
                                     SRC2_IMM_2D(VPRO_CONST::leak[18]),
                                     layer.seg_out_w - 1,
                                     layer.seg_out_w - 1);
}

inline void _relu_leaky(const LAYER_WRAPPER &layer, const uint32_t x_end, const uint32_t y_end, const uint32_t offset) {
    VPRO::DIM2::PROCESSING::mulh_neg(L0_1,
                                     DST_ADDR(offset, 1, layer.seg_out_w),
                                     SRC1_ADDR(offset, 1, layer.seg_out_w),
                                     SRC2_IMM_2D(VPRO_CONST::leak[18]),
                                     x_end,
                                     y_end);
}

inline void
_relu_leaky_pool(const LAYER_WRAPPER &layer, const uint32_t x_end, const uint32_t y_end, const uint32_t offset) {
    assert(layer.seg_out_w * 2 <= MAX_BETA);
    VPRO::DIM2::PROCESSING::mulh_neg(L0_1,
                                     DST_ADDR(offset, 2, 2 * layer.seg_out_w),
                                     SRC1_ADDR(offset, 2, 2 * layer.seg_out_w),
                                     SRC2_IMM_2D(VPRO_CONST::leak[18]),
                                     x_end,
                                     y_end);
}

inline void _relu_rect(const LAYER_WRAPPER &layer) {
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(0, 1, layer.seg_out_w),
                                SRC1_ADDR(0, 1, layer.seg_out_w),
                                SRC2_IMM_2D(0),
                                layer.seg_out_w,
                                layer.seg_out_w);
}

inline void _relu_rect(const LAYER_WRAPPER &layer, const uint32_t x_end, const uint32_t y_end, const uint32_t offset) {
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(offset, 1, layer.seg_out_w),
                                SRC1_ADDR(offset, 1, layer.seg_out_w),
                                SRC2_IMM_2D(0),
                                x_end,
                                y_end);
}

inline void
_relu_rect_pool(const LAYER_WRAPPER &layer, const uint32_t x_end, const uint32_t y_end, const uint32_t offset) {
    assert(layer.seg_out_w * 2 <= MAX_BETA);
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(offset, 2, 2 * layer.seg_out_w),
                                SRC1_ADDR(offset, 2, 2 * layer.seg_out_w),
                                SRC2_IMM_2D(0),
                                x_end,
                                y_end);
}

inline void _relu6_load(const int32_t shift_value) {
    int six_value = 6;
    int shift = shift_value;
    if (shift_value > 18) { // 20-bit max for imm, shift of 19 -> 20-bit (negative value)
        shift = 18;
        six_value = six_value << (shift_value - shift);
    }
    VPRO::DIM2::PROCESSING::mull(L0_1,
                                 DST_ADDR(RF_RELU_6_BASE, 0, 0),
                                 SRC1_IMM_2D(1 << shift),
                                 SRC2_IMM_2D(six_value), // limit to 18-bit!
                                 0,
                                 0);
}

inline void _relu_6(const LAYER_WRAPPER &layer) {
    int tmp_base = RF_RELU_6_BASE - vector_length_compensate - 2;
    if (vector_length_compensate > 0) {
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(tmp_base, 1, 0),
                                    SRC1_ADDR(tmp_base, 1, 0),
                                    SRC2_IMM_2D(0),
                                    vector_length_compensate, 0);
    }
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(0, 1, layer.seg_out_w),
                                SRC1_ADDR(0, 1, layer.seg_out_w),
                                SRC2_IMM_2D(0),
                                layer.seg_out_w - 1,
                                layer.seg_out_w - 1);
    if (vector_length_compensate > 0) {
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(tmp_base, 1, 0),
                                    SRC1_ADDR(tmp_base, 1, 0),
                                    SRC2_IMM_2D(0),
                                    vector_length_compensate, 0);
    }
    VPRO::DIM2::PROCESSING::min(L0_1,
                                DST_ADDR(0, 1, layer.seg_out_w),
                                SRC1_ADDR(0, 1, layer.seg_out_w),
                                SRC2_ADDR(RF_RELU_6_BASE, 0, 0),
                                layer.seg_out_w - 1,
                                layer.seg_out_w - 1);
}

inline void _relu_6(const LAYER_WRAPPER &layer, const uint32_t x_end, const uint32_t y_end, const uint32_t offset) {
    // if (layer.seg_out_w * layer.seg_out_h) // iterations of conv
    // kernel_x * ... length of each
    int v_l = (x_end + 1) * (y_end + 1);
    int tmp_base = 0;
    if (v_l < 5) { // lenght of this result to be relue'd
        // sync cause read data is still processed by conv
        tmp_base = RF_RELU_6_BASE - (5 - v_l) - 2;
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(tmp_base, 1, 0),
                                    SRC1_ADDR(tmp_base, 1, 0),
                                    SRC2_IMM_2D(0),
                                    5 - v_l, 0);
    }
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(offset, 1, layer.seg_out_w),
                                SRC1_ADDR(offset, 1, layer.seg_out_w),
                                SRC2_IMM_2D(0),
                                x_end,
                                y_end);
    if (v_l < 5) { // lenght of this result to be relue'd
        // sync cause read data is still processed by conv
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(tmp_base, 1, 0),
                                    SRC1_ADDR(tmp_base, 1, 0),
                                    SRC2_IMM_2D(0),
                                    5 - v_l, 0);
    }
    VPRO::DIM2::PROCESSING::min(L0_1,
                                DST_ADDR(offset, 1, layer.seg_out_w),
                                SRC1_ADDR(offset, 1, layer.seg_out_w),
                                SRC2_ADDR(RF_RELU_6_BASE, 0, 0),
                                x_end,
                                y_end);
    if (v_l < 5) { // lenght of this result to be relue'd
        // sync cause read data is still processed by conv
        VPRO::DIM2::PROCESSING::add(L0_1,
                                    DST_ADDR(tmp_base, 1, 0),
                                    SRC1_ADDR(tmp_base, 1, 0),
                                    SRC2_IMM_2D(0),
                                    5 - v_l, 0);
    }
}

inline void
_relu_6_pool(const LAYER_WRAPPER &layer, const uint32_t x_end, const uint32_t y_end, const uint32_t offset) {
    assert(layer.seg_out_w * 2 <= MAX_BETA);
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(offset, 2, 2 * layer.seg_out_w),
                                SRC1_ADDR(offset, 2, 2 * layer.seg_out_w),
                                SRC2_IMM_2D(0),
                                x_end,
                                y_end);
    VPRO::DIM2::PROCESSING::min(L0_1,
                                DST_ADDR(offset, 2, 2 * layer.seg_out_w),
                                SRC1_ADDR(offset, 2, 2 * layer.seg_out_w),
                                SRC2_ADDR(RF_RELU_6_BASE, 0, 0),
                                x_end,
                                y_end);
}

inline void _pool(const LAYER_WRAPPER &layer, const uint32_t x_end_1, const uint32_t x_end_2, const uint32_t y_end,
                  const uint32_t offset) {
    assert(layer.seg_out_w * 2 <= MAX_BETA);
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(offset, 1, layer.seg_out_w * 2),
                                SRC1_ADDR(offset, 1, layer.seg_out_w * 2),
                                SRC2_ADDR(offset + layer.seg_out_w, 1, layer.seg_out_w * 2), x_end_1, y_end / 2,
                                false, true);
    // max is on top row
    VPRO::DIM2::PROCESSING::max(L0_1,
                                DST_ADDR(offset, 2, layer.seg_out_w * 2),
                                SRC1_ADDR(offset, 2, layer.seg_out_w * 2),
                                SRC2_ADDR(offset + 1, 2, layer.seg_out_w * 2), x_end_2, y_end / 2,
                                false, true);
    // max is on left row
}

inline void _shift_store(const LAYER_WRAPPER &layer, const uint16_t &buffer, const uint32_t x_end, const uint32_t y_end,
                         const uint32_t offset,
                         uint8_t lane) {
    VPRO::DIM2::PROCESSING::shift_ar((lane == 0) ? L0 : L1,
                                     DST_ADDR(offset, 1, layer.seg_out_w),
                                     SRC1_ADDR(offset, 1, layer.seg_out_w),
                                     SRC2_IMM_2D(layer.store_shift_right),  // 1
                                     x_end,
                                     y_end, true);

    VPRO::DIM2::LOADSTORE::store(buffer,
                                 offset, 1, layer.seg_out_w,
                                 x_end,
                                 y_end,
                                 (lane == 0) ? L0 : L1);
}

inline void
_shift_store_pool(const LAYER_WRAPPER &layer, const uint16_t &buffer, const uint32_t x_end, const uint32_t y_end,
                  uint32_t dst_offset, uint32_t src1_offset, uint8_t lane) {
    assert(2 * layer.seg_out_w <= MAX_BETA);
    VPRO::DIM2::PROCESSING::shift_ar((lane == 0) ? L0 : L1,
                                     DST_ADDR(src1_offset, 2, 2 * layer.seg_out_w),
                                     SRC1_ADDR(src1_offset, 2, 2 * layer.seg_out_w),
                                     SRC2_IMM_2D(layer.store_shift_right),  // 1
                                     x_end,
                                     y_end, true);

    VPRO::DIM2::LOADSTORE::store(buffer,
                                 dst_offset, 1, layer.seg_out_w / 2,
                                 x_end,
                                 y_end,
                                 (lane == 0) ? L0 : L1);
}

inline void _residual(const LAYER_WRAPPER &layer, const uint16_t buffer, const uint32_t x_end, const uint32_t y_end,
                      const uint32_t offset) {

    VPRO::DIM2::LOADSTORE::loads(buffer,
                                 offset, 1, layer.seg_in_w,
                                 x_end, y_end);
    VPRO::DIM2::PROCESSING::mull(L0,
                                 DST_ADDR(offset, 1, layer.seg_in_w),
                                 SRC1_IMM_2D(1 << layer.residual_0_left_shift),
                                 SRC2_LS_2D,
                                 x_end, y_end);

    VPRO::DIM2::LOADSTORE::load_shift_left(buffer + offset + 1024, 0, 1, layer.seg_in_w, x_end, y_end,
                                           layer.residual_1_left_shift);
    // LOAD RESIDUAL 1, ADD
//    __load_shift_left(LS, buffer + offset + 1024, 0,
//                      1, layer.seg_in_w, layer.residual_1_left_shift, x_end, y_end);
    VPRO::DIM2::PROCESSING::add(L0,
                                DST_ADDR(offset, 1, layer.seg_in_w),
                                SRC1_LS_2D,
                                SRC2_ADDR(offset, 1, layer.seg_in_w),
                                x_end,
                                y_end);

    // STORE ( overwrite Residual 0 )
    VPRO::DIM2::PROCESSING::shift_ar(L0,
                                     DST_ADDR(offset, 1, layer.seg_out_w),
                                     SRC1_ADDR(offset, 1, layer.seg_out_w),
                                     SRC2_IMM_2D(layer.store_shift_right),
                                     x_end,
                                     y_end, true);
    VPRO::DIM2::LOADSTORE::store(buffer, offset, 1, layer.seg_out_w,
                                 x_end,
                                 y_end, L0);
}

inline void print_cmd_segment(const COMMAND_SEGMENT &seg) {
    const auto *vpro_cmd = reinterpret_cast<const COMMAND_VPRO *>(seg.data);
    const auto *dma_cmd = reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(seg.data);
    switch (seg.type) {
        case VPRO_SEG:
            printf("VPRO, ");
            if (vpro_cmd->command == conv_start)
                printf("conv_start, ");
            else if (vpro_cmd->command == conv_add)
                printf("conv_add, ");
            else if (vpro_cmd->command == relu_pool)
                printf("relu_pool, ");
            else if (vpro_cmd->command == shift_store)
                printf("shift_store, ");
            else if (vpro_cmd->command == residual)
                printf("residual, ");
            printf("lane: 0x%x, buffer: 0x%x, xend_1: %i, xend_2: %i, yend: %i, offset: %i\n",
                   vpro_cmd->lane, vpro_cmd->buffer, vpro_cmd->xend_1, vpro_cmd->xend_2, vpro_cmd->yend,
                   vpro_cmd->offset);
            break;
        case DMA_SEG:
            printf("DMA, ");
            if (dma_cmd->direction == COMMAND_DMA::DMA_DIRECTION::e2l1D)
                printf("e2l1D, ");
            else if (dma_cmd->direction == COMMAND_DMA::DMA_DIRECTION::e2l2D)
                printf("e2l2D, ");
            else if (dma_cmd->direction == COMMAND_DMA::DMA_DIRECTION::l2e1D)
                printf("l2e1D, ");
            else if (dma_cmd->direction == COMMAND_DMA::DMA_DIRECTION::l2e2D)
                printf("l2e2D, ");
            printf("cluster: 0x%x, unit_mask: 0x%lx, mm_addr: 0x%lx, lm_addr: 0x%lx, x_stride: %i, x_size: %i, y_size: %i\n",
                   dma_cmd->cluster, dma_cmd->unit_mask, dma_cmd->mm_addr, dma_cmd->lm_addr, dma_cmd->x_stride,
                   dma_cmd->x_size, dma_cmd->y_size);
            break;
        case VPRO_WAIT:
            printf("SYNC VPRO");
            break;
        case DMA_WAIT:
            printf("SYNC DMA");
            break;
    }
}

//#define RV_PRINT_SEGMENT_CNT
//#define SEGMENT_SCHEDULING_VERBOSE

void calcLayer(const LAYER_WRAPPER &layer, const COMMAND_SEGMENT *segments, const void *conv, const uint32_t seg_size,
               const uint32_t weight_addr_offset) {

#ifdef SIMULATION
    uint32_t startclock = aux_get_sys_time_lo();
#else
    VPRO_BUSY_MASK_CL = 0xffffffff;
#endif
//    printf("Layer %i\n", layer.number );

    /**
     * PERFORM PAD
     */
    if (layer.kernel_length > 1) { // PAD!
        // configure the dma to pad loaded segments
        dma_set_pad_widths(layer.pad.top, layer.pad.right, layer.pad.bottom, layer.pad.left);
        dma_set_pad_value(layer.pad.value);
    }

    vector_length = (layer.seg_out_w) * (layer.seg_out_h);
    if (vector_length < 5)
        vector_length_compensate = 5 - vector_length;
    else
        vector_length_compensate = 0;

    if (layer.type == LAYERTYPE::CONV2 || layer.type == LAYERTYPE::DEPTHWISE_CONV2) {
        RF_KERNEL_BASE = 1024 - (layer.kernel_length * layer.kernel_length);
        RF_BIAS_BASE = RF_KERNEL_BASE - 1;
        RF_RELU_6_BASE = RF_BIAS_BASE - 1;
        kernel_x = layer.kernel_length;
        kernel_y = layer.kernel_length;

        //the result after MAC (convolution) is shifted right
        // to be stored in RF with 24-bit
        vpro_mac_h_bit_shift(layer.conv_result_shift_right);
        if (layer.kernel_length == 1)
            vpro_mul_h_bit_shift(layer.conv_result_shift_right);

        if (layer.relu_type == RELUTYPE::LEAKY)
            vpro_mul_h_bit_shift(18);

        vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::Z_INCREMENT);
        vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ADDR);  // for adding bias and accumulating of out channel in RF

        // not kernel 1 and leaky (different shift values)
        assert(!((layer.kernel_length == 1) && (layer.relu_type == RELUTYPE::LEAKY)));
    }

    if (layer.relu_type == RELUTYPE::RELU6) {
        // store shifted value of "6" to RF
        sim_printf("LAYER GONNA SHIFT 6 left by: %i \n", layer.relu_6_shift_left);
        if (layer.relu_6_shift_left > 20) { // 6 takes 3 bit. if 24 are taken, result gets negative!
            printf_warning("Relu 6 overflow...");
        }
        _relu6_load(layer.relu_6_shift_left);
    }

#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
    create_conv_template_functions(layer);
#endif

#ifdef IS_SIMULATION
    printf_info("Total Segments: %i (%i [%3.2f %%, +%3.2f %%] with sense due to HW Configuration Overhead)\n",
                seg_size,
                seg_size, 100. * (float(seg_size) / float(seg_size)),
                100. * (float(seg_size - seg_size) / float(seg_size)));
    double percent;
    double previous_percent = 0.0;

#endif

    // RF Layout
    // KERNEL
    //    1024 (end) - 9 (3x3 kernel) => 1014-1023
    // BIAS
    //    1024 (end) - 9 (3x3 kernel) -1 => 1013
    // RELU6_value
    //    1012
    // DATA (CONV Out)
    //    0 - 1011

    // LM Layout
    // KERNEL
    //    (buffer_calc * 4096) + 4096 - (kernel_x * kernel_y * (lane+1));
    //      A: L0: 8192 - 1*9 (3x3 kernel) = 8183-8191
    //      A: L1: 8192 - 2*9 (3x3 kernel) = 8174-8182
    //      B: L0: 4096 - 1*9 (3x3 kernel) = 4087-4095
    //      B: L1: 4096 - 2*9 (3x3 kernel) = 4079-4086
    // BIAS
    //    (buffer_calc * 4096) + 4096 - (kernel_x * kernel_y * 2)- 1 - lane;
    //      A: L0: 8192 - 2*9 (3x3 kernel) - 1     = 8173
    //      A: L1: 8192 - 2*9 (3x3 kernel) - 1 - 1 = 8172
    //      B: L0: 4096 - 2*9 (3x3 kernel) - 1     = 4078
    //      B: L1: 4096 - 2*9 (3x3 kernel) - 1 - 1 = 4077
    // DATA
    //      IN: ?
    //      OUT: ?

    /**
     * EXECUTE SEGMENTs         <-- main Loop -->
     *
     * Fetches Segment for current layer (big loop)
     * Depending on command type, executes DMA or VPRO instructions
     *
     * DMA:
     *  dma offset is added (depending on dynamic weights array adresses in mips/vpro system)
     *  -> precalculated in configuration_generation app. only needed for SIM (conv pointer passed)
     *
     * VPRO:
     *  all functions are declared inline
     */

#ifdef RV_PRINT_SEGMENT_CNT
    int lst = 0;
#endif
//    int dmas = 0;
//    int vpros = 0;
//    int dma_sync = 0;
//    int vpro_sync = 0;

    auto start_segment = intptr_t(&segments[0]);
    auto end_segment = intptr_t(&segments[0]) + seg_size * sizeof(COMMAND_SEGMENT);

#ifndef SIMULATION
    // declaration of a uint32_t variabale here will force gcc application for risc-v only to load the dcache short address once!?
    uint32_t *dcache_short_hw = (uint32_t *)(IDMA_COMMAND_DCACHE_ADDR);
#endif

// #pragma GCC unroll 8
    for (intptr_t seg_cnt = start_segment; seg_cnt < end_segment; seg_cnt += sizeof(COMMAND_SEGMENT)) {

#ifdef SIMULATION
        int seg_cnt_index = (seg_cnt - start_segment) / sizeof(COMMAND_SEGMENT);
        percent = (100 * (1 - (double(seg_size - seg_cnt_index) / seg_size)));
        if (percent > previous_percent + 2) { // print every 2 percent difference again
            previous_percent = percent;
            printf("\r Segments left: %6i / %i (Process: %4.1f%%)", seg_size - seg_cnt_index, seg_size, percent);
            printProgress(percent, 60);
//            printf(" Time: %lf ns", core_->getTime());
        }
#elif defined(RV_PRINT_SEGMENT_CNT)
        int seg_cnt_index = (seg_cnt - start_segment) / sizeof(COMMAND_SEGMENT);
        //                uint32_t mask = 0xffffffff; // every segments
                //        uint32_t mask = 0xffffff80; // every 128 segments
                                    uint32_t mask = 0xfffffc00; // every 1024 segments
                                    if (((seg_size - seg_cnt_index) & mask) != lst){
                                        printf("\r%7i",seg_size - seg_cnt_index);
                                        lst = (seg_size - seg_cnt_index) & mask;
                                    }
#endif
        //const COMMAND_SEGMENT &seg = *(COMMAND_SEGMENT *)(seg_cnt); //segments[seg_cnt]; // ((COMMAND_SEGMENT *)(seg_cnt))->

#ifdef SEGMENT_SCHEDULING_VERBOSE
        print_cmd_segment(*(COMMAND_SEGMENT *)seg_cnt);
#endif

        if (((COMMAND_SEGMENT *) (seg_cnt))->type == VPRO_SEG) {
#if defined(RV_PRINT_SEGMENT_CNT)
            vpros++;
#endif
            const COMMAND_VPRO &vpro = *reinterpret_cast<const COMMAND_VPRO *>(((COMMAND_SEGMENT *) (seg_cnt))->data);
            if (vpro.command == VPRO_TYPE::conv_start) {
#if RV_VPRO_EXT == 1 and not defined(SIMULATION)
                _bias_load_right(layer, vpro.bias_load_buffer_l0, 0);
                _bias_load_right(layer, vpro.bias_load_buffer_l1, 1);
#else
                if (layer.bias_shift_right > 0) {
                    _bias_load_right(layer, vpro.bias_load_buffer_l0, 0);
                    _bias_load_right(layer, vpro.bias_load_buffer_l1, 1);
                } else {
                    _bias_load_left(layer, vpro.bias_load_buffer_l0, 0);
                    _bias_load_left(layer, vpro.bias_load_buffer_l1, 1);
                }
#endif
                _kernel_load_right(vpro.kernel_load_buffer_l0, 0, 0);
                _kernel_load_right(vpro.kernel_load_buffer_l1, 1, 0);
                _conv(layer, vpro.buffer);
            } else if (vpro.command == VPRO_TYPE::conv_add) {
                _kernel_load_right(vpro.kernel_load_buffer_l0, 0, 0);
                _kernel_load_right(vpro.kernel_load_buffer_l1, 1, 0);
                _conv_add(layer, vpro.buffer);
            } else if (vpro.command == VPRO_TYPE::residual) {
                _residual(layer, vpro.buffer, vpro.xend_1, vpro.yend, vpro.offset);
            } else if (vpro.command == VPRO_TYPE::shift_store) {
                if (layer.pool_stride == 1) {
                    _shift_store(layer, vpro.buffer, vpro.xend_1, vpro.yend, vpro.offset, vpro.lane);
                } else {
                    _shift_store_pool(layer, vpro.buffer, vpro.xend_1, vpro.yend, vpro.xend_2, vpro.offset,
                                      vpro.lane);
                }
            } else if (vpro.command == VPRO_TYPE::relu_pool) {
                if (layer.pool_stride == 1) {         // no pooling  // only layer informations are relevant!
                    if (layer.relu_type == RELUTYPE::LEAKY) {
                        // for leaky relu, the leak value is encoded with .18
                        // the result has to bes shifted back by 18 bit
                        // TODO: Make shure conv (if kernel_l == 1) is finished! before reset of mulh
                        // done before:
                        // vpro_mul_h_bit_shift(18);
                        _relu_leaky(layer);
                    } else if (layer.relu_type == RELUTYPE::RECT) {
                        _relu_rect(layer);
                    } else if (layer.relu_type == RELUTYPE::RELU6) {
                        _relu_6(layer);
                    }
                    if (vector_length_compensate > 0) {
                        // lenght of this result to be relue'd  // sync cause read data is still processed by conv/store or relu
                        VPRO::DIM2::PROCESSING::add(L0_1,
                                                    DST_ADDR(962, 1, 0),
                                                    SRC1_ADDR(962, 1, 0),
                                                    SRC2_IMM_2D(0),
                                                    vector_length_compensate, 0);
                    }
                } else {                             // with pooling // precalc layer informations:
                    // with pool, but direct addressable, one command
                    // TODO: pooling is always MAX pooling -> configurable
                    _pool(layer, vpro.xend_1, vpro.xend_2, vpro.yend, 0);
                    if (layer.relu_type == RELUTYPE::LEAKY) {
                        // for leaky relu, the leak value is encoded with .18 (0.1)
                        // the result has to bes shifted back by 18 bit
                        // TODO: mulh_bit_shift differs between conv (kernel == 1) and leaky_relu.
                        //      Make shure conv is finished! before set of mulh_bit_shift for relu
                        //      to be done before: vpro_mul_h_bit_shift(18);
                        _relu_leaky_pool(layer, vpro.xend_2, vpro.xend_2, 0);
                    } else if (layer.relu_type == RELUTYPE::RECT) {
                        _relu_rect_pool(layer, vpro.xend_2, vpro.xend_2, 0);
                    } else if (layer.relu_type == RELUTYPE::RELU6) {
                        _relu_6_pool(layer, vpro.xend_2, vpro.xend_2, 0);
                    }
                    if (vector_length_compensate > 0) {
                        // lenght of this result to be relue'd  // sync cause read data is still processed by conv/store or relu
                        VPRO::DIM2::PROCESSING::add(L0_1,
                                                    DST_ADDR(962, 1, 0),
                                                    SRC1_ADDR(962, 1, 0),
                                                    SRC2_IMM_2D(0),
                                                    vector_length_compensate, 0);
                    }
                }
            }
        } else if (((COMMAND_SEGMENT *) (seg_cnt))->type == DMA_BLOCK) {
            const COMMAND_DMA::COMMAND_DMA &dmab = *reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(((COMMAND_SEGMENT *) (seg_cnt))->data);
            uint block_size = dmab.unit_mask;
//            printf_warning("DMA BLOCK Segment! [size; %i]\n", block_size); // , start: %li, seg_cnt);

#ifdef SIMULATION
            for (int i = 0; i < block_size; i++) {
                seg_cnt += sizeof(COMMAND_SEGMENT);
                assert((((COMMAND_SEGMENT *) (seg_cnt))->type == DMA_SEG));
                const COMMAND_DMA::COMMAND_DMA &dma = *reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(((COMMAND_SEGMENT *) (seg_cnt))->data);
//                print_cmd_segment(*(COMMAND_SEGMENT *) (seg_cnt));
                if (dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l1D ||
                    dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l2D) {
                    if (dma.isKernelOffset || dma.isBiasOffset) {
                        dma_dcache_short_command(((COMMAND_SEGMENT *) (seg_cnt))->data,
                                                 weight_addr_offset,
                                                 true); // external object (seg.data.mm_addr is offset in this addr)
                    } else {
                        dma_dcache_short_command(((COMMAND_SEGMENT *) (seg_cnt))->data, 0, true);
                    }
                } else {
                    dma_dcache_short_command(((COMMAND_SEGMENT *) (seg_cnt))->data, 0, true);
                }
            }
//            printf_warning("DMA BLOCK Segment trigger finished! [size; %i, end: %li]\n", block_size, seg_cnt);
#else
            dma_block_size(block_size);
            dma_block_addr_trigger((void *)(seg_cnt + sizeof(COMMAND_SEGMENT)));
            seg_cnt += block_size * sizeof(COMMAND_SEGMENT);
#endif
        } else if (((COMMAND_SEGMENT *) (seg_cnt))->type == BOTH_SYNC) {
#ifndef SIMULATION
            // load dcache line for segments to avoid dcache stall in next loop iterations
                    {
                        auto dcache_line_size_bytes = 4096; // 1024 Bytes in 64 x 128-bit words
                        [[maybe_unused]] volatile auto tmp = *(reinterpret_cast<const uint8_t *>(seg_cnt) + dcache_line_size_bytes);
                    }
#endif
            vpro_sync();
        } else if (((COMMAND_SEGMENT *) (seg_cnt))->type == DMA_WAIT) {
//            printf("[SYNC DMA]\n");
#if defined(RV_PRINT_SEGMENT_CNT)
            dma_sync++;
#endif
#ifndef SIMULATION
            // load dcache line for segments to avoid dcache stall in next loop iterations
                    {
                        auto dcache_line_size_bytes = 4096; // 1024 Bytes in 64 x 128-bit words
                        [[maybe_unused]] volatile auto tmp = *(reinterpret_cast<const uint8_t *>(seg_cnt) + dcache_line_size_bytes);
                    }
#endif
            vpro_dma_sync();
//            dma_wait_to_finish(0xffffffff);
        } else if (((COMMAND_SEGMENT *) (seg_cnt))->type == VPRO_WAIT) {
//            printf("[SYNC VPRO]\n");
#if defined(RV_PRINT_SEGMENT_CNT)
            vpro_sync++;
#endif
#ifndef SIMULATION
            // load dcache line for segments to avoid dcache stall in next loop iterations
                    {
                        auto dcache_line_size_bytes = 4096; // 1024 Bytes in 64 x 128-bit words
                        [[maybe_unused]] volatile auto tmp = *(reinterpret_cast<const uint8_t *>(seg_cnt) + dcache_line_size_bytes);
                    }
#endif
            vpro_lane_sync();
//            vpro_wait_busy(0xffffffff, 0xffffffff);
        } else if (((COMMAND_SEGMENT *) (seg_cnt))->type == DMA_SEG) {
//            printf("[DMA]\n");
#if defined(RV_PRINT_SEGMENT_CNT)
            dmas++;
#endif
//            const COMMAND_DMA::COMMAND_DMA &dma = *reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(seg.data);
//            if (dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l1D) {
//                printf("[DMA] pad_0: %s, pad_1: %s, pad_2: %s, pad_3: %s\n", (dma.pad_0?"true":"false"),
//                       (dma.pad_1?"true":"false"), (dma.pad_2?"true":"false"), (dma.pad_3?"true":"false"));
//            }

            // shortcut issue via dcache parallel read
#ifdef SIMULATION
            const COMMAND_DMA::COMMAND_DMA &dma = *reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(((COMMAND_SEGMENT *) (seg_cnt))->data);
            if (dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l1D ||
                dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l2D) {
                if (dma.isKernelOffset || dma.isBiasOffset) {
                    dma_dcache_short_command(((COMMAND_SEGMENT *) (seg_cnt))->data,
                                             weight_addr_offset); // external object (seg.data.mm_addr is offset in this addr)
                } else {
                    dma_dcache_short_command(((COMMAND_SEGMENT *) (seg_cnt))->data);
                }
            } else {
                dma_dcache_short_command(((COMMAND_SEGMENT *) (seg_cnt))->data);
            }
#else
            *dcache_short_hw = uint32_t(intptr_t(((COMMAND_SEGMENT *)(seg_cnt))->data));
//                dma_dcache_short_command(((COMMAND_SEGMENT *)(seg_cnt))->data);
#endif
//            const COMMAND_DMA::COMMAND_DMA &dma = *reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(seg.data);
//            if (dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l1D) {
//                dma_ext1D_to_loc1D_broadcast(dma.cluster, dma.unit_mask, dma.mm_addr, dma.lm_addr, dma.x_size);
//            } else if (dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l2D) {
//                bool pad[4] = {dma.pad_0, dma.pad_1, dma.pad_2, dma.pad_3};
//                dma_ext2D_to_loc1D_broadcast(dma.cluster, dma.unit_mask, dma.mm_addr, dma.lm_addr, dma.x_stride,
//                                             dma.x_size, dma.y_size, pad);
//            } else if (dma.direction == COMMAND_DMA::DMA_DIRECTION::l2e1D) {
//                dma_loc1D_to_ext1D(dma.cluster, dma.mm_addr, dma.lm_addr, dma.x_size);
//            } else if (dma.direction == COMMAND_DMA::DMA_DIRECTION::l2e2D) {
//                dma_loc1D_to_ext2D(dma.cluster, dma.mm_addr, dma.lm_addr, dma.x_stride, dma.x_size, dma.y_size);
//            }
        } else {
            // not recognized segment type
            // check segment address, generation (endianess), values, ...
            aux_print_debugfifo(0xdead1009);
            printf("\n[Error] Segment type unknown!\n");
            printf("Segment.type 0x%8x\n", (unsigned int) ((COMMAND_SEGMENT *) (seg_cnt))->type);
            printf("Segment[%u] @ 0x%8x\n", (unsigned int) ((seg_cnt - start_segment) / sizeof(COMMAND_SEGMENT)),
                   (unsigned int) uint32_t(seg_cnt));
            exit(1);
        } // case    / if
    } // for all cmd segments


#ifdef SIMULATION
    //    printProgress(percent, 60);
    printf("\n");
    printf("[LAYER %i] took %i cycles\n", layer.number, aux_get_cycle_cnt() - startclock);
    printf("[Clock] %i cycles\n", aux_get_cycle_cnt());
#elif defined(RV_PRINT_SEGMENT_CNT)
    printf("\r      0 Segments Remaining\n");
    printf("\tDMA Segments: %i\n", dmas);
    printf("\tVPRO Segments: %i\n", vpros);
    printf("\tDMA Sync Segments: %i\n", dma_sync);
    printf("\tVPRO Sync Segments: %i\n", vpro_sync);
#endif
}
