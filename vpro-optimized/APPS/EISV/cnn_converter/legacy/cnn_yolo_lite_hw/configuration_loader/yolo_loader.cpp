//
// Created by gesper on 06.04.22.
//

#include "yolo_loader.h"
#include "../configuration_generation/file_helper.h"
#include "../configuration_generation/segment_creation.h"
#include "vpro/dma_cmd_struct.h"

#include <string>
#include <bitset>
#include <iomanip>


yolo_loader::yolo_loader(bool set_base_addr_weights_to_elf_extraction, bool do_interleaving, bool do_dma_extension) {
#ifdef TESTRUN
    layers = LayerGeneration::getLayerList(true);
#else
    layers = LayerGeneration::getLayerList();
#endif

    if (layers.back().output.MM_base != output_mm_base) {
        printf_error(
                "[ERROR!] MM Output is located wrong! It is: \n\tuint32_t output_mm_base = 0x%x;\n\t// Size: %i x %i x %i, Stride: %i\n\n",
                layers.back().output.MM_base, layers.back().output.in_x, layers.back().output.in_y,
                layers.back().output.in_channels, layers.back().output.MM_x_stride);
    }

    original_layers = std::list<LAYER>(layers);
    segments = SegmentGeneration::generateSegmentList(layers);
    dump_segments();
//    segV = segments.front().toStdVector();
//    std::copy(segV.begin(), segV.end(), std::back_inserter(segL));

    printf("\n================================================================\n");
    printf("Generation Finished\n");
    printf("================================================================\n\n");

#ifndef TESTRUN
    copyLayerData(yolo.layer[0], layers);
    copyLayerData(yolo.layer[1], layers);
    copyLayerData(yolo.layer[2], layers);
    copyLayerData(yolo.layer[3], layers);
    copyLayerData(yolo.layer[4], layers);
    copyLayerData(yolo.layer[5], layers);
    copyLayerData(yolo.layer[6], layers);
    yolo.weights[0] = &conv0;
    yolo.weights[1] = &conv1;
    yolo.weights[2] = &conv2;
    yolo.weights[3] = &conv3;
    yolo.weights[4] = &conv4;
    yolo.weights[5] = &conv5;
    yolo.weights[6] = &conv6;
    assignKernel(conv0, Layer_0::conv_weights, Layer_0::bias, yolo.layer[0]);
    assignKernel(conv1, Layer_1::conv_weights, Layer_1::bias, yolo.layer[1]);
    assignKernel(conv2, Layer_2::conv_weights, Layer_2::bias, yolo.layer[2]);
    assignKernel(conv3, Layer_3::conv_weights, Layer_3::bias, yolo.layer[3]);
    assignKernel(conv4, Layer_4::conv_weights, Layer_4::bias, yolo.layer[4]);
    assignKernel(conv5, Layer_5::conv_weights, Layer_5::bias, yolo.layer[5]);
    assignKernel(conv6, Layer_6::conv_weights, Layer_6::bias, yolo.layer[6]);
#else
    copyLayerData(yolo.layer[0], layers);
    yolo.weights[0] = &conv0;
    assignKernel(conv0, TESTLAYER::conv_weights, TESTLAYER::bias, yolo.layer[0]);
#endif
    if (!layers.empty()) {
        printf_error("ERROR: Layer list should be processed completely by now. but it is not empty!!! Size. %i \n",
                     layers.size());
    }

    yolo.segments[0] = L0_Segments;
#ifndef TESTRUN
    yolo.segments[1] = L1_Segments;
    yolo.segments[2] = L2_Segments;
    yolo.segments[3] = L3_Segments;
    yolo.segments[4] = L4_Segments;
    yolo.segments[5] = L5_Segments;
    yolo.segments[6] = L6_Segments;
#endif
    printf("\n================================================================\n");
    printf("Load of weights and Layer data Finished. Command Segments assigned.\n");
    printf("================================================================\n\n");

    command_list = create_command_list(segments, original_layers, set_base_addr_weights_to_elf_extraction, do_interleaving, do_dma_extension);
    dump_layers();
    dump_commands();

    for (uint i = 0; i < layer_count; ++i) {
        printf_info("Command Segments (Layer %i): %i \n", i, command_list[i].length());

        uint j = 0;
        for (const auto& cmd_seg: command_list[i]) {
            yolo.segments[i][j] = COMMAND_SEGMENT(cmd_seg);
            j++;
        }
    }

    printf("\n================================================================\n");
    printf("Command List generated! \n");
    printf("================================================================\n");
}


