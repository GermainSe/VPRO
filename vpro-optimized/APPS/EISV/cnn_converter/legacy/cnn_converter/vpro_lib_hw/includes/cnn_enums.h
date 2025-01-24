//
// Created by gesper on 1/12/21.
//

#ifndef CNN_YOLO_LITE_CNN_ENUMS_H
#define CNN_YOLO_LITE_CNN_ENUMS_H

namespace LAYERTYPE {
    enum LAYERTYPE : uint8_t {
        RESIDUAL = 0,
        CONV2 = 1,
        DEPTHWISE_CONV2 = 2,
        UNKNOWN = 3
    };
}


namespace POOLTYPE {
    enum POOLTYPE : uint8_t {
        NONE = 0,
        MAX = 1, // ideas: min pooling, avg pooling?
    };
}
namespace RELUTYPE{
    enum RELUTYPE : uint8_t {
        LEAKY = 0,
        RECT = 1,
        RELU6 = 2,
        NONE = 3
    };
}

/**
 * To identify buffers (double-buffering) inside the segment generation process
 */
enum BUFFER : uint8_t{
    A = 0,
    B = 1
};


/**
 * Top level list to be looped in order
 */
enum COMMAND_SEGMENT_TYPE : uint8_t {
    DMA_SEG = 0,
    VPRO_SEG = 1,
    DMA_WAIT = 2,
    VPRO_WAIT = 3,
    DMA_BLOCK = 4,
    BOTH_SYNC = 5,
    UNKNOWN = 255
};
/**
 * For VPRO Commands
 */
enum VPRO_TYPE : uint8_t  {
    conv_start = 0,
    conv_add = 1,
    relu_pool = 2,
    shift_store = 3,
    residual = 4
};



#endif //CNN_YOLO_LITE_CNN_ENUMS_H
