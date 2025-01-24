#include "instructions/loadstore/loadb.h"
#include <vpro.h>
#include "helper.h"

Loadb::Loadb(uint32_t x_end,
    uint32_t y_end,
    uint32_t z_end,
    uint32_t offset,
    uint32_t src_offset,
    uint32_t src_alpha,
    uint32_t src_beta,
    uint32_t src_gamma)
    : LoadStore(x_end,
          y_end,
          z_end,
          offset,
          Addressing(src_offset, src_alpha, src_beta, src_gamma, Address::Type::SRC1)),
      m_immediate(Addressing(offset, Address::Type::SRC2)) {
    m_is_chain = true;
}

void Loadb::vproInstruction() {
    VPRO::DIM3::LOADSTORE::loadb(getOffset(),
        getSrc().getOffset(),
        getSrc().getAlpha(),
        getSrc().getBeta(),
        getSrc().getGamma(),
        getXEnd(),
        getYEnd(),
        getZEnd(),
        getUpdateFlags());
}
void Loadb::riscvInstruction(int32_t* rf,
    int16_t* lm,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    int64_t& accu,
    ChainMemory& out_chain,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) {

    int32_t loaded_data = lm[getSrc().calculateAddress(x, y, z) + m_immediate.getImmediate()];

    // load unsigned!
    loaded_data = DataFormat::unsigned8Bit(loaded_data);  // load of 16-bit!

    // store dst -> not happening here, only chained data
    out_chain.push(loaded_data);
}
