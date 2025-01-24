//
// Created by gesper on 26.01.23.
//
#include "generate_cmds.h"

Commands::Commands() {

#ifdef SIMULATION
    cmd_list = (COMMAND *) malloc(max_total_cmds * sizeof(COMMAND));
#else
    cmd_list = (COMMAND *)(intptr_t)(0x06000000);
#endif
        //new COMMAND[max_total_cmds];


    assert(NUM_CLUSTERS == VPRO_CFG::CLUSTERS);
    assert(NUM_VU_PER_CLUSTER == VPRO_CFG::UNITS);

    bool double_buffer_filled = false;
    bool double_buffer_running = false;
    bool double_buffer_processed = false;

    load_buffer = 0; // LM input
    calc_buffer = 0; // LM input
    calc_buffer_out = 0; // LM output

    uint command_nr = 0;
    uint x_o = 0;
    uint y_o = 0;
    uint x_i = 0;
    uint y_i = 0;

    bool load = false;

    while(true){
        /**
         * Fill First Double Buffer Load Segment
         */
        if (x_i == 0 && y_i == 0){
            assert(!double_buffer_filled);
            for(uint c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
                for (uint u = 0; u < VPRO_CFG::UNITS; ++u) {
                    // Load actual x, y block
                    uint32_t in_mm = mm_input + 2 *  //byte address
                                                (x_i * segment.dim_out_x +
                                                 y_i * ((input.dim_x + mm_in_stride) * segment.dim_out_y));

                    int32_t in_mm_stride =  (input.dim_x + mm_in_stride) - segment.dim_in_x + 1;

                    bool pad[4];
                    pad[ COMMAND_DMA::PAD::TOP] = (y_i == 0);
                    pad[ COMMAND_DMA::PAD::RIGHT] = (x_i == segment.num_x - 1);
                    pad[ COMMAND_DMA::PAD::BOTTOM] = (y_i == segment.num_y - 1);
                    pad[ COMMAND_DMA::PAD::LEFT] = (x_i == 0);

                    COMMAND cmd = genLoad(c, u, in_mm, load_buffer, segment.dim_in_x, segment.dim_in_y, in_mm_stride, pad);

                    cmd_list[command_nr] = cmd;
                    command_nr++;

                    double_buffer_running = true;
                    if (!increment(x_i, y_i)){  // final block done!
                        c = VPRO_CFG::CLUSTERS;
                        u = VPRO_CFG::UNITS;
                        double_buffer_running = false; // there are no further blocks to load
                    }
                }
            }
            cmd_list[command_nr] = genSync();
            command_nr++;
            load_buffer = 4096;
            double_buffer_filled = true;
            // fill first double buffer
            continue;
        }

        /**
         * Store
         */
        if (double_buffer_processed){ // something to store
            for(uint c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
                for (uint u = 0; u < VPRO_CFG::UNITS; ++u) {

                    // store actual x, y block
                    uint32_t out_mm = mm_output + 2 *  //byte address
                                                  (x_o * segment.dim_out_x +
                                                   y_o * (segment.dim_out_y * (output.dim_x + mm_out_stride)));

                    int32_t out_stride = output.dim_x - segment.dim_out_x + 1;

                    COMMAND cmd = genStore(c, u, out_mm, calc_buffer_out, segment.dim_out_x, segment.dim_out_y, out_stride);

                    cmd_list[command_nr] = cmd;
                    command_nr++;

                    if (!increment(x_o, y_o)) {  // final block done!
                        c = VPRO_CFG::CLUSTERS;
                        u = VPRO_CFG::UNITS;
                        double_buffer_processed = false; // there are no further blocks to store
                    }
                }
            }
            if (calc_buffer_out == 0)
                calc_buffer_out = 4096;
            else
                calc_buffer_out = 0;
        }

        /**
         * Load
         */
        if (double_buffer_running){ // Load further blocks
            for(uint c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
                for (uint u = 0; u < VPRO_CFG::UNITS; ++u) {
                    // Load actual x, y block
                    uint32_t in_mm = mm_input + 2 *  //byte address
                                                (x_i * segment.dim_out_x +
                                                 y_i * ((input.dim_x + mm_in_stride) * segment.dim_out_y));

                    int32_t in_mm_stride =  (input.dim_x + mm_in_stride) - segment.dim_in_x + 1;

                    bool pad[4];
                    pad[ COMMAND_DMA::PAD::TOP] = (y_i == 0);
                    pad[ COMMAND_DMA::PAD::RIGHT] = (x_i == segment.num_x - 1);
                    pad[ COMMAND_DMA::PAD::BOTTOM] = (y_i == segment.num_y - 1);
                    pad[ COMMAND_DMA::PAD::LEFT] = (x_i == 0);

                    COMMAND cmd = genLoad(c, u, in_mm, load_buffer, segment.dim_in_x, segment.dim_in_y, in_mm_stride, pad);

                    cmd_list[command_nr] = cmd;
                    command_nr++;

                    double_buffer_running = true;
                    if (!increment(x_i, y_i)){  // final block done!
                        c = VPRO_CFG::CLUSTERS;
                        u = VPRO_CFG::UNITS;
                        double_buffer_running = false; // there are no further blocks to load
                    }
                }
            }
            if (load_buffer == 0)
                load_buffer = 4096;
            else
                load_buffer = 0;
            load = true;
        }

        /**
         * process in lanes
         */
        if (double_buffer_filled){
            cmd_list[command_nr] = genProcess(calc_buffer, calc_buffer_out);
            command_nr++;
            double_buffer_processed = true;

            if (calc_buffer == 0)
                calc_buffer = 4096;
            else
                calc_buffer = 0;
            if (load)
                double_buffer_filled = true;
            else
                double_buffer_filled = false;
            load = false;
        }

        /**
         * sync
         */
        cmd_list[command_nr] = genSync();
        command_nr++;

        if (!double_buffer_filled && !double_buffer_processed) break;
        if (command_nr >= max_total_cmds){
            printf_error("MORE THAN ALLOWED NUMBER OF COMMANDS!\n"); exit(1);
        }
//        printf("x: %i, y: %i, x_o: %i, y_o: %i\n", x_i, y_i, x_o, y_o);
    }
    total_commands = command_nr;

    printf_info("Commands generated! Total: %i\n", command_nr);
}

