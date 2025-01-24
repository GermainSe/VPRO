#include "helper.h"

const char* print(LAYERTYPE::LAYERTYPE type){
    switch (type) {
        case LAYERTYPE::RESIDUAL:
            return "RESIDUAL";
        case LAYERTYPE::CONV2:
            return "CONV2";
        case LAYERTYPE::DEPTHWISE_CONV2:
            return "DEPTHWISE_CONV2";
        default:
            return "UNKNOWN";
    }
}
const char* print(RELUTYPE::RELUTYPE type){
    switch (type) {
        case RELUTYPE::LEAKY:
            return "LEAKY";
        case RELUTYPE::RECT:
            return "RECT";
        case RELUTYPE::RELU6:
            return "RELU6";
        case RELUTYPE::NONE:
            return "NONE";
        default:
            return "UNKNOWN";
    }
}
const char* print(POOLTYPE::POOLTYPE type){
    switch (type) {
        case POOLTYPE::MAX:
            return "MAX";
        case POOLTYPE::NONE:
            return "NONE";
        default:
            return "UNKNOWN";
    }
}
const char* print(BUFFER type){
    switch (type) {
        case A:
            return "A";
        case B:
            return "B";
        default:
            return "UNKNOWN";
    }
}
const char* print(COMMAND_SEGMENT_TYPE type){
    switch (type) {
        case DMA_SEG:
            return "DMA_SEG";
        case VPRO_SEG:
            return "VPRO_SEG";
        case DMA_WAIT:
            return "DMA_WAIT";
        case VPRO_WAIT:
            return "VPRO_WAIT";
        default:
            return "UNKNOWN";
    }
}
const char* print(VPRO_TYPE type){
    switch (type) {
        case conv_start:
            return "conv_start";
        case conv_add:
            return "conv_add";
        case relu_pool:
            return "relu_pool";
        case shift_store:
            return "shift_store";
        case residual:
            return "residual";
        default:
            return "UNKNOWN";
    }
}

