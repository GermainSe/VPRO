//
// Created by gesper on 05.04.22.
//

#ifndef CONV2D_VPRO_SPECIAL_REGISTER_ENUMS_H
#define CONV2D_VPRO_SPECIAL_REGISTER_ENUMS_H

namespace VPRO {
    // bit(0) = active
    // 00 = imm, 01 = addr, 10 = zero (equal to mac_pre)
    /**
     * MAC allows use of SRC1 for special purpose if data is chained from LS
     * SRC1 can be used to initialize the accumulator (as MACH_PRE/MACL_PRE)
     */
    enum MAC_INIT_SOURCE : uint32_t {
        IMM = 0b001,    /** uses value of src1 as Immediate SRC1_IMM */
        ADDR = 0b011,    /** uses src1 as address SRC1_ADDR to load the initalize value from RF */
        ZERO = 0b101,    /** uses zero for initalization */
    };

    [[nodiscard]] __attribute__((unused)) static const char* print(MAC_INIT_SOURCE s){
        switch (s) {
            case IMM:
                return "IMM";
            case ADDR:
                return "ADDR";
            case ZERO:
                return "ZERO";
            default:
                return "??";
        }
    }

    /**
     * MAC Reset (_pre) will be triggered once or multiple times per vpro command
     * For 3D this can be when z increments (fake 2D mode)
     */
    enum MAC_RESET_MODE : uint32_t {
        NEVER = 0b000,   /** disables reset */
        ONCE = 0b001,    /** reset when z = 0, y = 0 AND x = 0 */
        Z_INCREMENT = 0b011,    /** reset when y = 0 AND x = 0 [default] */
        Y_INCREMENT = 0b101,    /** reset when x = 0 */
        X_INCREMENT = 0b110,    /** reset when x = 0 */
    };

    [[nodiscard]] __attribute__((unused)) static const char* print(MAC_RESET_MODE s){
        switch (s) {
            case NEVER:
                return "NEVER";
            case ONCE:
                return "ONCE";
            case Z_INCREMENT:
                return "Z_INCREMENT";
            case Y_INCREMENT:
                return "Y_INCREMENT";
            case X_INCREMENT:
                return "X_INCREMENT";
            default:
                return "??";
        }
    }
}

#endif //CONV2D_VPRO_SPECIAL_REGISTER_ENUMS_H
