//
// Created by gesper on 06.04.22.
//

#ifndef CNN_YOLO_LITE_HW_SEGMENT_CREATION_DMA_H
#define CNN_YOLO_LITE_HW_SEGMENT_CREATION_DMA_H

#include <QVector>
#include <stdint.h>
#include <cnn_struct.h>
#include <vpro/dma_cmd_struct.h>
#include "segment_scheduling.h"

#include <QVector>

// TODO max number of units is 56 due to dma broadcast limit
extern QVector<DMA_DESCRIPTOR> dma_transactions_type1D;
extern QVector<DMA_DESCRIPTOR> dma_transactions_type2D;


COMMAND_SEGMENT createDMA_wait();

void dmaBiasLoad(const LAYER &layer, const SEGMENT &segment, void *conv, int cluster, int unit, BUFFER &buffer_load,
                 int lane);

void dmaCoeffLoad(const LAYER &layer, const SEGMENT &segment, void *conv, int cluster, int unit, BUFFER &buffer_load,
                  int lane);

void dmaDataLoad(const LAYER &layer, const SEGMENT &segment, int cluster, int unit, BUFFER &buffer_load);

void dmaResidualDataLoad(const LAYER &layer, const SEGMENT &segment, int cluster, int unit, BUFFER &buffer_load);

COMMAND_SEGMENT createDMA_Load(DMA_DESCRIPTOR &dma, const uint32_t &unit_mask, void *conv, const LAYER &layer);

COMMAND_SEGMENT
createDMA_DataStore(const LAYER &layer, const SEGMENT &segment, int cluster, int unit, BUFFER &buffer_load, int lane);

QVector<COMMAND_SEGMENT> dmaStartBroadcastLoad(const LAYER &layer, void *conv);

#endif //CNN_YOLO_LITE_HW_SEGMENT_CREATION_DMA_H
