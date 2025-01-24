//
// Created by gesper on 1/12/21.
//

#ifndef CNN_YOLO_LITE_TESTLAYER_H
#define CNN_YOLO_LITE_TESTLAYER_H

#include "cnn_struct_reduced.h"

namespace TESTLAYER {

    constexpr int test_layer_dim = 16;
    constexpr int test_layer_in_channels = 2;
    constexpr int test_layer_out_channels = 3;
    constexpr int test_layer_pool_stride = 1;
    constexpr int test_layer_kernel = 3;

    extern RELUTYPE::RELUTYPE test_layer_relu;

    extern int16_t conv_result_shift_right;
    extern int16_t bias_store_shift_right;
    extern int16_t bias_load_shift_right;

    extern int16_t result_fractional_bit;
    extern int16_t result_integer_bit;

    //Data Format is (# out channels)(# in channels)(# kernel W*H)
    extern int16_t conv_weights[test_layer_in_channels][test_layer_out_channels][
            test_layer_kernel * test_layer_kernel];
    extern int16_t bias[test_layer_out_channels];
}

#endif //CNN_YOLO_LITE_TESTLAYER_H
