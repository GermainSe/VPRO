#include <stdint.h>
#include <algorithm>
#include <vpro.h>
#include <eisv.h>
#include "riscv/eisV_hardware_info.hpp"

/**
 * Test Data Variables
 */
constexpr int NUM_TEST_ENTRIES = 64;
volatile int16_t __attribute__ ((section (".vpro"))) input_data[NUM_TEST_ENTRIES];

/**
 * Main
 */
int main(int argc, char *argv[]) {
    sim_init(main, argc, argv);

    aux_clr_sys_time();
    aux_wait_cycles(10);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(30);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(111);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(111);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(522);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(450);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(10);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(30);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(111);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(111);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(522);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();
    aux_wait_cycles(450);
    aux_print_debugfifo(aux_get_sys_time_lo());

    aux_clr_sys_time();

    return 0;
}

