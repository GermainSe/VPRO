//
// Created by gesper on 06.04.22.
//

#include "segment_creation_vpro.h"
//#include "../configuration_loader/yolo_configuration.h"
#include <helper.h>
#include <vpro_functions.h>

COMMAND_SEGMENT createVPRO_wait() {
    COMMAND_SEGMENT seg;
    seg.type = VPRO_WAIT;
    return seg;
}

COMMAND_SEGMENT createVPRO_Conv_start(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc,
                                      bool addConvResultToSegmentInRF) {
    COMMAND_SEGMENT seg;
    seg.type = VPRO_SEG;

    if (layer.conv_result_shift_right < 0) {
        printf_error("Kernel to be shifted negative! -- not implemented\n");
    }
    if (layer.conv.stride != 1) {
        printf_error("CONV start with stride not needed in YOLO LITE -> implementation missing !!!!!!!!\n");
    }
    if (addConvResultToSegmentInRF) {
        printf_error("CONV Start with addd!!!!!!!!\n");
    }

    reinterpret_cast<COMMAND_VPRO *>(seg.data)->command = VPRO_TYPE::conv_start;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->buffer = (int(buffer_calc) * 4096); // TODO: check _vpro_conv()

    // kernel load
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->kernel_load_buffer_l0 =
            (int(buffer_calc) * 4096) + 4096 - (kernel_x * kernel_y * (0 + 1));
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->kernel_load_buffer_l1 =
            (int(buffer_calc) * 4096) + 4096 - (kernel_x * kernel_y * (1 + 1));

    // bias load
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->bias_load_buffer_l0 =
            (int(buffer_calc) * 4096) + 4096 - (kernel_x * kernel_y * 2) - 1 - 0;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->bias_load_buffer_l1 =
            (int(buffer_calc) * 4096) + 4096 - (kernel_x * kernel_y * 2) - 1 - 1;

    return seg;
}

COMMAND_SEGMENT
createVPRO_Conv_add(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc, bool addConvResultToSegmentInRF) {
    COMMAND_SEGMENT seg;
    seg.type = VPRO_SEG;

    if (layer.conv_result_shift_right < 0) {
        printf_error("Kernel to be shifted negative! -- not implemented\n");
    }
    if (layer.conv.stride != 1) {
        printf_error("CONV add with stride not needed in YOLO LITE -> implementation missing !!!!!!!!\n");
    }
    if (!addConvResultToSegmentInRF) {
        printf_error("CONV Add without addd!!!!!!!!\n");
    }

    reinterpret_cast<COMMAND_VPRO *>(seg.data)->command = VPRO_TYPE::conv_add;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->buffer = (int(buffer_calc) * 4096); // TODO: check _vpro_conv()

    // kernel load
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->kernel_load_buffer_l0 =
            (int(buffer_calc) * 4096) + 4096 - (kernel_x * kernel_y * (0 + 1));
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->kernel_load_buffer_l1 =
            (int(buffer_calc) * 4096) + 4096 - (kernel_x * kernel_y * (1 + 1));

    return seg;
}

