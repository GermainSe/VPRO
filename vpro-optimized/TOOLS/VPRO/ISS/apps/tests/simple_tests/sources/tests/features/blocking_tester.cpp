//
// Created by renke on 08.05.20.
//

#include "tests/features/blocking_tester.h"


#include <stdint.h>
#include <math.h>
#include <vector>
// Intrinsic auxiliary library
#include "core_wrapper.h"
#include "simulator/helper/typeConversion.h"

#include "defines.h"
#include "helper.h"
namespace blockingTest {


    bool tester::SKIP_DATA = false;
    int tester::TEST_VECTOR_LENGTH = 50;

    //void resetRF(int length) {
    //    rf_set(   0, 0, 1024, L0);
    //    rf_set(0x10, 1, length, L0); // address: 16
    //    rf_set(0x20, 2, length, L0); // 32
    //    rf_set(0x30, 4, length, L0); // 48
    //
    //    rf_set(   0, 0, 1024, L1);
    //    rf_set(0x10, 1, length, L1); // address: 16
    //    rf_set(0x20, 2, length, L1); // 32
    //    rf_set(0x30, 4, length, L1); // 48
    //
    //    printf("RESET RF\n");
    //    vpro_wait_busy(0xffffffff, 0xffffffff);
    //}
    //
    //void resetLM(int length) {
    //    VectorUnit *unit = (*(core_->getClusters()[0]->getUnits()))[0];
    //    uint8_t *lm = unit->getlocalmemory();
    //    for (int i = 0; i < 2048; i++) {
    //        lm[i] = 0;
    //    }
    //    for(int i = 0; i < length; i++)
    //        unit->writeLocalMemoryData(200+i, 64);
    //    printf("RESET LM\n");
    //}

