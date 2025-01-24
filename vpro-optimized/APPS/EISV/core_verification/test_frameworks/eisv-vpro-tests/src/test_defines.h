#ifndef TEST_DEFINES_H
#define TEST_DEFINES_H

#include <stdint.h>
#include <vpro.h>
#include <eisv.h>
#include <vpro/dma_cmd_struct.h>

#ifndef NUM_TEST_ENTRIES
#define NUM_TEST_ENTRIES 64
extern volatile int16_t result_array[1024];
#else
// added for DMA_OVERLOAD - overwritten NUM_TEST_ENTRIES
extern volatile int16_t result_array[NUM_TEST_ENTRIES*2*8*4];
#endif

/**
 * Test Data Variables
 */
extern volatile int16_t test_array_1[NUM_TEST_ENTRIES];
extern volatile int16_t test_array_2[NUM_TEST_ENTRIES];
extern volatile int16_t result_array_zeros[1024];
extern volatile int16_t result_array_dead[1024];
extern volatile int16_t result_array_large[1024*1024];

bool pad_flags[4] = {false, false, false, false};  // for dma padding

#define SIGNATURE_ADDRESS       (*((volatile uint32_t*) (0xffffffc4)))   // r/w
//#define SIGNATURE_ADDRESS       (*((volatile uint32_t*) (0xffffffb0)))   // r/w


#ifdef SIMULATION 
    //sim_init(main, argc, argv, HW);
    #define INIT() sim_init(main, argc, argv)
#else
    #define INIT()
#endif


#endif
