#ifndef CONV_H
#define CONV_H

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <inttypes.h>

#include <vpro.h>
#include <eisv.h>

// input defines
constexpr uint32_t kernel_size = 7;
constexpr bool do_opt = false;

constexpr bool use_dma_loop = false;

#define RV_EXT 0
#if not defined(SIMULATION) && RV_EXT == 1
constexpr bool vpro_ext = true;
#else
constexpr bool vpro_ext = false;    // never for sim
#endif

struct image_dim_t{
    uint32_t dim_x{};
    uint32_t dim_y{};
};

//constexpr image_dim_t input = {.dim_x = 8, .dim_y = 8};
//constexpr image_dim_t output = {.dim_x = 8, .dim_y = 8};
//constexpr image_dim_t input = {.dim_x = 31, .dim_y = 31};
//constexpr image_dim_t output = {.dim_x = 31, .dim_y = 31};
//constexpr image_dim_t input = {.dim_x = 32, .dim_y = 32};
//constexpr image_dim_t output = {.dim_x = 32, .dim_y = 32};
//constexpr image_dim_t input = {.dim_x = 496, .dim_y = 496};
//constexpr image_dim_t output = {.dim_x = 496, .dim_y = 496};
constexpr image_dim_t input = {.dim_x = 512, .dim_y = 512};
constexpr image_dim_t output = {.dim_x = 512, .dim_y = 512};
//constexpr image_dim_t input = {.dim_x = 1024, .dim_y = 1024};
//constexpr image_dim_t output = {.dim_x = 1024, .dim_y = 1024};
//constexpr image_dim_t input = {.dim_x = 8192, .dim_y = 8192};
//constexpr image_dim_t output = {.dim_x = 8192, .dim_y = 8192};

/**
 * Generate maximal sized segments...
 */

struct segment_t{
    uint32_t dim_in_x{};
    uint32_t dim_in_y{};
    uint32_t num_x{};
    uint32_t num_y{};
    uint32_t dim_out_x{};
    uint32_t dim_out_y{};
};

#include <limits>
namespace Detail
{
    double constexpr sqrtNewtonRaphson(double x, double curr, double prev)
    {
        return curr == prev
               ? curr
               : sqrtNewtonRaphson(x, 0.5 * (curr + x / curr), curr);
    }
}
double constexpr c_sqrt(double x)
{
    return x >= 0 && x < std::numeric_limits<double>::infinity()
           ? Detail::sqrtNewtonRaphson(x, x, 0)
           : std::numeric_limits<double>::quiet_NaN();
}
constexpr int int_ceil(float f)
{
    const int i = static_cast<int>(f);
    return f > i ? i + 1 : i;
}
constexpr int int_floor(float f)
{
    const int i = static_cast<int>(f);
    return f < i ? i - 1 : i;
}
constexpr segment_t max_seg(){ // for split to two lanes (additional block with half height of kernel is stored)
    // 1024 RF entries -> 32 for dim of out seg
    uint32_t stride = 1;
    uint32_t n_weights = kernel_size * kernel_size;
    uint32_t rf_free_entries = 1024 - n_weights;

    // local memory is halved for double buffering
    uint32_t lm_free_entries = 8192 / 2 - 2 * n_weights;
    uint32_t lm_in_seg_max = uint32_t(int_floor(float(c_sqrt(lm_free_entries) / stride)));

    uint32_t max_beta = 63; //FIXME: use globals
    uint32_t max_xend_yend = 63; //FIXME: use globals

    //  VPRO can 2D address max 31 * 31 sections (beta limited to 5 bit - next line address), so dim is max 31
    lm_in_seg_max = std::min(max_beta, uint32_t(int_ceil(float(lm_in_seg_max))));
    uint32_t rf_out_seg_max = std::min(lm_in_seg_max, uint32_t(int_floor(float(c_sqrt(rf_free_entries)))));

    // Segment
    segment_t seg;
    seg.num_x = int(std::max(int_ceil(float(output.dim_x) / float(rf_out_seg_max)),
                             int_ceil(float(input.dim_x) / float(lm_in_seg_max))));
    seg.num_y = int(std::max(int_ceil(float(output.dim_y) / float(rf_out_seg_max)),
                             int_ceil(float(input.dim_y) / float(lm_in_seg_max))));

    seg.dim_out_x  = int_ceil(float(output.dim_x) / float(seg.num_x));
    seg.dim_out_y = int_ceil(float(output.dim_y) / float(seg.num_y));

    // limit segment addressing by x_end, y_end
    uint32_t max_seg_dim = max_xend_yend + 1;   // for all segments...
    if (seg.dim_out_x  > max_seg_dim) {
        seg.num_x = int_ceil(float(output.dim_x) / float(max_seg_dim));
        seg.dim_out_x  = int_ceil(float(output.dim_x) / float(seg.num_x));
    }
    if (seg.dim_out_y > max_seg_dim) {
        seg.num_y = int_ceil(float(output.dim_y) / float(max_seg_dim));
        seg.dim_out_y = int_ceil(float(output.dim_y) / float(seg.num_y));
    }

    // increment seg in with kernel padding
    seg.dim_in_x = ((kernel_size - 1) / stride) + seg.dim_out_x * stride;
    seg.dim_in_y = ((kernel_size - 1) / stride) + seg.dim_out_y * stride;

    // fix for too large beta (seg_in_x/y)
    if (seg.dim_in_x > max_beta){
        seg.num_x++;
        seg.dim_out_x = int_ceil(float(output.dim_x)/float(seg.num_x));
        seg.dim_in_x = ((kernel_size - 1) / stride) + seg.dim_out_x * stride;
    }
    if (seg.dim_in_y > max_beta){
        seg.num_y++;
        seg.dim_out_y = int_ceil(float(output.dim_y)/float(seg.num_y));
        seg.dim_in_y = ((kernel_size - 1) / stride) + seg.dim_out_y * stride;
    }

    return seg;
}

