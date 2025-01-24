//
// Created by gesper on 26.01.23.
//

#ifndef CONV2D_GENERATE_CMDS_H
#define CONV2D_GENERATE_CMDS_H

#include "conv.h"
#include "bif.h"

class Commands{

public:
    // simple conv 2d:
    // process load segments -> process -> store segments
    // with double buffer (load, load+process, store+load+process, store+process, store)
    // list includes Sync

// maximum loads per sync-block
    static constexpr uint32_t parallel_units = NUM_VU_PER_CLUSTER * NUM_CLUSTERS;

// segments (# of loads/stores)
    static constexpr uint32_t total_segments = segment.num_x * segment.num_y;

// +2 (to init/out of double buffering)
// *2 to include process commands
// +syncs for parallel block count
    static constexpr uint32_t syncs = 2+2*(int_ceil(float(total_segments)/float(parallel_units)));
    static constexpr uint32_t loads_stores = 2*total_segments;
    static constexpr uint32_t max_total_cmds = loads_stores+syncs;

    static constexpr bool print_gen_cmds = false;

    Commands();

    void generate_dma_blocks();


    uint32_t total_commands;
    COMMAND *cmd_list; //[max_total_cmds];

    void dump();
    void dump_to_file(const char *filename);
private:
    static bool increment(uint &x, uint &y);

    static COMMAND genLoad(uint cluster, uint unit, uint mm_adr, uint loc_addr, uint x_size, uint y_size, int x_stride, const bool pad[4]);
    static COMMAND genStore(uint cluster, uint unit, uint mm_adr, uint loc_addr, uint x_size, uint y_size, int x_stride);
    static COMMAND genProcess(uint buffer,uint buffer_out);
    static COMMAND genSync();

};




#endif //CONV2D_GENERATE_CMDS_H
