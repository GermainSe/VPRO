//
// Created by renke on 08.05.20.
//

#include "tests/features/chaining_tester.h"

#include <stdint.h>
#include <math.h>

// Intrinsic auxiliary library
#include "core_wrapper.h"
#include <vpro.h>
#include "simulator/helper/typeConversion.h"

#include "defines.h"
#include "helper.h"

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

void chaining_tester::init_RF_for_chaining(int length)
{
    resetRF(length);
    rf_set(0x10, 1, length, L0); // address: 16
    rf_set(0x20, 2, length, L0); // 32
    rf_set(0x30, 4, length, L0); // 48

    rf_set(0x10, 1, length, L1); // address: 16
    rf_set(0x20, 2, length, L1); // 32
    rf_set(0x30, 4, length, L1); // 48
};
void chaining_tester::init_RF_for_chaining_incr(int length)
{
    resetRF(length);
    rf_set_incr(0x10, 1, length, L0); // address: 16
    rf_set_incr(0x20, 2, length, L0); // 32
    rf_set_incr(0x30, 4, length, L0); // 48

    rf_set_incr(0x10, 1, length, L1); // address: 16
    rf_set_incr(0x20, 2, length, L1); // 32
    rf_set_incr(0x30, 4, length, L1); // 48
};

bool chaining_tester::SKIP_DATA = false;
int chaining_tester::TEST_VECTOR_LENGTH = 15;

//----------------------------------------------------------------------------------
//----------------------------------Main--------------------------------------------
//----------------------------------------------------------------------------------
bool chaining_tester::perform_tests(){

    // Data base addresses
    int a = 0x10;
    int b = 0x20;
    int c = 0x30;
    int length = TEST_VECTOR_LENGTH;

    printf("-1-1-1-1\n");

    resetLM(length);
    init_RF_for_chaining(length);

    printf("0000\n");

    sim_dump_register_file(0, 0, 0);
    sim_dump_register_file(0, 0, 1);


    printf("AAAA\n");
    vpro_wait_busy(0xffff, 0xffff); // defined start

    int lane_delay = 16; // test 3b
    /**
     * 1. Test
     */
    printf("BBBB\n");


    printf("TEST: L0 -> L1 && L1 <- L0\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // L0 -> L1
    // L0[c] = a+b=3
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);
    // L1[b] = (a+b)+c=7
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_CHAINING_LEFT_2D, SRC2_ADDR(c, 1, length), length-1, 0);
    // L0 -> L1 (reversed schedule)
    // L1[a] = 8+a=9
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_CHAINING_LEFT_2D, SRC2_ADDR(a, 1, length), length-1, 0);
    // L0[b] = (a+b)+a=8
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(b, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(c, 1, length), length-1, 0);
    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
        sim_dump_register_file(0, 0, 0);
        sim_dump_register_file(0, 0, 1);
        sim_dump_local_memory(0, 0);
////        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(3, L0, c, length);
        verify(4, L0, b, length);
        verify(11, L1, a, length);
        verify(2, L1, b, length);

        resetLM(length);
        init_RF_for_chaining(length);
    }

//     /**
//      * 2. Test
//      */
//     printf("TEST: L0 -> L1, LS\n");
//     //debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
//     // L0 -> L1, LS
//     // L0[c]=a+b=3
//     __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                     DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);
//     // L1[c]=a+b+b=5
//     __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                     DST_ADDR(c, 1, length), SRC1_CHAINING_LEFT_DELAYED_2D, SRC2_ADDR(b, 1, length), length-1, 0);
//     // LM[0]=a+b=3
//     __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
//                                     DST_ADDR(0, 1, length), SRC1_CHAINING_2D(0), SRC2_IMM_2D(0), length-1, 0);

//     if (!SKIP_DATA) {
//         vpro_wait_busy(0xffffffff, 0xffffffff);
//         sim_dump_register_file(0, 0, 0);
//         sim_dump_register_file(0, 0, 1);
//         sim_dump_local_memory(0, 0);
// ////        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
//         verify(3, L0, c, length);
//         verify(5, L1, c, length);
//         verify(3, LS, 0, length, false);

//         resetLM(length);
//         init_RF_for_chaining(length);
//     }

    /**
     * 3. Test
     */
    printf("TEST: L0 -> L1 -> LS\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // L0 -> L1 -> LS

    // L0[c] = a+b=3
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);
    // L1[a] = a+b+c=7
    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_CHAINING_LEFT_2D, SRC2_ADDR(c, 1, length), length-1, 0);
    // LM[0]=a+b+c=7