#ifdef SIMULATION
void printLayer(const LAYER &layer) {
    printf_info("#############################################################################################################\n");
    printf_info("Layer [%i] - %s\n", layer.number, layer.name);
    printf_info(">>Type: ");
    switch (layer.type) {
        case LAYERTYPE::DEPTHWISE_CONV2:
            printf_info("DEPTHWISE-");
        case LAYERTYPE::CONV2:
            printf_info("CONV2 Layer\n");

            printf_info(">> Input:\tMM Start[%10i], Stride: %3i, End[%10i]\tSize: %4i x %4i x %4i\n",
                   layer.input.MM_base, layer.input.MM_x_stride, layer.input.MM_end,
                   layer.input.in_x, layer.input.in_y, layer.input.in_channels);
            printf_info(">> Pad-Widths: [Top %i, Right %i, Bottom %i, Left %i]\t, Value: %1i\n",
                   layer.pad.top, layer.pad.right, layer.pad.bottom, layer.pad.left, layer.pad.value);
            printf_info(">> Conv: Stride: %i,\tSegments: %5i (%2i x %2i with Out: %2i x %2i, In: %2i x %2i)\tSize: %4i x %4i x %4i\n",
                   layer.conv.stride, layer.conv.num_segments,
                   layer.conv.seg_num_x, layer.conv.seg_num_y, layer.conv.seg_out_w, layer.conv.seg_out_h,
                   layer.conv.seg_in_w, layer.conv.seg_in_h,
                   layer.conv.kernel_length, layer.conv.kernel_length, layer.conv.out_channels);
//            printf_info("\tResult: %i x %i x %i\n", // 	MM[%i] (Stride: %i, MM_end[%i])
//            layer.conv.output.MM_base, layer.conv.output.MM_x_stride, layer.conv.output.MM_end,
//                   layer.conv.output.in_x, layer.conv.output.in_y, layer.conv.output.in_channels);
            if (layer.pool.type != POOLTYPE::NONE) {
                printf_info(">> Pool: \t%s, stride: %i\n",
                       ((layer.pool.type == POOLTYPE::MAX) ? "MAX" : "unknown"),
                       layer.pool.stride);
            }
            if (layer.relu.type != RELUTYPE::NONE) {
                printf_info(">> Relu:  \t%s\n",
                       ((layer.relu.type == RELUTYPE::LEAKY) ? "Leaky" : ((layer.relu.type == RELUTYPE::RECT) ? "Rect"
                                                                                                      : (layer.relu.type ==
                                       RELUTYPE::RELU6)
                                                                                                        ? "RELU6"
                                                                                                        : "unknown")));
            }
            break;

        case LAYERTYPE::RESIDUAL:
            printf_info("RESIDUAL Layer\n");
            printf_info(">> Input:\tMM Start[%10i], Stride: %3i, End[%10i]\tSize: %4i x %4i x %4i\n",
                   layer.residual_0->output.MM_base,
                   layer.residual_0->output.MM_x_stride, layer.residual_0->output.MM_end, layer.residual_0->output.in_x,
                   layer.residual_0->output.in_y,
                   layer.residual_0->output.in_channels);
            printf_info(">> Input:\tMM Start[%10i], Stride: %3i, End[%10i]\tSize: %4i x %4i x %4i\n",
                   layer.residual_1->output.MM_base,
                   layer.residual_1->output.MM_x_stride, layer.residual_1->output.MM_end, layer.residual_1->output.in_x,
                   layer.residual_1->output.in_y,
                   layer.residual_1->output.in_channels);

            printf_info("\tSegments: %i (%2i x %2i with Dim: %2i x %2i)\n",
                   layer.conv.num_segments,
                   layer.conv.seg_num_x, layer.conv.seg_num_y, layer.conv.seg_in_w, layer.conv.seg_in_h);

            break;

        default:
            printf_info("unknown Layer Type!\n");
    }
    printf_info(">> Output:\tMM Start[%10i], Stride: %3i, End[%10i]\tSize: %4i x %4i x %4i\n", layer.output.MM_base,
           layer.output.MM_x_stride, layer.output.MM_end, layer.output.in_x, layer.output.in_y,
           layer.output.in_channels);

//    for (int c = 0; c < layer.conv.input.in_channels; c++)
//        printf_info("In Channel %i starts: %i\n", c, layer.conv.input.MM_base_channel[c]);
//    for (int c = 0; c < layer.conv.output.in_channels; c++)
//        printf_info("Out Channel %i starts: %i\n", c, layer.conv.output.MM_base_channel[c]);

    printf_info("#############################################################################################################\n");

#ifdef CREATE_INPUT_CFG
    QFile::copy("../init/input.cfg",
                "../init/archive/input_before_" + QDateTime::currentDateTime().toString("YYYY_MM_dd-HH_mm") +
                ".cfg.old");
    QFile inf("../init/input.cfg");
    if (inf.open(QIODevice::ReadWrite | QIODevice::Truncate | QIODevice::Text)) {
        QTextStream stream(&inf);
        for (int in = 0; in < layer.input.in_channels; in++) {
            stream << "../data/input_" << in << ".bin " << layer.input.MM_base_channel[in] << endl;
        }
#ifdef TEST
        stream << "../data/test_2.bin 0" << endl;
#endif // test
    }
#endif // input cfg

#ifdef CREATE_OUTPUT_CFG
    QFile::copy("../exit/output.cfg",
                "../exit/archive/output_before_" + QDateTime::currentDateTime().toString("YYYY_MM_dd-HH_mm") +
                ".cfg.old");
    QFile outf("../exit/output.cfg");
    if (outf.open(QIODevice::ReadWrite | QIODevice::Truncate | QIODevice::Text)) {
        QTextStream stream(&outf);
        // input out
        stream << "../data/input_out.bin " << layer.pad.input.MM_base << " "
               << (layer.pad.input.in_x * layer.pad.input.in_y * 2 * layer.pad.input.in_channels) << endl;
        // padding out
        stream << "../data/pad_out.bin " << layer.pad.output.MM_base << " "
               << (layer.pad.output.in_x * layer.pad.output.in_y * layer.pad.output.in_channels * 2) << endl;

        // results out
        for (int in = 0; in < layer.output.in_channels; in++) {
            stream << "../data/output_" << in << ".bin " << layer.output.MM_base_channel[in] << " "
                   << (layer.output.in_x * layer.output.in_y * 2) << endl;
        }
#ifdef TEST
        // test
        stream << "../data/test_out_pad.bin " << layer.pad.output.MM_base << " "
               << (layer.pad.output.in_x * layer.pad.output.in_y * 2) << endl;
        stream << "../data/test_out.bin " << layer.output.MM_base_channel[0] << " "
               << (layer.output.in_x * layer.output.in_y * 2) << endl;
#endif // test
    }
#endif //output cfg

    fflush(stdout);
}
#endif // is simulation

