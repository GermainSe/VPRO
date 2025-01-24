//
// Created by gesper on 06.04.22.
//

#include "segment_creation.h"
#include "segment_creation_vpro.h"
#include "segment_creation_dma.h"
#include <helper.h>
#include "file_helper.h"
#include "../configuration_loader/yolo_configuration.h"

#include "BaseExtractor.h"
#include "SegmentGeneration.h"
#include "SegmentInterleaver.h"
#include "VPRO_DMA_BlockExtension_Extractor.h"

#ifndef SOURCE_DIR
#define SOURCE_DIR ""
#endif

COMMAND_SEGMENT createSync(){
    COMMAND_SEGMENT seg;
    seg.type = BOTH_SYNC;
    return seg;
}


QList<COMMAND_SEGMENT> *create_command_list(QList<QVector<SEGMENT *>> &segments, std::list<LAYER> &original_layers, bool set_base_addr_weights_to_elf_extraction, bool do_interleaving, bool do_dma_extension) {

    printf_info("Generating Segement List for segs: \n");
//    for (const auto& v: segments) {
//        printf_info("%i Segments \n", v.length());
//    }
//    printf_info("VPRO_CFG::parallel_Lanes: %i\n",  VPRO_CFG::parallel_Lanes);
//    printf_info("VPRO_CFG::LANES: %i\n", VPRO_CFG::LANES);
//    printf_info("VPRO_CFG::UNITS: %i\n",  VPRO_CFG::UNITS);
//    printf_info("VPRO_CFG::CLUSTERS: %i\n",  VPRO_CFG::CLUSTERS);
    QList<uint> sed_list;

    auto complete_command_list = new QList<COMMAND_SEGMENT>[layer_count];

    bool fail = false;
    // assign from previous calc LAYER list (x86)
    for (auto l = 0; l < int(layer_count); ++l) {

        QList<COMMAND_SEGMENT> command_list;

        QVector<SEGMENT *> &calculation = segments[l];
        const LAYER &layer = original_layers.front();
        void *conv = yolo.weights[l];
        int seg_size = calculation.size();

        BUFFER buffer_load = BUFFER::A;
        BUFFER buffer_calc = BUFFER::A;

        dma_transactions_type1D.clear();
        dma_transactions_type2D.clear();

        for (auto &i: dma_transactions_type1D) {
            i.dir = COMMAND_DMA::DMA_DIRECTION::e2l1D;
            i.cluster = 0;
            i.unit = 0;
            i.mm_addr = 0;
            i.lm_addr = 0;
            i.x_size = 0;
            i.y_size = 0;
            i.word_count = 0;
            i.x_stride = 1;
            i.pad[0] = false;
            i.pad[1] = false;
            i.pad[2] = false;
            i.pad[3] = false;
        }
        vector_length = (layer.conv.seg_out_w) * (layer.conv.seg_out_h);
        if (vector_length < 5)
            vector_length_compensate = 5 - vector_length;
        else
            vector_length_compensate = 0;

        if (layer.type == LAYERTYPE::CONV2 || layer.type == LAYERTYPE::DEPTHWISE_CONV2) {
            RF_KERNEL_BASE = 1024 - (layer.conv.kernel_length * layer.conv.kernel_length);
            RF_BIAS_BASE = RF_KERNEL_BASE - 1;
            RF_RELU_6_BASE = RF_BIAS_BASE - 1;
            kernel_x = layer.conv.kernel_length;
            kernel_y = layer.conv.kernel_length;
        }

        if (layer.relu.type == RELUTYPE::RELU6) {
            // store shifted value of "6" to RF
            sim_printf("LAYER GONNA SHIFT 6 left by: %i \n", layer.relu_6_shift_left);
            if (layer.relu_6_shift_left > 20) { // 6 takes 3 bit. if 24 are taken, result gets negative!
                printf_warning("Relu 6 overflow...");
            }
        }

        int seg_cnt = 0;
        if (layer.type == LAYERTYPE::DEPTHWISE_CONV2 || layer.type == LAYERTYPE::CONV2) {
            /**
             *  First Segments
             */
            /*** first load ***/
            int cl = 0; // cluster of this segment
            int un = 0; // unit of this segment
            int ln = 0; // lane of this segment
            for (auto i = 0; i < VPRO_CFG::parallel_Lanes; i++) {
                SEGMENT &segment = *calculation[i];
                if (!segment.dummy) {
                    // dma kernel load
                    dmaCoeffLoad(layer, segment, conv, cl, un, buffer_load, ln);
                    // dma bias load
                    if (segment.isFirst) {
                        dmaBiasLoad(layer, segment, conv, cl, un, buffer_load, ln);
                    }
                }
                ++ln;
                if (ln == VPRO_CFG::LANES) {
                    ++un;
                    ln = 0;
                    if (un == VPRO_CFG::UNITS) {
                        un = 0;
                        ++cl;
                    }
                }
            }
            cl = 0; // cluster of this segment
            un = 0; // unit of this segment
            ln = 0; // lane of this segment
            for (auto i = 0; i < VPRO_CFG::parallel_Lanes; i++) {
                SEGMENT &segment = *calculation[i];
                if (!segment.dummy) {
                    // dma input data load
                    if (ln == 0) {
                        dmaDataLoad(layer, segment, cl, un, buffer_load);
                    }
                }
                ++ln;
                if (ln == VPRO_CFG::LANES) {
                    ++un;
                    ln = 0;
                    if (un == VPRO_CFG::UNITS) {
                        un = 0;
                        ++cl;
                    }
                }
            }
            QVector<COMMAND_SEGMENT> dmas = dmaStartBroadcastLoad(layer, conv);
            for (auto &seg: dmas) {
                command_list.append(seg);
            }
            buffer_load = (buffer_load == A) ? B : A;

            /*** wait finish ***/
            command_list.append(createDMA_wait());

            /**
             *  MAIN LOOP over all Segments
             */
            while (seg_size - seg_cnt >=
                   2 * VPRO_CFG::parallel_Lanes) {    // more segments to process than 2*... (load + calc parallel)
                /*** Load next ***/
                ln = 0;
                un = 0;
                cl = 0;
                for (auto i = VPRO_CFG::parallel_Lanes; i < 2 * VPRO_CFG::parallel_Lanes; i++) {    // later block to be loaded
                    SEGMENT &segment = *calculation[i + seg_cnt];
                    if (!segment.dummy) {
                        // dma kernel load
                        dmaCoeffLoad(layer, segment, conv, cl, un, buffer_load, ln);
                        // dma bias load
                        if (segment.isFirst) {
                            dmaBiasLoad(layer, segment, conv, cl, un, buffer_load, ln);
                        }
                    }
                    ++ln;
                    if (ln == VPRO_CFG::LANES) {
                        ++un;
                        ln = 0;
                        if (un == VPRO_CFG::UNITS) {
                            un = 0;
                            ++cl;
                        }
                    }
                }
                ln = 0;
                un = 0;
                cl = 0;
                for (auto i = VPRO_CFG::parallel_Lanes; i < 2 * VPRO_CFG::parallel_Lanes; i++) {    // later block to be loaded
                    SEGMENT &segment = *calculation[i + seg_cnt];
                    if (!segment.dummy) {
                        // dma input data load once per unit
                        if (ln == 0) {
                            dmaDataLoad(layer, segment, cl, un, buffer_load);
                        }
                    }
                    ++ln;
                    if (ln == VPRO_CFG::LANES) {
                        ++un;
                        ln = 0;
                        if (un == VPRO_CFG::UNITS) {
                            un = 0;
                            ++cl;
                        }
                    }
                }
                // start of dma moved into vpro loop for order mixing...
                /*** Execute this ***/
                dmas = dmaStartBroadcastLoad(layer, conv);
                for (auto &seg: dmas) {
                    command_list.append(seg);
                }
                for (auto lane = 0; lane < VPRO_CFG::LANES; lane++) { // once for each lane
                    SEGMENT &segment = *calculation[lane + seg_cnt];
                    if (lane == 0) {
                        if (!segment.dummy) {
                            if (segment.isFirst)
                                // includes bias + kernel load
                                command_list.append(
                                        createVPRO_Conv_start(layer, segment, buffer_calc, !segment.isFirst));
                            else
                                // includes kernel load
                                command_list.append(createVPRO_Conv_add(layer, segment, buffer_calc, !segment.isFirst));
                        }
                        if (!segment.dummy && segment.isLast) {
                            command_list.append(createVPRO_ReluPool(layer, segment, buffer_calc));
                        }
                    }
                    if (!segment.dummy && segment.isLast) {
                        // store
                        command_list.append(createVPRO_ShiftStore(layer, segment, buffer_calc, lane));
                    }
                }
                /*** Wait for finish ***/

                command_list.append(createSync());
//                command_list.append(createDMA_wait());
//                command_list.append(createVPRO_wait());

                /*** Store this ***/
                ln = 0;
                un = 0;
                cl = 0;
                for (auto i = 0; i < VPRO_CFG::parallel_Lanes; i++) {
                    SEGMENT &segment = *calculation[i + seg_cnt];
                    if (!segment.dummy && segment.isLast) {
                        command_list.append(createDMA_DataStore(layer, segment, cl, un, buffer_calc, ln));
//                        dmaDataStore(layer, segment, cl, un, buffer_calc, ln);
                    }
                    ++ln;
                    if (ln == VPRO_CFG::LANES) {
                        ++un;
                        ln = 0;
                        if (un == VPRO_CFG::UNITS) {
                            un = 0;
                            ++cl;
                        }
                    }
                }

                buffer_load = (buffer_load == A) ? B : A;
                buffer_calc = (buffer_calc == A) ? B : A;
                seg_cnt += VPRO_CFG::parallel_Lanes;
            } // while


            /**
             *  Remaining Segments
             */
            // last segment is loaded but not yet executed or stored
            if (seg_size - seg_cnt >= VPRO_CFG::parallel_Lanes) {
                /*** Execute this ***/
                for (auto lane = 0; lane < VPRO_CFG::LANES; lane++) { // once for each lane
                    SEGMENT &segment = *calculation[lane + seg_cnt];
                    if (lane == 0 && !segment.dummy) {
                        if (segment.isFirst)
                            // includes bias + kernel load
                            command_list.append(createVPRO_Conv_start(layer, segment, buffer_calc, !segment.isFirst));
                        else
                            // includes kernel load
                            command_list.append(createVPRO_Conv_add(layer, segment, buffer_calc, !segment.isFirst));

                        if (segment.isLast) {
                            command_list.append(createVPRO_ReluPool(layer, segment, buffer_calc));
                        }
                    }
                    if (!segment.dummy && segment.isLast) {
                        // store
                        command_list.append(createVPRO_ShiftStore(layer, segment, buffer_calc, lane));
                    }
                }
                /*** Wait for finish ***/
                command_list.append(createSync());
//                command_list.append(createDMA_wait());
//                command_list.append(createVPRO_wait());

                /*** Store this ***/
                ln = 0;
                un = 0;
                cl = 0;
                for (auto i = 0; i < VPRO_CFG::parallel_Lanes; i++) {
                    SEGMENT &segment = *calculation[i + seg_cnt];
                    if (!segment.dummy && segment.isLast) {
                        command_list.append(createDMA_DataStore(layer, segment, cl, un, buffer_calc, ln));
//                        dmaDataStore(layer, segment, cl, un, buffer_calc, ln);
                    }
                    ++ln;
                    if (ln == VPRO_CFG::LANES) {
                        ++un;
                        ln = 0;
                        if (un == VPRO_CFG::UNITS) {
                            un = 0;
                            ++cl;
                        }
                    }
                }
                /*** Wait for finish ***/
                command_list.append(createSync());
//                command_list.append(createVPRO_wait());
//                command_list.append(createDMA_wait());

                buffer_load = (buffer_load == A) ? B : A;
                buffer_calc = (buffer_calc == A) ? B : A;
                seg_cnt += VPRO_CFG::parallel_Lanes;
            } // now all segments are finished
        } else if (layer.type == LAYERTYPE::RESIDUAL) {

            /**
            *  First Segments
            */
            int ln = 0;
            int un = 0;
            int cl = 0;
            for (auto i = 0; i < VPRO_CFG::parallel_Lanes; i++) {
                SEGMENT &segment = *calculation[i];

                if (!segment.dummy) { // this means it is lane 0! -> residual
                    // mm offset = residual 0  // lm offset = 0 && residual 1 // lm offset = 1024
                    dmaResidualDataLoad(layer, segment, cl, un, buffer_load);
                }
                ++ln;
                if (ln == VPRO_CFG::LANES) {
                    ++un;
                    ln = 0;
                    if (un == VPRO_CFG::UNITS) {
                        un = 0;
                        ++cl;
                    }
                }
            }
            QVector<COMMAND_SEGMENT> dmas = dmaStartBroadcastLoad(layer, conv);
            for (auto &seg: dmas) {
                command_list.append(seg);
            }
            buffer_load = (buffer_load == A) ? B : A;
            /*** wait finish ***/
            command_list.append(createDMA_wait());

            /**
             *  MAIN LOOP over all Segments
             */
            while (seg_size - seg_cnt >=
                   2 * VPRO_CFG::parallel_Lanes) {    // more segments to process than 2*... (load + calc parallel)
                /*** Load next ***/
                ln = 0;
                un = 0;
                cl = 0;
                for (auto i = VPRO_CFG::parallel_Lanes; i < 2 * VPRO_CFG::parallel_Lanes; i++) {    // later block to be loaded
                    SEGMENT &segment = *calculation[i + seg_cnt];
                    if (!segment.dummy && ln == 0) { // this means it is lane 0! -> residual
                        // mm offset = residual 0  // lm offset = 0 && residual 1 // lm offset = 1024
                        dmaResidualDataLoad(layer, segment, cl, un, buffer_load);
                    }
                    ++ln;
                    if (ln == VPRO_CFG::LANES) {
                        ++un;
                        ln = 0;
                        if (un == VPRO_CFG::UNITS) {
                            un = 0;
                            ++cl;
                        }
                    }
                }
                // load start merged into vpro function start
                /*** Execute this ***/
                dmas = dmaStartBroadcastLoad(layer, conv);
                for (auto &seg: dmas) {
                    command_list.append(seg);
                }
                SEGMENT &segment = *calculation[0 + seg_cnt];
                if (!segment.dummy) { // this means it is lane 0! -> residual
                    command_list.append(createVPRO_Residual(layer, segment, buffer_calc));
//                    vproResidual(layer, segment, buffer_calc); // Load, add, store
                }
                /*** Wait for finish ***/
                command_list.append(createSync());
//                command_list.append(createVPRO_wait());
//                command_list.append(createDMA_wait());

                /*** Store this ***/
                ln = 0;
                un = 0;
                cl = 0;
                for (auto i = 0; i < VPRO_CFG::parallel_Lanes; i++) {
                    segment = *calculation[i + seg_cnt];
                    if (!segment.dummy) {
//                        dmaDataStore(layer, segment, cl, un, buffer_calc, ln);
                        command_list.append(createDMA_DataStore(layer, segment, cl, un, buffer_calc, ln));
                    }
                    ++ln;
                    if (ln == VPRO_CFG::LANES) {
                        ++un;
                        ln = 0;
                        if (un == VPRO_CFG::UNITS) {
                            un = 0;
                            ++cl;
                        }
                    }
                }
                buffer_load = (buffer_load == A) ? B : A;
                buffer_calc = (buffer_calc == A) ? B : A;
                seg_cnt += VPRO_CFG::parallel_Lanes;
            } // while

            /**
             *  Remaining Segments
             */
            // last segment is loaded but not yet executed or stored
            if (seg_size - seg_cnt >= VPRO_CFG::parallel_Lanes) {
                /*** Execute this ***/
                SEGMENT &segment = *calculation[0 + seg_cnt];
                if (!segment.dummy) {
                    command_list.append(createVPRO_Residual(layer, segment, buffer_calc));
//                    vproResidual(layer, segment, buffer_calc); // Load, add, store
                }
                /*** Wait for finish ***/
                command_list.append(createSync());
//                command_list.append(createVPRO_wait());
//                command_list.append(createDMA_wait());
                /*** Store this ***/
                ln = 0;
                un = 0;
                cl = 0;
                for (auto i = 0; i < VPRO_CFG::parallel_Lanes; i++) {
                    segment = *calculation[i + seg_cnt];
                    if (!segment.dummy) {
                        command_list.append(createDMA_DataStore(layer, segment, cl, un, buffer_calc, ln));
//                        dmaDataStore(layer, segment, cl, un, buffer_calc, ln);
                    }
                    ++ln;
                    if (ln == VPRO_CFG::LANES) {
                        ++un;
                        ln = 0;
                        if (un == VPRO_CFG::UNITS) {
                            un = 0;
                            ++cl;
                        }
                    }
                }
                /*** Wait for finish ***/
                command_list.append(createSync());
//                command_list.append(createVPRO_wait());
//                command_list.append(createDMA_wait());

                buffer_load = (buffer_load == A) ? B : A;
                buffer_calc = (buffer_calc == A) ? B : A;
                seg_cnt += VPRO_CFG::parallel_Lanes;
            } // now all segments are finished
        }

        /**
         * Interleave Order of DMA, VPRO
         */
        // Interleave VPRO and DMA Commands inside one block (between sync).
        // DMA may change order in subblock of Load / Store
        if (do_interleaving){
            assert(do_dma_extension == false);
            auto il = SegmentInterleaver(command_list);
            command_list = il.interleave();
        }
        /**
         * DMA Block Extension (Hardware of EIS-V with DMA Command FSM)
         */
        if (do_dma_extension){
            assert(do_interleaving == false);
            auto dX = VPRO_DMA_BlockExtension_Extractor(command_list);
            command_list = dX.generate();
        }

        // Containing all COMMAND_SEGMENT for this layer
        // save those segments list to load in execution
//        QList<COMMAND_SEGMENT> command_list;

        uint size_yolo_seg_list = BaseExtractor::extract_segment_size(l);
        uint size_seg_list = command_list.size();

        if (size_yolo_seg_list != size_seg_list) {
            sed_list.append(size_seg_list);
            printf_error("%i, ", size_seg_list);
            fail = true;
        }

//        int cnt_vpro = 0;
//        int cnt_dma = 0, cnt_dma_l2e1d = 0, cnt_dma_l2e2d = 0, cnt_dma_e2l1d = 0, cnt_dma_e2l2d = 0;
//        int cnt_vpro_sync = 0;
//        int cnt_dma_sync = 0;
//        for (const auto s: command_list) {
//            if (s.type == VPRO_SEG) {
//                cnt_vpro++;
//            } else if (s.type == DMA_SEG) {
//                cnt_dma++;
////                COMMAND_DMA::COMMAND_DMA &dma = *reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(s.data);
//                auto *dma = reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(s.data);
//                if (dma->direction == COMMAND_DMA::DMA_DIRECTION::e2l1D) {
//                    cnt_dma_e2l1d++;
//                } else if (dma->direction == COMMAND_DMA::DMA_DIRECTION::e2l2D) {
//                    cnt_dma_e2l2d++;
//                } else if (dma->direction == COMMAND_DMA::DMA_DIRECTION::l2e1D) {
//                    cnt_dma_l2e1d++;
//                } else if (dma->direction == COMMAND_DMA::DMA_DIRECTION::l2e2D) {
//                    cnt_dma_l2e2d++;
//                } else {
//                    printf_error("Dma type unknown direction!\n");
//                }
//            } else if (s.type == DMA_WAIT) {
//                cnt_dma_sync++;
//            } else if (s.type == VPRO_WAIT) {
//                cnt_vpro_sync++;
//            } else {
//                printf_error("command type unknown!\n");
//            }
//        }
//        printf_info("Cnts: VPRO %i, DMA: %i, SYNC_VPRO: %i, SYNC_DMA: %i\n", cnt_vpro, cnt_dma, cnt_vpro_sync, cnt_dma_sync);
//        printf_info("CntDMA types: l2e1d: %i, l2e2d: %i, e2l1d: %i, e2l2d: %i\n", cnt_dma_l2e1d, cnt_dma_l2e2d, cnt_dma_e2l1d, cnt_dma_e2l2d);

        /**
         * Copy and correct Bias/Kernel base address to target address (+ riscv readelf position + offset)
         */
        auto *command_final_list = new COMMAND_SEGMENT[size_seg_list]();
        const int16_t *bias_base = BaseExtractor::extract_bias_base(conv, layer.number);
        const int16_t *kernel_base = BaseExtractor::extract_kernel_base(conv, layer.number);
        auto kernel_in_conv = uint32_t(intptr_t(kernel_base)) - uint32_t(intptr_t(conv));
        auto bias_in_conv = uint32_t(intptr_t(bias_base)) - uint32_t(intptr_t(conv));
        if (set_base_addr_weights_to_elf_extraction) {
            auto conv_elf_base = getElfBaseForObject("../bin/main.readelf",
                                                     (QString("conv") + QString::number(l)).toStdString().c_str());
            if (!fail)
                printf_info("[Segment Adding for DMAs] Base for conv%i [.elf extracted]: 0x%8x\n", l, conv_elf_base);

            int i = 0;
            for (const auto& s: command_list) {
                command_final_list[i] = COMMAND_SEGMENT(s);
                // TODO: modify weights base addresses for bias and weights
                if (command_final_list[i].type == DMA_SEG) {
                    COMMAND_DMA::COMMAND_DMA &dma = *reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(command_final_list[i].data);
                    if (dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l1D) {
                      dma.mm_addr = dma.mm_addr + kernel_in_conv + conv_elf_base;
                    }
                }
                i++;
            }
        } else {    // just set it to 0 base addr offset (not weights base -> elf, ISS, ... differ where the arrays are located)
            int i = 0;
            for (const auto& s: command_list) {
                command_final_list[i] = COMMAND_SEGMENT(s);
                // TODO: modify weights base addresses for bias and weights
                if (command_final_list[i].type == DMA_SEG) {
                    COMMAND_DMA::COMMAND_DMA &dma = *reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(command_final_list[i].data);
                    if (dma.direction == COMMAND_DMA::DMA_DIRECTION::e2l1D) {
                      dma.mm_addr = dma.mm_addr + kernel_in_conv;
                    }
                }
                i++;
            }
        }

        /**
         * append to return final list
         */
        for (uint seg_index = 0; seg_index < size_seg_list; ++seg_index) {
            complete_command_list[l].append(command_final_list[seg_index]);
        }
        original_layers.pop_front();

        delete[] command_final_list;
    } // for layer

    if(!fail){
        printf_success("Segment List copied to YOLO Struct (reduced)\n");
    } else {
        printf_error("\n\nNot successfull generated Struct... configuraton_loader/yolo_configuration.h is going to be modified. Rerun this compile step!\n\n");
        QString search_ = "";
        for (auto size_ : sed_list){
            search_ += (QString::number(size_)) + ", ";
        }
        bool successful_replace = false;
        QString filename = QString(SOURCE_DIR) + "/configuration_loader/yolo_configuration.h";
        printf_info("%s\n", ("Infile: " + filename).toStdString().c_str());
        QFile inputFile(filename);
        if (inputFile.open(QIODevice::ReadOnly))
        {
            QFile outFile(filename+".tmp");
            if (outFile.open(QIODevice::WriteOnly)) {
                QTextStream out(&outFile);
                QTextStream in(&inputFile);
                while (!in.atEnd()) {
                    QString line = in.readLine();
                    out << line << "\n";
                    if (line.contains("SEARCH__STRING__SEG__NUM")) {
                        line = in.readLine();
                        out << search_ << "\n"; // replace
                        successful_replace = true;
                    }
                }
                outFile.close();
            } else{
                printf_error("Tmp Out File could not be opened! Replace manually!\n");
            }
            inputFile.close();
        } else {
            printf_error("File to modify could not be opened! Replace manually!\n");
        }
        if (successful_replace){
            QFile::rename(filename, filename+".bak");
            QFile::rename(filename+".tmp", filename);
            printf_success("Replace of yolo_configuration.h successfull!\n");
            exit(3);
        }
        exit(2);
    }
    return complete_command_list;
}
