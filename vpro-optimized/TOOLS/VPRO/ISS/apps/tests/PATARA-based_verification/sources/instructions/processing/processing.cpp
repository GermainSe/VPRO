#include "instructions/processing/processing.h"
#include <vpro.h>
#include "helper.h"

Processing::Processing(LANE lane,
    uint32_t x_end,
    uint32_t y_end,
    uint32_t z_end,
    Addressing addr_dst,
    Addressing addr_src1,
    Addressing addr_src2,
    bool is_chain,
    bool update_flags,
    bool blocking)
    : Instruction(lane, x_end, y_end, z_end, update_flags, is_chain, blocking),
      m_addr_dst(addr_dst),
      m_addr_src1(addr_src1),
      m_addr_src2(addr_src2) {}

// other instructions

bool Processing::isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right) {
    return m_addr_src1.checkStall(ls, left, right) || m_addr_src2.checkStall(ls, left, right);
}

bool Processing::isInputChain() {
    return m_addr_src1.getIsChain() || m_addr_src2.getIsChain();
}

int32_t Processing::getSrc1Data(const int32_t* rf,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) {
    return DataFormat::signed24Bit(m_addr_src1.getData(rf, x, y, z, ls, left, right));
}

int32_t Processing::getSrc2Data(const int32_t* rf,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) {
    return DataFormat::signed24Bit(m_addr_src2.getData(rf, x, y, z, ls, left, right));
}

void Processing::updateOperandAddresses() {
    if (!getSrc1()->getIsChain()){
        getSrc1()->calculateAddress();
    }
    if (!getSrc2()->getIsChain()){
        getSrc2()->calculateAddress();
    }
    if (!getDst()->getIsChain()){
        getDst()->calculateAddress();
    }
}
