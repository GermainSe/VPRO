//
// Created by gesper on 12.12.23.
//

#ifndef PATARA_BASED_VERIFICATION_VPRO_OPERATIONS_H
#define PATARA_BASED_VERIFICATION_VPRO_OPERATIONS_H

namespace Operation {
enum Operation {
    NONE,  // Helper: first

    Processing,  // Helper: to identify begin of Processing operations
    NOP,
    ADD,
    SUB,
    MULL,
    MULH,
    MULL_NEG,
    MULH_NEG,
    MULL_POS,
    MULH_POS,
    MACL,
    MACL_PRE,
    MACH,
    MACH_PRE,
    XOR,
    XNOR,
    AND,
    NAND,
    OR,
    NOR,
    SHIFT_LR,
    SHIFT_AR,
    SHIFT_AR_NEG,
    SHIFT_AR_POS,
    MV_PL,
    MV_MI,
    MV_NZ,
    MV_ZE,
    ABS,
    MIN,
    MAX,

    LoadStore,  // Helper: to identify begin of Load Store operations
    LOAD,
    LOADS,
    LOADB,
    LOADBS,
    STORE,

    END,  // Helper: last one
};

[[nodiscard]] __attribute__((unused)) static bool is_loadstore(Operation op) {
    return (op < Operation::END && op > Operation::LoadStore);
}

[[nodiscard]] __attribute__((unused)) static bool is_load(Operation op) {
    return (op < Operation::STORE && op > Operation::LoadStore);
}

[[nodiscard]] __attribute__((unused)) static bool is_store(Operation op) {
    return (op == Operation::STORE);
}

[[nodiscard]] __attribute__((unused)) static bool is_processing(Operation op) {
    return (op > Operation::Processing && op < Operation::LoadStore);
}

[[nodiscard]] __attribute__((unused)) static const char* print(Operation op) {
    switch (op) {
        case NONE:
            return "NONE";
        case Processing:
            return "Processing";
        case NOP:
            return "NOP";
        case ADD:
            return "ADD";
        case SUB:
            return "SUB";
        case MULL:
            return "MULL";
        case MULH:
            return "MULH";
        case MULL_POS:
            return "MULL_POS";
        case MULH_POS:
            return "MULH_POS";
        case MULL_NEG:
            return "MULL_NEG";
        case MULH_NEG:
            return "MULH_NEG";
        case MACL:
            return "MACL";
        case MACL_PRE:
            return "MACL_PRE";
        case MACH:
            return "MACH";
        case MACH_PRE:
            return "MACH_PRE";
        case XOR:
            return "XOR";
        case XNOR:
            return "XNOR";
        case AND:
            return "AND";
        case NAND:
            return "NAND";
        case OR:
            return "OR";
        case NOR:
            return "NOR";
        case SHIFT_LR:
            return "SHIFT_LR";
        case SHIFT_AR:
            return "SHIFT_AR";
        case SHIFT_AR_POS:
            return "SHIFT_AR_POS";
        case SHIFT_AR_NEG:
            return "SHIFT_AR_NEG";
        case ABS:
            return "ABS";
        case MIN:
            return "MIN";
        case MV_MI:
            return "MV_MI";
        case MV_NZ:
            return "MV_NZ";
        case MV_PL:
            return "MV_PL";
        case MV_ZE:
            return "MV_ZE";
        case MAX:
            return "MAX";
        case LoadStore:
            return "LoadStore";
        case LOAD:
            return "LOAD";
        case LOADS:
            return "LOADS";
        case LOADB:
            return "LOADB";
        case LOADBS:
            return "LOADBS";
        case STORE:
            return "STORE";
        case END:
            return "END";
        default:
            return "???";
    }
}
}  // namespace Operation

#endif  //PATARA_BASED_VERIFICATION_VPRO_OPERATIONS_H
