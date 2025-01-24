//
// Created by gesper on 12.11.20.
//

#include "yolo_configuration.h"

YOLO_LITE __attribute__ ((aligned (16))) __attribute__ ((section (".nobss"))) yolo;

#ifdef TESTRUN

WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel>
        __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv0;

COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss"))) L0_Segments[test_segm_cont];

#else

COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) L0_Segments[layer_segment_num[0]];
COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) L1_Segments[layer_segment_num[1]];
COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) L2_Segments[layer_segment_num[2]];
COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) L3_Segments[layer_segment_num[3]];
COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) L4_Segments[layer_segment_num[4]];
COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) L5_Segments[layer_segment_num[5]];
COMMAND_SEGMENT __attribute__ ((aligned (16))) __attribute__ ((section (".nobss_32byte_align"))) L6_Segments[layer_segment_num[6]];

WEIGHTS_REDUCED<3, 16, 3> __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv0;
WEIGHTS_REDUCED<16, 32, 3> __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv1;
WEIGHTS_REDUCED<32, 64, 3> __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv2;
WEIGHTS_REDUCED<64, 128, 3> __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv3;
WEIGHTS_REDUCED<128, 128, 3> __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv4;
WEIGHTS_REDUCED<128, 256, 3> __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv5;
WEIGHTS_REDUCED<256, 125, 1> __attribute__ ((aligned (16))) __attribute__ ((section (".vpro"))) conv6;

#endif