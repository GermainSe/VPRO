//
// Created by gesper on 12.11.20.
//

#include "SegmentGeneration.h"

#include <chrono>
//#include <helper.h>
#include <segment_scheduling.h>
#include <core_wrapper.h>
//#include "defines.h"
#include "simulator/helper/debugHelper.h"
//#include "simulator/helper/typeConversion.h"

namespace SegmentGeneration {
    SEGMENT *generateDummySegment(const SEGMENT *ref) {
//     sim_printf("Dummy Segment generated!\n");
        SEGMENT *seg = new SEGMENT();
//    seg->in_x = ref->in_x;
//    seg->in_y = ref->in_y;
        seg->in_MM_base_0 = ref->in_MM_base_0;
        seg->in_MM_base_1 = ref->in_MM_base_1;
        seg->in_MM_x_stride_0 = ref->in_MM_x_stride_0;
        seg->in_MM_x_stride_1 = ref->in_MM_x_stride_1;

//    seg->out_x = ref->out_x;
//    seg->out_y = ref->out_y;
        seg->out_MM_base = ref->out_MM_base;
        seg->out_MM_x_stride = ref->out_MM_x_stride;

        seg->x_seg = ref->x_seg;
        seg->y_seg = ref->y_seg;
        seg->in_channel = ref->in_channel;
        seg->out_channel = ref->out_channel;

        seg->isFirst = ref->isFirst;
        seg->isLast = ref->isLast;

        seg->dummy = true;
        return seg;
    }

    QList<SEGMENT *> generateDummySegment(const SEGMENT *ref, int count) {
//     sim_printf("Dummy Segment generated!\n");
        QList<SEGMENT *> list;
        for (; count > 0; count--) {
            SEGMENT *seg = new SEGMENT();
//        seg->in_x = ref->in_x;
//        seg->in_y = ref->in_y;
            seg->in_MM_base_0 = ref->in_MM_base_0;
            seg->in_MM_base_1 = ref->in_MM_base_1;
            seg->in_MM_x_stride_0 = ref->in_MM_x_stride_0;
            seg->in_MM_x_stride_1 = ref->in_MM_x_stride_1;

//        seg->out_x = ref->out_x;
//        seg->out_y = ref->out_y;
            seg->out_MM_base = ref->out_MM_base;
            seg->out_MM_x_stride = ref->out_MM_x_stride;

            seg->x_seg = ref->x_seg;
            seg->y_seg = ref->y_seg;
            seg->in_channel = ref->in_channel;
            seg->out_channel = ref->out_channel;

            seg->isFirst = ref->isFirst;
            seg->isLast = ref->isLast;

            seg->dummy = true;

            list.append(seg);
        }
        return list;
    }

    bool pushToSegmentsIfFullBatch(QVector<SEGMENT *> &segments, QList<QList<SEGMENT *>> &HW_batch_list, int &lane) {
        if (lane > 0 && (lane % VPRO_CFG::parallel_Lanes) == 0) {
//         sim_printf("appending full HW Lane batch to segments list! VPRO_CFG::parallel_Lanes (%i), List size %i -> \n",
//                VPRO_CFG::parallel_Lanes, segments.size());
            for (int s = 0; s < HW_batch_list.at(0).size(); s++) {
                for (auto &batch: HW_batch_list) {
                    SEGMENT *seg = batch[s];
                    segments.append(seg);
                }
            }
//        for(auto & batch : HW_batch_list){
//             sim_printf("Lane Batch pushed:\n");
//            for(auto & s : batch){
//                printf_info("\tSegment, %i x %i, in %i, out %i, dummy %i, first %i, last %i\n", s->x_seg, s->y_seg,
//                        s->in_channel, s->out_channel,
//                            (s->dummy)?1:0, (s->isFirst)?1:0, (s->isLast)?1:0);
//            }
//        }
            for (auto &batch: HW_batch_list) {
                batch.clear();
            }
//         sim_printf("List size %i\n", segments.size());
            lane = 0;
            return true;
        }
        return false;
    }

