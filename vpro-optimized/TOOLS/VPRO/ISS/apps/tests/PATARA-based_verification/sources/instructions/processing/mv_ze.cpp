#include "instructions/processing/mv_ze.h"
#include <vpro.h>
#include "helper.h"

Mv_ze::Mv_ze(LANE lane,
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
          blocking) {}
void Mv_ze::vproInstruction() {
    VPRO::DIM3::PROCESSING::mv_zero(getLane(),
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
void Mv_ze::riscvInstruction(int32_t* rf,
    int16_t* lm,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    int64_t& accu,
    ChainMemory& out_chain,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) {
    int32_t src1_data, src2_data, result;

    src1_data = getSrc1Data(rf, x, y, z, ls, left, right);
    src2_data = getSrc2Data(rf, x, y, z, ls, left, right);
    result = src2_data;

    auto flag = getSrc1()->getZFlag(rf, x, y, z, ls, left, right);
    if (flag) {
        writeRF(rf, getDst()->calculateAddress(x, y, z), result);
//        printf_warning("(Mv_ze) RV: RF[%i] = %i, flag: %i\n", getDst()->calculateAddress(x, y, z), result, flag);
    } else {
//        printf_warning("(Mv_ze) RV: RF[%i] (no write) = %i, flag: %i\n", getDst()->calculateAddress(x, y, z), result, flag);
    }

    if (getIsChain()) {
        out_chain.push(result);
    }
}