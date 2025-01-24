
#ifndef cnn_structs
#define cnn_structs

#include <stdint.h>
#include <math.h>
#include <stdio.h>
#include <algorithm>
#include <iostream>

#include "cnn_struct_reduced.h"
#include "cnn_enums.h"

struct CNN_input {
    CNN_input():
            in_x(0), in_y(0), in_channels(0), 
            MM_base(0), MM_x_stride(0),  MM_base_channel(nullptr), MM_end(0) {
    };

    CNN_input(int in_channels) :
            in_x(0), in_y(0), in_channels(in_channels),
            MM_base(0), MM_x_stride(0), MM_base_channel(new int[in_channels]), MM_end(0) {

    };

    CNN_input(int in_x, int in_y, int in_channels,
              int MM_base, int MM_x_stride) :
            in_x(in_x), in_y(in_y), in_channels(in_channels),
            MM_base(MM_base), MM_x_stride(MM_x_stride), MM_base_channel(new int[in_channels]), MM_end(0) {
        for (int i_c = 0; i_c < in_channels; i_c++) {
            MM_base_channel[i_c] = MM_base + 2 * (in_x + MM_x_stride) * (in_y + MM_x_stride) * i_c;
        }
        MM_end = MM_base + 2 * (in_x + MM_x_stride) * (in_y + MM_x_stride) * in_channels;
    };

    int in_x; // real image dimension (pay att on stride!)
    int in_y;
    int in_channels;

    unsigned int MM_base;
    int MM_x_stride; //
    int *MM_base_channel; // Base of each channel

    int MM_end; // first free address after this block
};

struct PAD {
    PAD( int value) :
//            bottom(bottom), top(top), right(right), left(left),
            value(value)
    {
    };

    int bottom;
    int top;
    int right;
    int left;
    
    int value; // used for padding
};

struct KERNEL {
    KERNEL() :
            x(0), y(0), in_channel(0), out_channel(0), MM_base(0), LM_base(0), RF_base(0), address(nullptr), address64(nullptr) {};
    int x;
    int y;

    int in_channel; // kernel info about #in_channel
    int out_channel; // kernel info about #out_channel

    int MM_base;
    int LM_base;
    int RF_base;

    int16_t *address;
    int64_t *address64;
};

struct BIAS {
    BIAS() :
            out_channel(0), MM_base(0), LM_base(0), RF_base(0), address(nullptr), address64(nullptr) {};
    int out_channel;

    int MM_base;
    int LM_base;
    int RF_base;

    int16_t *address;
    int64_t *address64;
};

