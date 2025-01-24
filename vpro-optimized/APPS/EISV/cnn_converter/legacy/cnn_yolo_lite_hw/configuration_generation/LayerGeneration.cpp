//
// Created by gesper on 12.11.20.
//

#include "LayerGeneration.h"

#include "map"
#include <chrono>
#include <helper.h>
//#include <core_wrapper.h>
#include "../configuration_loader/yolo_configuration.h"

namespace LayerGeneration {

    void printHWScore(const std::list<LAYER> &layers) {
        std::map<int, int> hw_score;
        // i represents # of Parallel_LANES (+1)
        for (int i = 2; i <= 514; i += 2) { // calc efficiency for a theoretical maximum of 514 lanes (+1)
            hw_score[i] = 0;
            for (const LAYER &l: layers) {
                int remaining_seg = i - ((l.conv.seg_num_x * l.conv.seg_num_y * l.output.in_channels) % i);
                if (remaining_seg >= i)
                    remaining_seg -= i;
                hw_score[i] += l.input.in_channels * remaining_seg;
            }
        }
        int max_score = 0;
        for (auto hw: hw_score) {
            if (hw.second > max_score)
                max_score = hw.second;
        }
        for (auto hw: hw_score) {
            printf("Overhead for %i Lanes:\t", hw.first);
            printProgress(float(hw.second) / float(max_score) * 100, 100);
            printf(" = %i\n", hw.second);
        }
    }


