#include "instructions/processing/mach_pre.h"
#include <vpro.h>
#include "constants.h"
#include "helper.h"

Mach_pre::Mach_pre(LANE lane,
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
void Mach_pre::vproInstruction() {
    VPRO::DIM3::PROCESSING::mach_pre(getLane(),
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
void Mach_pre::riscvInstruction(int32_t* rf,
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

    if (z == 0 && y == 0 && x == 0) {
        accu = 0;
    }

    // set src
    src1_data = getSrc1Data(rf, x, y, z, ls, left, right);
    src2_data = DataFormat::signed18Bit(getSrc2Data(rf, x, y, z, ls, left, right));

//    printf_warning("RV Mach_pre: %i x %i + %i = ", src1_data, src2_data, accu);

    accu = DataFormat::signed48Bit(accu) + int64_t(src1_data) * int64_t(src2_data);

//    printf_warning("\n DefaultConfiurationModes::MAC_H_BIT_SHIFT: %i\n", DefaultConfiurationModes::MAC_H_BIT_SHIFT);

    accu = DataFormat::signed48Bit(accu);
    result = DataFormat::signed24Bit(accu >> DefaultConfiurationModes::MAC_H_BIT_SHIFT);

//    printf_warning("%i , %i\n ", accu, result);
//    printf_warning("RV Mach_pre: RF[%i] = %i\n", getDst()->calculateAddress(x, y, z), result);

    writeRF(rf, getDst()->calculateAddress(x, y, z), result);
    if (getIsChain()) {
        out_chain.push(result);
    }
}