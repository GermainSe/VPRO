//
// Created by renke on 08.09.20.
//

#include "tests/features/inter_unit_chaining_tester.h"

// Intrinsic auxiliary library
#include "core_wrapper.h"
#include "simulator/helper/typeConversion.h"

#include "defines.h"
#include "helper.h"

uint32_t in_mask;
uint32_t out_mask;

void write_ascending_vector_local_memory(){
    // initialize test data
    for(int i=0; i < 64;i++){
        core_->getClusters()[0]->getUnits()[0]->writeLocalMemoryData(i, i);
    }
}
bool assert_num_units(int _num_units){
    // check if hardware configuration suits the test conditions
    if(NUM_VU_PER_CLUSTER == _num_units){
        return true;
    }
    else{
        printf("defined masks do not work for this hardware configuration\n"
               "set NUM_VU_PER_CLUSTER = %i or adapt masks to this hardware configuration\n", _num_units);
        return false;
    }
}

void define_masks(uint32_t _in_mask, uint32_t _out_mask)
{
    in_mask = _in_mask;
    out_mask = _out_mask;
}

void reset_register_files()
{
    for(int cluster = 0; cluster < NUM_CLUSTERS; cluster++){
        for(int unit = 0; unit < NUM_VU_PER_CLUSTER; unit++){
            rf_set(0, 0, 1024, 0);
            rf_set(0, 0, 1024, 1);
        }
    }
}

void reset_mask_and_rf(){
    vpro_set_unit_mask(0xffffffff);
    reset_register_files();
}

void test1(){
    if(!(assert_num_units(2))){
        printf("test 1 not performed");
        return;
    }
    vpro_wait_busy(0b01, 0b11);
    reset_mask_and_rf();

    vpro_set_unit_mask(0b01);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0,0,0), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);

    vpro_set_unit_mask(0b10);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_wait_busy(0x1, 0x11);
    for(int i=0; i < 64;i++){
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L0)");
    }
    reset_mask_and_rf();
}

void test2(){
    if(!(assert_num_units(2))){
        printf("test 1 not performed");
        return;
    }
    vpro_wait_busy(0b01, 0b11);
    reset_mask_and_rf();

    vpro_set_unit_mask(0b01);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0,0,0), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);

    vpro_set_unit_mask(0b10);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L1, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_wait_busy(0x1, 0x11);
    for(int i=0; i < 64;i++){
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L0)");
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[1]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L1)");
    }
    reset_mask_and_rf();
}

void test3(){
    if(!(assert_num_units(2))){
        printf("test 1 not performed");
        return;
    }
    vpro_wait_busy(0b01, 0b11);
    reset_mask_and_rf();

    vpro_set_unit_mask(0b01);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0,0,0), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_set_unit_mask(0b10);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_wait_busy(0x1, 0x11);
    for(int i=0; i < 64;i++){
        if(core_->getClusters()[0]->getUnits()[0]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L0)");
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L1)");
    }
    reset_mask_and_rf();
}

void test4(){
    if(!(assert_num_units(2))){
        printf("test 1 not performed");
        return;
    }
    vpro_wait_busy(0b01, 0b11);
    reset_mask_and_rf();

    vpro_set_unit_mask(0b10);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0,0,0), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);

    vpro_set_unit_mask(0b01);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_set_unit_mask(0b10);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);


    vpro_wait_busy(0x1, 0x11);
    for(int i=0; i < 64;i++){
        if(core_->getClusters()[0]->getUnits()[0]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L0)");
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L1)");
    }
    reset_mask_and_rf();
}

void test5(){
    if(!(assert_num_units(2))){
        printf("test 2 not performed");
        return;
    }
    vpro_wait_busy(0x1, 0x11);
    reset_mask_and_rf();

    vpro_set_unit_mask(0b01);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0,0,0), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L1, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_set_unit_mask(0b10);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L1, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_wait_busy(0x1, 0x11);
    for(int i=0; i < 64;i++){
        if(core_->getClusters()[0]->getUnits()[0]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L0)");
        if(core_->getClusters()[0]->getUnits()[0]->getLanes()[1]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L1)");
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L0)");
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[1]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L1)");
    }
}

void test6(){
    if(!(assert_num_units(3))){
        printf("test 3 not performed");
        return;
    }
    vpro_wait_busy(0x1, 0x111);
    reset_mask_and_rf();

    vpro_set_unit_mask(0b010);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0,0,0), SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);


    vpro_set_unit_mask(0b100);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_RIGHT_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_set_unit_mask(0b001);
    __vpro(LS, NBL, CH, FUNC_LOAD, NFU, DST_ADDR(0, 0,0), SRC1_LS_LEFT_2D, SRC2_IMM_2D(0), 7, 7);
    __vpro(L0, NBL, NCH, FUNC_ADD, NFU, DST_ADDR(0, 1, 8), SRC1_LS_DELAYED_2D, SRC2_IMM_2D(0), 7, 7);

    vpro_wait_busy(0x1, 0x111);
    for(int i=0; i < 64;i++){
        if(core_->getClusters()[0]->getUnits()[0]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U0L0)");
        if(core_->getClusters()[0]->getUnits()[1]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U1L0)");
        if(core_->getClusters()[0]->getUnits()[2]->getLanes()[0]->regFile.get_rf_data(i, 3) != i) printf_error("test failed (U2L0)");
    }
}

bool inter_unit_chaining_tester::perform_tests(){


    write_ascending_vector_local_memory();
    define_masks(0b01, 0b10);

    test1();
    test2();
    test3();
    test4();
    test5();
    test6();
}