struct CONV {
    CONV(const CNN_input &input, LAYERTYPE::LAYERTYPE &layertype, int out_channel, int kernel_length, int in_channel_per_conv,
            int stride = 1, bool adjustForPooling = false, const CNN_input &residual_0 = CNN_input(), const CNN_input &residual_1 = CNN_input()) :
            input(input), residual_0(residual_0), residual_1(residual_1), type(layertype),
            out_channels(out_channel),
            in_channels(in_channel_per_conv),
            stride(stride),
            kernel(new KERNEL[out_channel * in_channel_per_conv]),
            bias(new BIAS[out_channel]),
            kernel_length(kernel_length),
            num_segments(0),
            seg_num_x(0), seg_num_y(0),
            seg_out_w(0), seg_out_h(0), seg_in_w(0), seg_in_h(0),
            segments(nullptr),
            output(CNN_input(out_channel)) {
        if (type == LAYERTYPE::CONV2 || type == LAYERTYPE::DEPTHWISE_CONV2) { // kernel_length > 0
            for (int o_c = 0; o_c < out_channels; o_c++) {
                for (int i_c = 0; i_c < in_channel_per_conv; i_c++) {
                    kernel[o_c * in_channel_per_conv + i_c].in_channel = i_c;
                    kernel[o_c * in_channel_per_conv + i_c].out_channel = o_c;
                    kernel[o_c * in_channel_per_conv + i_c].x = kernel_length;
                    kernel[o_c * in_channel_per_conv + i_c].y = kernel_length;
                }
            }
            for (int o_c = 0; o_c < out_channels; o_c++) {
                bias[o_c].out_channel = o_c;
            }
            output.in_x = int(ceil(float(input.in_x) / stride)); // layer / conv
            output.in_y = int(ceil(float(input.in_y) / stride));
        } else { // RESIDUAL  type == LAYERTYPE::RESIDUAL
            output.in_x = residual_0.in_x;
            output.in_y = residual_0.in_y;
        }
        output.MM_base = input.MM_end;

        // 1024 RF entries -> 32 for dim of out seg
        // - 1 entry bias
        // - (e.g. 9) kernel entries
        // = 1011 RF entries -> 31 for dim of out seg
        int free_rf_entries = 1024 - 1 - kernel_length * kernel_length;

        // 8192 LM entries -> 2 buffer
        // 4096 ea
        // - lane * 1
        // - lane * kernel * kernel
        // 2 LANES!
        // 4096 - 2 - 2 * kernel_length * kernel_length;
        int free_lm_entries = 4096 - 2 - 2 * kernel_length * kernel_length;
        int maximal_LM_in_seg_dimension = floor(sqrt(free_lm_entries));

        // TODO: change this?
        //   but [!]: VPRO can 2D address max 31 * 31 sections (beta limited to 5 bit - next line address), so dim is max 31
        int maximum_value_beta = 31;
        int maximum_value_xend_yend = 31;
        maximal_LM_in_seg_dimension = std::min(maximum_value_beta,
                                               int(ceil(float(maximal_LM_in_seg_dimension) / stride)));

        int maximal_RF_out_seg_dimension = std::min(maximal_LM_in_seg_dimension,
                                                    int(floor(sqrt(free_rf_entries))));

        seg_num_x = std::max(ceil(float(output.in_x) / float(maximal_RF_out_seg_dimension)),
                             ceil(float(input.in_x) / float(maximal_LM_in_seg_dimension)));
        seg_num_y = std::max(ceil(float(output.in_y) / float(maximal_RF_out_seg_dimension)),
                             ceil(float(input.in_y) / float(maximal_LM_in_seg_dimension)));

        seg_out_w = ceil(float(output.in_x) / float(seg_num_x));
        seg_out_h = ceil(float(output.in_y) / float(seg_num_y));

        // limit to 16 -> segment addressing by x_end, y_end
        int max_seg_dim = maximum_value_xend_yend + 1;   // for all segments...
        if (seg_out_w > max_seg_dim) {
            seg_num_x = ceil(float(output.in_x) / float(max_seg_dim));
            seg_out_w = ceil(float(output.in_x) / float(seg_num_x));
        }
        if (seg_out_h > max_seg_dim) {
            seg_num_y = ceil(float(output.in_y) / float(max_seg_dim));
            seg_out_h = ceil(float(output.in_y) / float(seg_num_y));
        }

        if (kernel_length == 1) { // vector over input size,
            // limit segment size to 22 -> vector over input size,
            //    to accumulate, split of RF, max 1024/2 for segment -> 0-484 [final accu result], 484-996 [tmp conv res]
            max_seg_dim = 22;
            if (seg_out_w > max_seg_dim) {
                seg_num_x = ceil(float(output.in_x) / float(max_seg_dim));
                seg_out_w = ceil(float(output.in_x) / float(seg_num_x));
            }
            if (seg_out_h > max_seg_dim) {
                seg_num_y = ceil(float(output.in_y) / float(max_seg_dim));
                seg_out_h = ceil(float(output.in_y) / float(seg_num_y));
            }
            seg_in_w = seg_out_w * stride;
            seg_in_h = seg_out_h * stride;
        } else if (kernel_length > 0) {
//            // TODO: vector over input size not senseful.
//            //    accu over kernel mul result would require additional op...
//            int max_seg_dim = 16;
//            if (seg_out_w > max_seg_dim){
//                seg_num_x = ceil(float(output.in_x) / float(max_seg_dim));
//                seg_out_w = ceil(float(output.in_x)/float(seg_num_x));
//            }
//            if (seg_out_h > max_seg_dim){
//                seg_num_y = ceil(float(output.in_y) / float(max_seg_dim));
//                seg_out_h = ceil(float(output.in_y)/float(seg_num_y));
//            }

//            max_seg_dim = 15;

            if (seg_out_w > max_seg_dim){
                seg_num_x = ceil(float(output.in_x) / float(max_seg_dim));
                seg_out_w = ceil(float(output.in_x)/float(seg_num_x));
            }
            if (seg_out_h > max_seg_dim){
                seg_num_y = ceil(float(output.in_y) / float(max_seg_dim));
                seg_out_h = ceil(float(output.in_y)/float(seg_num_y));
            }

            seg_in_w = ((kernel_length - 1) / stride) + seg_out_w * stride;
            seg_in_h = ((kernel_length - 1) / stride) + seg_out_h * stride;
            if (seg_in_w > maximum_value_beta){
                seg_num_x++;
                seg_out_w = ceil(float(output.in_x)/float(seg_num_x));
                seg_in_w = ((kernel_length - 1) / stride) + seg_out_w * stride;
            }
            if (seg_in_h > maximum_value_beta){
                seg_num_y++;
                seg_out_h = ceil(float(output.in_y)/float(seg_num_y));
                seg_in_h = ((kernel_length - 1) / stride) + seg_out_h * stride;
            }

        } else {
            seg_in_w = seg_out_w;
            seg_in_h = seg_out_h;
        }

        if (adjustForPooling) {
            if (seg_out_w % 2 != 0) { // has to be divideable by two
                seg_out_w--;
                seg_in_w = ((kernel_length - 1) / stride) + seg_out_w * stride;
                seg_num_x = ceil(float(output.in_x) / float(seg_out_w));
            }
            if (seg_out_h % 2 != 0) { // has to be divideable by two
                seg_out_h--;
                seg_in_h = ((kernel_length - 1) / stride) + seg_out_h * stride;
                seg_num_y = ceil(float(output.in_y) / float(seg_out_h));
            }
        }

//            // Manual overwrite...
//            seg_num_x = ceil(float(output.in_x) / float(1));
//            seg_num_y = ceil(float(output.in_y) / float(1));
//            seg_out_w = ceil(float(output.in_x)/float(seg_num_x));
//            seg_out_h = ceil(float(output.in_y)/float(seg_num_y));

        // stride used for Main.verify mm extraction and internal (here) address calc...
        output.MM_x_stride = seg_out_w * seg_num_x - output.in_x;  // +-1 ? - no, this is not parsed by dma
        num_segments = seg_num_x * seg_num_y * out_channel * in_channel_per_conv;

        segments = (SEGMENT ****)malloc(sizeof(SEGMENT ***) * out_channels);
        for (int i = 0; i < out_channels; i++) {
            segments[i] = (SEGMENT ***)malloc(sizeof(SEGMENT **) * seg_num_y);
            for (int j = 0; j < seg_num_y; j++) {
                segments[i][j] = (SEGMENT **)malloc(sizeof(SEGMENT *) * seg_num_x);
                for (int o = 0; o < seg_num_x; o++) {
                  segments[i][j][o] = (SEGMENT *)calloc(1, sizeof(SEGMENT ) * in_channel_per_conv); // default for all struct members: 0
                }
            }
        }

//        if (adjustForPooling) { // no, this information is used from inside Layer.pool
//            output.in_x /= 2;
//            output.in_y /= 2;
//        }

        // calc addresses of output (used after execute of segments for WB of each segment)
        if (!adjustForPooling) {
            for (int oc = 0; oc < out_channel; oc++) {
                output.MM_base_channel[oc] = output.MM_base + 2 * (output.in_x + output.MM_x_stride) *
                                                              (output.in_y + output.MM_x_stride) * oc;
            }
            output.MM_end = output.MM_base +
                            2 * (output.in_x + output.MM_x_stride) * (output.in_y + output.MM_x_stride) *
                            output.in_channels;
        } else {  // POOL step does not calc all segments MM out addresses, this id done here, so adjust if pooling is applied
            output.MM_x_stride = seg_out_w * seg_num_x / 2 - output.in_x / 2;  // +-1 ? - no, this is not parsed by dma
            for (int oc = 0; oc < out_channel; oc++) {
                output.MM_base_channel[oc] = output.MM_base + 2 * (output.in_x / 2 + output.MM_x_stride) *
                                                              (output.in_y / 2 + output.MM_x_stride) * oc;
            }
            output.MM_end = output.MM_base +
                            2 * (output.in_x / 2 + output.MM_x_stride) * (output.in_y / 2 + output.MM_x_stride) *
                            output.in_channels;
        }

        // fill all segments with informations about input, output, dimension, index, pad, etc.
        int out_c = 0;   // to assign correct info to segments
        int in_c = 0;    // to assign correct info to segments
        int seg_cnt = 0;
        while (seg_cnt < num_segments) {
            int x_seg = seg_cnt % seg_num_x;
            int y_seg = int(float(seg_cnt) / (float) seg_num_x);
            y_seg = y_seg % seg_num_y;

//            printf("Creating Segment... x: %i, y: %i, inc: %i, outc: %i\n", x_seg, y_seg, in_c, out_c);

            SEGMENT &segment = segments[out_c][y_seg][x_seg][in_c];
            segment.x_seg = x_seg;
            segment.y_seg = y_seg;
            segment.out_channel = out_c;
            if (type == LAYERTYPE::CONV2 || type == LAYERTYPE::RESIDUAL)
                segment.in_channel = in_c;
            else
                segment.in_channel = 0; // out_c;

            //
            // INPUT Data Addresses
            // this stride is used by dma. stride = 1 == no additional pixel...
            // input address depends on in channel/x/y
            // input takes care of conv stride
            // for DEPTHWISE: base address depends on out_c instead of in_c
            // for RESIDUAL: two segments are loaded with their own stride...
            //
            if (type == LAYERTYPE::CONV2)
                segment.in_MM_base_0 = input.MM_base_channel[in_c] +
                                       2 * ( // byte aligned
                                               (x_seg * seg_out_w * stride) +
                                               (y_seg * seg_out_h * stride *
                                                (input.in_x + input.MM_x_stride))); // take care of input x stride
            else if (type == LAYERTYPE::DEPTHWISE_CONV2)
                segment.in_MM_base_0 = input.MM_base_channel[out_c] +
                                       2 * ( // byte aligned
                                               (x_seg * seg_out_w * stride) +
                                               (y_seg * seg_out_h * stride *
                                                (input.in_x + input.MM_x_stride))); // take care of input x stride
            else if (type == LAYERTYPE::RESIDUAL) { // + res input base addresses
                segment.in_MM_base_0 = residual_0.MM_base_channel[out_c] +
                                       2 * ( // byte aligned
                                               (x_seg * seg_out_w * stride) +
                                               (y_seg * seg_out_h * stride *
                                                (residual_0.in_x +
                                                 residual_0.MM_x_stride))); // take care of input x stride
                segment.in_MM_base_1 = residual_1.MM_base_channel[out_c] +
                                       2 * ( // byte aligned
                                               (x_seg * seg_out_w * stride) +
                                               (y_seg * seg_out_h * stride *
                                                (residual_1.in_x +
                                                 residual_1.MM_x_stride))); // take care of input x stride
            }

            // DMA uses this stride for data load of this segment
            if (type == LAYERTYPE::CONV2 || type == LAYERTYPE::DEPTHWISE_CONV2) {
                segment.in_MM_x_stride_0 =
                        (input.in_x + input.MM_x_stride) - (seg_in_w) + 1;  // take care of input x stride
                segment.in_MM_x_stride_1 =
                        (input.in_x + input.MM_x_stride) - (seg_in_w) + 1;  // take care of input x stride
            } else if (type == LAYERTYPE::RESIDUAL) {
                segment.in_MM_x_stride_0 =
                        (residual_0.in_x + residual_0.MM_x_stride) - (seg_in_w) + 1;  // take care of input x stride
                segment.in_MM_x_stride_1 =
                        (residual_1.in_x + residual_1.MM_x_stride) - (seg_in_w) + 1;  // take care of input x stride
            }


            //
            // Output Data Addresses
            // this stride is used for dma. stride = 1 == no additional pixel...
            // each segment is written back into mm after calc. this is the used address / stride for the segment
            //
            if (!adjustForPooling) {
                segment.out_MM_base = output.MM_base_channel[out_c] +
                                      2 * ( // byte aligned
                                              x_seg * seg_out_w +
                                              y_seg * seg_out_h * (output.in_x +
                                                                   output.MM_x_stride)); //  (output.MM_x_stride + 1) //  output.MM_x_stride
                segment.out_MM_x_stride =
                        (seg_out_w * seg_num_x) - (seg_out_w) + 1; // (output.in_x + output.MM_x_stride)
            } else {
                segment.out_MM_base = output.MM_base_channel[out_c] +
                                      ( // byte aligned /2 -> pool
                                              x_seg * seg_out_w +
                                              y_seg * seg_out_h * (output.in_x / 2 +
                                                                   output.MM_x_stride)); //  (output.MM_x_stride + 1) //  output.MM_x_stride
                segment.out_MM_x_stride =
                        (seg_out_w * seg_num_x) / 2 - (seg_out_w) / 2 + 1; // (output.in_x + output.MM_x_stride)
            }

            // next segment. update in_c/out_c/index
            seg_cnt++;
            if (seg_cnt % (seg_num_x * seg_num_y) == 0) {
                out_c++;
            }
            if (out_c >= out_channels) {
                out_c = 0;
                in_c++;
            }
        } // while segments

//        printf("Conv:  input from %i - %i.\n", input.MM_base, input.MM_end);
//        printf("Conv: output from %i - %i.\n", output.MM_base, output.MM_end);
    };

