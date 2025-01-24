// ########################################################
// # example app for MIPS, using some IO/Data instruction #
// #                                                      #
// # Sven Gesper, EIS, Tu Braunschweig, 2021              #
// ########################################################

#include <stdint.h>
#include <algorithm>
#include <vpro.h>
#include "riscv/eisV_hardware_info.hpp"

#include <map>
#include <iostream>
#include <fstream>
#include <vector>
#include <filesystem>

using one_parameter_uint32_t_function = uint32_t(*)(uint32_t);

// uint32_t *pregen_arr;
std::vector<uint32_t> pregen_arr;
uint32_t pregen_words;

/*
 __vpro(
    lane_mask,                                      !!!!
    blocking ? BLOCKING : NONBLOCKING, 
    is_chain ? IS_CHAIN : NO_CHAIN, 
    FUNC_ADD,                                       !!!!
    update_flags ? FLAG_UPDATE : NO_FLAG_UPDATE,
    dst, src1, src2, x_end, y_end, z_end);
*/
/*
Vprocmd gen_vpro_struct(const std::shared_ptr<CommandVPRO> &command) {
    Vprocmd cmd;
    cmd.data[0] = 514;
    
    cmd.data[4] = command->is_chain;
    cmd.data[5] = command->blocking;
    cmd.data[6] = command->flag_update;

    cmd.data[8] = command->src1.getImm();
    cmd.data[9] = command->src2.getImm();
    cmd.data[10] = command->dst.getImm();
    cmd.data[1] = command->x_end;
    cmd.data[2] = command->y_end;
    cmd.data[3] = command->z_end;
    
    cmd.data[7] = command->getType();               //  id
    cmd.data[11] = 0;                               // func

    return cmd;
}
*/

/*
(iss_aux) VPRO: 4 0 1 2 0 0 4608 268435456 7 7 0
(iss_aux) VPRO: 1 0 0 16 0 4608 536870912 268435456 7 7 0
(iss_aux) VPRO: 4 0 1 2 0 0 4608 268435520 7 7 0
[MACH_] need to set init source to IMM before using mac with addr init of accu
(iss_aux) VPRO: 1 0 0 23 0 4608 536870912 4608 7 7 0
(iss_aux) VPRO: 1 0 1 16 0 4608 4608 268435456 7 7 0
(iss_aux) VPRO: 4 0 0 8 0 805306368 4608 268435584 7 7 0
*/
uint32_t gen_vpro(uint32_t addr) {
    printf("VPRO: %u %u %u %u %u %u %u %u %u %u %u\n", 
            pregen_arr[addr + 1], 
            pregen_arr[addr + 2], pregen_arr[addr + 3], 
            pregen_arr[addr + 4], 
            pregen_arr[addr + 5],
            pregen_arr[addr + 6], pregen_arr[addr + 7], pregen_arr[addr + 8],
            pregen_arr[addr + 9], pregen_arr[addr + 10], pregen_arr[addr + 11]);

    __vpro(pregen_arr[addr + 1], 
            pregen_arr[addr + 2], pregen_arr[addr + 3], 
            pregen_arr[addr + 4], 
            pregen_arr[addr + 5],
            pregen_arr[addr + 6], pregen_arr[addr + 7], pregen_arr[addr + 8],
            pregen_arr[addr + 9], pregen_arr[addr + 10], pregen_arr[addr + 11]);
    return 12;
}

/*
dma_e2l_2d(cluster_mask, unit_mask, ext_base, loc_base, x_size, y_size, x_stride, pad_flags);
dma_ext2D_to_loc1D(uint32_t cluster, intptr_t ext_base, uint32_t loc_base, uint32_t x_stride, uint32_t x_size,
                        uint32_t y_size, const bool pad_flags[4] = default_flags
*/
uint32_t gen_dma(uint32_t addr) {
    if (pregen_arr[addr + 10]) {
        printf("DMA e2l: %u %u %u %u %u %u\n", pregen_arr[addr + 1], pregen_arr[addr + 4], pregen_arr[addr + 5], 
                            pregen_arr[addr + 6], pregen_arr[addr + 7], pregen_arr[addr + 8]);
        dma_ext2D_to_loc1D(pregen_arr[addr + 1], pregen_arr[addr + 4], pregen_arr[addr + 5], 
                            pregen_arr[addr + 6], pregen_arr[addr + 7], pregen_arr[addr + 8]);
    } else {
        printf("DMA l2e: %u %u %u %u %u %u\n", pregen_arr[addr + 1], pregen_arr[addr + 4], pregen_arr[addr + 5], 
                            pregen_arr[addr + 6], pregen_arr[addr + 7], pregen_arr[addr + 8]);
        dma_loc1D_to_ext2D(pregen_arr[addr + 1], pregen_arr[addr + 4], pregen_arr[addr + 5], 
                            pregen_arr[addr + 6], pregen_arr[addr + 7], pregen_arr[addr + 8]);
    }
    return 11;
}

uint32_t gen_v_sync(uint32_t addr) {
    vpro_wait_busy();
    return 1;
}

uint32_t gen_d_sync(uint32_t addr) {
    dma_wait_to_finish();
    return 1;
}