    int fillSegmentList(QVector<SEGMENT *> &segments, const LAYER &layer) {
        // [Cl: %i, VU/Cl: %i, Vl/Vu: %i, Total VPRO_CFG::LANES: %i]\n", CLUSTERS, VPRO_CFG::UNITS, VPRO_CFG::LANES, VPRO_CFG::parallel_Lanes);

        //
        // creates a batch of (HW count) segemnts to be processed parallel
        // all use same input block (CONV2, not DEPTHWISE CONV2)
        // different kernel
        //
        int appended_dummies = 0;

        // dma kernel load always
        // input data load once per unit, per segment -> always but broadcasted to both VPRO_CFG::LANES

        // output calculated over all input channels and accumulated in lane
        // store after IC convolutions
        QList<QList<SEGMENT *>> HW_batch_list;
        for (int i = VPRO_CFG::parallel_Lanes; i > 0; i--) {
            HW_batch_list.append(QList<SEGMENT *>());
        }
        QList<SEGMENT *> *batch;
        int lane = 0;

        for (auto y = 0; y < layer.conv.seg_num_y; y++) {
            for (auto x = 0; x < layer.conv.seg_num_x; x++) {
                for (auto oc = 0; oc < layer.output.in_channels; oc++) {   // e.g. for CONV2 mostly between 3 and 512

                    // this oc, x, y is processed on hw lane ...
                    batch = &HW_batch_list[lane];
                    lane++;
                    if (layer.type == LAYERTYPE::CONV2) {
                        for (auto ic = 0; ic < layer.conv.in_channels; ic++) {
                            SEGMENT *seg = &(layer.conv.segments[oc][y][x][ic]);
                            // requires load of bias ...
                            seg->isFirst = (ic == 0);
                            // requires store to MM
                            seg->isLast = (ic == layer.conv.in_channels - 1);
                            seg->dummy = false;
//                        printSegment(layer, *seg);
                            batch->append(seg);

//                         sim_printf("Modified batch %i: Size now: %i\n", lane, batch->size());

                            if (seg->isLast && lane != 0 && (lane % VPRO_CFG::LANES) != 0 && oc == layer.output.in_channels - 1) {
//                          fill Dumies until this batch can be run on the VPRO_CFG::LANES in the current unit
//                          1) next appended item is a different OC
//                             the input from this last one unit is wrong (last IC)
//                               => special case if only one in_channel. different out will receive correct in_channel
//                          2) if x/y differ the input is wrong (IC, OC)
//                          3) next ic requires full batch, so next element
                                int lastBatchSize = batch->size();
                                batch = &HW_batch_list[lane];
                                lane++;
                                appended_dummies += lastBatchSize;
                                batch->append(generateDummySegment(seg, lastBatchSize));
                            }
                        } // IC
                    } else { // DEPTHWISE or RESIUDAL, one inchannel per segment
                        SEGMENT *seg = &(layer.conv.segments[oc][y][x][0]);
                        // requires load of bias ...
                        seg->isFirst = true;
                        // requires store to MM
                        seg->isLast = true;
                        seg->dummy = false;
//                        printSegment(layer, *seg);
                        batch->append(seg);

                        // TODO: in channel changes for each seg, x/y as well, fill second lane in unit always
                        int lastBatchSize = batch->size();
                        batch = &HW_batch_list[lane];
                        lane++;
                        appended_dummies += lastBatchSize;
                        batch->append(generateDummySegment(seg, lastBatchSize));
                    }
//                     sim_printf("HW_batch_list size: %i, batch size (lane %i) %i\n", HW_batch_list.size(), lane, batch->size());
                    pushToSegmentsIfFullBatch(segments, HW_batch_list, lane);
                } // OC
                while (lane != 0 && (lane % VPRO_CFG::LANES) != 0) {
//                  1) fill Dumies until next batch can run on VPRO_CFG::LANES of a different unit
//                  different x/y -> different input data!
//                     sim_printf("Generating a dummy batch of size %i, next OC will run on a different Unit!\n", HW_batch_list[lane - 1].size());
                    batch = &HW_batch_list[lane];
                    int lastBatchSize = HW_batch_list[lane - 1].size();
                    appended_dummies += lastBatchSize;
                    batch->append(generateDummySegment(HW_batch_list[lane - 1][0], lastBatchSize));
                    lane++;
                }
                pushToSegmentsIfFullBatch(segments, HW_batch_list, lane);
            } // X
        } // Y
        if (lane != 0) { // batches for some VPRO_CFG::LANES
            while (lane % VPRO_CFG::parallel_Lanes != 0) {
                // remaining segments batch needs empty batches for other VPRO_CFG::LANES
//                 sim_printf("Generating a dummy batch of size %i to have all VPRO_CFG::UNITS assigned for this hw!\n", HW_batch_list[lane - 1].size());
                batch = &HW_batch_list[lane];
                int lastBatchSize = HW_batch_list[lane - 1].size();
                appended_dummies += lastBatchSize;
                batch->append(generateDummySegment(HW_batch_list[lane - 1][0], lastBatchSize));
                lane++;
            }
            if (!pushToSegmentsIfFullBatch(segments, HW_batch_list, lane))
                printf_warning("Final Push Batch not successfull! Remaining batches of size %i. lane: &i\n",
                               HW_batch_list[0].size(), lane);
        }

        if (appended_dummies != 0) {
            printf_info("  Segment List generated.\n");
            printf_info("                 Layer %i.: %i (%i x %i) In-Channels -> %i (%i x %i) Out-Channels\n",
                        layer.number, layer.input.in_channels, layer.input.in_x, layer.input.in_y,
                        layer.output.in_channels, layer.output.in_x, layer.output.in_y);
            printf_info(
                    "                 %3.1f%% -> Total: %i Segments in List of this Layer. (%i Segments meaningfull for CNN)\n",
                    100 * (float(segments.size()) / float(layer.conv.num_segments)), segments.size(),
                    layer.conv.num_segments);
        }
        return appended_dummies;
    }

