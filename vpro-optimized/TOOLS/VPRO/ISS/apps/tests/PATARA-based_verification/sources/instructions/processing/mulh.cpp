#include "instructions/processing/mulh.h"
#include <vpro.h>
#include "constants.h"
#include "helper.h"

Mulh::Mulh(LANE lane,
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
void Mulh::vproInstruction() {
    VPRO::DIM3::PROCESSING::mulh(getLane(),
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
void Mulh::riscvInstruction(int32_t* rf,
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

    // set src; MUL uses 24 x 18-bit
    src1_data = getSrc1Data(rf, x, y, z, ls, left, right);
    src2_data = DataFormat::signed18Bit(getSrc2Data(rf, x, y, z, ls, left, right));

//    printf_warning("RV MULH: 0x%06x x 0x%06x = ", src1_data, src2_data);

    accu = int64_t(src1_data) * int64_t(src2_data);  // mull will store result in accumulation register

//    printf_warning("accu: %" PRIu64 " | 0x%" PRIx64 " ", accu, accu);

    accu = DataFormat::signed48Bit(accu);
    result = DataFormat::signed24Bit(
        accu >> DefaultConfiurationModes::MUL_H_BIT_SHIFT);  // result of mull is accu lower part

//    printf_warning("%i , %i\n ", accu, result);
//    printf_warning("(MUL H SHIFT: %i) RV MULH: RF[%i] = %i\n", DefaultConfiurationModes::MUL_H_BIT_SHIFT, getDst()->calculateAddress(x, y, z), result);

    writeRF(rf, getDst()->calculateAddress(x, y, z), result);
    if (getIsChain()) {
        out_chain.push(result);
    }
}