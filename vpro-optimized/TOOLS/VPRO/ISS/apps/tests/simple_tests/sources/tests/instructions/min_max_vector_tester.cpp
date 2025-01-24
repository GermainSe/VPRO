//
// Created by renke on 08.05.20.
//

#include "tests/instructions/min_max_vector_tester.h"

// Intrinsic auxiliary library
#include "core_wrapper.h"
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
//    vpro_wait_busy(0, 0);
//}
//
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

bool min_max_vector_tester::perform_tests(){

    int length = 15;  // test vector length

    resetLM(length);
    resetRF(length);
    vpro_wait_busy(0, 0); // defined start

    sim_dump_register_file(0, 0, 0);
    sim_dump_register_file(0, 0, 1);

    return true;
}
