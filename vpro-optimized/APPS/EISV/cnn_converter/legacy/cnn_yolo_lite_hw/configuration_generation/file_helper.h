//
// Created by gesper on 06.04.22.
//

#ifndef CNN_YOLO_LITE_HW_FILE_HELPER_H
#define CNN_YOLO_LITE_HW_FILE_HELPER_H

#include <stdint.h>
#include <iostream>
#include <helper.h>

template<typename T>
std::ofstream SaveNewObject(T *object, const std::string &filename, int size = -1);

template<typename T>
void SaveObject(std::ofstream &out, T *object, const std::string &filename, int size = -1);

template<typename T>
std::ofstream SaveNewObject(T *object, const std::string &filename, int size) {
//    for (int i = 0; i < 9+9+1 ; ++i){
//        printf_info("Save Layer Data [%i] = %i\n", i, (((int16_t *)object)[47+i]));
//    }
    std::ofstream out(filename.c_str(), std::ios::binary);
    if (size < 0) {
        out.write((char *) object, sizeof(T));
        printf_success("Layer Data wrote out to New [%s]. Size: %li  \n", filename.c_str(), sizeof(*object));
    } else {
        out.write((char *) object, size);
        printf_success("Data wrote out to New [%s]. Size: %li  \n", filename.c_str(), size);
    }
    return out;
    //printf_error("[ERROR] Error opening output file [%s]!\n", output.toStdString().c_str());
}

template<typename T>
void SaveObject(std::ofstream &out, T *object, const std::string &filename, int size) {
    if (size < 0) {
        out.write((char *) object, sizeof(T));
        printf_success("Layer Data wrote out to [%s]. Size: %li \n", filename.c_str(), sizeof(*object));
    } else {
        out.write((char *) object, size);
        printf_success("Layer Data wrote out to [%s]. Size: %li \n", filename.c_str(), size);
    }
}

/**
 * print parameters of this Layer (Wrapper parameters)
 * @tparam Layer LAYER_REDUCED
 * @param l
 */
template<typename Layer>
void printLayer(Layer &l) {
    printf("############### Layer %i ############################# \n", (l.number) - 1);
    printf("Address type:                     %lx , data: %x / %i\n", intptr_t(&(l.type)), l.type, l.type);
    printf("Address number :                  %lx , data: %x / %i\n", intptr_t(&(l.number)), (l.number), (l.number));
    printf("Address conv_result_shift_right : %lx , data: %x / %i \n", intptr_t(&(l.conv_result_shift_right)),
           (l.conv_result_shift_right), (l.conv_result_shift_right));
    printf("Address relu_6_shift_left :       %lx , data: %x / %i \n", intptr_t(&(l.relu_6_shift_left)),
           (l.relu_6_shift_left), (l.relu_6_shift_left));
    printf("Address bias_shift_right :        %lx , data: %x / %i \n", intptr_t(&(l.bias_shift_right)),
           (l.bias_shift_right), (l.bias_shift_right));
    printf("Address store_shift_right :       %lx , data: %x / %i \n", intptr_t(&(l.store_shift_right)),
           (l.store_shift_right), (l.store_shift_right));
    printf("Address residual_1_left_shift :   %lx , data: %x / %i \n", intptr_t(&(l.residual_1_left_shift)),
           (l.residual_1_left_shift), (l.residual_1_left_shift));
    printf("Address residual_0_left_shift :   %lx , data: %x / %i \n", intptr_t(&(l.residual_0_left_shift)),
           (l.residual_0_left_shift), (l.residual_0_left_shift));
    printf("Address pool.stride:              %lx , data: %x / %i \n", intptr_t(&(l.pool_stride)), (l.pool_stride),
           (l.pool_stride));
    printf("Address relu.type:                %lx , data: %x / %i \n", intptr_t(&(l.relu_type)), l.relu_type,
           l.relu_type);
    printf("Address pad.top:                  %lx , data: %x / %i \n", intptr_t(&(l.pad.top)), (l.pad.top),
           (l.pad.top));
    printf("Address pad.left:                 %lx , data: %x / %i \n", intptr_t(&(l.pad.left)), (l.pad.left),
           (l.pad.left));
    printf("Address pad.bottom:               %lx , data: %x / %i \n", intptr_t(&(l.pad.bottom)), (l.pad.bottom),
           (l.pad.bottom));
    printf("Address pad.right:                %lx , data: %x / %i \n", intptr_t(&(l.pad.right)), (l.pad.right),
           (l.pad.right));
    printf("Address pad.value:                %lx , data: %x / %i \n", intptr_t(&(l.pad.value)), (l.pad.value),
           (l.pad.value));
    printf("Address conv stride :             %lx , data: %x / %i \n", intptr_t(&(l.stride)), (l.stride), (l.stride));
    printf("Address conv kernel_length :      %lx , data: %x / %i \n", intptr_t(&(l.kernel_length)), (l.kernel_length),
           (l.kernel_length));
    printf("Address conv seg_out_w :          %lx , data: %x / %i \n", intptr_t(&(l.seg_out_w)), (l.seg_out_w),
           (l.seg_out_w));
    printf("Address conv seg_out_h :          %lx , data: %x / %i \n", intptr_t(&(l.seg_out_h)), (l.seg_out_h),
           (l.seg_out_h));
    printf("Address conv in_channels :        %lx , data: %x / %i \n", intptr_t(&(l.in_channels)), (l.in_channels),
           (l.in_channels));
    printf("Address conv out_channels :       %lx , data: %x / %i \n", intptr_t(&(l.out_channels)), (l.out_channels),
           (l.out_channels));
    printf("Address conv seg_in_w :           %lx , data: %x / %i \n", intptr_t(&(l.seg_in_w)), (l.seg_in_w),
           (l.seg_in_w));
    printf("Address conv seg_in_h :           %lx , data: %x / %i \n\n", intptr_t(&(l.seg_in_h)), (l.seg_in_h),
           (l.seg_in_h));
}

QString commang_seg_qstring(const COMMAND_SEGMENT &s);

QString getDir();

int getElfBaseForObject(const char *filename, const char *object);
#endif //CNN_YOLO_LITE_HW_FILE_HELPER_H
