#include "instructions/loadstore/store.h"
#include <vpro.h>
#include "helper.h"

Store::Store(uint32_t x_end,
    uint32_t y_end,
    uint32_t z_end,
    uint32_t offset,
    uint32_t dst_offset,
    uint32_t dst_alpha,
    uint32_t dst_beta,
    uint32_t dst_gamma,
    LANE src_lane)
    : LoadStore(x_end,
          y_end,
          z_end,
          offset,
          Addressing(dst_offset, dst_alpha, dst_beta, dst_gamma,Address::Type::SRC1)), //TODO: Implement for more then 2 lanes
      m_src_lane(src_lane),
      m_immediate(Addressing(offset, Address::Type::SRC2)) {
    assert(src_lane == L0 || src_lane == L1);
}

void Store::vproInstruction() {
    VPRO::DIM3::LOADSTORE::store(getOffset(),
        getSrc().getOffset(),
        getSrc().getAlpha(),
        getSrc().getBeta(),
        getSrc().getGamma(),
        getXEnd(),
        getYEnd(),
        getZEnd(),
        m_src_lane);
}

bool Store::isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right) {
    if (m_src_lane == L0) {
        return left.isEmpty();
    } else if (m_src_lane == L1) {
        return right.isEmpty();
    }
    printf_error("[ERROR | LS Store isInputChainStall] store from unspecified LANE (m_src_lane needs to be L0 or L1)!\n");
    exit(1);
}

bool Store::isInputChain(){
    return true;
}

void Store::riscvInstruction(int32_t* rf,
    int16_t* lm,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    int64_t& accu,
    ChainMemory& out_chain,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) {

    int32_t data_to_store;

    if (m_src_lane == L0) {
        data_to_store = left.get();
    } else if (m_src_lane == L1) {
        data_to_store = right.get();
    } else {
        printf_error("[ERROR | LS Store risc instruction] store from unspecified LANE (m_src_lane needs to be L0 or L1)!\n");
        exit(1);
    }

    lm[getSrc().calculateAddress(x, y, z) + m_immediate.getImmediate()] = int16_t(data_to_store);   // cut
}
