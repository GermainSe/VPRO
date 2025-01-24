#include "command_helpers.h"
#include "vpro_globals.h"

namespace VPRO_COMMANDS {
    BIF::COMMAND_SEGMENT wait() {
      BIF::COMMAND_SEGMENT seg;
      seg.type.type = VPRO_WAIT;
      return seg;
    }

    BIF::COMMAND_SEGMENT sync() {
      BIF::COMMAND_SEGMENT seg;
      seg.type.type = BOTH_SYNC;
      return seg;
    }
}

void next_hardware_element(unsigned int &cluster, unsigned int &unit, unsigned int &lane) {
    ++lane;
    if (lane == VPRO_CFG::LANES) {
        ++unit;
        lane = 0;
        if (unit == VPRO_CFG::UNITS) {
            unit = 0;
            ++cluster;
        }
    }
}
