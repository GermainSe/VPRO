#include "instructions/loadstore/loadstore.h"
#include "instructions/instruction.h"
#include <vpro.h>

LoadStore::LoadStore(uint32_t x_end, uint32_t y_end, uint32_t z_end, uint32_t offset, Addressing src)
    :Instruction(LS, x_end, y_end, z_end, true), m_offset(offset), m_src(src), m_src2(offset, Address::Type::SRC2)
{
}
// getter
uint32_t LoadStore::getOffset() const { return m_offset; }
Addressing &LoadStore::getSrc() { return m_src; }

bool LoadStore::isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right) {
    return m_src.checkStall(ls, left, right);   // no source can cause stall
}

void LoadStore::updateOperandAddresses() {
    m_src.calculateAddress();
}
