//
// Created by gesper on 12.01.24.
//

#ifndef PATARA_BASED_VERIFICATION_TEST_ENV_H
#define PATARA_BASED_VERIFICATION_TEST_ENV_H

#include "addressing/addressing.h"
#include "vproOperations.h"

namespace TEST_ENVS{
struct test_cfg_s {
    int x_end{0};
    int y_end{0};
    int z_end{0};
    Addressing dst = Addressing(0, 1, 1, 1, Address::Type::DST);
    Addressing src1 = Addressing(0, 1, 1, 1, Address::Type::SRC1);
    Addressing src2 = Addressing(0, 1, 1, 1, Address::Type::SRC2);

    /**
     * Single instruction test
     */
    bool includeSingleInstructions{false};
    bool limitLane{false};
    LANE laneLimit{L0_1};

    /**
     * Chaining test
     */
    bool includeChains{false};
    bool includeSRC1{true};
    bool includeSRC2{true};

    /**
     * Extensions
     */
    bool limitOperations{false};
    Operation::Operation limitedOp{Operation::SHIFT_LR};

    bool introduceChainDelayCommands{false};
    int chainDelays{1};

    bool introduceBlockingChainCommands{false};
    bool introduceBlockingDelayCommands{false};

    /**
     * Register test
     */
    bool variateMACHInitSource{false};
    bool variateMACHResetMode{false};

    bool variateMACHShifts{false};
    bool variateMULHShifts{false};