void yolo_loader::print() {
    // TODO print conditional?
#ifndef TESTRUN
    printLayer(yolo.layer[0]);
    printLayer(yolo.layer[1]);
    printLayer(yolo.layer[2]);
    printLayer(yolo.layer[3]);
    printLayer(yolo.layer[4]);
    printLayer(yolo.layer[5]);
    printLayer(yolo.layer[6]);
#else
    printLayer(yolo.layer[0]);
#endif
}

std::string mmAddrStr(uint32_t addr) {
  std::stringstream ss;
  ss << "0x" << std::setfill('0') << std::setw(8) << std::right << std::hex << addr;
  return ss.str();
}


void yolo_loader::dump_layers() {
    std::string fname = "layers_ref.txt";
    std::ofstream fd(fname, std::ios::out);
    if (!fd){
        std::cout << "Could not open file " << fname << " for layer export!\n";
        return;
    }

    for (uint li = 0; li < layer_count; ++li) {
      LAYER_WRAPPER &lw = yolo.layer[li];
      fd << "LAYER " << li << "\n";
      fd << "in_channels             " << lw.in_channels             << "\n"
         << "out_channels            " << lw.out_channels            << "\n"
         << "number                  " << lw.number-1                << "\n" // layer.number is used inconsistently with layer name. adapt to consistent netgen numeration
         << "type                    ";
      switch(lw.type) {
      case LAYERTYPE::RESIDUAL       : fd << "RESIDUAL\n"; break;
      case LAYERTYPE::CONV2          : fd << "CONV2\n"; break;
      case LAYERTYPE::DEPTHWISE_CONV2: fd << "DEPTHWISE_CONV2\n"; break;
      case LAYERTYPE::UNKNOWN        : fd << "UNKNOWN\n"; break;
      }
      fd << "stride                  " << lw.stride                  << "\n"
         << "kernel_length           " << lw.kernel_length           << "\n"
         << "seg_out_w               " << lw.seg_out_w               << "\n"
         << "seg_out_h               " << lw.seg_out_h               << "\n"
         << "seg_in_w                " << lw.seg_in_w                << "\n"
         << "seg_in_h                " << lw.seg_in_h                << "\n"
         << "conv_result_shift_right " << lw.conv_result_shift_right << "\n"
         << "relu_6_shift_left       " << lw.relu_6_shift_left       << "\n"
         << "bias_shift_right        " << lw.bias_shift_right        << "\n"
         << "store_shift_right       " << lw.store_shift_right       << "\n"
         << "residual_1_left_shift   " << lw.residual_1_left_shift   << "\n"
         << "residual_0_left_shift   " << lw.residual_0_left_shift   << "\n"
         << "pool_stride             " << lw.pool_stride             << "\n"
         << "activation              ";
      switch(lw.relu_type) {
      case RELUTYPE::LEAKY: fd << "LEAKY\n"; break;
      case RELUTYPE::RECT : fd << "RECT\n"; break;
      case RELUTYPE::RELU6: fd << "RELU6\n"; break;
      case RELUTYPE::NONE : fd << "NONE\n"; break;
      }
      fd << "pad   : ";
      std::string prefix = "  ";
      fd << prefix << "top    " << lw.pad.top
         << prefix << "left   " << lw.pad.left
         << prefix << "bottom " << lw.pad.bottom
         << prefix << "right  " << lw.pad.right
         << prefix << "value  " << lw.pad.value  << "\n";
      fd << "input : ";
      fd << prefix << "mm_base  "                  << mmAddrStr(lw.input.mm_base)
         << prefix << "x        " << std::setw(10) << lw.input.x
         << prefix << "y        " << std::setw(10) << lw.input.y
         << prefix << "x_stride " << std::setw(10) << lw.input.x_stride
         << prefix << "channels " << std::setw(10) << lw.input.channels << "\n";
      fd << "output: ";
      fd << prefix << "mm_base  "                  << mmAddrStr(lw.output.mm_base)
         << prefix << "x        " << std::setw(10) << lw.output.x
         << prefix << "y        " << std::setw(10) << lw.output.y
         << prefix << "x_stride " << std::setw(10) << lw.output.x_stride
         << prefix << "channels " << std::setw(10) << lw.output.channels << "\n";
    }
    std::cout << "wrote layers to " << fname << "\n";
    fd.close();
}