//    VPRO::DIM2::LOADSTORE::store(0, 0, 1, length, length - 1, 0, L1);
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 1, length), SRC1_CHAINING_2D(1), SRC2_IMM_2D(0), length-1, 0);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
////        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(3, L0, c, length);
        verify(7, L1, a, length);
        verify(7, LS, 0, length, false);

        resetLM(length);
        init_RF_for_chaining(length);
    }

    /**
     * 3.b Test
     */
    printf("TEST: L0 -> L1 -> LS (delayed by other instruction before)\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // L0 -> L1 -> LS

    // DELAY
    lane_delay = 16;
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_SUB, NO_FLAG_UPDATE,
                                    DST_ADDR(200, 1, length), SRC1_ADDR(200, 1, lane_delay), SRC2_IMM_2D(0), lane_delay-1, 0);
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_SUB, NO_FLAG_UPDATE,
                                    DST_ADDR(200, 1, length), SRC1_ADDR(200, 1, lane_delay), SRC2_IMM_2D(0), lane_delay-4-1, 0);


    // L0[c] = a+b=3
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);
    // L1[a] = a+b+c=7
    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_CHAINING_LEFT_2D, SRC2_ADDR(c, 1, length), length-1, 0);
    // LM[0]=a+b+c=7
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 1, length), SRC1_CHAINING_2D(1), SRC2_IMM_2D(0), length-1, 0);



    // L0[b]=b+b=4
    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(b, 1, length), SRC1_ADDR(b, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);



    // L0[a]=a+a=2
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(a, 1, length), length-1, 0);
    // L1[c]=a+a+b=4
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_CHAINING_LEFT_2D, SRC2_ADDR(b, 1, length), length-1, 0);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
////        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(3, L0, c, length);
        verify(2, L0, a, length);
        verify(4, L0, b, length);
        verify(7, L1, a, length);
        verify(4, L1, c, length);
        verify(7, LS, 0, length, false);

        resetLM(length);
        init_RF_for_chaining(length);
    }

    /**
     * 4. Test
     */
    printf("TEST: L0 -> L1\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // L0 -> L1
    // L0[c] = a+b=3
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);
    // L1[a] = a+b+c=7
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_CHAINING_LEFT_2D, SRC2_ADDR(c, 1, length), length-1, 0);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
//        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(3, L0, c, length);
        verify(7, L1, a, length);

        resetLM(length);
        init_RF_for_chaining(length);
    }

    /**
     * 5. Test
     */
    printf("TEST: L0 -> L1 (reversed schedule)\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // L0 -> L1 (reversed schedule)
    // L1[a] = a+b+c=7
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_CHAINING_LEFT_2D, SRC2_ADDR(c, 1, length), length-1, 0);
    // L0[c] = a+b=3
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
//        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(3, L0, c, length);
        verify(7, L1, a, length);

        resetLM(length);
        init_RF_for_chaining(length);
    }
    /**
     * 6. Test
     */
    printf("TEST: L1 -> LS\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // L1 -> LS
    // L0[a] = b+99=101
    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(a, 1, length), SRC1_ADDR(b, 1, length), SRC2_IMM_2D(99), length-1, 0);
    // LM[0] = a+0=1
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 1, length), SRC1_CHAINING_2D(1), SRC2_IMM_2D(0), length-1, 0);
    // L1[c] = a+0=1
    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_IMM_2D(0), length-1, 0);

    //mandatory! so the next LS does not yet take this L1 data for chain input...
    vpro_wait_busy(0xffffffff, 0xffffffff);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
//        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(101, L0, a, length);
        verify(1, L1, c, length);
        verify(1, LS, 0, length, false);

        resetLM(length);
        init_RF_for_chaining(length);
    }

    /**
     * 7. Test
     */
    printf("TEST: LS -> L1 && LS -> L0 (crossed schedule)\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // LS <- L1 && LS <- L0 (crossed schedule)
    // LM[0] = b+5=7
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 1, length), SRC1_CHAINING_2D(1), SRC2_IMM_2D(0), length-1, 0);
    // L0[c] = a+5=6
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_IMM_2D(5), length-1, 0);
    // L1[c] = b+5=7
    __vpro(L1, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(b, 1, length), SRC2_IMM_2D(5), length-1, 0);
    // LM[100] = a+5=6
    __vpro(LS, NONBLOCKING, NO_CHAIN, FUNC_STORE, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 1, length), SRC1_CHAINING_2D(0), SRC2_IMM_2D(100), length-1, 0);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