constexpr segment_t segment = max_seg();
static_assert(segment.dim_out_x <= MAX_X_END);
static_assert(segment.dim_out_y - 1 <= MAX_Y_END);
static_assert(segment.dim_in_x <= MAX_BETA);
static_assert(segment.dim_out_x <= MAX_BETA);

constexpr uint32_t mm_input = 0x81000000; // byte address
constexpr uint32_t mm_in_stride = 0;
constexpr uint32_t mm_output = 0x91000000; // byte address
constexpr uint32_t mm_out_stride = segment.dim_out_x * segment.num_x - output.dim_x;

constexpr int kernel_load_shift_right = 1;
constexpr int conv_result_shift_right = 5;
constexpr int store_shift_right = 1;


// define start addresses of kernels in RF (=LM)
constexpr uint32_t RF_KERNEL_BASE = 1024-kernel_size*kernel_size;

constexpr uint32_t LM_INPUT_BASE = 0;
constexpr uint32_t LM_KERNEL_BASE = LM_INPUT_BASE + segment.dim_in_x*segment.dim_in_y;
constexpr uint32_t LM_END = LM_KERNEL_BASE + kernel_size*kernel_size;
static_assert(LM_END < 4096);   // for double buffering

// .nobss = uninitialized! (speed up sim), .vpro sections the risc access with dma (uninitialized as well)
extern int16_t __attribute__ ((section (".vpro"))) result_array[output.dim_x*output.dim_y];
//extern int16_t __attribute__ ((section (".vpro"))) result_array_zeros[segment.dim_out_x*segment.dim_out_y];
extern int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];

// no initialization data for those region!
extern int16_t __attribute__ ((section (".vpro"))) kernel[kernel_size*kernel_size];
extern int16_t __attribute__ ((section (".vpro"))) test_array_1[input.dim_x*input.dim_y];

constexpr bool pad_flags[4] = {false, false, false, false};  // for dma padding

extern int calc_buffer; // LM Base input
extern int calc_buffer_out; // LM Base output

extern int load_buffer;


void vpro_conv();
void vpro_load_kernel();

void vpro_ext_init();

#endif
