//
// Created by gesper on 06.04.22.
//

#include "segment_creation_dma.h"
#include "../configuration_loader/yolo_configuration.h"
#include <helper.h>

QVector<DMA_DESCRIPTOR> dma_transactions_type1D;
QVector<DMA_DESCRIPTOR> dma_transactions_type2D;

COMMAND_SEGMENT createDMA_wait() {
    COMMAND_SEGMENT seg;
    seg.type = DMA_WAIT;
    return seg;
}

void dmaBiasLoad(const LAYER &layer, const SEGMENT &segment, void *conv, int cluster, int unit, BUFFER &buffer_load,
                 int lane) {
    uint32_t buffer = (int(buffer_load) * 4096);
    // LOAD Bias
    //MM -> buffer + 4096 - (kernel.x * kernel.y * (2)) - 1 - 1 -lane

    DMA_DESCRIPTOR dma;
    dma.dir = COMMAND_DMA::DMA_DIRECTION::e2l1D;
    dma.cluster = cluster;
    dma.unit = unit;
    dma.lm_addr = buffer + 4096 - (kernel_x * kernel_y * (2)) - 1 - lane;

    const int16_t *bias = nullptr;
    switch (layer.number) {
#ifndef TESTRUN
        case 1:
            bias = &(reinterpret_cast<const WEIGHTS_REDUCED<3, 16> *>(conv)->bias[segment.out_channel]);
            break;
        case 2:
            bias = &(reinterpret_cast<const WEIGHTS_REDUCED<16, 32> *>(conv)->bias[segment.out_channel]);
            break;
        case 3:
            bias = &(reinterpret_cast<const WEIGHTS_REDUCED<32, 64> *>(conv)->bias[segment.out_channel]);
            break;
        case 4:
            bias = &(reinterpret_cast<const WEIGHTS_REDUCED<64, 128> *>(conv)->bias[segment.out_channel]);
            break;
        case 5:
            bias = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 128> *>(conv)->bias[segment.out_channel]);
            break;
        case 6:
            bias = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 256> *>(conv)->bias[segment.out_channel]);
            break;
        case 7:
            bias = &(reinterpret_cast<const WEIGHTS_REDUCED<256, 125, 1> *>(conv)->bias[segment.out_channel]);
            break;
#else
            case 1:
                bias = &(reinterpret_cast<const WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> *>(conv)->bias[segment.out_channel]);
                break;
#endif
        default:
            printf_error(
                    "[layer.number error!] Bias mm address error. Bias is stored as offset inside the bias parameter array! the offset has > 32-bit!!!! \n");
            break;
    }
    const int16_t *bias_base = nullptr;
    // note: mm_addr offsets for bias AND kernel are relative to kernel for command order sorting consistent with absoulute DRAM addresses (sorting happens BEFORE adding base addresses)
    switch (layer.number) {
#ifndef TESTRUN
        case 1:
          bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<3, 16, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 2:
            bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<16, 32, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 3:
            bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<32, 64, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 4:
            bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<64, 128, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 5:
            bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 128, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 6:
            bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 256, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 7:
            bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<256, 125, 1> *>(conv)->kernel[0][0][0]);
            break;
#else
            case 1:
                bias_base = &(reinterpret_cast<const WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> *>(conv)->kernel[0][0][0]);
                break;
#endif
        default:
            printf_error(
                    "[layer.number error!] Bias base mm address error. Bias is stored as offset inside the bias parameter array! the offset has > 32-bit!!!! \n");
            break;
    }
    dma.isMM_Bias_offset = true;
    dma.mm_addr = uint64_t(intptr_t(bias)) - uint64_t(intptr_t(bias_base));
    if (uint64_t(uint32_t(dma.mm_addr)) != dma.mm_addr) {
        printf_error(
                "Bias mm address error. Bias is stored as offset inside the bias parameter array! the offset has > 32-bit!!!! \n");
    }

    dma.word_count = 1;
    dma.y_size = 1;     // UNUSED! (std as on previous calc method, without dcache)
    dma.x_stride = 0; // 2   // UNUSED! - 1  = 1 (std as on previous calc method, without dcache) // TODO: CHECK: 1D dont have a stride
    dma_transactions_type1D.append(dma);
}

