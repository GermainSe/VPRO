//
// Created by gesper on 06.04.22.
//

#ifndef CNN_YOLO_LITE_HW_SEGMENT_CREATION_VPRO_H
#define CNN_YOLO_LITE_HW_SEGMENT_CREATION_VPRO_H

#include <stdint.h>
#include <cnn_struct.h>

COMMAND_SEGMENT createVPRO_wait();

COMMAND_SEGMENT createVPRO_Conv_start(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc,
                                      bool addConvResultToSegmentInRF);

COMMAND_SEGMENT
createVPRO_Conv_add(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc, bool addConvResultToSegmentInRF);

COMMAND_SEGMENT createVPRO_Residual(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc);

COMMAND_SEGMENT createVPRO_ShiftStore(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc, int lane);

COMMAND_SEGMENT createVPRO_ReluPool(const LAYER &layer, const SEGMENT &segment, BUFFER &buffer_calc);


#endif //CNN_YOLO_LITE_HW_SEGMENT_CREATION_VPRO_H
