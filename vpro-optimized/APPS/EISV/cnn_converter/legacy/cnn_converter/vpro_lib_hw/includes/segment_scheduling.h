

#ifndef segment_scheduling
#define segment_scheduling

#ifdef SIMULATION
#include "cnn_struct.h"
#else
#include "cnn_struct_reduced.h"
#endif

#include <vpro/dma_cmd_struct.h>
#include "defines.h"
#include "vpro_functions.h"

/**
 * main VPRO Function to execute the layers calculations
 * performs management of segments related to this layer and starts/waits for DMA and VPRO
 *   INPUT -> OUTPUT
 *   basis is convolution2D, bias and shift
 *   uses functions of the VPRO (LOAD, MAC, ADD, SHIFT, STORE)
 *   uses functions of the DMA (1D_to_2D, 2D_to_2D)
 *   beforms calculation in segments as defined in layer using double buffering
 *
 * @param layer
 */
//void calcLayer(const LAYER_WRAPPER &layer, SEGMENT* segments, int seg_size);
void calcLayer(const LAYER_WRAPPER &layer, const COMMAND_SEGMENT *segments, const void *conv, uint32_t seg_size, const uint32_t weight_addr_offset);

struct DMA_DESCRIPTOR{
    DMA_DESCRIPTOR()
    {
        pad[0] = false;
        pad[1] = false;
        pad[2] = false;
        pad[3] = false;
    }

    bool isMM_Kernel_offset{};
    bool isMM_Bias_offset{};

    COMMAND_DMA::DMA_DIRECTION dir{};
    uint32_t cluster{};
    uint32_t unit{};
    uint64_t mm_addr{};
    uint32_t lm_addr{};
    uint32_t x_size{};
    uint32_t y_size{};
    uint32_t word_count{};
    uint32_t x_stride{};
    bool pad[4]{};
};


#endif