    bool useMachInitWhileLSchain{false};
};

namespace default_addressings {
static auto x_end = 1;
static auto y_end = 1;
static auto rf_src1 = Addressing(0, 1, x_end + 1, (x_end + 1) * (y_end + 1), Address::Type::SRC1);
static auto rf_src2 = Addressing(0, 1, x_end + 1, (x_end + 1) * (y_end + 1), Address::Type::SRC2);
static auto rf_dst = Addressing(0, 1, x_end + 1, (x_end + 1) * (y_end + 1), Address::Type::DST);
//static auto imm_dst = Addressing(555, Address::Type::DST);
static auto imm_src1 = Addressing(555, Address::Type::SRC1);
static auto imm_src2 = Addressing(555, Address::Type::SRC2);
}  // namespace default_addressings

using namespace default_addressings;

static const test_cfg_s config_list_DEBUG[] = {
    // TODO:
    //  blocking -> failing data test / short independent / interleaved chains
    //  FIFO overflow test
    //  stall tests (from filled fifo)
    //      split single instruction of chain -> stall during exec
    //  complex addr coverage
    //  immediate coverage
  // blocking during chains (delays + end)
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeSingleInstructions = true,
     .includeChains = true,
//     .limitLane = true, .laneLimit = LS,
//     .includeSRC1 = true, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::SHIFT_AR_NEG,
//     .introduceChainDelayCommands = true, .chainDelays = 1,
     },
//    {.x_end = 2, .y_end = 2, .z_end = 2,
//     .dst = Addressing(0, 1, 3, 9, Address::Type::DST),
//     .src1 = Addressing(0, 1, 3, 9, Address::Type::SRC1),
//     .src2 = Addressing(0, 1, 3, 9, Address::Type::SRC2),
//     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
//     .limitOperations = true, .limitedOp = Operation::ADD,
//     .introduceChainDelayCommands = true, .chainDelays = 1,
//     .introduceBlockingChainCommands = false,
//     .introduceBlockingDelayCommands = true,
//     },
};
static const test_cfg_s config_list_COMPLETE[] = {
// mulh shift test
    {.x_end = 1, .y_end = 1, .z_end = 1,
     .dst = Addressing(0, 1, 2, 4, Address::Type::DST),
     .src1 = Addressing(0, 1, 2, 4, Address::Type::SRC1),
     .src2 = Addressing(0, 1, 2, 4, Address::Type::SRC2),
     .includeSingleInstructions = true, .limitLane = true, .laneLimit = L0_1,
     .limitOperations = true, .limitedOp = Operation::MULH,
     .variateMULHShifts = true,
     },
// mach shift test
    {.x_end = 1, .y_end = 1, .z_end = 1,
     .dst = Addressing(0, 1, 2, 4, Address::Type::DST),
     .src1 = Addressing(0, 1, 2, 4, Address::Type::SRC1),
     .src2 = Addressing(0, 1, 2, 4, Address::Type::SRC2),
     .includeSingleInstructions = true, .limitLane = true, .laneLimit = L0_1,
     .limitOperations = true, .limitedOp = Operation::MACH,
     .variateMACHShifts = true,
     },
// mach init combination test
    {.x_end = 1, .y_end = 1, .z_end = 1,
     .dst = Addressing(0, 1, 2, 4, Address::Type::DST),
     .src1 = Addressing(0, 1, 2, 4, Address::Type::SRC1),
     .src2 = Addressing(0, 1, 2, 4, Address::Type::SRC2),
     .includeSingleInstructions = true, .limitLane = true, .laneLimit = L0_1,
     .limitOperations = true, .limitedOp = Operation::MACH,
     .variateMACHInitSource = true,
     .variateMACHResetMode = true,
    },
// mach init combination test with LS as source
    {.x_end = 1, .y_end = 1, .z_end = 1,
     .dst = Addressing(0, 1, 2, 4, Address::Type::DST),
     .src1 = Addressing(0, 1, 2, 4, Address::Type::SRC1),
     .src2 = Addressing(0, 1, 2, 4, Address::Type::SRC2),   // useMachInitWhileLSchain -> overwritten data source to LS (also reuse of addr), interpreted as immediate or reset addr!
     .includeSingleInstructions = true, .limitLane = true, .laneLimit = L0_1,
     .limitOperations = true, .limitedOp = Operation::MACH,
     .variateMACHInitSource = true,
     .variateMACHResetMode = true,
     .useMachInitWhileLSchain = true,
     },
//limited op, single instr. ------- X end tes
    {63,
     0, 0,
     Addressing(0, 1, 63, 63, Address::Type::DST),
     Addressing(0, 1, 63, 63, Address::Type::SRC1),
     Addressing(0, 1, 63, 63, Address::Type::SRC2),
     true, true, L0_1,              // single Instr., limit, op
     false, false, false,           // chains, src1, src2, permute
     true, Operation::ADD,          // limit OP, OP
     },           // limit Lane, Lane
//limited op, single instr. ------- Y end tes
    {0,
     63, 0,
     Addressing(0, 63, 1, 63, Address::Type::DST),
     Addressing(0, 63, 1, 63, Address::Type::SRC1),
     Addressing(0, 63, 1, 63, Address::Type::SRC2),
     true, true, L0,                // single Instr., limit, op
     false, false, false,           // chains, src1, src2, permute
     true, Operation::SUB},         // limit Lane, Lane
//limited op, single instr. ------- Z end tes
    {0,
     0, 1023,
     Addressing(0, 63, 63, 1, Address::Type::DST),
     Addressing(0, 63, 63, 1, Address::Type::SRC1),
     Addressing(0, 63, 63, 1, Address::Type::SRC2),
     true, true, L1,                // single Instr., split
     false, false, false,           // chains, src1, src2, permute
     true, Operation::NOR},         // limit OP, OP
// all op, single instr
    {.x_end = 1, .y_end = 1, .z_end = 1,
     .dst = Addressing(1023-8, 1, 2, 4, Address::Type::DST),
     .src1 = Addressing(1023-8, 1, 2, 4, Address::Type::SRC1),
     .src2 = Addressing(1023-8, 1, 2, 4, Address::Type::SRC2),
     .includeSingleInstructions = true, .limitLane = true, .laneLimit = L0_1,
     },
    {.x_end = 1, .y_end = 1, .z_end = 1,
     .dst = Addressing(1023-8, 1, 2, 4, Address::Type::DST),
     .src1 = Addressing(1023-8, 1, 2, 4, Address::Type::SRC1),
     .src2 = Addressing(2222, Address::Type::SRC2),
     .includeSingleInstructions = true, .limitLane = true, .laneLimit = LS,
     },
//limited op, chains, rf | rf ------- Chain Test
//    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
//     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
//     .limitOperations = true, .limitedOp = Operation::NOR,},
//    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = imm_src1, .src2 = rf_src2,
//     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
//     .limitOperations = true, .limitedOp = Operation::NOR,},
//    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = imm_src2,
//     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
//     .limitOperations = true, .limitedOp = Operation::NOR,},
//    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = imm_src1, .src2 = imm_src2,
//     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
//     .limitOperations = true, .limitedOp = Operation::NOR,},
 // blocking during chains (delays + end)
    {.x_end = 2, .y_end = 2, .z_end = 2,
     .dst = Addressing(0, 1, 3, 9, Address::Type::DST),
     .src1 = Addressing(0, 1, 3, 9, Address::Type::SRC1),
     .src2 = Addressing(0, 1, 3, 9, Address::Type::SRC2),
     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::ADD,
     .introduceChainDelayCommands = true, .chainDelays = 1,
     .introduceBlockingChainCommands = true,
     .introduceBlockingDelayCommands = true,
     },
    {.x_end = 2, .y_end = 2, .z_end = 2,
     .dst = Addressing(0, 1, 3, 9, Address::Type::DST),
     .src1 = Addressing(0, 1, 3, 9, Address::Type::SRC1),
     .src2 = Addressing(0, 1, 3, 9, Address::Type::SRC2),
     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::ADD,
     .introduceChainDelayCommands = true, .chainDelays = 555,
     .introduceBlockingChainCommands = false,
     .introduceBlockingDelayCommands = true,
     },
// Chain with different delays, no blocking (stall triggers)
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::XNOR,
     .introduceChainDelayCommands = true, .chainDelays = 1,
     },
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::SUB,
     .introduceChainDelayCommands = true, .chainDelays = 2,
     },
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::MULL,
     .introduceChainDelayCommands = true, .chainDelays = 3,
     },
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = true, .includeSRC2 = false,
     .limitOperations = true, .limitedOp = Operation::NOR,
     .introduceChainDelayCommands = true, .chainDelays = 4,
     },
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::NAND,
     .introduceChainDelayCommands = true, .chainDelays = 5,
     },
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = true, .includeSRC2 = false,
     .limitOperations = true, .limitedOp = Operation::XOR,
     .introduceChainDelayCommands = true, .chainDelays = 6,
     },
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = false, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::ADD,
     .introduceChainDelayCommands = true, .chainDelays = 7,
     },
