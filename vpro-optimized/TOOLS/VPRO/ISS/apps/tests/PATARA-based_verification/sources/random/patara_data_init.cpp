//
// Created by gesper on 15.02.24.
//

#include "random/patara_data_init.h"
#include "random/random_lib.h"
#include "assert.h"
#include "constants.h"
#include <vpro.h>
#include <eisv.h>

void gen_random_mm_data(bool init_seed_const) {
    dcma_flush();
    dcma_reset();

    int size_bytes = VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS *
                     (2 * VPRO_CFG::LM_SIZE + 4 * 2 * VPRO_CFG::RF_SIZE);
    int size_64 = size_bytes / 8;
    intptr_t start = MMDatadumpLayout::INPUT_DATA_RANDOM;
    intptr_t end = MMDatadumpLayout::INPUT_DATA_RANDOM + size_bytes;

    if (init_seed_const)
        init_rand_seed(init_seed);

    uint64_t d = next_uint64();
#ifdef SIMULATION
    printf_info("Generate Random Data with %i Byte. Begin: ", size_bytes);
    for (int i = 0; i < 8; ++i) {
        printf_info("%x, ", ((uint8_t *)(&d))[i]);
        if (i == 7)
            printf("...\n");
    }
#endif

    auto* addr = (uint64_t*)start;
    for (int i = 0; i < size_64; ++i) {
#ifdef SIMULATION
//        core_->dbgMemWrite(i*8, (uint8_t *)(&d), 8);
        core_->dbgMemWrite(intptr_t (addr) + i*8+0, &(((uint8_t *)(&d))[0]));
        core_->dbgMemWrite(intptr_t (addr) + i*8+1, &(((uint8_t *)(&d))[1]));
        core_->dbgMemWrite(intptr_t (addr) + i*8+2, &(((uint8_t *)(&d))[2]));
        core_->dbgMemWrite(intptr_t (addr) + i*8+3, &(((uint8_t *)(&d))[3]));
        core_->dbgMemWrite(intptr_t (addr) + i*8+4, &(((uint8_t *)(&d))[4]));
        core_->dbgMemWrite(intptr_t (addr) + i*8+5, &(((uint8_t *)(&d))[5]));
        core_->dbgMemWrite(intptr_t (addr) + i*8+6, &(((uint8_t *)(&d))[6]));
        core_->dbgMemWrite(intptr_t (addr) + i*8+7, &(((uint8_t *)(&d))[7]));
#else
        *addr = d;
#endif
        d = next_uint64();
        addr = (uint64_t*)((uint8_t*)(addr) + 8);
    }
#ifndef SIMULATION
    asm volatile("" ::: "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
    aux_flush_dcache();
    asm volatile("" ::: "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
#endif
    assert((intptr_t)addr == end);
}


void gen_incremented_mm_data() {
    dcma_flush();
    dcma_reset();

    int size_bytes = VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS *
                        (2 * VPRO_CFG::LM_SIZE + 4 * 2 * VPRO_CFG::RF_SIZE);
    // 2 B per LM, 4 B per RF
    intptr_t start = MMDatadumpLayout::INPUT_DATA_RANDOM;
    intptr_t end = MMDatadumpLayout::INPUT_DATA_RANDOM + size_bytes;

#ifdef SIMULATION
    printf_info("Generate Random Data with %i Byte. Data: ", size_bytes);
    for (int i = 0; i < 8; ++i) {
        printf_info("%x, ", i);
        if (i == 7)
            printf("...\n");
    }
#endif

    auto* addr = (uint8_t*)start;
    uint16_t d = 0;
    for (int i = 0; i < size_bytes/2; ++i) {
#ifdef SIMULATION
        core_->dbgMemWrite(intptr_t (addr), (uint8_t*)&d, 2);
#else
        *((uint16_t*)addr) = d;
#endif
        d++;
        addr+=2;
    }
#ifndef SIMULATION
    asm volatile("" ::: "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
    aux_flush_dcache();
    asm volatile("" ::: "memory");  // compiler level memory barrier forcing optimizer to not re-order memory accesses across the barrier.
#endif
    assert((intptr_t)addr == end);
}