    void update(PAD &pad){
        int out_c = 0;   // to assign correct info to segments
        int in_c = 0;    // to assign correct info to segments
        int seg_cnt = 0;

        while (seg_cnt < num_segments) {
            int x_seg = seg_cnt % seg_num_x;
            int y_seg = int(float(seg_cnt) / (float) seg_num_x);
            y_seg = y_seg % seg_num_y;

            SEGMENT &segment = segments[out_c][y_seg][x_seg][in_c];

            // padding requires address modifications
            // the addresses until here assume direct addressing of a padded region
            if (type == LAYERTYPE::CONV2 || type == LAYERTYPE::DEPTHWISE_CONV2){

                segment.pad_top = (segment.y_seg == 0) && (pad.top > 0);
                segment.pad_right = (segment.x_seg == seg_num_x - 1) && (pad.right > 0);
                segment.pad_bottom = (segment.y_seg == seg_num_y - 1) && (pad.bottom > 0);
                segment.pad_left = (segment.x_seg == 0) && (pad.left > 0);

                if (stride > 1) { // if strided conv. no pad on top. left. if even input
                    if (input.in_x % 2 == 0)
                        segment.pad_left = false;
                    if (input.in_y % 2 == 0)
                        segment.pad_top = false;
                }
                if (stride > 1 && input.in_x % 2 == 0 && segment.pad_right) {
                    // correct stride to segment dimensions. pad width > 1 maybe..
                    segment.in_MM_x_stride_0 += pad.right + output.MM_x_stride * stride; // pad width = 3 -> 3
                }
                if ((stride > 1 && input.in_x % 2 != 0) || stride <= 1) {
                    // always

                    //                    - one up if not top
                    if (!segment.pad_top) {
                        segment.in_MM_base_0 -= 2 * (input.in_x + input.MM_x_stride) * pad.top;
                    }
                    //                    - one left if not left
                    if (!segment.pad_left) {
                        segment.in_MM_base_0 -= 2 * pad.left;
                    }
                    //                    right:
                    //                     - stride++, cause this model assumes complete padded segment in MM
                    if (segment.pad_right) {
                        segment.in_MM_x_stride_0 += pad.right; // + output.MM_x_stride*stride;
                    }
                    //                    left:
                    //                     - stride++
                    if (segment.pad_left) {
                        segment.in_MM_x_stride_0 += pad.left;
                    }
                }
            } else {
                segment.in_MM_base_0 += (2 * ((input.in_x + 1) % 2) * ((stride + 1) % 2) * ((input.in_x + input.MM_x_stride) + (stride - 1)));
            }


            // next segment. update in_c/out_c/index
            seg_cnt++;
            if (seg_cnt % (seg_num_x * seg_num_y) == 0) {
                out_c++;
            }
            if (out_c >= out_channels) {
                out_c = 0;
                in_c++;
            }
        } // while segments
    };

