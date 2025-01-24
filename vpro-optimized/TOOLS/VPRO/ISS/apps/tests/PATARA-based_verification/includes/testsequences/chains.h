//
// Created by gesper on 14.12.23.
//

#ifndef PATARA_BASED_VERIFICATION_CHAINS_H
#define PATARA_BASED_VERIFICATION_CHAINS_H

namespace InstructionChains {
enum InstructionChains {
    NONE,  // 0

    LS_L0,  // 2 chains following
    LS_L1,
    L0_LS,
    L1_LS,
    L0_L1,
    L1_L0,
    LS_L01,  // 3 chains following
    LS_L0_L1,
    LS_L1_L0,
    L0_L1_LS,
    L1_L0_LS,
    L0_LS1,
    L1_LS0,
    LS0_L1,
    LS1_L0,

    END
};

__attribute__((unused)) static const char * print(InstructionChains chain){
    switch (chain) {
        case NONE:
            return "NONE";
        case LS0_L1:
            return "LS|0->L1";
        case LS_L0:
            return "LS->L0";
        case LS_L1:
            return "LS->L1";
        case L0_LS:
            return "L0->LS";
        case L1_LS:
            return "L1->LS";
        case L0_L1:
            return "L0->L1";
        case L1_L0:
            return "L1->L0";
        case LS_L01:
            return "LS->L0|1";
        case LS_L0_L1:
            return "LS->L0->L1";
        case LS_L1_L0:
            return "LS->L1->L0";
        case L0_L1_LS:
            return "L0->L1->LS";
        case L1_L0_LS:
            return "L1->L0->LS";
        case L0_LS1:
            return "L0->LS|1";
        case L1_LS0:
            return "L1->LS|0";
        case LS1_L0:
            return "LS|1->L0";
        case END:
            return "END";
        default:
            return "???";
    }
}

}  // namespace InstructionChains

#endif  //PATARA_BASED_VERIFICATION_CHAINS_H
