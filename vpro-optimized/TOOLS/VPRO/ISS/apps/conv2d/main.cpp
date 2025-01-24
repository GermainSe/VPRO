#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <inttypes.h>

#include <vpro.h>
#include <eisv.h>
#include "riscv/eisV_hardware_info.hpp"

#ifdef SIMULATION
#include "iss_aux.h"
#endif

#include "conv.h"
#include "generate_cmds.h"
#include "cmd_loop.h"
#include "DmaLoopExtension.h"
#include <vector>

int main(int argc, char *argv[]) {
    sim_init(main, argc, argv);
    //sim_min_req(HW.CLUSTERS, HW.UNITS, 2); @DEPRECATED
    aux_print_hardware_info("Conv2D");

    bool hw_do_memcpy = false;
    bool hw_do_verification = false;

    printf("\nStart\n");
    printf("\nClusters: %i. UNITS: %i\n", VPRO_CFG::CLUSTERS, VPRO_CFG::UNITS);
    printf_info("\nConfig: kernel: %i x %i, input: %i x %i, output: %i x %i\n", kernel_size, kernel_size, input.dim_x, input.dim_y, output.dim_x, output.dim_y);
    printf_info("\tSegments (Count: %i x %i): input: %i x x%i, output: %i x %i\n", segment.num_x, segment.num_y, segment.dim_in_x, segment.dim_in_y, segment.dim_out_x, segment.dim_out_y);

    setbuf(stdout, NULL);

    if (do_opt)
        printf_info("OPTIMIZED SW Implementation\n");
    else
        printf_info("Only on Lane 0. unotimized SW Implementation\n");
    if (vpro_ext)
        printf_info("Risc-V, VPRO Extension active!\n\n");
    else
        printf_info("Risc-V IO generated VPRO Commands (Ext inactive!)\n\n");

    sim_stat_reset();
    aux_clr_sys_time();
    aux_reset_all_stats();

    // reset result array
    {
      int16_t count = 0;
        for (volatile int16_t &i: result_array) {
            i = int16_t(0xdead);
        }
//        for (volatile int16_t &i: result_array_zeros) {
//            i = 0;
//        }
        for (volatile int16_t &i: result_array_dead) {
            i = int16_t(0xdead);
        }
    }
    /**
    * Create some (random) input data
    */
    {
        int16_t count = 0;
        for (volatile int16_t &i: test_array_1) {
            i = count % 5;
            count = int16_t((abs(count) + 1) * (-1));
//          printf_info("input [%d]\n", i);
        }

#ifdef SIMULATION
        for (uint i = 0; i < input.dim_x*input.dim_y*sizeof(int16_t); ++i) {
            core_->dbgMemWrite(mm_input + i, &(((uint8_t *)(test_array_1))[i]));
        }
#else
        if (hw_do_memcpy)
        memcpy((void *)(mm_input), test_array_1, input.dim_x*input.dim_y*sizeof(int16_t));
#endif

        // random kernel coefficients
        for(int i = kernel_size*kernel_size - 1; i >= 0; --i) {
            kernel[i] = 1 << kernel_load_shift_right;
        }
    }

//    printf("Input Array: \n");
//    for (int y = 0; y < input.dim_y; ++y) {
//        for (int x = 0; x < input.dim_x; ++x) {
//            printf("%5i, ", test_array_1[x + y*input.dim_x]);
//        }
//        printf("\n");
//    }

    uint64_t cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    printf("[Risc-V Input generation] Sys-Time (Risc-V Cycles): %llu (%llu ms)\n",
           (unsigned long long)cnt, (unsigned long long)(1000 * cnt / get_gpr_risc_freq()));
    sim_stat_reset();
    aux_clr_sys_time();
    aux_reset_all_stats();

    /**
    * Initialize / Reset Memories of VPRO
    */
    // defaulting all VPRO configuration registers
    vpro_mac_h_bit_shift(24);
    vpro_mul_h_bit_shift(24);
    vpro_set_mac_init_source(VPRO::MAC_INIT_SOURCE::IMM);
    vpro_set_mac_reset_mode(VPRO::MAC_RESET_MODE::Z_INCREMENT);

    // init conv
    vpro_mac_h_bit_shift(conv_result_shift_right);
    vpro_mul_h_bit_shift(conv_result_shift_right);

    dma_set_pad_value(0);
    dma_set_pad_widths((kernel_size-1)/2, (kernel_size-1)/2, (kernel_size-1)/2, (kernel_size-1)/2);

    if (vpro_ext){
        vpro_ext_init();
    }

    // pre load functions to I-Cache
    vpro_load_kernel();
    vpro_conv();
    vpro_sync();

    // set all LMs to error value (0xdead)
    for (size_t i = 0; i < 8192; i += 1024) {
        dma_e2l_1d(0xffff, 0xffff, intptr_t(&(result_array_dead[0])), i, 1024);
    }
//    printf_warning("[DMA] Load Dead Result from %lx\n", intptr_t(&(result_array_dead[0])));
    // set RFs to error value (0xdead)
    __vpro(L0_1, BLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 1, 32),
           SRC2_IMM_2D(0), SRC2_IMM_2D(0xdead), 31, 31);

    vpro_sync();

    // reset cycle counters in subsystem
    sim_stat_reset();
    aux_clr_sys_time();
