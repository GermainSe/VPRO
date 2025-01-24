#include "helper.h"
#include "simulator/helper/typeConversion.h"

void dma_linearize2d(uint32_t cluster, uint32_t ext_src, uint32_t ext_dst, uint32_t loc_temp, uint32_t src_x_stride,
                     uint32_t src_x_size, uint32_t src_y_size) {
    for (int y = 0; y < src_y_size; y++) {
        dma_ext1D_to_loc1D(cluster, ext_src + 2 * y * (src_x_size + src_x_stride), loc_temp, src_x_size);
        dma_loc1D_to_ext1D(cluster, ext_dst + 2 * y * src_x_size, loc_temp, src_x_size);
        dma_wait_to_finish(cluster);
    }
}

void printProgress(double progress, int size) {
    // progressbar
    if (progress < 0) {
        printf(RED);
        progress += 100;
    }
    printf(" [");
    for (float i = 0; i <= 100; i += 100. / size) {
        if (progress > i)
            printf("#");
        else
            printf(" ");
    }
    printf("]");
    printf(RESET_COLOR);
}

//assumes little endian
void printBits(size_t const size, void const *const ptr) {
    unsigned char *b = (unsigned char *) ptr;
    unsigned char byte;
    int i, j;

    for (i = size - 1; i >= 0; i--) {
        for (j = 7; j >= 0; j--) {
            byte = (b[i] >> j) & 1;
            printf("%u", byte);
        }
    }
}

void rf_set(int offset, int value, int size, int lane) {
    if (lane == L0)
        lane = 0;
    else if (lane == L1)
        lane = 1;
    else if (lane == L0_1) {
        rf_set(offset, value, size, L0);
        lane = 1;
    }

    for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
        for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
            for (int addr = offset; addr < size + offset; ++addr) { // VPRO_CFG::RF_SIZE
                core_->getClusters()[cluster]->getUnits()[unit]->getLanes()[lane]->regFile.set_rf_data(addr, value);
            }
        }
    }
//
//    while (size >= 256){
//        size -= 256;
//        __builtin_vpro_instruction_word(lane, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                        DST_ADDR(offset+size, 1, 16),
//                                        SRC1_IMM(0),
//                                        SRC2_IMM(value),
//                                        15, 15);
//    }
//    if (size > 0){
//        size -= 1;
//        // max 255
//        auto x = int(size % 16); // 15
//        __builtin_vpro_instruction_word(lane, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                        DST_ADDR(offset, 1, 16),
//                                        SRC1_IMM(0),
//                                        SRC2_IMM(value),
//                                        x, 0);
//        size -= x;
//        if (size > 0){
//            int y = size / 16;
//            __builtin_vpro_instruction_word(lane, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                            DST_ADDR(offset+x, 1, 16),
//                                            SRC1_IMM(0),
//                                            SRC2_IMM(value),
//                                            15, y);
//        }
//    }
}

void rf_set_incr(int offset, int value, int size, int lane) {
    if (lane == L0)
        lane = 0;
    else if (lane == L1)
        lane = 1;
    else if (lane == L0_1) {
        rf_set_incr(offset, value, size, L0);
        lane = 1;
    }

    for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
        for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
            int cvalue = value;
            for (int addr = offset; addr < size + offset; ++addr) { // VPRO_CFG::RF_SIZE
                core_->getClusters()[cluster]->getUnits()[unit]->getLanes()[lane]->regFile.set_rf_data(addr, cvalue);
                cvalue++;
            }
        }
    }
}

void rf_set(int offset, const uint32_t *data, int size, int lane) {
//    uint addr = 0;
//    uint value = 0;
//    for (uint i = 0; i < size; i++){
//        value = data[i];
//        __builtin_vpro_instruction_word(lane, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                        DST_ADDR(offset+addr, 1, 1),
//                                        SRC1_IMM(0),
//                                        SRC2_IMM(value),
//                                        0, 0);
//        addr++;
//    }
    if (lane == L0)
        lane = 0;
    else if (lane == L1)
        lane = 1;
    else if (lane == L0_1) {
        rf_set(offset, data, size, L0);
        lane = 1;
    }

    for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
        for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
            for (int addr = offset; addr < size + offset; ++addr) { // VPRO_CFG::RF_SIZE
                uint value = data[addr - offset];
                core_->getClusters()[cluster]->getUnits()[unit]->getLanes()[lane]->regFile.set_rf_data(addr, value);
            }
        }
    }
}

void reset_all_RF() {
    for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; cluster++) {
        for (int unit = 0; unit < VPRO_CFG::UNITS; unit++) {
            for (int lane = 0; lane < VPRO_CFG::LANES; lane++) {
                for (int addr = 0; addr < VPRO_CFG::RF_SIZE; addr++) { // VPRO_CFG::RF_SIZE
                    core_->getClusters()[cluster]->getUnits()[unit]->getLanes()[lane]->regFile.set_rf_data(addr, 0);
                }
            }
        }
    }
}