    const CNN_input &input;
    const CNN_input &residual_0;
    const CNN_input &residual_1;

    LAYERTYPE::LAYERTYPE &type;
    int out_channels, in_channels;

    int stride;
    
    KERNEL *kernel; // [OUT_channels][INPUT.IN_channels]
    BIAS *bias;
    int kernel_length;

    int num_segments;
    int seg_num_x, seg_num_y;
    int seg_out_w, seg_out_h, seg_in_w, seg_in_h;

    SEGMENT ****segments;//  segments[out_channel][num_y][num_x][in_channel]

    CNN_input output;
};

struct POOL {
    POOLTYPE::POOLTYPE type;

    POOL(CNN_input &input, int stride) :
            type(POOLTYPE::NONE),
            input(input),
            output(CNN_input()),
            stride(stride)
    //poolSize(2)
    {
        output.in_channels = input.in_channels;

        output.in_x = ceil(float(input.in_x) / stride);
        output.in_y = ceil(float(input.in_y) / stride);

        output.MM_base = input.MM_base;
        output.MM_end = input.MM_end;
        output.MM_x_stride = input.MM_x_stride;

        delete []output.MM_base_channel;
        output.MM_base_channel = input.MM_base_channel;
    };

    //int poolSize; // kernel sizes different than 2 would require new implementation!
    CNN_input &input;
    CNN_input output;
    int stride;
};