template<typename LAYER>
void printLayer(const LAYER &layer) {
#ifdef IS_SIMULATION
    printf_info("#############################################################################################################\n");
    printf_info("Reduced Layer [%i]\n", layer.number);
    printf_info(">>Type: ");
    switch (layer.type) {
        case LAYERTYPE::DEPTHWISE_CONV2:
            printf_info("DEPTHWISE-");
        case LAYERTYPE::CONV2:
            printf_info("CONV2 Layer\n");

            printf_info(">> Pad-Widths: [Top %i, Right %i, Bottom %i, Left %i]\t, Value: %1i\n",
                   layer.pad.top, layer.pad.right, layer.pad.bottom, layer.pad.left, layer.pad.value);
            printf_info(">> Conv: \tSegments: %5i (with Out: %2i x %2i, In: %2i x %2i)\tSize: %4i x %4i x %4i\n",
                   layer.conv.num_segments,layer.conv.seg_out_w, layer.conv.seg_out_h,
                   layer.conv.seg_in_w, layer.conv.seg_in_h,
                   layer.conv.kernel_length, layer.conv.kernel_length, layer.conv.out_channels);
            if (layer.relu.type != RELUTYPE::NONE) {
                printf_info(">> Relu:  \t%s\n",
                       ((layer.relu.type == RELUTYPE::LEAKY) ? "Leaky" : ((layer.relu.type == RELUTYPE::RECT) ? "Rect"
                                                                                                              : (layer.relu.type ==
                                                                                                                 RELUTYPE::RELU6)
                                                                                                                ? "RELU6"
                                                                                                                : "unknown")));
            }
            break;
        default:
            printf_info("unknown Layer Type!\n");
    }
    printf_info("#############################################################################################################\n");
    fflush(stdout);
#endif // is simulation
}

#ifdef IS_SIMULATION
void printKernel(const KERNEL &kernel) {
    printf_info("#############################################################################################################\n");

    printf_info("Kernel (%i x %i):\n", kernel.x, kernel.y);
    printf_info(">> Input-Channel: %i Output-Channel: %i\n", kernel.in_channel, kernel.out_channel);
    printf_info(">> address[%li]\n", uint64_t(kernel.address));

    printf_info(LBLUE);
    int sum = 0;
    for (auto x = 0; x < kernel.x; x++) {
        for (auto y = 0; y < kernel.y; y++) {
            printf_info("%6i ", kernel.address[x + kernel.x * y]);
            sum += kernel.address[x + kernel.x * y];
        }
        printf_info("\n");
    }
    printf_info(RESET_COLOR);

    printf_info("Kernel sum: %i\n", sum);
    printf_info("#############################################################################################################\n");
    fflush(stdout);
}
#endif

