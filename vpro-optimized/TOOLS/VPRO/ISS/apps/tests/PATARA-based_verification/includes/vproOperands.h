//
// Created by gesper on 12.12.23.
//

#ifndef PATARA_BASED_VERIFICATION_VPRO_OPERANDS_H
#define PATARA_BASED_VERIFICATION_VPRO_OPERANDS_H

namespace Operand {
enum Operand {
    SRC1,
    SRC2,
    DST
};

[[nodiscard]] __attribute__((unused)) static const char * print(Operand operand){
    switch (operand) {
        case SRC1:
            return "SRC1";
        case SRC2:
            return "SRC2";
        case DST:
            return "DST";
        default:
            return "???";
    }
}

}  // namespace Operand

#endif  //PATARA_BASED_VERIFICATION_VPRO_OPERANDS_H
