//
// Created by gesper on 06.04.22.
//

#ifndef CNN_YOLO_LITE_HW_YOLO_LOADER_H
#define CNN_YOLO_LITE_HW_YOLO_LOADER_H

#include "../includes/yolo_lite_tf2.h" // CNN Weights
#include "../configuration_loader/yolo_configuration.h"
#include "../configuration_generation/LayerGeneration.h"
#include "../configuration_generation/SegmentGeneration.h"

class yolo_loader {

public:
    yolo_loader()= default;
    yolo_loader(bool set_base_addr_weights_to_elf_extraction, bool do_interleaving, bool do_dma_extension);

    std::list<LAYER> &getLayers() { return original_layers; }

    QList<QVector<SEGMENT *>> &getSegments() { return segments; }

    QList<COMMAND_SEGMENT> *getCommandList() { return command_list; }

    static void print();

private:
    std::list<LAYER> original_layers, layers;
    QList<QVector<SEGMENT *>> segments;
    QList<COMMAND_SEGMENT> *command_list{};

    void dump_layers();
    void dump_segments();
    void dump_commands();

/**
 * assign global const variables for biases and coefficients to Layer definition struct variables
 * need to be called before accessing variables for bias/coeffs (addresses aren't set before)
 * @tparam Layer
 * @tparam Coeff
 * @tparam Bias
 * @param layer
 * @param coefficients
 * @param bias
 */
    template<typename CONV, typename Coeff, typename Bias>
    void assignKernel(CONV &conv, const Coeff &coefficients, const Bias &bias, const LAYER_WRAPPER &layer) {
        for (uint o_c = 0; o_c < layer.out_channels; o_c++) {
            if (layer.type == LAYERTYPE::DEPTHWISE_CONV2) {
                for (int k = 0; k < 9; ++k) {
                    conv.kernel[0][o_c][k] = (coefficients[0][o_c][k]);
                }
            } else if (layer.type == LAYERTYPE::CONV2) {
                for (uint i_c = 0; i_c < layer.in_channels; i_c++) {
                    for (uint k = 0; k < uint(layer.kernel_length * layer.kernel_length); ++k) {
                        conv.kernel[i_c][o_c][k] = (coefficients[i_c][o_c][k]); // reorder!
                    }
                }
            }
        }
        for (uint o_c = 0; o_c < layer.out_channels; o_c++) {
            conv.bias[o_c] = (bias[o_c]);
        }
        printf_success("Assigned Kernel & Bias for %i -> %i channels\n", layer.in_channels, layer.out_channels);
    }


/**
 * Copy the complex LAYER data to the transferred LAYER_REDUCED object l
 * @tparam Layer LAYER_REDUCED with correct in and out channel template parameters
 * @param l pointer to target LAYER_REDUCED structure
 * @param layers reference parameter. front element is used to read data, pop'd in the end of this function
 */
    template<typename Layer>
    void copyLayerData(Layer &l, std::list<LAYER> &layers) {
        l.type = layers.front().type;
        l.number = (uint16_t(layers.front().number));
        l.conv_result_shift_right = (uint16_t(layers.front().conv_result_shift_right));
        l.relu_6_shift_left = (uint16_t(layers.front().relu_6_shift_left));
        l.bias_shift_right = (uint16_t(layers.front().bias_shift_right));
        l.store_shift_right = (uint16_t(layers.front().store_shift_right));
        l.residual_1_left_shift = (uint16_t(layers.front().residual_1_left_shift));
        l.residual_0_left_shift = (uint16_t(layers.front().residual_0_left_shift));
        l.pool_stride = (uint16_t(layers.front().pool.stride));
        l.relu_type = layers.front().relu.type;
        l.pad.bottom = (int32_t(layers.front().pad.bottom));
        l.pad.left = (int32_t(layers.front().pad.left));
        l.pad.right = (int32_t(layers.front().pad.right));
        l.pad.top = (int32_t(layers.front().pad.top));
        l.pad.value = (int32_t(layers.front().pad.value));
        l.stride = (uint16_t(layers.front().conv.stride));
        l.kernel_length = (uint16_t(layers.front().conv.kernel_length));
        l.seg_out_w = (uint16_t(layers.front().conv.seg_out_w));
        l.seg_out_h = (uint16_t(layers.front().conv.seg_out_h));
        l.in_channels = (uint16_t(layers.front().conv.in_channels));
        l.out_channels = (uint16_t(layers.front().conv.out_channels));
        l.seg_in_w = (uint16_t(layers.front().conv.seg_in_w));
        l.seg_in_h = (uint16_t(layers.front().conv.seg_in_h));
        l.input.mm_base = (uint32_t(layers.front().input.MM_base));
        l.input.x = (uint32_t(layers.front().input.in_x));
        l.input.y = (uint32_t(layers.front().input.in_y));
        l.input.channels = (uint32_t(layers.front().input.in_channels));
        l.input.x_stride = (uint32_t(layers.front().input.MM_x_stride));
        l.output.mm_base = (uint32_t(layers.front().output.MM_base));
        l.output.x = (uint32_t(layers.front().output.in_x));
        l.output.y = (uint32_t(layers.front().output.in_y));
        l.output.channels = (uint32_t(layers.front().output.in_channels));
        l.output.x_stride = (uint32_t(layers.front().output.MM_x_stride));
        layers.pop_front();
    }

};


#endif //CNN_YOLO_LITE_HW_YOLO_LOADER_H