#ifdef IS_SIMULATION
void printSegment(const LAYER &layer, const SEGMENT &segment) {
    printf_info("#############################################################################################################\n");

    printf_info("Segment\n");
    printf_info(">> Input-Channel: %i Output-Channel: %i\n", segment.in_channel, segment.out_channel);
    printf_info(">> X: %i / %i, Y: %i / %i\n", segment.x_seg, layer.conv.seg_num_x - 1, segment.y_seg,
           layer.conv.seg_num_y - 1);
    printf_info(">> Size: %i x %i -> Size: %i x %i \n", layer.conv.seg_in_w, layer.conv.seg_in_h, layer.conv.seg_out_w, layer.conv.seg_out_h);
    printf_info(">> in - MM[%i] (Stride: %i) \n", segment.in_MM_base_0, segment.in_MM_x_stride_0);
    printf_info(">> out - MM[%i] (Stride: %i) \n", segment.out_MM_base, segment.out_MM_x_stride);

    printf_info("#############################################################################################################\n");
    fflush(stdout);
}
#endif

#ifdef IS_SIMULATION
void printSegmentList(const std::list<SEGMENT *> &list, int LANES, const LAYER &layer) {

    bool toFile = false;
    FILE *p = stdout;
    auto file = fopen("../data/segmentList.csv", "w+");
    if (toFile){
        stdout = file;
    }

    printf("%s\n", std::string(25, '#').c_str());
    printf("Layer: %i\n", layer.number);
    printf("%s\n", std::string(25, '#').c_str());
    auto color = RESET_COLOR;
    int count = 0;
    for (SEGMENT *s : list) {
        printf("%s", color);
        printf("[Segment %6i, %li] ", count, uint64_t(s));
        printf("\tX %3i/%i, ", s->x_seg, layer.conv.seg_num_x);
        printf("\tY %3i/%i, ", s->y_seg, layer.conv.seg_num_y);
        printf("\tIN %3i, ", s->in_channel);
        printf("\tOUT %3i, ", s->out_channel);
        printf("\tFirst %1i, ", (s->isFirst ? 1 : 0));
        printf("\tLast %1i, ", (s->isLast ? 1 : 0));
        printf("\tDummy %1i, ", (s->dummy ? 1 : 0));

        printf("\tMM_in %1i, ", s->in_MM_base_0);
        printf("\tMM_in_stride_0 %1i, ", s->in_MM_x_stride_0);
        printf("\tMM_in_stride_1 %1i, ", s->in_MM_x_stride_1);
        printf("\tin_x %1i, ", layer.conv.seg_in_w);
        printf("\tin_y %1i, ", layer.conv.seg_in_h);

        printf("\tMM_out %1i, ", s->out_MM_base);
        printf("\tMM_out_stride %1i, ", s->out_MM_x_stride);
        printf("\tout_x %1i, ", layer.conv.seg_out_w);
        printf("\tout_y %1i", layer.conv.seg_out_h);

        printf("\n");
        count++;
        if ((count % LANES) == 0) {
            if (color == RESET_COLOR)
                color = INVERTED;
            else
                color = RESET_COLOR;
        }
    }
    printf(RESET_COLOR);
    printf("\n");

    if (toFile) {
        fflush(file);
        stdout = p;
    }
}
#endif

void printProgress(double progress, int size) {
#ifdef IS_SIMULATION
    // progressbar
    if (progress < 0) {
        printf(RED);
        progress += 100;
    }
    printf(" [");
    for (float i = 0; i <= 100; i += 100. / size) {
        if (progress > i)
            printf("#");
        else
            printf(" ");
    }
    printf("]");
    printf(RESET_COLOR);
#endif
}

//assumes little endian
void printBits(size_t const size, void const *const ptr) {
#ifdef IS_SIMULATION
    unsigned char *b = (unsigned char *) ptr;
    unsigned char byte;
    int i, j;

    for (i = size - 1; i >= 0; i--) {
        for (j = 7; j >= 0; j--) {
            byte = (b[i] >> j) & 1;
            printf_info("%u", byte);
        }
    }
#endif
}