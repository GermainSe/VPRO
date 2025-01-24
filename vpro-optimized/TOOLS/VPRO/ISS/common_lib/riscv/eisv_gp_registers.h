//
// Created by gesper on 09.02.22.
//

#ifndef CNN_YOLO_LITE_HW_EISV_GP_REGISTERS_H
#define CNN_YOLO_LITE_HW_EISV_GP_REGISTERS_H

#include "eisv_defs.h"
#include <stdint.h>

class GPR{
public:
    /**
     * Write to GP_REGISTERS + register_nr (Byte address)
     * @param register_nr The used sub-address (byte address) of the GPR
     * @param data 32-bit of Data to write to specified register
     * @return success
     */
    static bool write32(uint32_t register_nr, uint32_t data);
    static bool write16(uint32_t register_nr, uint16_t data);
    static bool write8(uint32_t register_nr, uint8_t data);

    /**
     * Read from GP_Register + register_nr (Byte address)
     * @param register_nr The used sub-address (byte address) of the GPR
     * @return 32-bit of Data from register
     */
    static uint32_t read32(uint32_t  register_nr);
};

#endif //CNN_YOLO_LITE_HW_EISV_GP_REGISTERS_H
