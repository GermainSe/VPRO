#include <vpro.h>
#include "helper.h"
#include "instructions/processing/nop.h"

Nop::Nop(LANE lane,
    uint32_t x_end,
    uint32_t y_end,
    uint32_t z_end,
    Addressing addr_dst,
    Addressing addr_src1,
    Addressing addr_src2,
    bool is_chain,
    bool update_flags,
    bool blocking)
    : Processing(lane,
          x_end,
          y_end,
          z_end,
          addr_dst,
          addr_src1,
          addr_src2,
          is_chain,
          update_flags,
          blocking) {
    assert(!is_chain && "NOP instruction cannot chain output! - no write enable as it is a NOP!");
}
void Nop::vproInstruction() {
    VPRO::DIM3::PROCESSING::nop(getLane(),
        getDst()->getAddress(),
        getSrc1()->getAddress(),
        getSrc2()->getAddress(),
        getXEnd(),
        getYEnd(),
        getZEnd(),
        getIsChain(),
        getUpdateFlags(),
        getBlocking());
}
void Nop::riscvInstruction(int32_t* rf,
    int16_t* lm,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    int64_t& accu,
    ChainMemory& out_chain,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) {

    getSrc1Data(rf, x, y, z, ls, left, right);  // unused data
    getSrc2Data(rf, x, y, z, ls, left, right);  // unused data

    // nothing
}