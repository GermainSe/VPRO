//
// Created by gesper on 11.11.20.
//


#ifndef CNN_YOLO_LITE_CNN_STRUCT_REDUCED_H
#define CNN_YOLO_LITE_CNN_STRUCT_REDUCED_H

#include <stdint.h>
#include "cnn_enums.h"
#include <vpro/dma_cmd_struct.h>
#include <cstring>
#include <string>
#include <iomanip>

/**
 * COMMAND (Segment) storage
 *  either DMA or VPRO Command
 */
struct COMMAND_SEGMENT {
    // start @ address inside struct @ 0x0
//    COMMAND_DMA::COMMAND_DMA
//    dma: 28 x 8-bit
//    COMMAND_SEGMENT::COMMAND_VPRO
//    vpro: 20 x 8-bit
    uint8_t data[31]{0};

    COMMAND_SEGMENT_TYPE type{UNKNOWN};

    // alignment in risc !
    // if COMMAND_SEGMENT size is 29 [28 data + 1 type]
    //      elements inside (accessed by LH/LW, as well for uint8_t)
    //      cause MEM-stage exception due to misaligned access
    //      array of segments need to align those to word-boundarys (COMMAND_Segment size multiple of 4-Byte)
    // dma_direct_command aligned 32 byte to reduce dcache complexity
};

struct COMMAND_VPRO {
    VPRO_TYPE command{};
    uint8_t lane{};
    uint16_t buffer{};
//    bool four_way{};
//    uint16_t xend_1[4]{}, xend_2[4]{}, yend[4]{}, offset[4]{};
    uint16_t xend_1{}, xend_2{}, yend{}, offset{};
//    uint16_t *dst_offset = xend_2;

    uint16_t kernel_load_buffer_l0{};
    uint16_t kernel_load_buffer_l1{};
    uint16_t bias_load_buffer_l0{};
    uint16_t bias_load_buffer_l1{};

    std::string to_string() const {
      std::stringstream ss;
        ss << "VPRO_CMD, ";
        switch (command) {
        case conv_start : ss << "conv_start" ; break;
        case conv_add   : ss << "conv_add"   ; break;
        case relu_pool  : ss << "relu_pool"  ; break;
        case shift_store: ss << "shift_store"; break;
        case residual   : ss << "residual"   ; break;
        }
        ss << ", lane " << uint32_t(lane)
           << ", buffer " << buffer
           << ", xend_1 " << xend_1
           << ", xend_2 " << xend_2
           << ", yend " << yend
           << ", offset " << offset
           << ", kernel_load_buffer_l0 " << kernel_load_buffer_l0
           << ", kernel_load_buffer_l1 " << kernel_load_buffer_l1
           << ", bias_load_buffer_l0 " << bias_load_buffer_l0
           << ", bias_load_buffer_l1 " << bias_load_buffer_l1 << "\n";
        return ss.str();        
    }
};

struct SEGMENT {
    SEGMENT() :
            in_MM_base_0(0), in_MM_base_1(0), in_MM_x_stride_0(0), in_MM_x_stride_1(0),
            out_MM_base(0), out_MM_x_stride(0),
            x_seg(0), y_seg(0), in_channel(0), out_channel(0),
            dummy(false), isLast(false), isFirst(false),
            pad_top(false), pad_right(false), pad_bottom(false), pad_left(false){    };

    uint32_t in_MM_base_0;
    uint32_t in_MM_base_1;
    int32_t in_MM_x_stride_0;
    int32_t in_MM_x_stride_1;

    uint32_t out_MM_base;
    int32_t out_MM_x_stride;

    int32_t x_seg;
    int32_t y_seg;
    int32_t in_channel; // segment info about #in_channel to get correct kernel
    int32_t out_channel;

    bool dummy; // if set, this segment is not written back into LM/MM
    bool isLast; // if set, this segment is last to be calculated in one lane
    bool isFirst; // if set, this segment is first to be calc (no accumulate of result)

    bool pad_top;
    bool pad_right;
    bool pad_bottom;
    bool pad_left;

    std::string to_string() const {
      std::stringstream ss;
      ss << std::setfill('0') 
         << "in_MM_base_0 0x"    << std::hex << std::setw(8) << in_MM_base_0     << "\n"
         << "in_MM_base_1 0x"    << std::hex << std::setw(8) << in_MM_base_1     << "\n"
         << "in_MM_x_stride_0 "  << std::dec                 << in_MM_x_stride_0 << "\n"
         << "in_MM_x_stride_1 "  << std::dec                 << in_MM_x_stride_1 << "\n"
         << "out_MM_base 0x"     << std::hex << std::setw(8) << out_MM_base      << "\n"
         << "out_MM_x_stride "   << std::dec                 << out_MM_x_stride  << "\n"
         << "x_seg "                                         << x_seg            << "\n"
         << "y_seg "                                         << y_seg            << "\n"
         << "in_channel "                                    << in_channel       << "\n"
         << "out_channel "                                   << out_channel      << "\n"
         << "dummy "                                         << dummy            << "\n"
         << "isLast "                                        << isLast           << "\n"
         << "isFirst "                                       << isFirst          << "\n"
         << "pad_top "                                       << pad_top          << "\n"
         << "pad_right "                                     << pad_right        << "\n"
         << "pad_bottom "                                    << pad_bottom       << "\n"
         << "pad_left "                                      << pad_left         << "\n";
      return ss.str();
    }
};


/**
 *  WEIGHTS storage
 * @tparam in_channel
 * @tparam out_channel
 * @tparam kernel_length
 */
template <int in_channel, int out_channel, int kernel_length = 3>
struct WEIGHTS_REDUCED{
    int16_t kernel[in_channel][out_channel][kernel_length*kernel_length]{};
    int16_t bias[out_channel]{};
};

/**
 * LAYER storage
 */
struct PAD_REDUCED{
//    PAD_REDUCED()= default;
    int32_t top;
    int32_t left;
    int32_t bottom;
    int32_t right;
    int32_t value;
};

struct MM_IMAGE{
    uint32_t mm_base;
    uint32_t x;
    uint32_t y;
    uint32_t x_stride;
    uint32_t channels;
};
struct LAYER_WRAPPER {
//    LAYER_WRAPPER(int in = 1, int out = 1, int kernel_l = 3, int nr = 0):
//            in_channels(in), out_channels(out), number(nr), kernel_length(kernel_l)
//    { };
//    LAYER_WRAPPER() = default;

    uint16_t in_channels;
    uint16_t out_channels;
    uint16_t number;
    LAYERTYPE::LAYERTYPE type;

    uint16_t stride;
    uint16_t kernel_length;
    uint16_t seg_out_w;
    uint16_t seg_out_h;
    uint16_t seg_in_w;
    uint16_t seg_in_h;

    int16_t conv_result_shift_right;
    int16_t relu_6_shift_left;
    int16_t bias_shift_right;
    int16_t store_shift_right;
    int16_t residual_1_left_shift;
    int16_t residual_0_left_shift;
    uint16_t pool_stride;

    RELUTYPE::RELUTYPE relu_type;
    PAD_REDUCED pad;

    MM_IMAGE input;
    MM_IMAGE output;

//    uint32_t num_segments{};  // Removed. together with boundary ext see below
//    uint8_t align_pad[4]{}; // to match 128-bit / 8 byte boundary for transfer with uemu...
};

#endif //CNN_YOLO_LITE_CNN_STRUCT_REDUCED_H