COMMAND_SEGMENT createVPRO_Residual(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc) {
    COMMAND_SEGMENT seg;
    seg.type = VPRO_SEG;

    printf_error("Residual -> implementation missing !!!!!!!!\n");

    reinterpret_cast<COMMAND_VPRO *>(seg.data)->command = VPRO_TYPE::residual;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->buffer = (int(buffer_calc) * 4096);

    if (layer.conv.seg_out_w != layer.conv.seg_out_h)
        printf_error("out X != out Y   [not handled case to store segment to LM!!!!!]");

    // for small segment sizes (max (MAX_X_END+1) x (MAX_X_END+1))
    uint32_t segment_size = (layer.conv.seg_out_w < (MAX_X_END + 1)) ? layer.conv.seg_out_w : (MAX_X_END + 1);

    // large segment size split into (2x2 parts) top left (with max size of (MAX_X_END+1) x (MAX_X_END+1) -- already processed)
    // parts below and right of top left segment part ((MAX_X_END+1)x(MAX_X_END+1))
    int32_t remaining = layer.conv.seg_out_w - (MAX_X_END + 1);
    if (layer.conv.seg_out_w < (MAX_X_END + 1))
        remaining = 0;
    // top left (size up to: (MAX_X_END+1) x (MAX_X_END+1))
    uint32_t offset_tl = 0;
    // bottom left (size: (MAX_X_END+1) x remain)
//    uint32_t offset_bl = (MAX_X_END + 1) * layer.conv.seg_out_w;
    // top right (size: remain x (MAX_X_END+1))
//    uint32_t offset_tr = (MAX_X_END + 1);
    // bottom right (size: square; remain x remain)
//    uint32_t offset_br = (MAX_X_END + 1) * layer.conv.seg_out_w + (MAX_X_END + 1);

    reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1 = segment_size - 1;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend = segment_size - 1;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset = offset_tl;
//    _residual(layer, buffer_calc, segment_size - 1, segment_size - 1, 0);
//    reinterpret_cast<COMMAND_VPRO *>(seg.data)->four_way = false;
    if (remaining > 0) {
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->four_way = true;

        printf_error(
                "Segment has more than one blob for Residual, modifications needed! segment should store 4x data... \n");

//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[1] = remaining - 1;
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[1]   = remaining - 1;
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[1] = offset_br;
//
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[2] = MAX_X_END;
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[2]   = remaining - 1;
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[2] = offset_bl;
//
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[3] = remaining - 1;
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[3]   = MAX_X_END;
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[3] = offset_tr;

//        _residual(layer, buffer_calc, remaining - 1, remaining - 1, offset_br);
//        _residual(layer, buffer_calc, MAX_X_END, remaining - 1, offset_bl);
//        _residual(layer, buffer_calc, remaining - 1, MAX_X_END, offset_tr);
    }

    return seg;
}