COMMAND Commands::genSync() {
    COMMAND c;
    c.type = SYNC;
    if (print_gen_cmds) { printf("[Gen]: "); ::dump(c); }
    return c;
}

COMMAND Commands::genProcess(uint buffer,uint buffer_out) {
    COMMAND c;
    c.lm_addr = buffer;
    c.mm_addr = buffer_out;
    c.type = PROCESS;
    if (print_gen_cmds) { printf("[Gen]: "); ::dump(c); }
    return c;
}

COMMAND Commands::genStore(uint cluster, uint unit, uint mm_adr, uint loc_addr, uint x_size, uint y_size,
                                     int x_stride) {
    COMMAND c;
    c.type = DMA;
    c.direction = COMMAND_DMA::DMA_DIRECTION::l2e2D;
    c.x_size = x_size;
    c.y_leap = x_stride;
    c.y_size = y_size;
    c.mm_addr = mm_adr;
    c.lm_addr = loc_addr;
    c.cluster =  1 << cluster;
    c.unit_mask = 1 << unit;
    if (print_gen_cmds) { printf("[Gen]: "); ::dump(c); }
    return c;
}

COMMAND Commands::genLoad(uint cluster, uint unit, uint mm_adr, uint loc_addr, uint x_size, uint y_size,
                                    int x_stride, const bool pad[4]) {

    uint padw = (kernel_size-1)/2;
    //                    - one up if not top
    if (!pad[COMMAND_DMA::PAD::TOP]) {
        mm_adr -= 2 * (input.dim_x + mm_in_stride) * padw;
    }
    //                    - one left if not left
    if (!pad[COMMAND_DMA::PAD::LEFT]) {
        mm_adr -= 2 * padw;
    }
    //                    right:
    //                     - stride++, cause this model assumes complete padded segment in MM
    if (pad[COMMAND_DMA::PAD::RIGHT]) {
        x_stride += int(padw); // + output.MM_x_stride*stride;
    }
    //                    left:
    //                     - stride++
    if (pad[COMMAND_DMA::PAD::LEFT]) {
        x_stride += int(padw);
    }

    COMMAND c;
    c.type = DMA;
    c.direction = COMMAND_DMA::DMA_DIRECTION::e2l2D;
    c.x_size = x_size;
    c.y_leap = x_stride;
    c.y_size = y_size;
    c.mm_addr = mm_adr;
    c.lm_addr = loc_addr;
    c.cluster =  1 << cluster;
    c.unit_mask = 1 << unit;
    c.padding |= pad[0];
    c.padding |= (pad[1] << 1);
    c.padding |= (pad[2] << 2);
    c.padding |= (pad[3] << 3);
    if (print_gen_cmds) { printf("[Gen]: "); ::dump(c); }
    return c;
}

bool Commands::increment(uint &x, uint &y) {
    x++;
    if (x < segment.num_x){
        return true;
    } else {
        x = 0;
        y++;
        if (y < segment.num_y){
            return true;
        } else {
            return false;
        }
    }
}

void Commands::generate_dma_blocks() {
    COMMAND *start = &cmd_list[0];
    for (uint i = 0; i < total_commands; ++i) {
        auto &c = cmd_list[i];
//    for (COMMAND &c: cmd_list) {
        if (start == &c) continue; // skip first
        if (start->type != DMA){ // not yet start of a DMA block
            start = &c;
            continue;
        }
        if (c.type == start->type) continue; // part of this DMA block

        // we got c (which is not a DMA. define the DMA block size until c)
        uint dma_block_size = (intptr_t(&c) - intptr_t(start))/sizeof(COMMAND);
        if (dma_block_size > 1){
            start->block_size = dma_block_size;
        }
        start = &c;
    }
}

void Commands::dump() {
    int index = 0;
    for (uint i = 0; i < total_commands; ++i) {
        auto c = cmd_list[i];
        printf("[%4i] ", index);
        ::dump(c);
        index++;
    }
}

#ifdef SIMULATION
#include <iostream>
#include <fstream>
#endif

void Commands::dump_to_file(const char *filename) {
#ifdef SIMULATION
    ofstream out;
    out.open(filename);

    int index = 0;
    for (uint i = 0; i < total_commands; ++i) {
        auto c = cmd_list[i];
        out << "[" << index << "] ";
        ::dump(c, out);
        index++;
    }

    out.close();
#endif
}
