//
// Created by gesper on 14.10.22.
//

#include "VPRO_DMA_BlockExtension_Extractor.h"

#include "file_helper.h"

constexpr bool skip_dma_block_gen = false;

COMMAND_SEGMENT VPRO_DMA_BlockExtension_Extractor::generate_DMABlock_Command(const uint32_t count) {
    COMMAND_SEGMENT seg;
    seg.type = DMA_BLOCK;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->unit_mask = count;
    return seg;
}

struct CMD_BLOCK {
    COMMAND_SEGMENT_TYPE type = UNKNOWN;
    QList<COMMAND_SEGMENT> list;
};

QList<COMMAND_SEGMENT> VPRO_DMA_BlockExtension_Extractor::generate() {
    QList<COMMAND_SEGMENT> dma_block, vpro_block;
    QList<COMMAND_SEGMENT> dma_block_cluster_broadcasts;
    QList<COMMAND_SEGMENT> cmds_final;

    QList<CMD_BLOCK> block_list;
    int merged_dma_commands = 0;    // by cluster broadcasting

    enum dir_t {
        UNINIT = 0,
        E2L = 1,
        L2E = 2,
    } dir = UNINIT;

    bool dir_switch = false;
//    for (const auto &s : command_final_list){
    for (int i = 0; i < command_final_list.size(); i++) {
        const auto &s = command_final_list.at(i);

        if (dir == UNINIT) {
            dir_switch = false;
            if (s.type == COMMAND_SEGMENT_TYPE::DMA_SEG) {
                if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(s.data).direction ==
                    COMMAND_DMA::DMA_DIRECTION::e2l1D ||
                    reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(s.data).direction ==
                    COMMAND_DMA::DMA_DIRECTION::e2l2D)
                    dir = E2L;
                else
                    dir = L2E;
            }
        } else {
            if (s.type == COMMAND_SEGMENT_TYPE::DMA_SEG) {
                if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(s.data).direction ==
                    COMMAND_DMA::DMA_DIRECTION::e2l1D ||
                    reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(s.data).direction ==
                    COMMAND_DMA::DMA_DIRECTION::e2l2D) {
                    if (dir == E2L)
                        dir_switch = false;
                    else
                        dir_switch = true;
                }
            }
        }

        if (s.type == DMA_SEG && !dir_switch) {
            dma_block.append(s);
        } else if (s.type == VPRO_SEG) {
            vpro_block.append(s);
        }

        if (dir_switch || s.type == VPRO_WAIT || s.type == DMA_WAIT || s.type == BOTH_SYNC || i == command_final_list.size() - 1) {    // sync
            if (!dma_block.empty()) {
                if (dma_block.size() > 1) {
                    std::stable_sort(dma_block.begin(), dma_block.end(),
                              [](const COMMAND_SEGMENT &d1, const COMMAND_SEGMENT &d2) -> bool {
                                  // direction hold 4 states (but '1 bit is ~ dir)
                                  assert((reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d1.data).direction &
                                          0b10) ==
                                         (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d2.data).direction &
                                          0b10));
                                  if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d1.data).mm_addr !=
                                      reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d2.data).mm_addr)
                                      return reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d1.data).mm_addr <
                                             reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d2.data).mm_addr; // sort by mm
                                  if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d1.data).lm_addr !=
                                      reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d2.data).lm_addr)
                                      return reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d1.data).lm_addr <
                                             reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d2.data).lm_addr;
                                  return reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d1.data).cluster <
                                         reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(d2.data).cluster;
                              });
                    COMMAND_SEGMENT *sb = &(*(dma_block.begin()));
                    auto *starter = reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(sb->data);
                    uint32_t cluster_mask = uint32_t(0b1u) << starter->cluster;
                    for (auto db = dma_block.begin(); db < dma_block.end(); db++) {
                        if (db == dma_block.begin()) continue;
                        auto *d = reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(db->data);
                        if (d->mm_addr == starter->mm_addr &&
                            d->lm_addr == starter->lm_addr &&
                            d->x_size == starter->x_size &&
                            d->x_stride == starter->x_stride &&
                            d->y_size == starter->y_size &&
                            d->pad_0 == starter->pad_0 &&
                            d->pad_1 == starter->pad_1 &&
                            d->pad_2 == starter->pad_2 &&
                            d->pad_3 == starter->pad_3 &&
                            d->unit_mask == starter->unit_mask &&
                            d->direction == starter->direction &&
                            d->isBiasOffset == starter->isBiasOffset &&
                            d->isKernelOffset == starter->isKernelOffset) {
                            assert(d->cluster != starter->cluster);
                            cluster_mask |= uint32_t(0b1u) << d->cluster;
                            merged_dma_commands++;
                        } else {
                            starter->cluster = cluster_mask;
                            dma_block_cluster_broadcasts.append(*sb);

                            starter = d;
                            sb = &*db;
                            cluster_mask = uint32_t(0b1u) << d->cluster;
                        }
                    }
                    starter->cluster = cluster_mask;
                    dma_block_cluster_broadcasts.append(*sb);

                    auto dma_comp = [](const COMMAND_SEGMENT &a, const COMMAND_SEGMENT &b) {
                        auto ac = reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(a.data);
                        auto bc = reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(b.data);
                        return ac->x_size * ac->y_size > bc->x_size * bc->y_size;
                    };
                    std::stable_sort(dma_block_cluster_broadcasts.begin(), dma_block_cluster_broadcasts.end(),
                              dma_comp);

                    cmds_final.append(vpro_block);
                    if (!skip_dma_block_gen)
                        cmds_final.append(generate_DMABlock_Command(dma_block_cluster_broadcasts.size()));
                    cmds_final.append(dma_block_cluster_broadcasts);

                    if (!dma_block_cluster_broadcasts.empty()) {
                        CMD_BLOCK block;
                        block.type = COMMAND_SEGMENT_TYPE::DMA_SEG;
                        block.list = dma_block_cluster_broadcasts;
                        block_list.append(block);
                    }

                    dma_block_cluster_broadcasts.clear();
                } else { // dma block size > 1
                    // set to cluster mask [ATTENTION, if this is a single dma command -> error]
                    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(dma_block.front().data)->cluster = uint32_t(0b1u) << reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(dma_block.front().data)->cluster;
                    cmds_final.append(dma_block);
                    cmds_final.append(vpro_block);
                    if (!dma_block.empty()) {
                        CMD_BLOCK block;
                        block.type = COMMAND_SEGMENT_TYPE::DMA_SEG;
                        block.list = dma_block;
                        block_list.append(block);
                    }
                }
            } else {   // dma not empty
                cmds_final.append(vpro_block);
            }

            if (!vpro_block.empty()) {
                CMD_BLOCK block;
                block.type = COMMAND_SEGMENT_TYPE::VPRO_SEG;
                block.list = vpro_block;
                block_list.append(block);
            }
            if (!dir_switch) {
                CMD_BLOCK block;
                block.type = s.type;
                block.list.append(s);
                block_list.append(block);
            }

            dma_block.clear();
            vpro_block.clear();

            if (!dir_switch) {  // this is a sync or final command (not started this by dir switch)
                cmds_final.append(s);
                dir = UNINIT;
            } else {
                assert(s.type == COMMAND_SEGMENT_TYPE::DMA_SEG);
                if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(s.data).direction ==
                    COMMAND_DMA::DMA_DIRECTION::e2l1D ||
                    reinterpret_cast<const COMMAND_DMA::COMMAND_DMA &>(s.data).direction ==
                    COMMAND_DMA::DMA_DIRECTION::e2l2D)
                    dir = E2L;
                else
                    dir = L2E;
                dma_block.append(s);
            }
        }
    }

    int total_cmd_segs = 0;
    int total_dma_blocks = 0;
    int total_vpro_blocks = 0;
    int total_dmas_blocks = 0;
    int total_vpros_blocks = 0;
    int total_sync_blocks = 0;
    for (const auto &i: block_list) {
        total_cmd_segs += i.list.size();
        if (i.type == COMMAND_SEGMENT_TYPE::DMA_SEG)
            total_dma_blocks++;
        if (i.type == COMMAND_SEGMENT_TYPE::VPRO_SEG)
            total_vpro_blocks++;
        if (i.type == COMMAND_SEGMENT_TYPE::VPRO_WAIT)
            total_vpros_blocks++;
        if (i.type == COMMAND_SEGMENT_TYPE::DMA_WAIT)
            total_dmas_blocks++;
        if (i.type == COMMAND_SEGMENT_TYPE::BOTH_SYNC)
            total_sync_blocks++;
    }

    printf_info("[After DMA Block creation]: with DMA BLOCKs, %i segs generated!\n", cmds_final.size());


    if (merged_dma_commands > 0)
        printf_info("  DMA Cluster Broadcast was able to merge %i DMA Commands\n", merged_dma_commands);

    printf_info("  Details: %i Blocks (%i DMAs, %i VPRO, %i DMA Sync, %i VPRO Sync, %i Both Sync), %i commands (without DMA block) total\n",
                block_list.size(), total_dma_blocks, total_vpro_blocks, total_dmas_blocks, total_vpros_blocks, total_sync_blocks,
                total_cmd_segs);

    cmds_final.clear();
    // assuming regular structure:
    //  DMA + VPRO (parallel) or DMA (only)
    //  Sync (both)
    // loop
    struct ParallelBlock {
        CMD_BLOCK dma;
        CMD_BLOCK vpro;
        bool got_dma = false;
        bool got_vpro = false;
    } pblock;

    for (const auto &i: block_list) {
        if (i.type == COMMAND_SEGMENT_TYPE::DMA_SEG) {
            if (pblock.got_dma) {
                pblock.dma.list.append(i.list);
            } else {
                pblock.dma = i;
            }
            pblock.got_dma = true;
        } else if (i.type == COMMAND_SEGMENT_TYPE::VPRO_SEG) {
            if (pblock.got_dma) {
                pblock.vpro.list.append(i.list);
            } else {
                pblock.vpro = i;
            }
            pblock.got_vpro = true;
        } else if (i.type == COMMAND_SEGMENT_TYPE::VPRO_WAIT || i.type == COMMAND_SEGMENT_TYPE::DMA_WAIT || i.type == COMMAND_SEGMENT_TYPE::BOTH_SYNC) {
            if (pblock.got_dma && !pblock.got_vpro) { // only DMA
                if (!pblock.dma.list.empty()) {
                    if (!skip_dma_block_gen)
                        cmds_final.append(generate_DMABlock_Command(pblock.dma.list.size()));
                }
                cmds_final.append(pblock.dma.list);
            } else if (pblock.got_dma && pblock.got_vpro) { // both

                // "interleave":
                //    60' block of dma
                //    all vpro
                //    remaining dmas
                QList<COMMAND_SEGMENT> first_block_dmas;
                for (int j = 0; j < 50; ++j) {              // TODO: global parameter?
                    if (!pblock.dma.list.empty()) {
                        first_block_dmas.append(pblock.dma.list.front());
                        pblock.dma.list.pop_front();
                    } else {
                        break;
                    }
                }
                //printf_warning("Block of %i DMAs! %i Remain\n", first_block_dmas.size(), pblock.dma.list.size());

                if (!first_block_dmas.empty()) {
                    if (!skip_dma_block_gen)
                        cmds_final.append(generate_DMABlock_Command(first_block_dmas.size()));
                }
                cmds_final.append(first_block_dmas);
                cmds_final.append(pblock.vpro.list);
                if (!pblock.dma.list.empty()) {
                    if (!skip_dma_block_gen)
                        cmds_final.append(generate_DMABlock_Command(pblock.dma.list.size()));
                }
                cmds_final.append(pblock.dma.list);
            } else if (!pblock.got_dma && pblock.got_vpro) {
                cmds_final.append(pblock.vpro.list);
            }
            cmds_final.append(i.list);  // sync
            pblock.dma.list.clear();
            pblock.vpro.list.clear();
            pblock.got_dma = false;
            pblock.got_vpro = false;
        } else {printf_error("unknown segment type!\n"); }
    }

    printf_info("[After interleaving]: with DMA BLOCKs, %i segs generated!\n", cmds_final.size());

    return cmds_final;
}
