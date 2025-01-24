
#include "core_wrapper.h"

#include <vpro.h>

#ifndef helper
#define helper

// Helper to translate main memory 2d array to main memory 1d array
void dma_linearize2d(uint32_t cluster, uint32_t ext_src, uint32_t ext_dst, uint32_t loc_temp, uint32_t src_x_stride,
                     uint32_t src_x_size, uint32_t src_y_size);

void printProgress(double percent, int size);

//assumes little endian
void printBits(size_t const size, void const * const ptr);

// sets all to 0
void resetRF(int length = 1024);
void reset_all_RF();
void reset_all_LM();

// use of VPRO instructions
void rf_set(int offset, int value, int size = 0, int lane = 0);
void rf_set(int offset, const uint32_t *data, int size, int lane = 0);

// sets all to 0
void resetLM(int length = 8192, int cluster = 0, int unit = 0);
void setLM(int length, int cluster, int unit, int data = 64, int address = 200);
void resetMM(int length = 1024*1024*512);
void setMM(int address, int data, int length = 1);

// linear check, all values the same?
void verifyRF(int value, int lane, int offset, int length, int cluster = 0, int unit = 0);
void verifyLM(int value, int offset, int length, int cluster = 0, int unit = 0);


// incrementing data setting
void set_all_LM_incr(int length, int data, int address);
void setLM_incr(int length, int cluster, int unit, int data, int address);
void rf_set_incr(int offset, int value, int size, int lane);
#endif
