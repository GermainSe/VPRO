//
// Created by gesper on 12.11.20.
//

#ifndef CNN_YOLO_LITE_SEGMENTGENERATION_H
#define CNN_YOLO_LITE_SEGMENTGENERATION_H

#include <cnn_struct.h>
#include <QList>
#include <QVector>

//constexpr int LANES = NUM_VECTORLANES;
//constexpr int UNITS = NUM_VU_PER_CLUSTER;
//constexpr int CLUSTERS = NUM_CLUSTERS;
//constexpr int parallel_LANES = LANES * UNITS * CLUSTERS;

namespace SegmentGeneration {

    /**
     * creates a list of segments to be processed for this CNN layer
     * parallelLanes items can be processed (dma) parallel (data are correct when loaded to LANE)
     * front LANE items per parallelLanes batch contains the vpro calc information (does not change inside the layers segments)
     * contains dummy elements if the number count not fit to HW
     *
     * @param segments return list
     * @param layer current layer with segments of conv
     * @return number of dummy elements per block of parallelLanes in the end
     */
    int fillSegmentList(QVector<SEGMENT *> &segments, const LAYER &layer);
    bool pushToSegmentsIfFullBatch(QVector<SEGMENT *> &segments, QList<QList<SEGMENT *>> &HW_batch_list, int &lane);

    SEGMENT *generateDummySegment(const SEGMENT *ref);
    QList<SEGMENT *> generateDummySegment(const SEGMENT *ref, int count);
    int getDummyCount(QVector<SEGMENT *> &segments, const LAYER &layer, bool printEnd = false);


    /**
     * call of fillSegmentList.
     * to fill the final list, depending on actual HW configuration to calculate Layer-after-Layer
     * TODO: improvement by layer merging (overhead-segments allow start of next layer ; real complex merge...)
     *
     * final List to be calc in order
     * contains LANES segments with same input data (different kernel) for same unit
     * each sequence contains independent segments (different input data, output data & kernels) to be executed on
     *   different units/clusters
     * LANE related segments for same unit/lane have different kernels/input data and occur after LANES*UNITS*CLUSTERS
     *   segments again
     * UNIT related segments have same input data but different segments on * lanes (differ in out/x or y).
     *   are grouped to 2 LANES due to output channels count dividable by 2
     *
     * @param layers
     * @return List for cnn execution using vpro lib for cnn execution (acc in lane, parallel load to different units, ... out channel after out channel)
    */
    QList<QVector<SEGMENT *>> generateSegmentList(const std::list<LAYER> &layers);
}


#endif //CNN_YOLO_LITE_SEGMENTGENERATION_H
