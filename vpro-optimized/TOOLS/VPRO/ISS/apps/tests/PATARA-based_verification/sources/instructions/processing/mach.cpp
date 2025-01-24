#include "instructions/processing/mach.h"
#include <vpro.h>
#include "constants.h"
#include "helper.h"

Mach::Mach(LANE lane,
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
void Mach::vproInstruction() {
    VPRO::DIM3::PROCESSING::mach(getLane(),
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
void Mach::riscvInstruction(int32_t* rf,
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
    bool reset = false;

//    printf("RV MACH DefaultConfiurationModes::MAC_RESET_MODE: %s\n", print(DefaultConfiurationModes::MAC_RESET_MODE));
    switch (DefaultConfiurationModes::MAC_RESET_MODE) {
        case VPRO::MAC_RESET_MODE::NEVER:
            break;
        case VPRO::MAC_RESET_MODE::ONCE:
            if (z == 0 && y == 0 && x == 0) {
                reset = true;
            }
            break;
        case VPRO::MAC_RESET_MODE::Z_INCREMENT:
            if (y == 0 && x == 0) {
                reset = true;
            }
            break;
        case VPRO::MAC_RESET_MODE::Y_INCREMENT:
            if (x == 0) {
                reset = true;
            }
            break;
        case VPRO::MAC_RESET_MODE::X_INCREMENT:
            reset = true;
            break;
    }
//    printf("RV MACH DefaultConfiurationModes::MAC_INIT_SOURCE: %s\n", print(DefaultConfiurationModes::MAC_INIT_SOURCE));
    if (reset) {
        switch (DefaultConfiurationModes::MAC_INIT_SOURCE) {
            case VPRO::MAC_INIT_SOURCE::IMM:
                accu = DataFormat::signed24_to_48Bit(getSrc2()->getImmediate(true));
                accu = accu << DefaultConfiurationModes::MAC_H_BIT_SHIFT;
                assert((getSrc2()->getIsChain() && getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LS) ||
                       (getSrc2()->getIsChain() && getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LEFT) ||
                       (getSrc2()->getIsChain() && getSrc2()->getChainDir() == Addressing::CHAIN_DIR_RIGHT) ||
                       getSrc2()->getIsImmediate());
                break;
            case VPRO::MAC_INIT_SOURCE::ADDR:
                accu = DataFormat::signed24_to_48Bit(rf[getSrc2()->calculateAddress(x, y, z, true)]);
                accu = accu << DefaultConfiurationModes::MAC_H_BIT_SHIFT;
                assert((getSrc2()->getIsChain() && getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LS) ||
                       (getSrc2()->getIsChain() && getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LEFT) ||
                       (getSrc2()->getIsChain() && getSrc2()->getChainDir() == Addressing::CHAIN_DIR_RIGHT) ||
                       !getSrc2()->getIsImmediate());
                break;
            case VPRO::MAC_INIT_SOURCE::ZERO:
                accu = 0;
                break;
        }
        accu = DataFormat::signed48Bit(accu);
    }

    // set src
    src1_data = getSrc1Data(rf, x, y, z, ls, left, right);
    src2_data = DataFormat::signed18Bit(getSrc2Data(rf, x, y, z, ls, left, right));

//    printf_warning("RV MACH: %i x %i + %i = ", src1_data, src2_data, accu);

    accu = DataFormat::signed48Bit(accu) + int64_t(src1_data) * int64_t(src2_data);

//    printf_warning("\n DefaultConfiurationModes::MAC_H_BIT_SHIFT: %i\n", DefaultConfiurationModes::MAC_H_BIT_SHIFT);

    accu = DataFormat::signed48Bit(accu);
    result = DataFormat::signed24Bit(accu >> DefaultConfiurationModes::MAC_H_BIT_SHIFT);

//    printf_warning("%i , %i\n ", accu, result);
//    printf_warning("RV MACH: RF[%i] = %i\n", getDst()->calculateAddress(x, y, z), result);

    writeRF(rf, getDst()->calculateAddress(x, y, z), result);
    if (getIsChain()) {
        out_chain.push(result);
    }
}