    void verify(int value, int lane, int offset, int length, bool rf = true) {
        VectorUnit *unit = core_->getClusters()[0]->getUnits()[0];
        int32_t *data_vpro = new int32_t[length];
        if (rf) {
            int id = (lane == L0) ? 0 : 1;
            for (auto l : unit->getLanes()) {
                if (l->vector_lane_id == id) {
                    for (int i = 0; i < length; i++) {
                        auto val = l->regFile.get_rf_data(i + offset);
                        data_vpro[i] = int32_t(*__24to32signed(val));
                    }
                    break;
                }
            }
        } else {
            for (int i = 0; i < length; i++) {
                data_vpro[i] = unit->getLocalMemoryData(offset + i);
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
            printf("\e[91mERROR on verify: %s != %i!\e[0m \n", (rf) ? "RF" : "LM", value);
            sim_wait_step();
        } else {
            printf("\e[32mSuccess on verify: %s == %i!\e[0m \n", (rf) ? "RF" : "LM", value);
        }
    }

    inline void __attribute__((always_inline)) loadTestDataLM(int cluster, int16_t *data, int size, int offset = 0){
        dma_ext1D_to_loc1D(cluster, uint64_t(intptr_t(data)), offset, size);
    }

    void tester::init_RF(int length)
    {
        resetRF(length*2);
        rf_set(0, 0, length, L0);
        rf_set(length, 1, length, L0); // address: 16
        rf_set(length*2, 2, length, L0); // 32
        //rf_set(0x30, 4, length, L0); // 48

        //rf_set(0x10, 1, length, L1); // address: 16
        //rf_set(0x20, 2, length, L1); // 32
        //rf_set(0x30, 4, length, L1); // 48
    };

    //----------------------------------------------------------------------------------
    //----------------------------------Main--------------------------------------------
    //----------------------------------------------------------------------------------
    bool tester::perform_tests(){

        // Data base addresses
        //int a = 0x10;
        //int b = 0x20;
        //int c = 0x30;
        int length = TEST_VECTOR_LENGTH;

        resetLM(length);

        sim_dump_register_file(0, 0, 0);
        sim_dump_register_file(0, 0, 1);
        vpro_wait_busy(0xffff, 0xffff); // defined start

        /**
         * 1. Test
         */
        printf("TEST: LO - BLOCKING\n");
        int tmp_len = 0;
        if(length != 50){
            tmp_len = length;
            length = 50;
            printf("Test Verifyable with length 50. Therefore changing to length 50 for this test");
        }
        init_RF(length);
        for(int i=0; i < 10; ++i){
            __vpro(L0, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                            DST_ADDR(i, 1, length),
                                            SRC1_ADDR(i, 1, length),
                                            SRC2_ADDR(length, 1, length),
                                            length-1, 0);
        }

        std::vector<int> comp = {1, 2, 4, 6, 9, 12, 16, 20, 25, 30, 26, 22, 19, 16, 14, 12, 11, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1};

        vpro_wait_busy(0xffffffff, 0xffffffff);
        for(int i = 0; i < comp.size(); ++i){
            verify(comp[i], L0, i, 1);
        }
        if(tmp_len)  length = tmp_len;

        /**
         * 2. Test
         **/
        printf("TEST: SIMPLE BLOCKING\n");
        sim_wait_step();
        // DMA load 1 to 0 [+64]
        /*int16_t data_arr_1[64];
        for(int i = 0; i < 64; ++i){
            data_arr_1[i] = 1;
        }*/
        //loadTestDataLM(0, const_cast<int16_t *>(data_arr_1), 64);
        dma_wait_to_finish(0xffffffff);

        // # init_RF
        length = 8;
        resetRF(length);
        int val = 1;
        for(int i = 0; i < length; ++i){
            rf_set(i, val, 1, L0);
            val++;
        }

        //LD (from: 0, size: 64, to: 0)
        /*
        __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOADS, NO_FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0), 7, 7);
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 8),
                                        SRC1_LS, SRC2_IMM_2D(0), 7, 7);
        */
        // reset result region to 0
        __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(128, 1, 8),
                                        SRC1_IMM_2D(0), SRC2_IMM_2D(0), 7, 7);

        // ADD (from: 0, size: 1, to: 128, by 17)
        // chaining by reading out in again... requires working block flag
        // 0x1234 : 4660
        __vpro(L0, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                        DST_ADDR(128 + 0, 1, 8),
                                        SRC1_ADDR(0, 1, 8), SRC2_IMM_2D(0x1234), 0, 0);
        __vpro(L0, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                        DST_ADDR(128 + 1, 1, 8),
                                        SRC1_IMM_2D(0x1234), SRC2_ADDR(128 + 0, 1, 8), 0, 0);
        __vpro(L0, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                        DST_ADDR(128 + 2, 1, 8),
                                        SRC1_IMM_2D(0x1234), SRC2_ADDR(128 + 1, 1, 8), 0, 0);
        __vpro(L0, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                        DST_ADDR(128 + 3, 1, 8),
                                        SRC1_IMM_2D(0x1234), SRC2_ADDR(128 + 2, 1, 8), 0, 0);
        __vpro(L0, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                        DST_ADDR(128 + 4, 1, 8),
                                        SRC1_IMM_2D(0x1234), SRC2_ADDR(128 + 3, 1, 8), 0, 0);

              /*
        __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                        DST_ADDR(128, 1, 8),
                                        SRC1_ADDR(128, 1, 8), SRC2_IMM_2D(0), 7, 7);


        __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
                                        DST_ADDR(128, 1, 8),
                                        SRC1_CHAINING(0), SRC2_IMM_2D(0), 7, 7);*/

        vpro_wait_busy(0xffffffff, 0xffffffff);
        //dma_loc_to_ext();
        dma_wait_to_finish(0xffffffff);


        std::vector<int32_t> result;

        result.push_back(1 + 0x1234);
        for(int i = 1; i < 5; ++i){
            result.push_back(result[i-1] + 0x1234);
        }

        for(int i = 0; i < result.size(); ++i){

            verify(result[i], L0, 128+i, 1);
            //verifyLM(result[i], off, length, 0,0);
        }

        //verifyLM(0, 0, );


        printf("All Tests done!\n");
        return true; // return to crt0.asm and loop forever
    }
}
