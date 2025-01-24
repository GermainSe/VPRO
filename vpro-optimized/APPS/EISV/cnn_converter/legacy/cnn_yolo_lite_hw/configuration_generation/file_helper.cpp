//
// Created by gesper on 06.04.22.
//

#include "file_helper.h"

const char* to_bin(size_t const size, void const *const ptr) {
  static char buf[256];
  uint64_t v = *(uint64_t *)ptr;
  
  char *p = buf;
  for (int i = size - 1; i >= 0; i--) {
    *p++ = '0' + ((v >> i) & 1);
  }
  return buf;
}

QString commang_seg_qstring(const COMMAND_SEGMENT &s) {
    QString ret = "";
    if (s.type == DMA_SEG) {
        ret += "DMA_CMD, direction";
        if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->direction == COMMAND_DMA::DMA_DIRECTION::l2e2D)
            ret += "l2e2D, ";
        else if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->direction ==
                 COMMAND_DMA::DMA_DIRECTION::l2e1D)
            ret += "l2e1D, ";
        else if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->direction ==
                 COMMAND_DMA::DMA_DIRECTION::e2l2D)
            ret += "e2l2D, ";
        else if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->direction ==
                 COMMAND_DMA::DMA_DIRECTION::e2l1D)
            ret += "e2l1D ,";
        ret += "isKernelOffset ";
        if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->isKernelOffset)
            ret += "1, ";
        else
            ret += "0, ";
        ret += "isBiasOffset ";
        if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->isBiasOffset)
            ret += "1, ";
        else
            ret += "0, ";
            
        ret += "cluster " + QString::number(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->cluster) + ", ";
        ret += "unit_mask " + QString(to_bin(32, &(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->unit_mask))) + ", ";
            
        ret += "mm_addr 0x" + QString::number(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->mm_addr, 16) + ", ";
        ret += "lm_addr 0x" + QString::number(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->lm_addr, 16) + ", ";
        ret += "x_stride " + QString::number(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->x_stride) + ", ";
        ret += "x_size " + QString::number(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->x_size) + ", ";
//        ret += "y_size " + QString::number(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->mm_addr) + ", ";
        ret += "pad_0 ";
        if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->pad_0)
            ret += "1, ";
        else
            ret += "0, ";
        ret += "pad_1 ";
        if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->pad_1)
            ret += "1, ";
        else
            ret += "0, ";
        ret += "pad_2 ";
        if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->pad_2)
            ret += "1, ";
        else
            ret += "0, ";
        ret += "pad_3 ";
        if (reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->pad_3)
            ret += "1, ";
        else
            ret += "0, ";
    } else if (s.type == VPRO_SEG) {
        ret += "VPRO_CMD, ";
        if (reinterpret_cast<const COMMAND_VPRO *>(s.data)->command == shift_store)
            ret += "shift_store ";
        else if (reinterpret_cast<const COMMAND_VPRO *>(s.data)->command == relu_pool)
            ret += "relu_pool ";
        else if (reinterpret_cast<const COMMAND_VPRO *>(s.data)->command == conv_add)
            ret += "conv_add ";
        else if (reinterpret_cast<const COMMAND_VPRO *>(s.data)->command == conv_start)
            ret += "conv_start ";
        else if (reinterpret_cast<const COMMAND_VPRO *>(s.data)->command == residual)
            ret += "residual ";
        ret += "lane " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->lane) + ", ";
        ret += "buffer " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->buffer) + ", ";
        ret += "xend_1 " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->xend_1) + ", ";
        ret += "xend_2 " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->xend_2) + ", ";
        ret += "yend " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->yend) + ", ";
        ret += "offset " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->offset) + ", ";
        ret += "kernel_load_buffer_l0 " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->kernel_load_buffer_l0) + ", ";
        ret += "kernel_load_buffer_l1 " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->kernel_load_buffer_l1) + ", ";
        ret += "bias_load_buffer_l0 " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->bias_load_buffer_l0) + ", ";
        ret += "bias_load_buffer_l1 " + QString::number(reinterpret_cast<const COMMAND_VPRO *>(s.data)->bias_load_buffer_l1) + ", ";
//        ret += "four_way["+QString::number(reinterpret_cast<COMMAND_VPRO *>(s.data)->four_way)+"], ";
    } else if (s.type == VPRO_WAIT) {
        ret += "VPRO_WAIT";
    } else if (s.type == DMA_WAIT) {
        ret += "DMA_WAIT";
    } else if (s.type == DMA_BLOCK) {
        ret += "DMA_BLOCK, " + QString::number(reinterpret_cast<const COMMAND_DMA::COMMAND_DMA *>(s.data)->unit_mask);
    }
    ret += "\n";
    return ret;
}

QString getDir() {
    FILE *fpipe;
    QString cmd = "echo ${PWD}";
    auto cmd_std = cmd.toStdString();
    const char *command = cmd_std.c_str();
    if (!(fpipe = (FILE *) popen(command, "r"))) {
        printf_error("popen() failed.");
        exit(EXIT_FAILURE);
    }
    QString string = "";
    char c = 0;
    while (fread(&c, sizeof c, 1, fpipe)) {
        string += c;
    }
    pclose(fpipe);
    return string;
}

int getElfBaseForObject(const char *filename, const char *object) {
    FILE *fpipe;
    QString cmd = "echo \"obase=10; ibase=16; `cat " + QString(filename) + " | grep OBJECT.*" + QString(object) +
                  "$ | awk '{print $2;}' | sed 's/^0x//g' | tr '[:lower:]' '[:upper:]' `\" | bc";
    auto cmd_std = cmd.toStdString();
    const char *command = cmd_std.c_str();
    if (!(fpipe = (FILE *) popen(command, "r"))) {
        printf_error("popen() failed.");
        exit(EXIT_FAILURE);
    }
    QString string = "";
    char c = 0;
    while (fread(&c, sizeof c, 1, fpipe)) {
        string += c;
    }
    pclose(fpipe);
    return string.toInt();
}
