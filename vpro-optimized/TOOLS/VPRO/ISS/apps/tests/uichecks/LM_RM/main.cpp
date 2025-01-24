#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>


#include <stdint.h>
#include <vpro.h>
#include "core_wrapper.h"

int main(int argc, char *argv[]) {
    printf("Start\n");
    sim_init(main, argc, argv);

    volatile int16_t content[4];


    for(uint c = 0; c < VPRO_CFG::CLUSTERS; ++c) {
        vpro_set_cluster_mask((1u << c));
        content[0] = c;
        content[1] = c;
        for(uint u = 0; u < VPRO_CFG::UNITS; ++u){
            vpro_set_unit_mask((1u << u));
            content[2] = u;
            content[3] = u;
            dma_ext1D_to_loc1D(c, uint64_t(intptr_t(&(content[0]))), LM_BASE_VU(u), 4);
            dma_wait_to_finish(0xffffffff);
            for(uint i = 0; i < 32; ++i) {
                __vpro(L0, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR_3(i*32, 1, 0),
                   SRC2_IMM_2D(c*VPRO_CFG::UNITS*2+u*2+1), SRC2_IMM_2D(0), 31, 1);
                __vpro(L1, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR_3(i*32, 1, 0),
                   SRC2_IMM_2D(c*VPRO_CFG::UNITS*2+u*2+2), SRC2_IMM_2D(0), 31, 1);
            }
        }
    }
    vpro_wait_busy(0xffffffff, 0xffffffff);
    dma_wait_to_finish(0xffffffff);

    sim_stop();
    printf("\nEnd");
    return 0;
}

