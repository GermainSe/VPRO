// ########################################################
// # example app for MIPS, using some IO/Data instruction #
// #                                                      #
// # Sven Gesper, EIS, Tu Braunschweig, 2021              #
// ########################################################

#include <vpro.h>
#include "test_defines.h"


volatile int16_t __attribute__((section(".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__((section(".vpro"))) test_array_2[NUM_TEST_ENTRIES];
volatile int16_t __attribute__((section(".vpro"))) result_array[NUM_TEST_ENTRIES];

/**
 * Main
 */
int main(int argc, char *argv[]) {
    sim_init(main, argc, argv);
    sim_printf("\nDMA Test App\n");
    sim_printf("test_array_1 addr: 0x%x\n", test_array_1);
    sim_printf("test_array_2 addr: 0x%x\n", test_array_2);
    sim_printf("result_array addr: 0x%x\n", result_array);

    // normal_dma_test(test_array_1, test_array_2, result_array);
    // padding_left_test(test_array_1, test_array_2, result_array);
    // padding_top_test(test_array_1, test_array_2, result_array);
    // padding_right_test(test_array_1, test_array_2, result_array);
    // padding_bottom_test(test_array_1, test_array_2, result_array);
    // padding_top_left_test(test_array_1, test_array_2, result_array);
    // padding_top_right_test(test_array_1, test_array_2, result_array);
    // padding_bottom_left_test(test_array_1, test_array_2, result_array);
    // padding_bottom_right_test(test_array_1, test_array_2, result_array);
    // dma_2d_stride_test(test_array_1, test_array_2, result_array);
    dcma_auto_replace_cache_line(test_array_1, test_array_2, result_array);
    //dcma_uram_test(test_array_1, test_array_2, result_array);

    sim_printf("TESTS FINISHED\n");
    return 0;
}