    int getDummyCount(QVector<SEGMENT *> &segments, const LAYER &layer, bool printEnd) {
        int size = segments.size();

        int batch_dummies = 0;
        for (int i = size - VPRO_CFG::parallel_Lanes; i < size; i++) {
            if (segments.at(i)->dummy)
                batch_dummies++;
        }

        if (printEnd) {
            sim_printf("%s\n", std::string(25, '#').c_str());
            sim_printf("Layer: %i\n", layer.number);
            sim_printf("%s\n", std::string(25, '#').c_str());
            auto color = RESET_COLOR;
            for (int i = segments.size() - VPRO_CFG::parallel_Lanes * 3; i < segments.size(); i++) {
                SEGMENT *s = segments.at(i);
                sim_printf("%s", color);
                sim_printf("%s", (s->dummy) ? YELLOW : NORMAL_);
                sim_printf("[Segment %6i] ", i);
                sim_printf("\tX %3i/%i, ", s->x_seg, layer.conv.seg_num_x);
                sim_printf("\tY %3i/%i, ", s->y_seg, layer.conv.seg_num_y);
                sim_printf("\tIN %3i, ", s->in_channel);
                sim_printf("\tOUT %3i, ", s->out_channel);
                sim_printf("\tFirst %1i, ", (s->isFirst ? 1 : 0));
                sim_printf("\tLast %1i, ", (s->isLast ? 1 : 0));
                sim_printf("\tDummy %1i, ", (s->dummy ? 1 : 0));
                sim_printf("\n%s", RESET_COLOR);
                if (i % VPRO_CFG::parallel_Lanes == VPRO_CFG::parallel_Lanes - 1) {
                    if (color == RESET_COLOR)
                        color = INVERTED;
                    else
                        color = RESET_COLOR;
                }
            }
            sim_printf(RESET_COLOR);
            sim_printf("\n");
        }

        return batch_dummies * layer.input.in_channels;
    }

    QList<QVector<SEGMENT *>> generateSegmentList(const std::list<LAYER> &layers) {
/***
     * call of fillSegmentList.
     * to fill the final list, depending on actual HW configuration to calculate Layer-after-Layer
     * TODO: improvement by layer merging (overhead-segments allow start of next layer ; real complex merge...)
     *
    // final List to be calc in order
    // contains VPRO_CFG::LANES segments with same input data (different kernel) for same unit
    // each sequence contains independent segments (different input data, output data & kernels) to be executed on
    //   different VPRO_CFG::UNITS/clusters
    // LANE related segments for same unit/lane have different kernels/input data and occur after VPRO_CFG::LANES*VPRO_CFG::UNITS*CLUSTERS
    //   segments again
    // UNIT related segments have same input data but different segments on * VPRO_CFG::LANES (differ in out/x or y).
    //   are grouped to 2 VPRO_CFG::LANES due to output channels count dividable by 2
    */
        auto start = std::chrono::steady_clock::now();
        printf("Generating Segment List for VPRO...\n");

        fflush(stdout);
        QList<QVector<SEGMENT *>> segments;
        int newdummies = 0;
        int newdummiessum = 0;
//    int olddummies = 0;
        for (const LAYER &l: layers) {
            // new list of segments to be processed in this layer (including NOP-Segments in end...)
            QVector<SEGMENT *> newsegs;
            newdummies = fillSegmentList(newsegs, l);
//        printSegmentList(newsegs, VPRO_CFG::LANES, l);
            segments.push_back(newsegs);
            newdummiessum += newdummies;
            if (newdummies != 0)
                printf_info("Dummys in last %i (parallelLanes) elements: %i\n", VPRO_CFG::parallel_Lanes, newdummies);
        }
        if (newdummiessum != 0)
            printf("newdummies sum: %i\n", newdummiessum);

        auto end = std::chrono::steady_clock::now();
        qDebug() << "Segment List Generation. Elapsed time : "
                 << std::chrono::duration_cast<std::chrono::microseconds>(end - start).count()
                 << " us";
        return segments;
    }

}