COMMAND_SEGMENT createVPRO_ShiftStore(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc, int lane) {
    COMMAND_SEGMENT seg;
    seg.type = VPRO_SEG;

    reinterpret_cast<COMMAND_VPRO *>(seg.data)->command = VPRO_TYPE::shift_store;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->lane = lane;
    reinterpret_cast<COMMAND_VPRO *>(seg.data)->buffer = (int(buffer_calc) * 4096) + lane * 1024;

    // for small segment sizes (max (MAX_X_END+1)x(MAX_X_END+1))
    uint32_t segment_size = (layer.conv.seg_out_w < (MAX_X_END + 1)) ? layer.conv.seg_out_w : (MAX_X_END + 1);
    if (segment_size > MAX_X_END + 1) {
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->four_way = true;
        printf_error(
                "Segment has more than one blob for Store, modifications needed! segment should store 4x data... \n");

//        // large segment size split into (2x2 parts) top left (with max size of (MAX_X_END+1) x (MAX_X_END+1) -- already processed)
//        // parts below and right of top left segment part ((MAX_X_END+1) x (MAX_X_END+1))
//        int32_t remaining = layer.conv.seg_out_w - (MAX_X_END + 1);
//        if (layer.conv.seg_out_w < (MAX_X_END + 1))
//            remaining = 0;
//        // top left (size up to: (MAX_X_END+1) x (MAX_X_END+1))
//        uint32_t offset_tl = 0;
//        // bottom left (size: (MAX_X_END+1) x remain)
//        uint32_t offset_bl = (MAX_X_END + 1) * layer.conv.seg_out_w;
//        // top right (size: remain x (MAX_X_END+1))
//        uint32_t offset_tr = (MAX_X_END + 1);
//        // bottom right (size: square; remain x remain)
//        uint32_t offset_br = (MAX_X_END + 1) * layer.conv.seg_out_w + (MAX_X_END + 1);
//
//        if (layer.pool.stride == 1) {
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[0] = segment_size - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[0]   = segment_size - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[0] = offset_tl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[1] = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[1]   = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[1] = offset_br;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[2] = MAX_X_END;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[2]   = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[2] = offset_bl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[3] = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[3]   = MAX_X_END;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[3] = offset_tr;
//
////            _shift_store(layer, buffer_calc, segment_size - 1, segment_size - 1, 0, lane);
////            _shift_store(layer, buffer_calc, remaining - 1, remaining - 1, offset_br, lane);
////            _shift_store(layer, buffer_calc, MAX_X_END, remaining - 1, offset_bl, lane);
////            _shift_store(layer, buffer_calc, remaining - 1, MAX_X_END, offset_tr, lane);
//        } else { // stride of pooling
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[0] = (segment_size / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[0]   = (segment_size / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[0] = 0; // dst_offset
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[0] = offset_tl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[1] = (remaining / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[1]   = (remaining / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[1] = 8 * (layer.conv.seg_out_w / 2) + 8; // dst_offset
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[1] = offset_br;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[2] = ((MAX_X_END + 1) / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[2]   = (remaining / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[2] = offset_bl / 4; // dst_offset
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[2] = offset_bl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[3] = (remaining / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[3]   = ((MAX_X_END + 1) / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[3] = offset_tr / 2;  // dst_offset
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[3] = offset_tr;
//
////            _shift_store_pool(layer, buffer_calc, (segment_size / 2) - 1, (segment_size / 2 - 1),
////                              0, 0, lane);
////            _shift_store_pool(layer, buffer_calc, (remaining / 2) - 1, (remaining / 2) - 1,
////                              offset_br_scale, offset_br, lane);
////            _shift_store_pool(layer, buffer_calc, ((MAX_X_END + 1) / 2) - 1, (remaining / 2) - 1,
////                              offset_bl / 4, offset_bl, lane);
////            _shift_store_pool(layer, buffer_calc, (remaining / 2) - 1, ((MAX_X_END + 1) / 2) - 1,
////                              offset_tr / 2, offset_tr, lane);
//        } // stride of pooling
    } else {
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->four_way = false;
        if (layer.pool.stride == 1) {
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1 = segment_size - 1;
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend = segment_size - 1;
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset = 0;
//            _shift_store(layer, buffer_calc, segment_size - 1, segment_size - 1, 0, lane);
        } else {
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1 = (segment_size / 2) - 1;
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend = (segment_size / 2) - 1;
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2 = 0; // dst_offset
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset = 0;
//            _shift_store_pool(layer, buffer_calc, (segment_size / 2) - 1, (segment_size / 2 - 1), 0, 0, lane);
        }
    }

    return seg;
}

COMMAND_SEGMENT createVPRO_ReluPool(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc) {
    COMMAND_SEGMENT seg;
    seg.type = VPRO_SEG;

    reinterpret_cast<COMMAND_VPRO *>(seg.data)->command = VPRO_TYPE::relu_pool;
    if (layer.conv.seg_out_w <= (MAX_X_END + 1)) { // one blob
//        reinterpret_cast<COMMAND_VPRO *>(seg.data)->four_way = false;
    } else {
        printf_error(
                "Segment has more than one blob for RELU + POOL, modifications needed! segment should store 4x data... \n");
    }

    if (layer.conv.seg_out_w <= (MAX_X_END + 1)) { // one blob
        if (layer.pool.stride == 1) {         // no pooling
            // only layer informations are relevant!
        } else {                             // with pooling
            // precalc layer informations:
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1 = layer.conv.seg_out_w - 1;
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2 = ((layer.conv.seg_out_w) / 2) - 1;
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend = layer.conv.seg_out_w - 1;
            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset = 0;
        }
    } else { // 4 blobs
//        uint32_t segment_size = (layer.conv.seg_out_w < (MAX_X_END + 1)) ? layer.conv.seg_out_w : (MAX_X_END + 1);
//
//        // large segment size split into (2x2 parts) top left (with max size of (MAX_X_END+1) x (MAX_X_END+1) -- already processed)
//        // parts below and right of top left segment part ((MAX_X_END+1) x (MAX_X_END+1))
//        int32_t remaining = layer.conv.seg_out_w - segment_size;
//        // top left (size up to: (MAX_X_END+1) x (MAX_X_END+1))
//        uint32_t offset_tl = 0;
//        // bottom left (size: (MAX_X_END+1) x remain)
//        uint32_t offset_bl = (MAX_X_END + 1) * layer.conv.seg_out_w;
//        // top right (size: remain x (MAX_X_END+1))
//        uint32_t offset_tr = (MAX_X_END + 1);
//        // bottom right (size: square; remain x remain)
//        uint32_t offset_br = (MAX_X_END + 1) * layer.conv.seg_out_w + (MAX_X_END + 1);
//
//        if (layer.pool.stride == 1) {         // no pooling
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[0] = segment_size - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[0]   = segment_size - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[0] = offset_tl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[1] = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[1]   = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[1] = offset_br;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[2] = MAX_X_END;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[2]   = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[2] = offset_bl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[3] = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[3]   = MAX_X_END;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[3] = offset_tr;
//
////            _relu_leaky(layer, segment_size - 1, segment_size - 1, offset_tl);
////            _relu_leaky(layer, remaining - 1, remaining - 1, offset_br);
////            _relu_leaky(layer, MAX_X_END, remaining - 1, offset_bl);
////            _relu_leaky(layer, remaining - 1, MAX_X_END, offset_tr);
////
////            _relu_rect(layer, segment_size - 1, segment_size - 1, offset_tl);
////            _relu_rect(layer, remaining - 1, remaining - 1, offset_br);
////            _relu_rect(layer, MAX_X_END, remaining - 1, offset_bl);
////            _relu_rect(layer, remaining - 1, MAX_X_END, offset_tr);
////
////            _relu_6(layer, segment_size - 1, segment_size - 1, offset_tl);
////            _relu_6(layer, remaining - 1, remaining - 1, offset_br);
////            _relu_6(layer, MAX_X_END, remaining - 1, offset_bl);
////            _relu_6(layer, remaining - 1, MAX_X_END, offset_tr);
//
//        } else {                              // with pooling
//
//            // only for pooling step + mixed other vars // TODO: _vpro_pool-...
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[0] = segment_size - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[1] = remaining - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[2] = MAX_X_END;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_2[3] = 0; // unused
//
////            _pool(layer, segment_size - 1, (segment_size / 2) - 1, segment_size - 1, offset_tl);
////            _pool(layer, remaining - 1, (remaining / 2) - 1, remaining - 1, offset_br);
////            _pool(layer, MAX_X_END, ((MAX_X_END + 1) / 2) - 1, remaining - 1, offset_bl);
////            _pool(layer, remaining - 1, (remaining / 2) - 1, MAX_X_END, offset_tr);
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[0] = (segment_size / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[0]   = (segment_size / 2 - 1);
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[0] = offset_tl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[1] = (remaining / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[1]   = (remaining / 2 - 1);
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[1] = offset_br;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[2] = ((MAX_X_END + 1) / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[2]   = (remaining / 2 - 1);
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[2] = offset_bl;
//
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->xend_1[3] = (remaining / 2) - 1;
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->yend[3]   = ((MAX_X_END + 1) / 2 - 1);
//            reinterpret_cast<COMMAND_VPRO *>(seg.data)->offset[3] = offset_tr;
//
////            _relu_leaky_pool(layer, (segment_size / 2) - 1, (segment_size / 2 - 1), offset_tl);
////            _relu_leaky_pool(layer, (remaining / 2) - 1, (remaining / 2 - 1), offset_br);
////            _relu_leaky_pool(layer, ((MAX_X_END + 1) / 2) - 1, (remaining / 2 - 1), offset_bl);
////            _relu_leaky_pool(layer, (remaining / 2) - 1, ((MAX_X_END + 1) / 2 - 1), offset_tr);
////
////            _relu_rect_pool(layer, (segment_size / 2) - 1, (segment_size / 2 - 1), offset_tl);
////            _relu_rect_pool(layer, (remaining / 2) - 1, (remaining / 2 - 1), offset_br);
////            _relu_rect_pool(layer, ((MAX_X_END + 1) / 2) - 1, (remaining / 2 - 1), offset_bl);
////            _relu_rect_pool(layer, (remaining / 2) - 1, ((MAX_X_END + 1) / 2 - 1), offset_tr);
////
////            _relu_6_pool(layer, (segment_size / 2) - 1, (segment_size / 2 - 1), offset_tl);
////            _relu_6_pool(layer, (remaining / 2) - 1, (remaining / 2 - 1), offset_br);
////            _relu_6_pool(layer, ((MAX_X_END + 1) / 2) - 1, (remaining / 2 - 1), offset_bl);
////            _relu_6_pool(layer, (remaining / 2) - 1, ((MAX_X_END + 1) / 2 - 1), offset_tr);
//        }
    }
    return seg;
}