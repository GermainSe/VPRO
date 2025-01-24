//
// Created by gesper on 27.01.23.
//
#include "bif.h"

void dump(COMMAND c) {
    switch (c.type) {
        case DMA:
            printf("DMA, ");
            if (c.direction == COMMAND_DMA::e2l1D)
                printf("e2l 1D, ");
            else if (c.direction == COMMAND_DMA::e2l2D)
                printf("e2l 2D, ");
            else if (c.direction == COMMAND_DMA::l2e1D)
                printf("l2e 1D, ");
            else if (c.direction == COMMAND_DMA::l2e2D)
                printf("l2e 2D, ");
            printf(" block size: %i, ", c.block_size);

            printf(" Cl Mask: 0x%x, ", c.cluster);
            printf(" Un Mask: 0x%x, ", c.unit_mask);
            printf(" MM_addr: 0x%x, ", c.mm_addr);
            printf(" LM_addr: 0x%x, ", c.lm_addr);
            printf(" x_size: %i, ", c.x_size);
            printf(" y_size: %i, ", c.y_size);
            printf(" stride: %i, ", c.y_leap);
            printf(" pad: %s %s %s %s ", (c.padding & 1)?"TOP":"", ((c.padding >> 1) & 1)?"RIGHT":"", ((c.padding >> 2) & 1)?"BOTTOM":"", ((c.padding >> 3) & 1)?"LEFT":"");
            break;
        case DMA_LOOP:
        {
            auto *d = (COMMAND_DMA_LOOP*)&c;
            static char buf[1024];
            sprintf(buf, " DMA LOOP, " "block size %d, " "cluster_loop_len %d, " "cluster_loop_shift_incr %d, " "unit_loop_len %d, "
                         "unit_loop_shift_incr %d, " "inter_unit_loop_len %d, " "lm_incr 0x%04" PRIx32 ", " "mm_incr 0x%08" PRIx32 ", "
                         "dma_cmd_count %d",
                    d->block_size, d->cluster_loop_len, d->cluster_loop_shift_incr, d->unit_loop_len, d->unit_loop_shift_incr,
                    d->inter_unit_loop_len, d->lm_incr, d->mm_incr, d->dma_cmd_count);
            printf("%s", buf);
        }
            break;
        case PROCESS:
            printf("PROCESS, ");
            printf("calc_buffer: %i", c.lm_addr);
            break;
        case SYNC:
            printf("SYNC");
            break;
    }
    printf("\n");
}

void dump(COMMAND c, ofstream &out) {
#ifdef SIMULATION
    switch (c.type) {
        case DMA:
            out << "DMA, ";
            if (c.direction == COMMAND_DMA::e2l1D)
                out << "e2l 1D, ";
            else if (c.direction == COMMAND_DMA::e2l2D)
                out << "e2l 2D, ";
            else if (c.direction == COMMAND_DMA::l2e1D)
                out << "l2e 1D, ";
            else if (c.direction == COMMAND_DMA::l2e2D)
                out << "l2e 2D, ";
            out << " block size: " << c.block_size;

            out << ", Cl Mask: " << uint32_t(c.cluster);
            out << ", Un Mask: " << c.unit_mask;
            out << ", MM_addr: " << c.mm_addr;
            out << ", LM_addr: " << c.lm_addr;
            out << ", x_size: " << c.x_size;
            out << ", y_size: " << c.y_size;
            out << ", stride: " << c.y_leap;
            out << ", pad: " <<  ((c.padding & 1)?"TOP":"") << (((c.padding >> 1) & 1)?"RIGHT":"") << (((c.padding >> 2) & 1)?"BOTTOM":"") << (((c.padding >> 3) & 1)?"LEFT":"");
            break;
        case DMA_LOOP:
        {
            auto *d = (COMMAND_DMA_LOOP*)&c;
            static char buf[1024];
            sprintf(buf, " DMA LOOP, " "block size %d, " "cluster_loop_len %d, " "cluster_loop_shift_incr %d, " "unit_loop_len %d, "
                         "unit_loop_shift_incr %d, " "inter_unit_loop_len %d, " "lm_incr 0x%04" PRIx32 ", " "mm_incr 0x%08" PRIx32 ", "
                         "dma_cmd_count %d",
                    d->block_size, d->cluster_loop_len, d->cluster_loop_shift_incr, d->unit_loop_len, d->unit_loop_shift_incr,
                    d->inter_unit_loop_len, d->lm_incr, d->mm_incr, d->dma_cmd_count);
            out << buf;
        }
            break;
        case PROCESS:
            out << "PROCESS, ";
            out << "calc_buffer: " << c.lm_addr;
            out << ", calc_buffer_out: " << c.mm_addr;
            break;
        case SYNC:
            out << "SYNC";
            break;
    }
    out << "\n";
#endif
}
