//
// Created by gesper on 26.01.23.
//

#include "cmd_loop.h"


void CommandLoop::execute() {

    uint last_print = 0;
    for (uint i = 0; i < total_commands; ++i) {
        COMMAND &cmd = command_list[i];

//        if ((i & 1024) != last_print){
//            last_print = (i & 1024);
//            printf("%4i. Command: ", i);
//            dump(cmd);
//        }

        if (cmd.type == Type::DMA){
            if (cmd.block_size > 1){

#ifdef SIMULATION
                uint block_size = cmd.block_size;
                for (uint o = i; o < i+block_size; ++o) {
                    cmd = command_list[o];
                    dma_dcache_short_command((void*)&cmd);
                }
                i += (block_size - 1);
#else
                dma_block_size(cmd.block_size);
                dma_block_addr_trigger(&cmd);
                i += cmd.block_size - 1;
#endif
            } else {
                dma_dcache_short_command(&cmd);
            }
//            sim_wait_step(true, "DMA Done!");
        } else if (cmd.type == Type::PROCESS) {
            calc_buffer = cmd.lm_addr;
            calc_buffer_out = cmd.mm_addr;
            vpro_conv();
//            sim_wait_step(true, "VPRO Done!");
        } else if (cmd.type == Type::SYNC){
            aux_wait_cycles(10);
            vpro_sync();
//            vpro_dma_sync();
        }
//        aux_wait_cycles(10);
//        vpro_sync();
    }

}
