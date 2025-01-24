//
// Created by renke on 08.05.20.
//

#include "tests/features/chaining_ls_tester.h"

// Intrinsic auxiliary library
#include "core_wrapper.h"
#include "helper.h"

void chaining_ls_tester::test_U0LS_to_U1LS_to_U1L0(){
    printf("test_U0LS_to_U1LS_to_U1L0\n");
    reset_all_RF();
    reset_all_LM();

    uint test_len = 16;
    for(uint pos = 0; pos < test_len; pos++) core_->getClusters()[0]->getUnits()[0]->writeLocalMemoryData(pos, pos);

    vpro_set_unit_mask(0b001);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0, 0), SRC1_ADDR(0, 1, 0), SRC2_IMM_2D(0), test_len - 1, 0);
    vpro_set_unit_mask(0b010);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0, 0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), test_len - 1, 0);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 0), SRC1_LS_2D, SRC2_ADDR(0, 1, 0), test_len - 1, 0);
    vpro_wait_busy(0xffff, 0xffff);
    vpro_set_unit_mask(0xffff);

    uint8_t *lm = core_->getClusters()[0]->getUnits()[0]->getlocalmemory();
    uint8_t *rf = core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->getregister();
    bool error = false;
    for(uint pos = 0; pos < test_len; pos++){
        int element_lm = *(lm + pos*2);
        int element_rf = (*(rf + pos * 3u + 2u) << 16u) | (*(rf + pos * 3u + 1u) << 8u) | (*(rf + pos * 3u + 0u) << 0u);
        printf("pos:%2i lm:%2i rf:%2i\n", pos, element_lm, element_rf);
        if(element_lm != element_rf) error = true;
    }
    printf(error ? "FAIL\n" : "PASS\n");
}

void chaining_ls_tester::test_U0LS_to_U1LS_to_U1L0_and_U1L1(){
    printf("test_U0LS_to_U1LS_to_U1L0_and_U1L1\n");
    reset_all_RF();
    reset_all_LM();

    int test_len = 16;
    for(int pos = 0; pos < test_len; pos++){
        core_->getClusters()[0]->getUnits()[0]->writeLocalMemoryData(pos, pos);
    }

    vpro_set_unit_mask(0b1);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0, 0), SRC1_ADDR(0,1,0), SRC2_IMM_2D(0), test_len, 0);

    vpro_set_unit_mask(0b10);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), test_len, 0);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 0), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), test_len, 0);
    __vpro(L1, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 0), SRC1_LS_2D, SRC2_IMM_2D(0), test_len, 0);
    vpro_wait_busy(0xffff,0xffff);
    vpro_set_unit_mask(0xffff);

    uint8_t *lm = core_->getClusters()[0]->getUnits()[0]->getlocalmemory();
    uint8_t *rf0 = core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->getregister();
    uint8_t *rf1 = core_->getClusters()[0]->getUnits()[1]->getLanes()[1]->getregister();
    bool error = false;
    for(int pos = 0; pos < test_len; pos++){
        int element_lm = *(lm + pos*2);
        int element_rf0 = (*(rf0 + pos * 3u + 2u) << 16u) | (*(rf0 + pos * 3u + 1u) << 8u) | (*(rf0 + pos * 3u + 0u) << 0u);
        int element_rf1 = (*(rf1 + pos * 3u + 2u) << 16u) | (*(rf1 + pos * 3u + 1u) << 8u) | (*(rf1 + pos * 3u + 0u) << 0u);
        printf("pos:%2i lm:%2i rf0:%2i rf1:%2i\n", pos, element_lm, element_rf0, element_rf1);
        if(element_lm != element_rf0) error = true;
        if(element_lm != element_rf1) error = true;
    }
    printf(error ? "FAIL\n" : "PASS\n");
}

void chaining_ls_tester::test_U0L1_to_U0L0_to_U0LS_to_U1LS_to_U1L0_and_U1L1(){
    printf("test_U0L1_to_U0L0_to_U0LS_to_U1LS_to_U1L0_and_U1L1\n");
    reset_all_RF();
    reset_all_LM();

    uint test_len = 16;
    for(uint pos = 0; pos < test_len; pos++) core_->getClusters()[0]->getUnits()[0]->getLanes()[1]->regFile.set_rf_data(pos, pos);

    vpro_set_unit_mask(0b1);
    __vpro(L1, NBL, CH, FUNC_SUB, NFU, DST_ADDR(0, 1, 0), SRC1_IMM_2D(0), SRC2_ADDR(0, 1, 0), test_len, 0);
    __vpro(L0, NBL, CH, FUNC_ADD, NFU, DST_ADDR(0, 1, 0), SRC1_IMM_2D(0), SRC2_CHAINING_LEFT_2D, test_len, 0);
    __vpro(LS, NBL, CH, FUNC_STORE, NFU, DST_ADDR(0, 1, 0), SRC1_CHAINING_2D(0), SRC2_IMM_2D(0), test_len, 0);
    vpro_set_unit_mask(0b10);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), test_len, 0);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), test_len, 0);
    __vpro(L1, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0), test_len, 0);
    vpro_wait_busy(0xffff, 0xffff);
    vpro_set_unit_mask(0xffff);

    uint8_t *lm0 = core_->getClusters()[0]->getUnits()[0]->getlocalmemory();
    uint8_t *rf00 = core_->getClusters()[0]->getUnits()[0]->getLanes()[0]->getregister();
    uint8_t *rf01 = core_->getClusters()[0]->getUnits()[0]->getLanes()[1]->getregister();
    uint8_t *rf10 = core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->getregister();
    uint8_t *rf11 = core_->getClusters()[0]->getUnits()[1]->getLanes()[1]->getregister();

    bool error = false;
    for(uint pos = 0; pos < test_len; pos++){
        int element_lm0 = *(lm0 + pos*2);
        int element_rf00 = (*(rf00 + pos * 3u + 2u) << 16u) | (*(rf00 + pos * 3u + 1u) << 8u) | (*(rf00 + pos * 3u + 0u) << 0u);
        int element_rf01 = (*(rf01 + pos * 3u + 2u) << 16u) | (*(rf01 + pos * 3u + 1u) << 8u) | (*(rf01 + pos * 3u + 0u) << 0u);
        int element_rf10 = (*(rf10 + pos * 3u + 2u) << 16u) | (*(rf10 + pos * 3u + 1u) << 8u) | (*(rf10 + pos * 3u + 0u) << 0u);
        int element_rf11 = (*(rf11 + pos * 3u + 2u) << 16u) | (*(rf11 + pos * 3u + 1u) << 8u) | (*(rf11 + pos * 3u + 0u) << 0u);
        printf("pos:%2i lm0:%2i rf00:%2i rf01:%2i rf10:%2i rf11:%2i\n", pos, element_lm0, element_rf00, element_rf01, element_rf10, element_rf11);
        if(element_lm0 != element_rf00 || element_lm0 != element_rf10 || element_lm0 != element_rf01 || element_lm0 != element_rf11) error = true;
    }
    printf(error ? "FAIL\n" : "PASS\n");
}

bool chaining_ls_tester::perform_tests(){

    //test_U0LS_to_U1LS_to_U1L0();
    test_U0L1_to_U0L0_to_U0LS_to_U1LS_to_U1L0_and_U1L1();
    //test_U0LS_to_U1LS_to_U1L0_and_U1L1();

    printf("All Tests done!\n");
    return true; // return to crt0.asm and loop forever
}
