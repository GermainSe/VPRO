// ########################################################
// # example app for MIPS, using some IO/Data instruction #
// #                                                      #
// # Sven Gesper, EIS, Tu Braunschweig, 2021              #
// ########################################################

#include <stdint.h>
#include <algorithm>
#include <vpro.h>
#include <eisv.h>
#include "riscv/eisV_hardware_info.hpp"
#include "patara_random_vpro_instr.h"
#include "patara_complete_vpro_instr.h"
#include "patara_random_1vpro.h"
#include "patara_random_10vpro.h"
#include "patara_random_100vpro.h"
#include "patara_random_1000vpro_0_red.h"
#include "patara_random_1000vpro_1_red.h"
#include "patara_random_1000vpro_2_red.h"
#include "patara_random_1000vpro_3_red.h"
#include "patara_base.h"

/**
 * Main
 */
int main(int argc, char *argv[]) {
    sim_init(main, argc, argv);
//    aux_print_hardware_info("PATARA");
    printf("PATARA Simple (hardcoded tests...)\n");

    // broadcast to all
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);

    vpro_patara_base();

    printf("Random...\n");

//    vpro_random();

//    vpro_random_1();
    vpro_random_10();
//    vpro_random_100();

//    vpro_random_1000_0();
//    printf("P1 done!\n");
//    vpro_random_1000_1();
//    printf("P2 done!\n");
//    vpro_random_1000_2();
//    printf("P3 done!\n");
//    vpro_random_1000_3();
//    printf("P4 done!\n");

//    printf("Complete...\n");
    vpro_complete();

    vpro_lane_sync(); // vpro_wait_busy(0xffffffff, 0xffffffff);
    vpro_dma_sync(); // dma_wait_to_finish(0xffffffff);

    printf("DONE\n");
//    aux_print_statistics();

    sim_stop();
    return 0;
}
