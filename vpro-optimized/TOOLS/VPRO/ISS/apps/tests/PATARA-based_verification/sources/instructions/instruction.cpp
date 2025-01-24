#include "instructions/instruction.h"
#include <vpro.h>
#include "constants.h"

Instruction::Instruction(LANE lane, uint32_t x_end, uint32_t y_end, uint32_t z_end,
    bool update_flags, bool is_chain, bool blocking)
    : m_lane(lane), m_x_end(x_end), m_y_end(y_end), m_z_end(z_end),
      m_is_chain(is_chain), m_update_flags(update_flags), m_blocking(blocking) {

}

const char* Instruction::c_str() const {
    static char buf[4096];

    char operands_str[512];
    getOperands(operands_str);

    sprintf(buf,
        "Instruction for \033[47;30m %s \033[0m[\033[104;30m %-8s \033[0m]:\t%s [x: %u, y: %u, z: %u]%s%s%s",
        LANE_str[m_lane],
        getInstructionName(),
        operands_str,
        m_x_end,
        m_y_end,
        m_z_end,
        (m_is_chain) ? " Chaining" : "",
        (m_blocking) ? " Blocking" : "",
        (m_update_flags) ? " FlagUpdate" : "");
    return buf;
}
