//
// Created by gesper on 06.04.22.
//

#ifndef CNN_YOLO_LITE_HW_BASEEXTRACTOR_H
#define CNN_YOLO_LITE_HW_BASEEXTRACTOR_H

#include "stdint.h"

namespace BaseExtractor {
    int16_t * extract_bias_base(void *conv, unsigned int layer);
    int16_t * extract_kernel_base(void *conv, unsigned int layer);
    int extract_segment_size(unsigned int layer);
}


#endif //CNN_YOLO_LITE_HW_BASEEXTRACTOR_H
