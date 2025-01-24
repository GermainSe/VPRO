#include "constants.h"
#include <vpro/vpro_globals.h>

namespace MMDatadumpLayout
{
    #ifdef SIMULATION
    const uint32_t INPUT_DATA_RANDOM{0x10000000};
    const uint32_t RESULT_DATA_LM{0x30000000};
    const uint32_t RESULT_DATA_RF{0x30000000 + VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * 8192 * 2}; //8192 to 2048
    #else
    #if SAFE_BUT_SLOW == 1
    const uint32_t INPUT_DATA_RANDOM{0x80000000};
    const uint32_t RESULT_DATA_LM{0xA0000000};
    const uint32_t RESULT_DATA_RF{RESULT_DATA_LM + VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * 8192 * 2};
    #else
    const uint32_t INPUT_DATA_RANDOM{0x06000000};   // 0x80000000
    const uint32_t RESULT_DATA_LM{0xA0000000 +  // TODO: compare on cached region
                                  VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * 8192 * 2 +
                                  VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * 2 * 2048 * 2};  // 0xA0000000
    const uint32_t RESULT_DATA_RF{RESULT_DATA_LM + VPRO_CFG::CLUSTERS * VPRO_CFG::UNITS * 8192 * 2};
    #endif
    #endif
}
namespace InitRandomOffsetInLM
{
    const uint L0{2222};
    const uint L1{4444};
}
namespace DefaultConfiurationModes
{
    uint32_t CLUSTER_MASK{0xFFFFFFFF};
    uint32_t UNIT_MASK{0xFFFFFFFF};
    VPRO::MAC_INIT_SOURCE MAC_INIT_SOURCE{VPRO::MAC_INIT_SOURCE::ZERO};
    VPRO::MAC_RESET_MODE MAC_RESET_MODE{VPRO::MAC_RESET_MODE::Z_INCREMENT};
    unsigned int MAC_H_BIT_SHIFT{0};
    unsigned int MUL_H_BIT_SHIFT{0};
}
