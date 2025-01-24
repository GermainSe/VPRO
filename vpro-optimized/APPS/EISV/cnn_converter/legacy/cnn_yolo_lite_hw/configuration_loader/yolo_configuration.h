//
// Created by gesper on 11.11.20.
//


#ifndef CNN_YOLO_LITE_CONFIGURATION_H
#define CNN_YOLO_LITE_CONFIGURATION_H

#include <stdint.h>

#ifdef IS_SIMULATION

#include <cnn_struct.h>

#else
#include <cnn_struct_reduced.h>
#endif

#include "../includes/yolo_lite_tf2.h"
#include "../includes/testlayer.h"

/**
 * if TESTRUN is defined, the following Layer size / Segment size variables are used
 * the getLayerList() will use the TESTLAYER (instead yolo layers)
 */
//#define TESTRUN 1

//extern const uint32_t layer_segment_num[layer_count] __attribute__ ((aligned (16)));

#ifdef TESTRUN
constexpr bool load_execute_first_layer_only = true;
constexpr uint32_t layer_count = 1;
constexpr uint32_t test_segm_cont = 45; // 1C1U: 16x16 -> 14, 112x112 -> 179, 16x16x3 -> 26, 16x16x2 - 3 -> 45

constexpr uint32_t layer_segment_num[layer_count] __attribute__ ((aligned (16))) = {
        test_segm_cont
};

constexpr uint32_t input_mm_base = 0x11000000;
constexpr uint32_t output_mm_base = input_mm_base + TESTLAYER::test_layer_in_channels*TESTLAYER::test_layer_dim*TESTLAYER::test_layer_dim*2;
constexpr uint32_t output_mm_end = output_mm_base + TESTLAYER::test_layer_out_channels*TESTLAYER::test_layer_dim*TESTLAYER::test_layer_dim*2;

extern WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> conv0;

extern COMMAND_SEGMENT L0_Segments[test_segm_cont];
#else
constexpr bool load_execute_first_layer_only = true;
constexpr uint32_t layer_count = 7;

constexpr uint32_t layer_segment_num[layer_count] __attribute__ ((aligned (16))) = {
        // SEARCH__STRING__SEG__NUM - DO NOT REMOVE THIS COMMENT!!!
1834, 3157, 4872, 8773, 17285, 34568, 33791, 
};

constexpr uint32_t input_mm_base = 0x11000000;
constexpr uint32_t output_mm_base = 0x1110a700;
constexpr uint32_t output_mm_end = output_mm_base + 0x01000000; // for bin transmission check (upper boundary)

extern WEIGHTS_REDUCED<3, 16, 3> conv0 __attribute__ ((aligned (16)));
extern WEIGHTS_REDUCED<16, 32, 3> conv1 __attribute__ ((aligned (16)));
extern WEIGHTS_REDUCED<32, 64, 3> conv2 __attribute__ ((aligned (16)));
extern WEIGHTS_REDUCED<64, 128, 3> conv3 __attribute__ ((aligned (16)));
extern WEIGHTS_REDUCED<128, 128, 3> conv4 __attribute__ ((aligned (16)));
extern WEIGHTS_REDUCED<128, 256, 3> conv5 __attribute__ ((aligned (16)));
extern WEIGHTS_REDUCED<256, 125, 1> conv6 __attribute__ ((aligned (16)));

extern COMMAND_SEGMENT L0_Segments[layer_segment_num[0]];
extern COMMAND_SEGMENT L1_Segments[layer_segment_num[1]];
extern COMMAND_SEGMENT L2_Segments[layer_segment_num[2]];
extern COMMAND_SEGMENT L3_Segments[layer_segment_num[3]];
extern COMMAND_SEGMENT L4_Segments[layer_segment_num[4]];
extern COMMAND_SEGMENT L5_Segments[layer_segment_num[5]];
extern COMMAND_SEGMENT L6_Segments[layer_segment_num[6]];

#endif  // no testrun

// combine to one struct for yolo
struct YOLO_LITE {
    YOLO_LITE() {
        weights[0] = &conv0;
#ifndef TESTRUN
        weights[1] = &conv1;
        weights[2] = &conv2;
        weights[3] = &conv3;
        weights[4] = &conv4;
        weights[5] = &conv5;
        weights[6] = &conv6;
#endif

        segments[0] = &(L0_Segments[0]);
#ifndef TESTRUN
        segments[1] = &(L1_Segments[0]);
        segments[2] = &(L2_Segments[0]);
        segments[3] = &(L3_Segments[0]);
        segments[4] = &(L4_Segments[0]);
        segments[5] = &(L5_Segments[0]);
        segments[6] = &(L6_Segments[0]);
#endif
    };

    void *weights[layer_count]{};
    LAYER_WRAPPER layer[layer_count];
    COMMAND_SEGMENT *segments[layer_count]{};
};


extern YOLO_LITE yolo __attribute__ ((aligned (16)));

inline uint32_t getLayerCount() {
    return layer_count;
}

inline uint32_t getSegmentCount() {
    uint32_t sum = 0;
    for (unsigned int i = 0; i < getLayerCount(); ++i) {
        sum += layer_segment_num[i];
    }
    return sum;
}

#endif //CNN_YOLO_LITE_CONFIGURATION_H