void dmaCoeffLoad(const LAYER &layer, const SEGMENT &segment, void *conv, int cluster, int unit, BUFFER &buffer_load,
                  int lane) {

    uint32_t buffer = (int(buffer_load) * 4096);
    const int16_t *kernel = nullptr;
    switch (layer.number) {
#ifndef TESTRUN
        case 1:
            kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<3, 16, 3> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
            break;
        case 2:
            kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<16, 32, 3> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
            break;
        case 3:
            kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<32, 64, 3> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
            break;
        case 4:
            kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<64, 128, 3> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
            break;
        case 5:
            kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 128, 3> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
            break;
        case 6:
            kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 256, 3> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
            break;
        case 7:
            kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<256, 125, 1> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
            break;
#else
            case 1:
                kernel = &(reinterpret_cast<const WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> *>(conv)->kernel[segment.in_channel][segment.out_channel][0]);
                break;
#endif
        default:
            printf_error(
                    "[layer.number error!] Kernel mm address error. Kernel is stored as offset inside the Kernel parameter array! the offset has > 32-bit!!!! \n");
            break;
    }
    const int16_t *kernel_base = nullptr;
    switch (layer.number) {
#ifndef TESTRUN
        case 1:
            kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<3, 16, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 2:
            kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<16, 32, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 3:
            kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<32, 64, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 4:
            kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<64, 128, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 5:
            kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 128, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 6:
            kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<128, 256, 3> *>(conv)->kernel[0][0][0]);
            break;
        case 7:
            kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<256, 125, 1> *>(conv)->kernel[0][0][0]);
            break;
#else
            case 1:
                kernel_base = &(reinterpret_cast<const WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> *>(conv)->kernel[0][0][0]);
                break;
#endif
        default:
            printf_error(
                    "[layer.number error!] Kernel base mm address error. Kernel is stored as offset inside the Kernel parameter array! the offset has > 32-bit!!!! \n");
            break;
    }

    DMA_DESCRIPTOR dma;
    dma.dir = COMMAND_DMA::DMA_DIRECTION::e2l1D;
    dma.cluster = cluster;
    dma.unit = unit;
    dma.lm_addr = buffer + 4096 - (kernel_x * kernel_y * (lane + 1));
    dma.word_count = kernel_x * kernel_y;
    dma.y_size = 1;     // UNUSED! (std as on previous calc method, without dcache)
    dma.x_stride = 0; // 2  // UNUSED! - 1  = 1 (std as on previous calc method, without dcache) // TODO: CHECK: 1D dont have a stride
    dma.isMM_Kernel_offset = true;
    dma.mm_addr = uint64_t(intptr_t(kernel)) - uint64_t(intptr_t(kernel_base));

    if (uint64_t(uint32_t(dma.mm_addr)) != dma.mm_addr) {
        printf_error(
                "Kernel mm address error. Kernel is stored as offset inside the bias parameter array! the offset has > 32-bit!!!! \n");
    }

    dma_transactions_type1D.append(dma);
// LOAD segment kernel
    //MM -> buffer + 4096 - (kernel_x * kernel_y * (lane+1)) - 1)
}

void dmaDataLoad(const LAYER &layer, const SEGMENT &segment, int cluster, int unit, BUFFER &buffer_load) {
    uint32_t buffer = (int(buffer_load) * 4096);
    DMA_DESCRIPTOR dma;
    dma.dir = COMMAND_DMA::DMA_DIRECTION::e2l2D;
    dma.cluster = cluster;
    dma.unit = unit;
    dma.x_size = layer.conv.seg_in_w;
    dma.y_size = layer.conv.seg_in_h;
    dma.x_stride = segment.in_MM_x_stride_0;
    dma.mm_addr = segment.in_MM_base_0;
    dma.lm_addr = buffer;
    dma.pad[CommandDMA::PAD::TOP] = segment.pad_top;
    dma.pad[CommandDMA::PAD::RIGHT] = segment.pad_right;
    dma.pad[CommandDMA::PAD::BOTTOM] = segment.pad_bottom;
    dma.pad[CommandDMA::PAD::LEFT] = segment.pad_left;
    dma_transactions_type2D.append(dma);
}

