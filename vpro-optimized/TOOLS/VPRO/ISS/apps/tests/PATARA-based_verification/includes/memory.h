#ifndef P_MEMORY_H
#define P_MEMORY_H

#include <cstdint>
#include <vpro.h>

namespace LocalMemory
{
    void initialize_vpro();
    int16_t*** initialize_riscv();
    void store_to_main_memory();
    bool compare_lm(uint8_t* mm, int16_t*** lm, bool silent = false);
}

namespace RegisterFile
{
    void initialize_vpro();
    int32_t**** initialize_riscv_32();
    void store_to_main_memory();
    bool compare_rf(uint8_t *mm, int32_t ****rf, bool silent = false);
}

namespace MainMemory
{
    void unsafe_copy_to_cached_region(uint32_t dst, uint32_t src, uint32_t size);
    uint8_t* initialize(uint8_t *mm);
    void reference_calculation_init(uint8_t *mm, int16_t ***lm, int32_t ****rf);
}


#endif
