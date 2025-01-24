//
// Created by gesper on 06.04.22.
//

#include "SegmentInterleaver.h"
#include "file_helper.h"

QList<COMMAND_SEGMENT> SegmentInterleaver::interleave(){

    auto dma_comp = [](const COMMAND_SEGMENT &a, const COMMAND_SEGMENT &b) {
        auto ac = reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(a.data);
        auto bc = reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(b.data);
        return ac->x_size * ac->y_size > bc->x_size * bc->y_size;
    };

    enum DIR{
        E2L, L2E
    };

    QList<COMMAND_SEGMENT> dma_block;
    QList<COMMAND_SEGMENT> vpro_block;
    QList<COMMAND_SEGMENT> cmds_interleaved;
//    for (auto &s : command_final_list){
    for (int i = 0; i < command_final_list.size(); i++) {
        const auto &s = command_final_list.at(i);

        if (s.type == DMA_SEG) {
            dma_block.append(s);
        } else if (s.type == VPRO_SEG) {
            vpro_block.append(s);
        }
        if (s.type == VPRO_WAIT || s.type == DMA_WAIT || s.type == BOTH_SYNC || i == command_final_list.size() - 1){    // sync
            if (dma_block.length() != 0 && vpro_block.length() != 0) {  // both are filled
                // interleave and append
                // sort dma commands (largest first), but take care of direction change (needed????)
                QList<COMMAND_SEGMENT> dma_block_sorted;
                QList<COMMAND_SEGMENT> dma_subblock;
                DIR dir = (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(dma_block.front().data)->direction <= 1)? E2L : L2E;
                for (auto dma_c: dma_block) {
                    DIR dir_c = (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(dma_c.data)->direction <= 1)? E2L : L2E;
                    if (dir_c == dir) {
                        dma_subblock.append(dma_c);
                    } else {
                        dir = dir_c;
                        std::stable_sort(dma_subblock.begin(), dma_subblock.end(),
                                         dma_comp);
                        dma_block_sorted.append(dma_subblock);
                        dma_subblock.clear();
                        dma_subblock.append(dma_c);
                    }
                }
                if (!dma_subblock.empty()) {
                    std::stable_sort(dma_subblock.begin(), dma_subblock.end(),
                                     dma_comp);
                    dma_block_sorted.append(dma_subblock);
                    dma_subblock.clear();
                }

//                printf_info("DMA Front size: %i\n",
//                            reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(dma_block_sorted.front().data)->x_size *
//                            reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(dma_block_sorted.front().data)->y_size);

                while (dma_block_sorted.length() != 0 && vpro_block.length() != 0) {
                    cmds_interleaved.append(dma_block_sorted.takeFirst());
                    cmds_interleaved.append(vpro_block.takeFirst());
                }
                cmds_interleaved.append(dma_block_sorted);
                cmds_interleaved.append(vpro_block);
                dma_block.clear();
                dma_block_sorted.clear();
                vpro_block.clear();

            } else if (dma_block.length() != 0 || vpro_block.length() != 0) { // only one is filled

                if (!dma_block.empty()) {
                    // sort dma commands (largest first), but take care of direction change (needed????)
                    QList<COMMAND_SEGMENT> dma_block_sorted;
                    QList<COMMAND_SEGMENT> dma_subblock;
                    DIR dir = (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(dma_block.front().data)->direction <= 1)? E2L : L2E;
                    for (auto dma_c: dma_block) {
                        DIR dir_c = (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(dma_c.data)->direction <= 1)? E2L : L2E;
                        if (dir_c == dir) {
                            dma_subblock.append(dma_c);
                        } else {
                            dir = dir_c;
                            std::stable_sort(dma_subblock.begin(), dma_subblock.end(),
                                             dma_comp);
                            dma_block_sorted.append(dma_subblock);
                            dma_subblock.clear();
                            dma_subblock.append(dma_c);
                        }
                    }
                    if (!dma_subblock.empty()) {
                        std::stable_sort(dma_subblock.begin(), dma_subblock.end(),
                                         dma_comp);
                        dma_block_sorted.append(dma_subblock);
                        dma_subblock.clear();
                    }
                    cmds_interleaved.append(dma_block_sorted);
                    dma_block.clear();
                }

                if (!vpro_block.empty()) {
                    cmds_interleaved.append(vpro_block);
                    vpro_block.clear();
                }
            } else {  // both lists are empty
            }
            cmds_interleaved.append(s);

            if(!vpro_block.empty() || !dma_block.empty()){
                printf_error("either VPRO or DMA Block list not yet empty!\n");
            }
        }
    }

    if(!vpro_block.empty() || !dma_block.empty()){
        printf_error("BLOCKS not yet empty!\n");
    }
    return cmds_interleaved;
}