void yolo_loader::dump_segments() {
    std::string fname = "segments_ref.txt";
    std::ofstream fd(fname, std::ios::out);
    if (!fd){
        std::cout << "Could not open file " << fname << " for segment export!\n";
        return;
    }
    for (unsigned int l = 0; l < layer_count; l++) {
        std::list<LAYER>::iterator layer = original_layers.begin();
        std::advance(layer, l);
        fd << "LAYER " << l << ": " << segments[l].size() << " segments\n";
        for (int i = 0; i < segments[l].size(); i++) {
            fd << "SEGMENT " << i << "\n";
            fd << segments[l][i]->to_string();
        }
    }
    std::cout << "wrote segments to " << fname << "\n";
    fd.close();
}

void yolo_loader::dump_commands() {
    std::string fname = "commands_ref.txt";
    std::ofstream fd(fname, std::ios::out);
    if (!fd){
        std::cout << "Could not open file " << fname << " for command export!\n";
        return;
    }

    for (uint li = 0; li < layer_count; ++li) {
      fd << "LAYER " << li << ": " << command_list[li].size() << " commands\n";
    
      for (int ci=0; ci < command_list[li].size(); ci++) {
        fd << "[" << ci << "] ";
        auto cmd = command_list[li].at(ci);
        auto cmd_dma = reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(&cmd);
        switch (cmd.type) {
        case DMA_SEG:
            fd  << "DMA_CMD, direction ";
            switch(cmd_dma->direction) {
            case COMMAND_DMA::e2l1D: fd << "e2l1D"; break;
            case COMMAND_DMA::e2l2D: fd << "e2l2D"; break;
            case COMMAND_DMA::l2e1D: fd << "l2e1D"; break;
            case COMMAND_DMA::l2e2D: fd << "l2e2D"; break;
            default: fd << cmd_dma->direction;
            }
            fd  << ", isKernelOffset " << cmd_dma->isKernelOffset
                << ", isBiasOffset " << cmd_dma->isBiasOffset
                << ", cluster " << uint32_t(cmd_dma->cluster)
                << ", unit_mask " << std::bitset<32>(cmd_dma->unit_mask)
                << ", mm_addr 0x" << std::setfill('0') << std::setw(8) << std::hex << cmd_dma->mm_addr
                << ", lm_addr 0x" << std::setw(6) << cmd_dma->lm_addr
                << ", x_stride " << std::dec << cmd_dma->x_stride
                << ", x_size " << cmd_dma->x_size
                << ", pad_0 " << cmd_dma->pad_0
                << ", pad_1 " << cmd_dma->pad_1
                << ", pad_2 " << cmd_dma->pad_2
                << ", pad_3 " << cmd_dma->pad_3 << "\n";
            break;
        case VPRO_SEG: fd << reinterpret_cast<COMMAND_VPRO *>(&cmd)->to_string(); break;
        case DMA_WAIT: fd << "DMA_WAIT\n"; break;
        case VPRO_WAIT: fd << "VPRO_WAIT\n"; break;
        case DMA_BLOCK: fd << "DMA_BLOCK, size " << cmd_dma->unit_mask << "\n"; break;
        case BOTH_SYNC: fd << "BOTH_SYNC\n"; break;
        case UNKNOWN: fd << "UNKNOWN\n"; break;
        default: break;
        }
      }
    }
    std::cout << "wrote commands to " << fname << "\n";
    fd.close();
}
