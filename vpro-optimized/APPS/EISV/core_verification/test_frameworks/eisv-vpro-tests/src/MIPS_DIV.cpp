#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

#include "test_defines.h"
#include "vpro_test_functions.h"

// .nobss = uninitialized! (speed up sim), .vpro sections the risc access with dma (uninitialized as well)
volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) result_array[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_zeros[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_large[1024 * 1024];



int main(int argc, char *argv[]) {
    INIT();
    printf("Start\n");
    int16_t count = 0;

    // reset result array
    for (volatile int16_t &i : result_array){
        i = 0xdead;
        if (++count > NUM_TEST_ENTRIES) break;
    }
    (count = 0);
    // input data generation
    for (volatile int16_t &i : test_array_1){
        i = count;
        count = (abs(count)+1)*(-1);
    }
    count = NUM_TEST_ENTRIES - 1;
    for (volatile int16_t &i : test_array_2){
        i = count;
        count--;
    }
    // set LM to 0 value

    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(result_array_zeros[0]))), 128, NUM_TEST_ENTRIES);
    dma_e2l_1d(0b1, 0b1, uint64_t(intptr_t(&(result_array_zeros[0]))), 0, NUM_TEST_ENTRIES);
    // set whole RF to dead / error value
    __vpro(L0_1, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 32),
           SRC2_IMM_2D(0), SRC2_IMM_2D(0xdead), 31, 31);
    // reset shift registers
#if BITWIDTH_REDUCE_TO_16_BIT == 1
    vpro_mac_h_bit_shift(16);
    vpro_mul_h_bit_shift(16);
#else
    vpro_mac_h_bit_shift(24);
    vpro_mul_h_bit_shift(24);
#endif
    vpro_wait_busy(0xffffffff, 0xffffffff);
    dma_wait_to_finish(0xffffffff);

    // reset cycle counters in subsystem
    aux_clr_sys_time();

    // execute test
    // DIV Test
//        volatile int16_t rnd[256];
//        int16_t input_real[256];
//        int16_t input_imag[256];
//        int16_t input_abs[256];
//        volatile int16_t result[256];
//        uint32_t lshift = 1;
//        for (int i = 0; i < 256; ++i) {
//
//#ifdef SIMULATION
//            rnd[i] = uint16_t(uni(rng)) + i;
//            if (rnd[i] > 0xff)
//                rnd[i] = 0xff;
//#else
//            rnd[i] = std::min(aux_rnd_get() + i, 0xffu);
//#endif
//            result[i] = 0;
//            input_real[i] = rnd[i];
//            input_imag[i] = rnd[i];
//            input_abs[i] = rnd[i];
//        }
//        aux_clr_sys_time();
//        aux_clr_cycle_cnt();
        for (int i = 0; i < 64; i++) {
            if (test_array_2[i] != 0)
                result_array[i] = int16_t(((int32_t(int32_t(int16_t(test_array_1[i]) << 16u) / int16_t(test_array_2[i])) << 1u) >> 16u));
//            result[i] = int16_t(((int32_t(int32_t(input_imag[i] << 16) / input_abs[i]) << lshift) >> 16));
        }

    // DCMA
    dcma_flush();

// printf runtime (cycle counters in subsystem)
    uint64_t sys_time = aux_get_sys_time_lo();
    sys_time += (uint64_t(aux_get_sys_time_hi()) << 32);
    printf("SYS_TIME: %lu\n", sys_time);

    // verify framework: dump result
    dump(result_array, NUM_TEST_ENTRIES);

    printf("\nEnd");
    return 0;
}
