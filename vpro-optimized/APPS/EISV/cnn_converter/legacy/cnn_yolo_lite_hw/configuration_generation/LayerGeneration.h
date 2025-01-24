//
// Created by gesper on 12.11.20.
//

#ifndef CNN_YOLO_LITE_LAYERGENERATION_H
#define CNN_YOLO_LITE_LAYERGENERATION_H

#include <cnn_struct.h>
#include "list"
#include <QVector>
#include "../includes/defines.h"
#include <simulator/helper/debugHelper.h>
#include <simulator/helper/typeConversion.h>


namespace LayerGeneration {


    /**
     * Uses internal knowledge about the CNN structure
     * @return the list of structs for CNN execution on VPRO (Segment based)
     */
    std::list<LAYER> getLayerList(bool testlayer = false);

    /**
     * different HW configuration have different number of additional segments to fully calculate the given layers (CNN)
     * prints out an histogram of real calculated segments on variing numbers of vector lanes
     *  - dont care on dma's / clusters or mips attributes
     * Print of efficiency using x Lanes
     * this efficiency (overhead) is calculated and printed for maximal 514 Lanes
     * @param layers
     */
    void printHWScore(const std::list<LAYER> &layers);
};


#endif //CNN_YOLO_LITE_LAYERGENERATION_H
