#ifndef P_COMMON_H
#define P_COMMON_H

#include <cstdint>
#include <sys/types.h>
#include <vpro/vpro_special_register_enums.h>

// MM Layout: (segments with 256 MB)
// 0x0000_0000 - 0x0FFF_FFFF: Application (Do not use!)
// 0x1000_0000 - 0x1FFF_FFFF: Input Data (Randomized)
// 0x2000_0000 - 0x2FFF_FFFF: Temp Data (During Execution)
// 0x3000_0000 - 0x3FFF_FFFF: Dump Data (After Execution: LMs, RFs)
namespace MMDatadumpLayout
{
    extern const uint32_t INPUT_DATA_RANDOM;
    extern const uint32_t RESULT_DATA_LM;
    extern const uint32_t RESULT_DATA_RF;
#define SAFE_BUT_SLOW 1
}
namespace InitRandomOffsetInLM
{
    extern const uint L0;
    extern const uint L1;
}
namespace DefaultConfiurationModes
{
    extern uint32_t CLUSTER_MASK;
    extern uint32_t UNIT_MASK;
    extern VPRO::MAC_INIT_SOURCE MAC_INIT_SOURCE;
    extern VPRO::MAC_RESET_MODE MAC_RESET_MODE;
    extern unsigned int MAC_H_BIT_SHIFT;
    extern unsigned int MUL_H_BIT_SHIFT;
}

[[maybe_unused]] static const char * __attribute__((unused)) LANE_str[5] = {
    "--  ",
    "L0  ",
    "L1  ",
    "L0_1",
    "LS  "
};
#endif