//    aux_reset_all_stats();

//    // Generate Command List
    Commands commands = Commands();
    commands.generate_dma_blocks();       // TODO: enable and evaluate!!!!!!!!!!!!!!!!!!!!
    const char *filename = "command_list.txt";
    commands.dump_to_file(filename);

    if (use_dma_loop){
        // create a copy for DmaLoopExtension
        std::vector<COMMAND> v;
        v.assign(&commands.cmd_list[0], &commands.cmd_list[0] + commands.total_commands);
        DmaLoopExtension ext(v);
        ext.generate();
        // copy back to cmd_list, or use v.data() ?
        memcpy(&commands.cmd_list[0], v.data(), commands.total_commands);
    }

    CommandLoop loop = CommandLoop(commands.cmd_list, commands.total_commands);

    // Load Kernel
    dma_e2l_1d(0xffff, 0xffff, intptr_t(&(kernel[0])), LM_KERNEL_BASE + 0, kernel_size * kernel_size);
    dma_e2l_1d(0xffff, 0xffff, intptr_t(&(kernel[0])), LM_KERNEL_BASE + 4096, kernel_size * kernel_size);
    vpro_sync();
    vpro_load_kernel();
    vpro_sync();

    cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    printf("[Conv Init; Command Generation] Sys-Time (Risc-V Cycles): %llu (%llu ms)\n",
           (unsigned long long)cnt, (unsigned long long)(1000 * cnt / get_gpr_risc_freq()));

    printf_info(" Total: %i Segments to process on %i parallel units [%i Commands]\n",
           Commands::total_segments, Commands::parallel_units, commands.total_commands);
    // reset cycle counters in subsystem
    sim_stat_reset();
    aux_clr_sys_time();
    aux_reset_all_stats();

    /**
     * Main Loop of Conv
     */
    loop.execute();

    /**
     * End
     */
    dcma_flush();

    cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    aux_print_statistics();
    printf_success("[VPRO Conv only] Sys-Time (Risc-V Cycles): %llu (%llu ms)\n",
           (unsigned long long)cnt, (unsigned long long)(1000 * cnt / get_gpr_risc_freq()));

    printf("[Risc-V] VPRO output copy...\n");
    aux_clr_sys_time();
#ifdef SIMULATION
    for (uint i = 0; i < output.dim_x*output.dim_y*sizeof(int16_t); ++i) {
        core_->dbgMemRead(mm_output + i, &(((uint8_t *)(result_array))[i]));
    }
#else
    if (hw_do_memcpy)
    memcpy(result_array, (void *)(mm_output), output.dim_x*output.dim_y*sizeof(int16_t));
#endif
    cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    printf("    [done] (Risc-V Cycles): %llu (%llu ms)\n",
           (unsigned long long)cnt, (unsigned long long)(1000 * cnt / get_gpr_risc_freq()));

