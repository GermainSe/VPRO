//
// Created by gesper on 06.04.22.
//

#include "BaseExtractor.h"
#include <helper.h>
#include "../configuration_loader/yolo_configuration.h"

namespace BaseExtractor {
    int16_t *extract_bias_base(void *conv, unsigned int layer) {
        int16_t *bias_base = nullptr;

        switch (layer) {
#ifndef TESTRUN
            case 1:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<3, 16, 3> *>(conv)->bias[0]);
                break;
            case 2:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<16, 32, 3> *>(conv)->bias[0]);
                break;
            case 3:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<32, 64, 3> *>(conv)->bias[0]);
                break;
            case 4:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<64, 128, 3> *>(conv)->bias[0]);
                break;
            case 5:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<128, 128, 3> *>(conv)->bias[0]);
                break;
            case 6:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<128, 256, 3> *>(conv)->bias[0]);
                break;
            case 7:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<256, 125, 1> *>(conv)->bias[0]);
                break;
#else
            case 1:
                bias_base = &(reinterpret_cast<WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> *>(conv)->bias[0]);
                break;
#endif
            default:
                printf_error(
                        "[layer.number error!] Bias base mm address error. Bias is stored as offset inside the bias parameter array! the offset has > 32-bit!!!! \n");
                break;
        }
        return bias_base;
    }

    int16_t *extract_kernel_base(void *conv, unsigned int layer) {
        int16_t *kernel_base = nullptr;

        switch (layer) {
#ifndef TESTRUN
            case 1:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<3, 16, 3> *>(conv)->kernel[0][0][0]);
                break;
            case 2:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<16, 32, 3> *>(conv)->kernel[0][0][0]);
                break;
            case 3:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<32, 64, 3> *>(conv)->kernel[0][0][0]);
                break;
            case 4:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<64, 128, 3> *>(conv)->kernel[0][0][0]);
                break;
            case 5:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<128, 128, 3> *>(conv)->kernel[0][0][0]);
                break;
            case 6:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<128, 256, 3> *>(conv)->kernel[0][0][0]);
                break;
            case 7:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<256, 125, 1> *>(conv)->kernel[0][0][0]);
                break;
#else
            case 1:
                kernel_base = &(reinterpret_cast<WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> *>(conv)->kernel[0][0][0]);
                break;
#endif
            default:
                printf_error(
                        "[layer.number error!] Kernel base mm address error. Kernel is stored as offset inside the Kernel parameter array! the offset has > 32-bit!!!! \n");
                break;
        }

        return kernel_base;
    }


    int extract_segment_size(unsigned int layer) {
        switch (layer) {
            case 0:
                return sizeof(L0_Segments) / sizeof(L0_Segments[0]);
#ifndef TESTRUN
            case 1:
                return sizeof(L1_Segments) / sizeof(L1_Segments[0]);
            case 2:
                return sizeof(L2_Segments) / sizeof(L2_Segments[0]);
            case 3:
                return sizeof(L3_Segments) / sizeof(L3_Segments[0]);
            case 4:
                return sizeof(L4_Segments) / sizeof(L4_Segments[0]);
            case 5:
                return sizeof(L5_Segments) / sizeof(L5_Segments[0]);
            case 6:
                return sizeof(L6_Segments) / sizeof(L6_Segments[0]);
#endif
            default:
                printf_error("[Layer index out of boundary!!!!!!!!!!!!!!!!!!!!!!!!!!!! @ generate_configuration.cpp]");
                return -1;
        }
    }

}