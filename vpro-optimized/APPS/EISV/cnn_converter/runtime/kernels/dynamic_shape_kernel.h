#ifndef DYNAMIC_SHAPE_KERNEL_H
#define DYNAMIC_SHAPE_KERNEL_H

#include "bif.h"
#include <cstring>
#include "riscv/eisV_hardware_info.hpp"

#ifdef SIMULATION
#include "iss_aux.h"
#endif

namespace dynamic_shape {

uint16_t x{};
uint16_t y{};
uint16_t z{};

inline void set(const BIF::LAYER &layer) {

    uint16_t value;
#ifdef SIMULATION
    core_->dbgMemRead(intptr_t(layer.output.mm_base),   ((uint8_t *) &value));
    core_->dbgMemRead(intptr_t(layer.output.mm_base)+1, ((uint8_t *) &value)+1);
#else
    memcpy((void *) &value, (void *) layer.output.mm_base, sizeof(uint16_t));
#endif
    switch (layer.axis) {
    case 0:
        x = value;
        break;
    case 1:
        y = value;
        break;
    case 2:
        z = value;
        break;  
    default:
        break;
    }
    printf_info("Dynamic shape: Setting axis %d to size %d.\n", layer.axis, value);
}

} // namespace dynamic_shape

#endif // DYNAMIC_SHAPE_KERNEL_H