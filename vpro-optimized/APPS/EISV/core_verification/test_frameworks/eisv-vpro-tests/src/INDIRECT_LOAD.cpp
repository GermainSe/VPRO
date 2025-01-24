// #########################################################
// # Test for Load Store Lane using dynamic chained offset #
// #                                                       #
// # Sven Gesper, EIS, Tu Braunschweig, 2023               #
// #########################################################

#include <stdint.h>
#include <algorithm>
#include <vpro.h>

#include "test_defines.h"
#include "vpro_test_functions.h"

volatile uint16_t __attribute__ ((section (".vpro"))) __attribute__ ((aligned (32))) test_offsets[8];
volatile int16_t __attribute__ ((section (".vpro"))) __attribute__ ((aligned (32))) test_data[256];
volatile int16_t __attribute__ ((section (".vpro"))) __attribute__ ((aligned (32))) result_array[1024];

volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
//volatile int16_t __attribute__ ((section (".vpro"))) result_array[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_zeros[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_dead[1024];
volatile int16_t __attribute__ ((section (".vpro"))) result_array_large[1024 * 1024];

/**
 * Main
 */
int main(int argc, char *argv[]) {
    INIT();
    printf("Start\n");

    // copy/create data, as .vpro section has no initial data
    uint16_t tmp[8] = { 0x0001, 0x0023, 0x00A2, 0x00B7, 0x00CC, 0x009D, 0x0049, 0x0090 };
    // Init test data
    for (uint16_t i = 0; i < 256; i++) {
        test_data[i] = 255 - i;
        
        if (i < 8)
            test_offsets[i] = tmp[i];
    }
    

    // Upload test data, offsets
    dma_e2l_1d(1, 1, uintptr_t(test_data), 0, 256);
    dma_e2l_1d(1, 1, uintptr_t(test_offsets), 1024, 8);
    
    dma_wait_to_finish();

    // save offsets in L0
    VPRO::DIM2::LOADSTORE::load(
        1024, 0, 1, 0,
        7, 0
    );
    VPRO::DIM2::PROCESSING::add(
        L0,
        DST_ADDR(0, 1, 0),
        SRC1_LS_2D,
        SRC2_IMM_2D(0),
        7, 0
    );

    vpro_wait_busy();


    // chain offsets to load instruction
    VPRO::DIM2::PROCESSING::add(
        L0,
        DST_ADDR(0, 1, 0),
        SRC1_ADDR(0, 1, 0),
        SRC2_IMM_2D(0),
        7, 0,
        true
    );

    // use offset (address) to load dynamic
    VPRO::DIM3::LOADSTORE::dynamic_load(
        L0,
        0, 0, 0, 0,
        7, 0, 0
    );

    // save loaded data in L1
    VPRO::DIM2::PROCESSING::add(
        L1,
        DST_ADDR(0, 1, 0),
        SRC_LS_2D,
        SRC2_IMM_2D(0),
        7, 0
    );
    // 254 , 220, 93, ...


    // store back to LM
    VPRO::DIM3::PROCESSING::add(L1,
                                DST_ADDR(0, 1, 8, 0), SRC1_ADDR(0, 1, 8, 0), SRC2_IMM_3D(0),
                                7, 0, 0, true);

    VPRO::DIM3::LOADSTORE::store(2048,
                                 0, 1, 8, 0,
                                 7, 0, 0,
                                 L1);
    vpro_sync();
    
    // Transfer back to result array
    dma_l2e_1d(0b1, 0b1, intptr_t(result_array), 2048, 8);
    
    vpro_sync();

    dcma_flush();


    // printf runtime (cycle counters in subsystem)
    uint64_t sys_time = aux_get_sys_time_lo();
    sys_time += (uint64_t(aux_get_sys_time_hi()) << 32);
    printf("SYS_TIME: %lu\n", sys_time);

    // verify framework: dump result
    dump(result_array, 8);
    
    
    /**
     * Check result correctnes (Risc-V / ISS)
     
    // C-Code reference (MIPS executes this)
    auto reference_result = new int16_t[8];
    for (int i = 0; i < 8; i++) {
        reference_result[i] = 255-test_offsets[i];
    }
//    bool fail = false;
    for (int i = 0; i < 8; i++) {
        if (reference_result[i] != result_array[i]) {
            printf_error("Result is not same as reference! [Index: %i]\n", i);
            printf_error("Reference: %i, result: %i\n", reference_result[i], result_array[i]);
//            fail = true;
        } else {
            printf_success("Reference: %i  = result: %i\n", reference_result[i], result_array[i]);
        }
    }
    */

    printf("\nEnd");
    return 0;
}