void dmaResidualDataLoad(const LAYER &layer, const SEGMENT &segment, int cluster, int unit, BUFFER &buffer_load) {
    uint32_t buffer = (int(buffer_load) * 4096);
    {
        DMA_DESCRIPTOR dma;
        dma.dir = COMMAND_DMA::DMA_DIRECTION::e2l2D;
        dma.cluster = cluster;
        dma.unit = unit;
        dma.x_size = layer.conv.seg_in_w;
        dma.y_size = layer.conv.seg_in_h;
        dma.x_stride = segment.in_MM_x_stride_0;
        dma.mm_addr = segment.in_MM_base_0;
        dma.lm_addr = buffer;
        dma_transactions_type2D.append(dma);
    }
    {
        DMA_DESCRIPTOR dma;
        dma.dir = COMMAND_DMA::DMA_DIRECTION::e2l2D;
        dma.cluster = cluster;
        dma.unit = unit;
        dma.x_size = layer.conv.seg_in_w;
        dma.y_size = layer.conv.seg_in_h;
        dma.x_stride = segment.in_MM_x_stride_1;
        dma.mm_addr = segment.in_MM_base_1;
        dma.lm_addr = buffer + 1024;
        dma_transactions_type2D.append(dma);
    }
}

COMMAND_SEGMENT createDMA_Load(DMA_DESCRIPTOR &dma, const uint32_t &unit_mask, void *conv, const LAYER &layer) {
    COMMAND_SEGMENT seg;
    seg.type = DMA_SEG;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->direction = dma.dir;
    assert(dma.dir != COMMAND_DMA::DMA_DIRECTION::l2e1D);
    assert(dma.dir != COMMAND_DMA::DMA_DIRECTION::l2e2D);
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->cluster = dma.cluster;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->unit_mask = unit_mask;

    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->isBiasOffset = dma.isMM_Bias_offset;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->isKernelOffset = dma.isMM_Kernel_offset;

    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->mm_addr = dma.mm_addr;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->lm_addr = dma.lm_addr;
    if (dma.dir == COMMAND_DMA::DMA_DIRECTION::e2l1D) {
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->x_size = dma.word_count;
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->y_size = 1;
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->x_stride = 0; //dma.x_stride - 1;    // 1D dont have stride
    } else {
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->x_stride = dma.x_stride; // - 1;
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->x_size = dma.x_size;
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->y_size = dma.y_size;
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->pad_0 = dma.pad[0];
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->pad_1 = dma.pad[1];
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->pad_2 = dma.pad[2];
        reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->pad_3 = dma.pad[3];
    }
    return seg;
}

COMMAND_SEGMENT
createDMA_DataStore(const LAYER &layer, const SEGMENT &segment, int cluster, int unit, BUFFER &buffer_load, int lane) {
    int xsize = layer.conv.seg_out_w;
    int ysize = layer.conv.seg_out_h;
    if (layer.pool.stride == 2) {
        xsize = layer.conv.seg_out_w >> 1;
        ysize = layer.conv.seg_out_w >> 1;
    } else if (layer.pool.stride > 2) {
        xsize = layer.conv.seg_out_w / layer.pool.stride;
        ysize = layer.conv.seg_out_w / layer.pool.stride;
    }

    COMMAND_SEGMENT seg;
    seg.type = DMA_SEG;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->direction = COMMAND_DMA::DMA_DIRECTION::l2e2D;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->cluster = cluster;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->unit_mask = unit;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->mm_addr = segment.out_MM_base;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->lm_addr =
            LM_BASE_VU(unit) + (int(buffer_load) * 4096) + lane * 1024;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->x_stride = segment.out_MM_x_stride; // - 1; // ? no? -> segment has dma specific +1 modification (no stride) (input/output dont)
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->x_size = xsize;
    reinterpret_cast<COMMAND_DMA::COMMAND_DMA *>(seg.data)->y_size = ysize;

    // seg.word_count, pad not used!
    return seg;
}