std::map<uint32_t, one_parameter_uint32_t_function> offset_map = {
    { 512, &gen_v_sync },            // V_SYNC
    { 513, &gen_d_sync },            // D_SYNC
    { 514, &gen_vpro },              // VPRO   10
    { 515, &gen_dma },               // DMA    11
};


/**
 * Test Data Variables
 */
constexpr int NUM_TEST_ENTRIES = 64;
volatile int16_t __attribute__ ((section (".vpro"))) test_array_1[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) test_array_2[NUM_TEST_ENTRIES];
volatile int16_t __attribute__ ((section (".vpro"))) result_array[NUM_TEST_ENTRIES];

uint32_t eval_pregen(uint32_t addr, bool dry_run = false) {
    for (auto& [k, v]: offset_map) {
        if (pregen_arr[addr] == k) {
            return v(addr);
        }
    }
    return 10000000;                    // ERROR, skip generating further commands!
}

uint32_t check_results() {
    auto reference_result = new int16_t[NUM_TEST_ENTRIES];
    for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
        reference_result[i] = test_array_1[i] * test_array_2[i];
    }
    for (int i = 0; i < NUM_TEST_ENTRIES; i++) {
        if (reference_result[i] != result_array[i]) {
            printf_error("Result is not same as reference! [Index: %i]\n", i);
            printf_error("Reference: %i, result: %i\n", reference_result[i], result_array[i]);
        } else {
            printf_success("Reference: %i  = result: %i\n", reference_result[i], result_array[i]);
        }
    }
    return 0;
}

uint32_t setup_app() {
    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::ZERO);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::X_INCREMENT);
    vpro_mac_h_bit_shift(0);
    vpro_mul_h_bit_shift(0);

    for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
        test_array_1[i] = i;
        test_array_2[i] = i;
    }
    return 0;
}

void make_dma_arr() {
    for (int16_t i = 0; i < NUM_TEST_ENTRIES; i++) {
        test_array_1[i] = i;
        test_array_2[i] = i;
    }

    // DMA & VPRO Instructions
    dma_ext1D_to_loc1D(0, intptr_t(test_array_1), LM_BASE_VU(0) + 0, NUM_TEST_ENTRIES);
    dma_ext1D_to_loc1D(0, intptr_t(test_array_2), LM_BASE_VU(0) + NUM_TEST_ENTRIES, NUM_TEST_ENTRIES);
}

void print_pregen() {
    for (int i = 0; i < pregen_arr.size(); ++i) {
        std::cout << "Element " << i << ": " << pregen_arr[i] << std::endl;
    }
}

void print_curr_dir_old() {
    std::filesystem::path currentDir = std::filesystem::current_path();
    std::cout << "Current Directory: " << currentDir.string() << std::endl;
    return;
}

uint32_t LittleEndianToBigEndian(const uint8_t* bytes) {
    return static_cast<uint32_t>(bytes[0]) << 24 |
           static_cast<uint32_t>(bytes[1]) << 16 |
           static_cast<uint32_t>(bytes[2]) << 8 |
           static_cast<uint32_t>(bytes[3]);
}

std::vector<uint32_t> load_commands() {
    std::ifstream file("../pregen.bin", std::ios::binary);
    if (file.is_open()) {

        std::vector<uint8_t> buffer(std::istreambuf_iterator<char>(file), {});
        size_t numUInt32 = buffer.size() / 4;
        pregen_words = static_cast<uint32_t>(numUInt32);
        std::vector<uint32_t> bigEndianValues(numUInt32);

        for (size_t i = 0; i < numUInt32; ++i) {
            bigEndianValues[i] = LittleEndianToBigEndian(&buffer[i * 4]);
        }

        return bigEndianValues;
    } else {
        std::cerr << "Failed to open the file." << std::endl;
    }
    std::vector<uint32_t> errvec(1, 1000000);
    return errvec;
}

void dma_exit_cmds() {
    dma_loc1D_to_ext1D(0, intptr_t(result_array), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 2, NUM_TEST_ENTRIES);
    dma_loc1D_to_ext2D(0, intptr_t(result_array), LM_BASE_VU(0) + NUM_TEST_ENTRIES * 2, 1 - 1, NUM_TEST_ENTRIES, 1);
    dma_wait_to_finish(0xffffffff);
}

/**
 * Main
 */
int main(int argc, char *argv[]) {
    sim_init(main, argc, argv);
    aux_print_hardware_info("Template App");

    setup_app();

    pregen_arr = load_commands();

    // print_pregen();
    sim_printf("pregen_words: %u\n", pregen_words);

    // assemble commands
    make_dma_arr();
    uint32_t addr = 22;         // !! SKIP DMA COMMANDS WITH POINTERS !!
    pregen_words = 98;

    uint32_t eval_accu = 0;
    while (addr < pregen_words) {
        eval_accu = eval_pregen(addr);
        printf("EVAL @ %u = %u\n", addr, eval_accu);
        addr = addr + eval_accu;
    }

    sim_printf("Reference: %u\n", addr);

    dma_exit_cmds();

    dcma_flush();

    check_results();

    sim_stop();
    return 0;
}