void resetRF(int length) {
    for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; ++cluster) {
        for (int unit = 0; unit < VPRO_CFG::UNITS; ++unit) {
            for (int lane = 0; lane < VPRO_CFG::LANES; ++lane) {
                for (int addr = 0; addr < length; ++addr) { // VPRO_CFG::RF_SIZE
                    core_->getClusters()[cluster]->getUnits()[unit]->getLanes()[lane]->regFile.set_rf_data(addr, 0);
                }
            }
        }
    }
    printf("RF Reset \n");
}

void reset_all_LM() {
    for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; cluster++) {
        for (int unit = 0; unit < VPRO_CFG::UNITS; unit++) {
            uint8_t *lm = core_->getClusters()[cluster]->getUnits()[unit]->getlocalmemory();
            for (int i = 0; i < VPRO_CFG::LM_SIZE; i++) {
                lm[i] = 0;
            }
        }
    }
}

void resetLM(int length, int cluster, int unit) {
    VectorUnit *u = core_->getClusters()[cluster]->getUnits()[unit];
    uint8_t *lm = u->getlocalmemory();
    for (int i = 0; i < VPRO_CFG::LM_SIZE; i++) {
        lm[i] = 0;
    }
    for (int i = 0; i < length; i++)
        u->writeLocalMemoryData(200 + i, 64);
    printf("LM Reset \n");
}

void setLM(int length, int cluster, int unit, int data, int address) {
    VectorUnit *u = core_->getClusters()[cluster]->getUnits()[unit];
    for (int i = 0; i < length; i++)
        u->writeLocalMemoryData(address + i, data);
    printf("LM Reset \n");
}

void setLM_incr(int length, int cluster, int unit, int data, int address) {
    VectorUnit *u = core_->getClusters()[cluster]->getUnits()[unit];
    for (int i = 0; i < length; i++)
        u->writeLocalMemoryData(address + i, data + i);
    printf("LM Reset \n");
}

void set_all_LM_incr(int length, int data, int address) {
    for (int cluster = 0; cluster < VPRO_CFG::CLUSTERS; cluster++) {
        for (int unit = 0; unit < VPRO_CFG::UNITS; unit++) {
            setLM_incr(length, cluster, unit, data, address);
        }
    }
}

void resetMM(int length) {
    uint8_t data = 0;
    for (uint i = 0; i < 2*length; i++) {
        core_->dbgMemWrite(i, &data);
    }
    printf("MM Reset \n");
}


void setMM(int address, int data, int length) {
    uint8_t data_low, data_high;
    for (uint i = 0; i < 2*length; i = i + 2) {
        data_low = uint8_t(data % 256);
        data_high = uint8_t(data >> 8);
        core_->dbgMemWrite(address*2+i, &data_low);
        core_->dbgMemWrite(address*2+i+1, &data_high);
    }
    printf("MM set \n");
}


void verifyRF(int value, int lane, int offset, int length, int cluster, int unit) {
    VectorUnit *u = core_->getClusters()[cluster]->getUnits()[unit];
    int32_t *data_vpro = new int32_t[length]();
    int id = (lane == L0) ? 0 : 1;
    for (auto l: u->getLanes()) {
        if (l->vector_lane_id == id) {
            for (int i = 0; i < length; i++) {
                auto val = l->regFile.get_rf_data(i + offset);
                data_vpro[i] = int32_t(*__24to32signed(val));
            }
            break;
        }
    }
    bool correct = true;
    for (int i = 0; i < length; i++) {
        correct &= (data_vpro[i] == value);
    }
    if (!correct) {
        for (int i = 0; i < length; i++) {
            printf("Compare: %i : %i ?= %i\n", i, data_vpro[i], value);
        }
        printf("\e[91mERROR on verify: %s != %i!\e[0m \n", "RF", value);
        sim_wait_step();
    } else {
        printf("\e[32mSuccess on verify: %s == %i!\e[0m [RF from %4i - %4i]\n", "RF", value, offset,
               offset + length - 1);
    }
    delete[]data_vpro;
}

void verifyLM(int value, int offset, int length, int cluster, int unit) {
    VectorUnit *u = core_->getClusters()[cluster]->getUnits()[unit];
    int32_t *data_vpro = new int32_t[length]();
    for (int i = 0; i < length; i++) {
        data_vpro[i] = u->getLocalMemoryData(offset + i);
    }
    bool correct = true;
    for (int i = 0; i < length; i++) {
        correct &= (data_vpro[i] == value);
    }
    if (!correct) {
        for (int i = 0; i < length; i++) {
            printf("Compare: %i : %i ?= %i\n", i, data_vpro[i], value);
        }
        printf("\e[91mERROR on verify: %s != %i!\e[0m \n", "LM", value);
        sim_wait_step();
    } else {
        printf("\e[32mSuccess on verify: %s == %i!\e[0m \n", "LM", value);
    }
    delete[]data_vpro;
}