QVector<COMMAND_SEGMENT> dmaStartBroadcastLoad(const LAYER &layer, void *conv) {
    QVector<COMMAND_SEGMENT> cmd_seg_list;
    if (!dma_transactions_type1D.empty()) {
        std::stable_sort(dma_transactions_type1D.begin(), dma_transactions_type1D.end(),
                  [](const DMA_DESCRIPTOR &d1, const DMA_DESCRIPTOR &d2) -> bool {
                      return d1.mm_addr < d2.mm_addr; // sort by mm
                  });
        DMA_DESCRIPTOR &starter = dma_transactions_type1D[0];
        uint32_t unit_mask = uint32_t(0b1u) << starter.unit;
        for (auto &dma: dma_transactions_type1D) {
            assert(dma.dir == COMMAND_DMA::DMA_DIRECTION::l2e1D || dma.dir == COMMAND_DMA::DMA_DIRECTION::e2l1D);
            if (dma.mm_addr == starter.mm_addr &&
                dma.lm_addr == starter.lm_addr &&
                dma.word_count == starter.word_count &&
                dma.cluster == starter.cluster &&
                dma.isMM_Bias_offset == starter.isMM_Bias_offset &&
                dma.isMM_Kernel_offset == starter.isMM_Kernel_offset) {
                unit_mask |= uint32_t(0b1u) << dma.unit;
            } else {
                cmd_seg_list.append(createDMA_Load(starter, unit_mask, conv, layer));
//                startDMADesriptor(starter, unit_mask);
                starter = dma;
                unit_mask = uint32_t(0b1u) << dma.unit;
            }
        }
        cmd_seg_list.append(createDMA_Load(starter, unit_mask, conv, layer));
//        startDMADesriptor(starter, unit_mask);
    }
    if (!dma_transactions_type2D.empty()) {
        std::stable_sort(dma_transactions_type2D.begin(), dma_transactions_type2D.end(),
                  [](const DMA_DESCRIPTOR &d1, const DMA_DESCRIPTOR &d2) -> bool {
                      return d1.mm_addr < d2.mm_addr; // sort by mm
                  });
        DMA_DESCRIPTOR &starter = dma_transactions_type2D[0];
        uint32_t unit_mask = uint32_t(0b1u) << starter.unit;
        for (auto &dma: dma_transactions_type2D) {
            assert(dma.dir == COMMAND_DMA::DMA_DIRECTION::l2e2D || dma.dir == COMMAND_DMA::DMA_DIRECTION::e2l2D);
            if (dma.mm_addr == starter.mm_addr &&
                dma.lm_addr == starter.lm_addr &&
                dma.x_stride == starter.x_stride &&
                dma.y_size == starter.y_size &&
                dma.x_size == starter.x_size &&
                dma.cluster == starter.cluster &&
                dma.isMM_Bias_offset == starter.isMM_Bias_offset &&
                dma.isMM_Kernel_offset == starter.isMM_Kernel_offset) {
                unit_mask |= uint32_t(0b1u) << dma.unit;
            } else {
                cmd_seg_list.append(createDMA_Load(starter, unit_mask, conv, layer));
//                startDMADesriptor(starter, unit_mask);
                starter = dma;
                unit_mask = uint32_t(0b1u) << dma.unit;
            }
        }
        cmd_seg_list.append(createDMA_Load(starter, unit_mask, conv, layer));
//        startDMADesriptor(starter, unit_mask);
    }
    dma_transactions_type1D.clear();
    dma_transactions_type2D.clear();
    return cmd_seg_list;
}