    std::list<LAYER> getLayerList(bool testlayer) {
        auto start = std::chrono::steady_clock::now();

        std::list<LAYER> layers = std::list<LAYER>();
//    std::list<LAYER *> finals;
        LAYER *layer;

        if (testlayer) { // create test layer (none network)
            auto input = new CNN_input(TESTLAYER::test_layer_dim, TESTLAYER::test_layer_dim,
                                       TESTLAYER::test_layer_in_channels, input_mm_base, 0);
            layer = new LAYER(*input, *input, LAYERTYPE::CONV2, TESTLAYER::test_layer_kernel,
                              TESTLAYER::test_layer_out_channels, 1, TESTLAYER::test_layer_pool_stride);
            layer->name = "Test";
            layer->number = 1;
            layer->relu.type = TESTLAYER::test_layer_relu;
            layer->conv_result_shift_right = TESTLAYER::conv_result_shift_right;
            layer->bias_shift_right = TESTLAYER::bias_load_shift_right;
            layer->store_shift_right = TESTLAYER::bias_store_shift_right;
            layers.push_back(*layer);

        } else {// create yolo network
            // HW: 1GB mem, VPRO region > 0x10000000, init @0x11000000
            // 1090519040
            // SIM max 512MB mem
            // 0
            auto input = new CNN_input(224, 224, 3, input_mm_base, 0);
            layer = new LAYER(*input, *input, LAYERTYPE::CONV2, 3, 16, 1, 2);
            layer->name = "Layer_0 CONV2+BIAS+RELU";
            layer->number = 1;
            layer->relu.type = RELUTYPE::LEAKY;
            layer->conv_result_shift_right = Layer_0::conv_result_shift_right;
            layer->bias_shift_right = Layer_0::bias_load_shift_right;
            layer->store_shift_right = Layer_0::bias_store_shift_right;
            layers.push_back(*layer);

            layer = new LAYER(layer->output, layer->output, LAYERTYPE::CONV2, 3, 32, 1, 2);
            layer->name = "Layer_1 CONV2+BIAS+RELU";
            layer->number = 2;
            layer->relu.type = RELUTYPE::LEAKY;
            layer->conv_result_shift_right = Layer_1::conv_result_shift_right;
            layer->bias_shift_right = Layer_1::bias_load_shift_right;
            layer->store_shift_right = Layer_1::bias_store_shift_right;
            layers.push_back(*layer);

            layer = new LAYER(layer->output, layer->output, LAYERTYPE::CONV2, 3, 64, 1, 2);
            layer->name = "Layer_2 CONV2+BIAS+RELU";
            layer->number = 3;
            layer->relu.type = RELUTYPE::LEAKY;
            layer->conv_result_shift_right = Layer_2::conv_result_shift_right;
            layer->bias_shift_right = Layer_2::bias_load_shift_right;
            layer->store_shift_right = Layer_2::bias_store_shift_right;
            layers.push_back(*layer);

            layer = new LAYER(layer->output, layer->output, LAYERTYPE::CONV2, 3, 128, 1, 2);
            layer->name = "Layer_3 CONV2+BIAS+RELU";
            layer->number = 4;
            layer->relu.type = RELUTYPE::LEAKY;
            layer->conv_result_shift_right = Layer_3::conv_result_shift_right;
            layer->bias_shift_right = Layer_3::bias_load_shift_right;
            layer->store_shift_right = Layer_3::bias_store_shift_right;
            layers.push_back(*layer);

            layer = new LAYER(layer->output, layer->output, LAYERTYPE::CONV2, 3, 128, 1, 2);
            layer->name = "Layer_4 CONV2+BIAS+RELU";
            layer->number = 5;
            layer->relu.type = RELUTYPE::LEAKY;
            layer->conv_result_shift_right = Layer_4::conv_result_shift_right;
            layer->bias_shift_right = Layer_4::bias_load_shift_right;
            layer->store_shift_right = Layer_4::bias_store_shift_right;
            layers.push_back(*layer);

            // BN Conv2D Layer #6, Out-Shape: (1, 7, 7, 256)
            //        SEGMENT segs[out_channels * seg_num_y * seg_num_x * in_channel_per_conv + out_channels * seg_num_y * seg_num_x];
            layer = new LAYER(layer->output, layer->output, LAYERTYPE::CONV2, 3, 256, 1, 1);
            layer->name = "Layer_5 CONV2+BIAS+RELU";
            layer->number = 6;
            layer->relu.type = RELUTYPE::LEAKY;
            layer->conv_result_shift_right = Layer_5::conv_result_shift_right;
            layer->bias_shift_right = Layer_5::bias_load_shift_right;
            layer->store_shift_right = Layer_5::bias_store_shift_right;
            layers.push_back(*layer);

            // BN Conv2D Layer #7, Out-Shape: (1, 7, 7, 125)
            //        SEGMENT segs[out_channels * seg_num_y * seg_num_x * in_channel_per_conv + out_channels * seg_num_y * seg_num_x];
            layer = new LAYER(layer->output, layer->output, LAYERTYPE::CONV2, 1, 125, 1, 1);
            layer->name = "Layer_6 CONV2+BIAS+NONE";
            layer->number = 7;
            layer->relu.type = RELUTYPE::NONE;
            layer->conv_result_shift_right = Layer_6::conv_result_shift_right;
            layer->bias_shift_right = Layer_6::bias_load_shift_right;
            layer->store_shift_right = Layer_6::bias_store_shift_right;
            layers.push_back(*layer);
        }
//    finals.push_back(layer);

        for (LAYER &l: layers) {

            // TODO print conditional?
//        printLayer(l);

//          AVOIIDED BY using two in mm addresses in each segment...
//        // check the residual layer. assumption: same x stride, y, x, channels
            if (l.type == LAYERTYPE::RESIDUAL) {
                if (l.residual_0->output.in_channels != l.residual_1->output.in_channels) {
                    printf_info("RESIDUAL channels mismatch!, layer %i, %i != %i\n", l.number,
                                l.residual_0->output.in_channels, l.residual_1->output.in_channels);
                }
                if (l.residual_0->output.in_x != l.residual_1->output.in_x) {
                    printf_info("RESIDUAL in_x mismatch!, layer %i, %i != %i\n", l.number, l.residual_0->output.in_x,
                                l.residual_1->output.in_x);
                }
                if (l.residual_0->output.in_y != l.residual_1->output.in_y) {
                    printf_info("RESIDUAL in_y mismatch!, layer %i, %i != %i\n", l.number, l.residual_0->output.in_y,
                                l.residual_1->output.in_y);
                }
                if (l.residual_0->output.MM_x_stride != l.residual_1->output.MM_x_stride) {
                    printf_info("RESIDUAL MM_x_stride mismatch!, layer %i, %i != %i\n", l.number,
                                l.residual_0->output.MM_x_stride, l.residual_1->output.MM_x_stride);
                }
            }

            // Check for error reasons on mul bit widths...
            if (l.relu_6_shift_left >= 24) {
                printf_warning("6 Shift for RELU out of range [-24-bit]!? %i!\n", l.relu_6_shift_left);
            }
            if (l.relu_6_shift_left > 20) {// 6 takes 3 bit. if 24 are taken, result gets negative!
                printf_info("6 Shift for RELU out of range [-20-bit]!? %i!\n", l.relu_6_shift_left);
                int correction = l.relu_6_shift_left - 20;
                printf_info("corection: %i!\n", correction);
                if (l.store_shift_right < correction)
                    printf_warning("store_shift_right does not allow correction! < corr\n");
                l.conv_result_shift_right += correction;
                l.bias_shift_right += correction;
                l.relu_6_shift_left -= correction;
                l.store_shift_right -= correction;
            }
            if (-l.bias_shift_right >= 24) {
                printf_warning("bias_shift_right out of range [-24-bit]!? %i!\n", -l.bias_shift_right);
            }
            if (l.conv_result_shift_right >= 18) {
                printf_warning("conv_result_shift_right = %i, %i takes more than 18 bit! \n", l.conv_result_shift_right,
                               1u << l.conv_result_shift_right);
            }
            if (l.conv_result_shift_right < 0) {
                printf_warning("conv_result_shift_right < 0 !: %i\n", l.conv_result_shift_right);
            }
        }
        printf("Checks done!\n");

        auto end = std::chrono::steady_clock::now();
        printf_info("Layer Struct generation... Elapsed time : %i",
                    std::chrono::duration_cast<std::chrono::microseconds>(end - start).count());
        printf_info(" us\n");
//    qDebug() << "Layer Struct generation... Elapsed time : "
//             << std::chrono::duration_cast<std::chrono::microseconds>(end - start).count()
//             << " us";

        return layers;
    }


}