#ifndef SIMULATION
    if (hw_do_verification) {
#endif
    /**
     * Reference + Verification
     */
    printf("[Risc-V] Reference calculation...\n");
    aux_clr_sys_time();
    auto *referenceresult = (int16_t *) malloc(output.dim_x * output.dim_y * sizeof(int16_t));
    {
//        int16_t inputdata[(input.dim_x + kernel_size-1)*(input.dim_y + kernel_size - 1)]{0}; // zero padding by initialization
        auto *inputdata = (int16_t *) malloc(
                (input.dim_x + kernel_size - 1) * (input.dim_y + kernel_size - 1) * sizeof(int16_t));
        for (uint x = 0; x < input.dim_x + kernel_size - 1; ++x) {
            for (uint y = 0; y < input.dim_y + kernel_size - 1; ++y) {
                inputdata[x + y * (input.dim_x + kernel_size - 1)] = 0;
            }
        }

        uint padw = (kernel_size - 1) / 2;
        uint pad_start_y = padw * padw + padw * input.dim_x + padw * padw; // top pad (incl. top left, top right)
        uint pad_start = pad_start_y + padw; // to first element
        for (uint x = 0; x < input.dim_x; ++x) {
            for (uint y = 0; y < input.dim_y; ++y) {
                inputdata[pad_start + y * (input.dim_x + 2 * padw) + x] = test_array_1[x + y * input.dim_x];
            }
        }

        for (uint ix = 0; ix < output.dim_x; ++ix) {
            for (uint iy = 0; iy < output.dim_y; ++iy) {
                int64_t output_pixel = 0;
                for (uint kx = 0; kx < kernel_size; ++kx) {
                    for (uint ky = 0; ky < kernel_size; ++ky) {
                        int64_t input_pix = int64_t(inputdata[ix +
                                                              (input.dim_x + kernel_size - 1) * iy +
                                                              kx +
                                                              ky * (input.dim_x + kernel_size - 1)]);
                        int64_t kernel_pix = int64_t(kernel[kx + ky * kernel_size] >> kernel_load_shift_right);

                        output_pixel += input_pix * kernel_pix;
//                        printf("I (%i + %i, %i + %i) = %li, ", ix, kx, iy, ky, input_pix);
//                        printf("K (%i, %i) = %li, ", kx, ky, kernel_pix);
//                        printf("O  %li \n", output_pixel);
                    }
                }
                referenceresult[ix + iy * output.dim_y] = int16_t(
                        (uint64_t(output_pixel >> conv_result_shift_right)) >> store_shift_right);
            }
        }
    }

    cnt = (((uint64_t(aux_get_sys_time_hi())) << 32) + uint64_t(aux_get_sys_time_lo()));
    printf("    [done] (Risc-V Cycles): %llu (%llu ms)\n",
           (unsigned long long) cnt, (unsigned long long) (1000 * cnt / get_gpr_risc_freq()));

    printf("[Risc-V] Verification...\n");
    int fail = 0;
    int success = 0;
    int near = 0;
    for (uint i = 0; i < output.dim_x * output.dim_y; ++i) {
        int error = abs(result_array[i] - referenceresult[i]);
        if (error == 1) near++;
        if (error > 1) {
            fail++;
            if (fail <= 10)
                printf_error("[Verification Fail!] result[%i] = 0x%08x = %d but reference = 0x%08x = %d\n", i,
                             result_array[i], result_array[i],
                             referenceresult[i], referenceresult[i]);
        } else {
            success++;
            if (success <= 10)
                printf_success("[Verification] result[%i] = 0x%08x = %d\n", i, referenceresult[i], referenceresult[i]);
        }
//        if (fail >= 10) break;
    }
    if (fail > 0) {
        printf_error("[Verification Fail!] There were %i errors in executing the conv2d!\n", fail);
    } else {
        printf_success("[Verification succeeded!] There were no errors in executing the conv2d!\n");
        if (near > 0) {
            printf_warning("[Verification] Result %i times in range +/- 1!\n", near);
        }
    }
#ifndef SIMULATION
    }
#endif

//    printf("VPRO Result in 2D: \n");
//    for (int y = 0; y < output.dim_y; ++y) {
//        for (int x = 0; x < output.dim_x; ++x) {
//            int error = abs(result_array[x + y*output.dim_x] - referenceresult[x + y*output.dim_x]);
//            if (error > 1) {
//                printf_error("%4i, ", result_array[x + y*output.dim_x]);
//            } else {
//                printf_success("%4i, ", result_array[x + y*output.dim_x]);
//            }
//        }
//        printf("\n");
//    }

    printf("\nEnd");
    sim_stop();
    return 0;
}