// chaining test with both operands utilized for chain input (x2)
    {.x_end = 1, .y_end = 1, .z_end = 1, .dst = rf_dst, .src1 = rf_src1, .src2 = rf_src2,
     .includeChains = true, .includeSRC1 = true, .includeSRC2 = true,
     .limitOperations = true, .limitedOp = Operation::ADD,},    // remove for more excessive
};

enum ENV {
    COMPLETE = 0,  // equal index in config_lists
    DEBUG,
};

__attribute__((unused)) static int getMaxBatches(const ENV& test_env) {
    switch (test_env) {
        case COMPLETE:
            return sizeof(config_list_COMPLETE) / sizeof(test_cfg_s);
        case DEBUG:
            return sizeof(config_list_DEBUG)/ sizeof(test_cfg_s);
        default:
            return -1;
    }
}

__attribute__((unused)) static const test_cfg_s& getBatch(const ENV& test_env, const int& test_iteration) {
    switch (test_env) {
        case COMPLETE:
            return config_list_COMPLETE[test_iteration];
        case DEBUG:
            return config_list_DEBUG[test_iteration];
        default:
            printf_error(
                "Error: getBatch out of test iteration range! (test: %i)\n", test_iteration);
            exit(1);
    }
}
}
#endif  //PATARA_BASED_VERIFICATION_TEST_ENV_H