//        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(6, L0, c, length);
        verify(7, L1, c, length);
        verify(6, LS, 100, length, false);
        verify(7, LS, 0, length, false);

        resetLM(length);
        init_RF_for_chaining(length);
    }

//     /**
//      * 8. Test
//      */
//     printf("TEST: LS -> L0, L1\n");
//     // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
//     // LS -> L0, L1
//     __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOAD, NO_FLAG_UPDATE,
//                                     DST_ADDR(0, 0, 0), SRC1_ADDR(0, 1, length), SRC2_IMM_2D(200), length-1, 0);
//     // L0[c] = 64+a=65
//     __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                     DST_ADDR(c, 1, length), SRC1_LS_DELAYED_2D, SRC2_ADDR(a, 1, length), length-1, 0);
//     // L1[c] = 64+b=66
//     __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
//                                     DST_ADDR(c, 1, length), SRC1_LS_2D, SRC2_ADDR(b, 1, length), length-1, 0);

//     if (!SKIP_DATA) {
//         vpro_wait_busy(0xffffffff, 0xffffffff);
// //        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
//         verify(65, L0, c, length);
//         verify(66, L1, c, length);
//         verify(64, LS, 200, length, false);

//         resetLM(length);
//         init_RF_for_chaining(length);
//     }

    /**
     * 9. Test
     */
    printf("TEST: LS -> L1 <- L0\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // LS -> L1 <- L0
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOAD, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 0, 0), SRC1_ADDR(0, 1, length), SRC2_IMM_2D(200), length-1, 0);
    // L0[c] = a+b=3
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);
    // L1[c] = 64+a+b=67
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_LS_2D, SRC2_CHAINING_LEFT_2D, length-1, 0);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
//        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(64, LS, 200, length, false);
        verify(3, L0, c, length);
        verify(67, L1, c, length);

        init_RF_for_chaining(length);
    }

    /**
     * 10. Test
     */
    printf("TEST: LS -> L1 <- L0 (reversed)\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    // LS -> L1 <- L0 (reversed)
    // L0[c] = a+b=3
    __vpro(L0, NONBLOCKING, IS_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_ADDR(a, 1, length), SRC2_ADDR(b, 1, length), length-1, 0);
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOAD, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 0, 0), SRC1_ADDR(0, 1, length), SRC2_IMM_2D(200), length-1, 0);
    // L1[c] = 64+a+b=67
    __vpro(L1, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_LS_2D, SRC2_CHAINING_LEFT_2D, length-1, 0);

    vpro_wait_busy(0xffffffff, 0xffffffff);

    if (!SKIP_DATA) {
//        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
        verify(64, LS, 200, length, false);
        verify(3, L0, c, length);
        verify(67, L1, c, length);

        init_RF_for_chaining_incr(length);
        set_all_LM_incr(length, 64, 200);
    }


    /**
     * 11. Test
     */
    printf("TEST: LS -> L0, L1, incrementing data\n");
    // debug |= DEBUG_PIPELINE | DEBUG_CHAINING;
    //Do sth else first in L0

    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(0x100, 1, length), SRC1_ADDR(c,1,length), SRC2_ADDR(a, 1, length), length-1, 0);
    // LS -> L0
    __vpro(LS, NONBLOCKING, IS_CHAIN, FUNC_LOAD, NO_FLAG_UPDATE,
                                    DST_ADDR(0, 0, 0), SRC1_ADDR(0, 1, length), SRC2_IMM_2D(200), length-1, 0);
    // L0[c] = 64[!]+a[!]=65[!!]
    __vpro(L0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE,
                                    DST_ADDR(c, 1, length), SRC1_LS_2D, SRC2_ADDR(a, 1, length), length-1, 0);

    if (!SKIP_DATA) {
        vpro_wait_busy(0xffffffff, 0xffffffff);
//        debug &= ~DEBUG_PIPELINE & ~DEBUG_CHAINING;
		for (int i = 0; i < length; i++){
        	verify(64+1+i+i, L0, c+i, 1);	// 1 [a!incrementing] + 64 [LS -> LM data!incrementing]
        }
	}



    printf("All Tests done!\n");
    return true; // return to crt0.asm and loop forever
}