struct RELU {
    RELUTYPE::RELUTYPE type;

    RELU(RELUTYPE::RELUTYPE t) :
            type(t)
    {
    };

};

struct LAYER {
    LAYER(CNN_input in,
          CNN_input &last_out, // = in (for standard layers). used for out of this layer (starting from last_out.MM_end)
          LAYERTYPE::LAYERTYPE layertype,
          int kernel_lenght,
          int out_channels,
          int conv_stride = 1,
          int pool_size = 1,
          const CNN_input &residual_0 = CNN_input(), const CNN_input &residual_1 = CNN_input()) :
            input(in), //CNN_input(in_x, in_y, in_channels, MM_base, MM_x_stride)),
            last_out(last_out),
            type(layertype),
            pad(0), //(kernel_lenght - 1) / 2),
            conv(input, type, out_channels, (type == LAYERTYPE::RESIDUAL)? 0 : kernel_lenght,
                    (type == LAYERTYPE::DEPTHWISE_CONV2 || type == LAYERTYPE::RESIDUAL)? 1 : in.in_channels,
                    conv_stride, (pool_size == 2), residual_0, residual_1),
            pool(conv.output, pool_size),
            relu(RELU(RELUTYPE::NONE)),
            output(pool.output),
            number(0),
            name("undefined"),
            residual_0(nullptr),
            residual_1(nullptr),
            residual_0_left_shift(0),
            residual_1_left_shift(0),
            conv_result_shift_right(0),
            bias_shift_right(0),
            store_shift_right(0),
            relu_6_shift_left(0){

        pad.top = ((kernel_lenght - 1) / 2);
        pad.right = ((kernel_lenght - 1) / 2) + output.MM_x_stride*conv.stride*pool_size;
        pad.bottom = ((kernel_lenght - 1) / 2) + output.MM_x_stride*conv.stride*pool_size;
        pad.left = ((kernel_lenght - 1) / 2);

        conv.update(pad);
//        printf("LAYER: input    from %i - %i.\n", input.MM_base, input.MM_end);
//        printf("LAYER: output   from %i - %i.\n", output.MM_base, output.MM_end);
//        printf("LAYER: last_out from %i - %i.\n\n", last_out.MM_base, last_out.MM_end);
    }

    CNN_input input;
    CNN_input &last_out;
    
    LAYERTYPE::LAYERTYPE type;
    
    PAD pad;
    CONV conv;
    POOL pool;
    RELU relu;
    
    CNN_input &output;

    int number;
    const char *name;

    LAYER *residual_0;
    LAYER *residual_1;

    int residual_0_left_shift;
    int residual_1_left_shift;

    int conv_result_shift_right;
    int bias_shift_right;
    int store_shift_right;
    unsigned int relu_6_shift_left;
};


#endif
