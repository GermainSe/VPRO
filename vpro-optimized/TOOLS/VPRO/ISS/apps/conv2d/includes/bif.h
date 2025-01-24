//
// Created by gesper on 27.01.23.
//

#ifndef CONV2D_BIF_H
#define CONV2D_BIF_H

#include "conv.h"
#include "vpro/dma_cmd_struct.h"

#ifdef SIMULATION
#include <iostream>
#include <fstream>
#else
class ofstream;
#endif


enum Type : uint8_t{
    DMA = 1,    // load or store
    PROCESS = 2,
    DMA_LOOP = 5,
    SYNC = 4
};

struct COMMAND {
    COMMAND_DMA::DMA_DIRECTION direction{};
    uint8_t unused{0}; // no longer used by hardware but still useful for debug
    uint8_t unused2{0}; // no longer used by hardware but still useful for debug
    // switch padding on/off per transfer; padding length is configured layer-wide via LAYER.pad
    uint8_t padding{}; // 7 downto 0 := '3 = left, '2 = bottom, '1 = right, '0 = top |  order see CommandDMA::PAD

    uint32_t cluster{}; // index when generated by layer, turned into a bit mask by DmaBlockExtension
    uint32_t unit_mask{};
    uint32_t mm_addr{}; // byte address of first non-padding element

    uint16_t unused3{0};
    uint16_t block_size{0};  //

    uint32_t lm_addr{}; // word address
    uint16_t y_leap{}; // distance of last transferred element in row n to first element of row n+1; =1 for gapless
    // misleadingly called "x_stride" in ISS and HW
    uint16_t x_size{}; // in 16-bit words
    uint16_t y_size{}; // in 16-bit words
    Type type{DMA};

    COMMAND()= default;

    bool equals(const COMMAND &ref) const {
        bool equal = true;
        equal &= (ref.direction == direction);
//      equal &= (ref.isBiasOffset == isBiasOffset);
//      equal &= (ref.isKernelOffset == isKernelOffset);
        equal &= (ref.cluster == cluster);
        equal &= (ref.unit_mask == unit_mask);
        //equal &= (ref.mm_addr == mm_addr);//FIXME: uncomment this, once MM addresses are handled correctly
        equal &= (ref.lm_addr == lm_addr);
        equal &= (ref.y_leap == y_leap);
        equal &= (ref.x_size == x_size);
        equal &= (ref.y_size == y_size);
        equal &= (ref.padding == padding);
        return equal;
    }
};
static_assert(sizeof(COMMAND) == 32);

struct COMMAND_DMA_LOOP {
    COMMAND_DMA::DMA_DIRECTION direction{COMMAND_DMA::loop};// '0.
    uint8_t cluster_loop_len{};
    int8_t cluster_loop_shift_incr{};
    uint8_t unit_loop_len{};

    int8_t unit_loop_shift_incr{};  // '1.
    uint8_t inter_unit_loop_len{};
    uint8_t struct_padding0[2]{};

    int16_t lm_incr{};  // 13-bit signed! // '2.
    uint8_t struct_padding1[2]{};

    int32_t mm_incr{}; // '3.

    uint16_t dma_cmd_count{};// '4.
    uint16_t block_size{0};//pad structure to 32 byte
    uint8_t struct_padding2[10]{};//pad structure to 32 byte
    Type type{DMA_LOOP};

    const char *to_char() const {
        static char buf[1024];
        sprintf(buf, " DMA LOOP, " "cluster_loop_len %d, " "cluster_loop_shift_incr %d, " "unit_loop_len %d, "
                     "unit_loop_shift_incr %d, " "inter_unit_loop_len %d, " "lm_incr 0x%04" PRIx32 ", " "mm_incr 0x%08" PRIx32 ", "
                     "dma_cmd_count %d",
                cluster_loop_len, cluster_loop_shift_incr, unit_loop_len, unit_loop_shift_incr,
                inter_unit_loop_len, lm_incr, mm_incr, dma_cmd_count);
        return buf;
    }

    bool equals(const COMMAND_DMA_LOOP &ref) const {
        bool equal = true;
        equal &= (ref.direction == direction);
        equal &= (ref.cluster_loop_len == cluster_loop_len);
        equal &= (ref.cluster_loop_shift_incr == cluster_loop_shift_incr);
        equal &= (ref.unit_loop_len == unit_loop_len);
        equal &= (ref.unit_loop_shift_incr == unit_loop_shift_incr);
        equal &= (ref.inter_unit_loop_len == inter_unit_loop_len);
        equal &= (ref.lm_incr == lm_incr);
        equal &= (ref.mm_incr == mm_incr);
        equal &= (ref.dma_cmd_count == dma_cmd_count);
        return equal;
    }
};
static_assert(sizeof(COMMAND_DMA_LOOP) == 32);

void dump(COMMAND c);

void dump(COMMAND c, ofstream &out);

#endif //CONV2D_BIF_H
