//
// Created by thieu on 20.09.22.
//

#ifndef DMA_TESTS_NORMAL_DMA_H
#define DMA_TESTS_NORMAL_DMA_H
#include <algorithm>
#include <stdint.h>
#include <vpro.h>
#include <eisv.h>
#include <random>
#include <vpro/dma_cmd_struct.h>

#define NUM_TEST_ENTRIES 1024

void normal_dma_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_left_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_top_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_right_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_bottom_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_top_left_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_top_right_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_bottom_left_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void padding_bottom_right_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void dma_2d_stride_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void dcma_auto_replace_cache_line(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
void dcma_uram_test(volatile int16_t *test_array_1, volatile int16_t *test_array_2, volatile int16_t *result_array);
#endif //DMA_TESTS_NORMAL_DMA_H
