#ifndef POINTPILLARS_KERNEL_H
#define POINTPILLARS_KERNEL_H

#include "bif.h"
#include "riscv/eisV_hardware_info.hpp"
#include "memutils.h"
#include "conv1d_kernel.h"
#include "activation_kernel.h"
#include "../segment_scheduling.h"

#define PP_N_SEGMENTS 100
#define PP_SEG_OUT_SIZE 576

using namespace BIF;

#define ZEND_UNINITIALIZED -1

inline void _pool_scatter(uint32_t zend, uint32_t lm_result_base, uint32_t lm_index_base, uint32_t rf_conv_base) {
    // RF memory layout:
    // [0, seg_out_size):                       2D output segment
    // [seg_out_size, seg_out_size+seg_len):    point-wise features
    // Indices of the points within the output segment are chained via L/S lane.
    // Indirect addressing is used in max-operation to get the current maximum
    // at the index (SRC1) and write the updated maximum back to the index (DST)

    // initialize output segment with zeros
    VPRO::DIM3::PROCESSING::add(
        L0_1,
        DST_ADDR(0, 0, 0, 1),
        SRC1_IMM_3D(0),
        SRC2_IMM_3D(0),
        0, 0, PP_SEG_OUT_SIZE-1
    );
    // stall by W2R_BUBBLE_CYCLES+1 cycles, in case subsequent max-pooling directly addresses
    // one of the last elements in the output segment
    insertNops(W2R_BUBBLE_CYCLES+1, L0_1);

    // chain segment indices from L/S lane
    VPRO::DIM3::LOADSTORE::load(
        lm_index_base, // lm_offset
        0, 0, 0, 1, // offset, alpha, beta, gamma
        4-1, 0, zend // xend, yend, zend
    );

    // pool and scatter
    VPRO::DIM3::PROCESSING::max(
        L0_1,
        DST_INDIRECT_LS(),
        SRC1_INDIRECT_LS(),
        SRC2_ADDR(rf_conv_base, 0, 0, 1),
        4-1, 0, zend // repeat 4 times for each element to avoid data hazards
    );    
}

inline void reset_indices_lm(uint32_t lm_base, uint32_t zend) {
    VPRO::DIM3::PROCESSING::add(
        L0,
        DST_ADDR(0, 0, 0, 0),
        SRC1_IMM_3D(RF_DISCARD_ADDR),
        SRC2_IMM_3D(0),
        0, 0, zend,
        true
    );
    VPRO::DIM3::LOADSTORE::store(
        lm_base,
        0, 0, 0, 1,
        0, 0, zend,
        L0
    );
}

inline void read_grid_segmentation(const LAYER &layer, uint16_t point_counts[PP_N_SEGMENTS], uint16_t seg_offsets[PP_N_SEGMENTS]) {

    // read number of points per segment, last element in point_counts stores total number of points
    _memcopy_vpro(0x1, intptr_t(point_counts), intptr_t(layer.input.mm_base), PP_N_SEGMENTS);
    aux_flush_dcache();
    dma_wait_to_finish(0x1); // wait until copy of point_counts is finished
    aux_clr_dcache(); // make sure cache is refreshed when accessing point_counts
    dcma_flush();
    // calculate offset to respective segment based on point counts
    for (uint seg=0, off=0; seg < PP_N_SEGMENTS; seg++) {
        seg_offsets[seg] = off;
        off += sizeof(int16_t) * point_counts[seg];
    }
}

inline uint16_t dynamic_dma_block(const LAYER &layer, const COMMAND_SEGMENT* cmd, const uint16_t point_counts[PP_N_SEGMENTS], const uint16_t seg_offsets[PP_N_SEGMENTS]) {
    const COMMAND_DMA &dmab = cmd->dma;
    intptr_t block_cmd = intptr_t(cmd) + sizeof(COMMAND_SEGMENT);
    uint block_size = dmab.unit_mask;
    uint32_t curr_seg = 0; // index of the current segment
    uint16_t max_seg_size = 0; 

    // update dynamically sized DMA commands within the current block (indicated by x_size=0)
    for (uint i=0; i < block_size; i++, block_cmd += sizeof(COMMAND_SEGMENT)) {
        COMMAND_DMA *curr_dma = (COMMAND_DMA *) block_cmd;
        if (curr_dma->x_size != 0) { // no dynamically sized DMA command
            continue;
        }
        curr_dma->direction = e2l1D; // perform dynamic DMA as 1D transfer
        curr_seg = curr_dma->y_leap; // y_leap encodes index of the current segment

        // determine maximum segment size within this block
        max_seg_size = std::max(max_seg_size, point_counts[curr_seg]);
        
        if (point_counts[curr_seg] == 0) { // no points to transfer, but x_size=0 not allowed, thus transfer one zero
            curr_dma->x_size = 1;
            curr_dma->mm_addr = layer.input.mm_base + curr_seg; // transfer one zero
        } else { // update size and mm_addr of DMA command for current segment
            curr_dma->x_size = point_counts[curr_seg];
            curr_dma->mm_addr += seg_offsets[curr_seg];
        }
    }
    aux_flush_dcache(); //TODO: check whether this is necessary
    return max_seg_size;
}

#endif // POINTPILLARS_KERNEL_H