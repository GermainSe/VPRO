#include "instructions/processing/shift_ar.h"
#include <vpro.h>
#include "helper.h"

Shift_ar::Shift_ar(LANE lane,
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
void Shift_ar::vproInstruction() {
    VPRO::DIM3::PROCESSING::shift_ar(getLane(),
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
void Shift_ar::riscvInstruction(int32_t* rf,
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
    src2_data = DataFormat::unsigned5Bit(getSrc2Data(rf, x, y, z, ls, left, right));

    result = DataFormat::signed24Bit(src1_data >> uint32_t(src2_data));

//    printf("Shift_ar: src1: %i >> src2: %i = %i\n", src1_data, src2_data, result);

    if (src2_data > 24){
        // shift of more than width of data path should not occur!
        //  the hardware does not catch this "software error"
        //  -> imitate hardware by performing the shift and set msb bits to zero
        result &= (0xffffffu) >> (src2_data - 24);
    }

    writeRF(rf, getDst()->calculateAddress(x, y, z), result);
    if (getIsChain()) {
        out_chain.push(result);
    }
}