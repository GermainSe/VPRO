
#include <stdint.h>
#include <math.h>
#include <chrono>
#include <ctime>
#include <helper.h>
#include <segment_scheduling.h>
#include "configuration_loader/yolo_configuration.h"
#include <vpro.h>
#include <eisv.h>

#ifdef SIMULATION
/**
 * Configuration of the Simulation execution
 */
//#define PRINT_LAYER_INFO
//#define LOAD_ALL_LAYER_INPUT_FROM_REF_DATA
#define DUMP_EACH_LAYER_DATA_BINARY
#define DUMP_AND_VERIFY_INPUT_DATA
#define VERIFY_EACH_LAYER_DUMPED_DATA

#include <QProcess>
#include <cnn_struct.h>
#include "configuration_loader/yolo_loader.h"
#include "test.h"
#include <string>
#include "configuration_generation/BaseExtractor.h"

/**
 * copies data from local variable to main memory
 * @param mm_address byte addr in main memory
 * @param src src data pointer which will be dereferenced
 * @param length in 16-bit words
 */
void copy2MM(int mm_address, int16_t *src_start, const int16_t *src_end) {
    uint8_t data_low, data_high;
    uint32_t addr = 0;
//    for (int16_t *i = src_start; i < src_end; i++) {
    while (src_start < src_end) {
        data_low = uint8_t(*src_start % 256);
        data_high = uint8_t(*src_start >> 8);
        core_->dbgMemWrite(mm_address + addr * 2, &data_low);
        core_->dbgMemWrite(mm_address + addr * 2 + 1, &data_high);
        addr++;
        src_start++;
    }
}

#else // SIMULATION
#include <cnn_struct_reduced.h>
#include "riscv/riscv-csr.hpp"
using namespace riscv::csr;
#endif  // SIMULATION

//#define IGNORE_PRINTF 1
#ifdef IGNORE_PRINTF
#define printf(fmt, ...) (0)
#else
//#define RV_PRINT_LAYER_CYCLE_DETAILS
#endif


template<typename Layer>
void printLayer(Layer &l) {
    printf("############### Layer %i ############################# \n", (l.number) - 1);
    printf("type:                     %lx , data: %x / %i = %s\n", intptr_t(&(l.type)), l.type, l.type, print(l.type));
    printf("number :                  %lx , data: %x / %i\n", intptr_t(&(l.number)), (l.number), (l.number));
    printf("conv_result_shift_right : %lx , data: %x / %i \n", intptr_t(&(l.conv_result_shift_right)),
           (l.conv_result_shift_right), (l.conv_result_shift_right));
    printf("relu_6_shift_left :       %lx , data: %x / %i \n", intptr_t(&(l.relu_6_shift_left)), (l.relu_6_shift_left),
           (l.relu_6_shift_left));
    printf("bias_shift_right :        %lx , data: %x / %i \n", intptr_t(&(l.bias_shift_right)), (l.bias_shift_right),
           (l.bias_shift_right));
    printf("store_shift_right :       %lx , data: %x / %i \n", intptr_t(&(l.store_shift_right)), (l.store_shift_right),
           (l.store_shift_right));
    printf("residual_1_left_shift :   %lx , data: %x / %i \n", intptr_t(&(l.residual_1_left_shift)),
           (l.residual_1_left_shift), (l.residual_1_left_shift));
    printf("residual_0_left_shift :   %lx , data: %x / %i \n", intptr_t(&(l.residual_0_left_shift)),
           (l.residual_0_left_shift), (l.residual_0_left_shift));
    printf("pool.stride:              %lx , data: %x / %i \n", intptr_t(&(l.pool_stride)), (l.pool_stride),
           (l.pool_stride));
    printf("relu.type:                %lx , data: %x / %i = %s \n", intptr_t(&(l.relu_type)), l.relu_type, l.relu_type,
           print(l.relu_type));
    printf("pad.top:                  %lx , data: %x / %i \n", intptr_t(&(l.pad.top)), (l.pad.top), (l.pad.top));
    printf("pad.left:                 %lx , data: %x / %i \n", intptr_t(&(l.pad.left)), (l.pad.left), (l.pad.left));
    printf("pad.bottom:               %lx , data: %x / %i \n", intptr_t(&(l.pad.bottom)), (l.pad.bottom),
           (l.pad.bottom));
    printf("pad.right:                %lx , data: %x / %i \n", intptr_t(&(l.pad.right)), (l.pad.right), (l.pad.right));
    printf("pad.value:                %lx , data: %x / %i \n", intptr_t(&(l.pad.value)), (l.pad.value), (l.pad.value));
    printf("conv stride :             %lx , data: %x / %i \n", intptr_t(&(l.stride)), (l.stride), (l.stride));
    printf("conv kernel_length :      %lx , data: %x / %i \n", intptr_t(&(l.kernel_length)), (l.kernel_length),
           (l.kernel_length));
    printf("conv seg_out_w :          %lx , data: %x / %i \n", intptr_t(&(l.seg_out_w)), (l.seg_out_w), (l.seg_out_w));
    printf("conv seg_out_h :          %lx , data: %x / %i \n", intptr_t(&(l.seg_out_h)), (l.seg_out_h), (l.seg_out_h));
    printf("conv in_channels :        %lx , data: %x / %i \n", intptr_t(&(l.in_channels)), (l.in_channels),
           (l.in_channels));
    printf("conv out_channels :       %lx , data: %x / %i \n", intptr_t(&(l.out_channels)), (l.out_channels),
           (l.out_channels));
    printf("conv seg_in_w :           %lx , data: %x / %i \n", intptr_t(&(l.seg_in_w)), (l.seg_in_w), (l.seg_in_w));
    printf("conv seg_in_h :           %lx , data: %x / %i \n\n", intptr_t(&(l.seg_in_h)), (l.seg_in_h), (l.seg_in_h));
}



//----------------------------------------------------------------------------------
//----------------------------------Main--------------------------------------------
//----------------------------------------------------------------------------------
// Versioning
#define VERSION_MAJOR 0
#define VERSION_MINOR 1

#include <versioning.h>

char versionVersion[] = {
        VERSION_MAJOR_INIT, '.', VERSION_MINOR_INIT, '\0'
};
char completeVersion[] = {
        BUILD_YEAR_CH0, BUILD_YEAR_CH1, BUILD_YEAR_CH2, BUILD_YEAR_CH3,
        '-', BUILD_MONTH_CH0, BUILD_MONTH_CH1, '-', BUILD_DAY_CH0, BUILD_DAY_CH1,
        ' ', BUILD_HOUR_CH0, BUILD_HOUR_CH1,
        ':', BUILD_MIN_CH0, BUILD_MIN_CH1, ':', BUILD_SEC_CH0, BUILD_SEC_CH1, '\0'
};

#include "riscv/eisV_hardware_info.hpp"

#ifdef SIMULATION
void export_bin_weights_layer(int16_t *weights, int weights_memsize, int16_t *bias, int bias_memsize, int layernum) {
  std::stringstream ss;
  ss << "layer_" <<  std::setfill('0') << std::setw(3) << std::right << layernum << "_weights.bin";
  std::string fname = ss.str();
  
  std::ofstream fd(fname, std::ofstream::binary | std::ofstream::out);
  if (!fd){
    std::cout << "Could not open file " << fname << " for bin coeff export!\n";
  }
  fd.write(reinterpret_cast<char*>(weights), weights_memsize);
  fd.write(reinterpret_cast<char*>(bias), bias_memsize);
  fd.close();
}


void export_bin_weights() {
  std::string fname = "yololite_quantparams.inc";
  std::ofstream fd(fname, std::ofstream::binary | std::ofstream::out);
  if (!fd){
    std::cout << "Could not open file " << fname << " for quant param export!\n";
  }

#define _EXPORT_LAYER(NUM) do { \
    export_bin_weights_layer((int16_t*)Layer_##NUM::conv_weights, sizeof(Layer_##NUM::conv_weights), (int16_t*)Layer_##NUM::bias, sizeof(Layer_##NUM::bias), NUM); \
    fd << "l" << NUM << "->result_shift_right = " << Layer_##NUM::conv_result_shift_right << ";\n"; \
    fd << "l" << NUM << "->bias_shift_right   = " << Layer_##NUM::bias_load_shift_right   << ";\n"; \
    fd << "l" << NUM << "->store_shift_right  = " << Layer_##NUM::bias_store_shift_right  << ";\n"; \
  } while(0)
#define EXPORT_LAYER(NUM) _EXPORT_LAYER(NUM)

  EXPORT_LAYER(0);
  EXPORT_LAYER(1);
  EXPORT_LAYER(2);
  EXPORT_LAYER(3);
  EXPORT_LAYER(4);
  EXPORT_LAYER(5);
  EXPORT_LAYER(6);
  fd.close();
//  exit(0);
}
#endif // SIMULATION

int main(int argc, char *argv[]) {
    sim_init(main, argc, argv, HW);

#ifdef SIMULATION
    export_bin_weights();
#endif // SIMULATION

#define PRINT_HEADER
#ifdef PRINT_HEADER
    aux_print_hardware_info("YOLO_LITE CNN", versionVersion, completeVersion);
#endif

    
    // ARM Communication Register Indexes
    enum ARM_RV_Comm : uint32_t {
        rv_input_parsed = 128,
        rv_output_ready = 132,
        arm_input_ready = 136,
        arm_output_parsed = 140,
        rv_running = 144,
    };


#ifdef SIMULATION
    // initialize yolo layer config, weights and segments
    auto loader = yolo_loader(false, false, true);     // dma blocks ("interleaved" -> block, vpro, remaining dma)
//    auto loader = yolo_loader(false, true, false);     // interleaved (dma, vpro, dma, vpro, ...)
// yolo struct is initialized now
    TestManager tm;
#ifdef PRINT_LAYER_INFO
    loader.print(); // layer info
#endif
#ifdef LOAD_ALL_LAYER_INPUT_FROM_REF_DATA
    printf_info("LOAD_ALL_LAYER_INPUT_FROM_REF_DATA is set \n");
#endif
#ifdef DUMP_EACH_LAYER_DATA_BINARY
    printf_info("DUMP_EACH_LAYER_DATA_BINARY is set \n");
#endif
#ifdef DUMP_AND_VERIFY_INPUT_DATA
    printf_info("DUMP_AND_VERIFY_INPUT_DATA is set \n");
#endif
#ifdef VERIFY_EACH_LAYER_DUMPED_DATA
    printf_info("VERIFY_EACH_LAYER_DUMPED_DATA is set \n");
#endif
#endif  // SIMULATION

//    printLayer(yolo.layer[0]);
//    printLayer(yolo.layer[1]);
//    printLayer(yolo.layer[2]);
//    printLayer(yolo.layer[3]);
//    printLayer(yolo.layer[4]);
//    printLayer(yolo.layer[5]);
//    printLayer(yolo.layer[6]);

//    printf("Result will be at lcation: \n");
//    printf("\tBase: 0x%x\n", yolo.layer[layer_count - 1].output.mm_base);
//    printf("\tX: %d\n", yolo.layer[layer_count - 1].output.x);
//    printf("\tY: %d\n", yolo.layer[layer_count - 1].output.y);
//    printf("\tChannels: %d\n", yolo.layer[layer_count - 1].output.channels);

//    printf("Ready to start VPRO execution... \n");

    vpro_set_cluster_mask(0xFFFFFFFF);
    vpro_set_unit_mask(0xFFFFFFFF);

    GPR::write32(rv_output_ready, 0);
    GPR::write32(rv_input_parsed, 0);
    GPR::write32(rv_running, 1);
    GPR::write32(arm_input_ready, 1);
    GPR::write32(arm_output_parsed, 1);

#ifdef SIMULATION
    bool failed = false;
    QDir dir;
#ifdef DUMP_AND_VERIFY_INPUT_DATA
    dir.mkpath("../data/simulation_output/Layer_0/");
    printf_info("Dumping Input Channels...\n");
    for (int channel = 0; channel < yolo.layer[0].in_channels; ++channel) {
        QFile file(QString("../data/simulation_output/Layer_0/") +
                   QString("channel_") + QString::number(channel) + QString(".bin"));
        file.open(QIODevice::WriteOnly);
        QDataStream out(&file);
        for (unsigned long int y = 0; y < yolo.layer[0].input.y; y++) {
            for (unsigned long int x = 0; x < yolo.layer[0].input.x; x++) {
                uint32_t addr = yolo.layer[0].input.mm_base + 2 * (x + (yolo.layer[0].input.x +
                                                                        yolo.layer[0].input.x_stride) * y + channel *
                                                                                                            (yolo.layer[0].input.x +
                                                                                                             yolo.layer[0].input.x_stride) *
                                                                                                            yolo.layer[0].input.y);
                uint8_t rdata_low, rdata_high;
                core_->dbgMemRead(addr, &rdata_low);
                core_->dbgMemRead(addr + 1, &rdata_high);
                out << qint8(rdata_low);
                out << qint8(rdata_high);
            }
        }
        file.close();

        auto *verifyProcess = new QProcess();
        verifyProcess->start("diff", QStringList() <<
                                                   "../data/reference_c/binary/Layer_0/channel_" +
                                                   QString::number(channel) + ".bin" <<
                                                   "../data/simulation_output/Layer_0/channel_" +
                                                   QString::number(channel) + ".bin");

        verifyProcess->waitForFinished();
        QString s = QString(verifyProcess->readAllStandardOutput());
        if (!s.isEmpty()) {
            printf_error("Input Channels differ to data/reference_c/!? [Channel: %i]\n", channel);
            tm.addTest(Test("Layer Verification Input Data", "Channel " + std::to_string(channel), s.toStdString()));
            failed = true;
        } else {
            tm.addTest(Test("Layer Verification Input Data", "Channel " + std::to_string(channel)));
        }
        printf_info("Binary Input dumped to: %s [size: %i B]\n", file.fileName().toStdString().c_str(),
                    (yolo.layer[0].input.x + yolo.layer[0].input.x_stride) * yolo.layer[0].input.y * 2);
    }
#endif  // DUMP_AND_VERIFY_INPUT_DATA
#endif  // SIMULATION

    /**
     * MAIN LOOP to process images
     *
     * risc-v waits until arm_input_ready is set
     *  arm_input_ready set by arm
     *   arm_input_ready gets reset by eis-v
     *   rv_input_parsed set by eis-v
     *    rv_input_parsed gets reset by arm
     *
     * eis-v waits until arm_output_parsed is set
     *  arm_output_parsed gets reset by eis-v
     *  eis-v sets rv_output_ready
     *   rv_output_ready gets reset by arm
     *    arm_output_parsed set by arm
     */
    while (GPR::read32(rv_running) != 0) {
        uint64_t totalclock = 0;

#ifdef SIMULATION
        printf("\nMain loop is running. waiting for input ready...\n");
#else   // SIMULATION
        mcountinhibit_ops::write(0xffff);
        printf("\nMain loop is running. waiting for input ready...\n");
        mcountinhibit_ops::write(0x0000);
#endif  // SIMULATION

        while (GPR::read32(arm_input_ready) == 0 && GPR::read32(rv_running) != 0) {
            // wait for input data, aux_wait_cycles(2);
        }
        GPR::write32(arm_input_ready, 0);

        // reset DCMA to load new input into cache
        dcma_reset();

        uint32_t weights_addr_offsets[layer_count] = {};
#ifdef SIMULATION
        // load weights to mm
        for (unsigned int i = 0; i < layer_count; ++i) {
            int16_t *start = BaseExtractor::extract_kernel_base(const_cast<void *>(yolo.weights[i]),
                                                                yolo.layer[i].number);
            int16_t *end = &(BaseExtractor::extract_bias_base(const_cast<void *>(yolo.weights[i]),
                                                              yolo.layer[i].number)[yolo.layer[i].out_channels]);
            copy2MM(weights_addr_offsets[i], start, end);
            if (i < layer_count - 1) {
                weights_addr_offsets[i + 1] = weights_addr_offsets[i] + (end - start) * 2;
            }
        }
#else   // SIMULATION
        //        cycle_ops::write(0);
        //        cycleh_ops::write(0);
        //        instret_ops::write(0);
        //        instreth_ops::write(0);
                mhpmcounter13::write(0);
                mhpmcounter12::write(0);
                mhpmcounter14::write(0);
                mhpmcounter5::write(0);
                mhpmcounter6::write(0);
                mhpmcounter4_ops::write(0);
                mhpmcounter3_ops::write(0);
                mhpmcounter7::write(0);
                mhpmcounter8::write(0);
                mhpmcounter9::write(0);
                mhpmcounter10::write(0);
                aux_reset_all_stats();
        //        mcounteren_ops::write(0xffffffff);  // TODO: illegal instruction exception handler ... but it works (counts print cycles for "illegal...")
        //        mcounteren_ops::write(0x3);
        //            mcountinhibit_ops::write(0xffff); // no effect?!
#endif  // SIMULATION

        // start CNN
        for (unsigned int i = 0; i < layer_count; ++i) {

#ifdef RV_PRINT_LAYER_CYCLE_DETAILS
            printf("Layer %i \n", yolo.layer[i].number);
//            printf("Segments to process: %i\n", layer_segment_num[i]);
//            mcounteren_ops::write(0xffffffff);
#endif

            if (i == layer_count - 1) {    // final layer
                while (GPR::read32(arm_output_parsed) == 0 && GPR::read32(rv_running) != 0) {
                    // wait for output to be parsed from arm, aux_wait_cycles(2);
                }
                GPR::write32(arm_output_parsed, 0); // reset it
            }

            /**
             * Only execute specific layers
             *  requires: input data from previous layer (can be loaded from reference in Simulation)
             */
//            bool execute_layer = false;
//            for (auto ok: {5u}){
//                if (i == ok)
//                    execute_layer = true;
//            }
//            if (!execute_layer){
//                printf_warning("Skipping Layer %i / .number = %i (Simulation)\n", i, i+1);
//                continue;
//            }
#ifdef SIMULATION
/**
 * Load the input data from reference to avoid follow-up-errors
 */
#ifdef LOAD_ALL_LAYER_INPUT_FROM_REF_DATA
            printf_info("Loading Reference Channels Input Data for (previous) Layer %i ...\n",
                        yolo.layer[i].number - 1);
            for (int channel = 0; channel < yolo.layer[i].in_channels; ++channel) {
                QFile file(
                        QString("../data/reference_c/binary/Layer_") + QString::number(yolo.layer[i].number - 1) + "/" +
                        QString("channel_") + QString::number(channel) + QString(".bin"));
                file.open(QIODevice::ReadOnly);
                QDataStream in(&file);
                for (unsigned long int y = 0; y < yolo.layer[i].input.y; y++) {
                    for (unsigned long int x = 0; x < yolo.layer[i].input.x; x++) {
                        uint32_t addr = yolo.layer[i].input.mm_base + 2 * (x + (yolo.layer[i].input.x +
                                                                                yolo.layer[i].input.x_stride) * y +
                                                                           channel * (yolo.layer[i].input.x +
                                                                                      yolo.layer[i].input.x_stride) *
                                                                           yolo.layer[i].input.y);
                        int16_t wdata;
                        in >> wdata;
                        uint8_t wdata_low = wdata % 256;
                        uint8_t wdata_high = (wdata - wdata_low) >> 8;
                        core_->dbgMemWrite(addr, &wdata_low);
                        core_->dbgMemWrite(addr + 1, &wdata_high);
                    }
                }
                file.close();
                if (channel < 5 || (channel == yolo.layer[i].out_channels - 1)) {
                    printf_info("Loaded Layer %i Channel %i \n", yolo.layer[i].number - 1, channel);
                } else if (channel == 5) {
                    printf_info("...\n");
                }
            }
#endif
#endif
            aux_clr_sys_time();
#ifdef RV_PRINT_LAYER_CYCLE_DETAILS
            aux_reset_all_stats();
#endif
            calcLayer(yolo.layer[i], yolo.segments[i], yolo.weights[i], layer_segment_num[i], weights_addr_offsets[i]);
            uint32_t endclock = aux_get_sys_time_lo();
            totalclock += endclock;
            // if each layer is dumped, dcma flush is needed always
            // else only for last layer
#ifndef DUMP_EACH_LAYER_DATA_BINARY
            if (i == layer_count - 1) {
#endif
            dcma_flush();
#ifndef DUMP_EACH_LAYER_DATA_BINARY
            }
#endif

#ifdef RV_PRINT_LAYER_CYCLE_DETAILS
            //            mcounteren_ops::write(0);
                        aux_print_statistics();
                        printf("Stats have been reset before this Layer!\n");
                        printf("\tRisc Clock\t Layer: %i, \tAccumulated: %li\n", endclock, totalclock);
            //            mcounteren_ops::write(0xffffffff);
#endif

#ifdef SIMULATION
            int fails = 0;
#ifdef DUMP_EACH_LAYER_DATA_BINARY
            dir.mkpath("../data/simulation_output/Layer_" + QString::number(yolo.layer[i].number) + "/");
            printf_info("Layer %i / .number %i done. Dumping Output Channels...\n", i, yolo.layer[i].number);
            for (int channel = 0; channel < yolo.layer[i].out_channels; ++channel) {
                QFile file(
                        QString("../data/simulation_output/Layer_") + QString::number(yolo.layer[i].number) + "/" +
                        QString("channel_") + QString::number(channel) + QString(".bin"));
                file.open(QIODevice::WriteOnly);
                QDataStream out(&file);
                for (unsigned long int y = 0; y < yolo.layer[i].output.y; y++) {
                    for (unsigned long int x = 0; x < yolo.layer[i].output.x; x++) {
                        uint32_t addr = yolo.layer[i].output.mm_base +
                                        2 * (x + (yolo.layer[i].output.x + yolo.layer[i].output.x_stride) * y +
                                             channel * (yolo.layer[i].output.x + yolo.layer[i].output.x_stride) *
                                             yolo.layer[i].output.y);
                        uint8_t rdata_low, rdata_high;
                        core_->dbgMemRead(addr, &rdata_low);
                        core_->dbgMemRead(addr + 1, &rdata_high);
                        out << qint8(rdata_low);
                        out << qint8(rdata_high);
                    }
                }
                file.close();
                if (channel < 5 || (channel == yolo.layer[i].out_channels - 1)) {
                    printf_info("Binary Output dumped to: %s [size: %i B]\n", file.fileName().toStdString().c_str(),
                                (yolo.layer[0].input.x + yolo.layer[0].input.x_stride) * yolo.layer[0].input.y * 2);
                } else if (channel == 5) {
                    printf_info("...\n");
                }
#ifdef VERIFY_EACH_LAYER_DUMPED_DATA
                if (QFileInfo::exists("../data/reference_c/binary/Layer_" +
                                      QString::number(yolo.layer[i].number) + "/channel_" +
                                      QString::number(channel) + ".bin")) {
                    auto *verifyProcess = new QProcess();
                    verifyProcess->start("diff", QStringList() <<
                                                               "../data/reference_c/binary/Layer_" +
                                                               QString::number(yolo.layer[i].number) + "/channel_" +
                                                               QString::number(channel) + ".bin" <<
                                                               "../data/simulation_output/Layer_" +
                                                               QString::number(yolo.layer[i].number) + "/channel_" +
                                                               QString::number(channel) + ".bin");

                    verifyProcess->waitForFinished();
                    QString s = QString(verifyProcess->readAllStandardOutput());
                    if (!s.isEmpty()) {
                        if (channel < 4 || (channel == yolo.layer[i].out_channels - 1))
                            printf_error("Channels differ to data/reference_c/! [Channel: %i]\n", channel);
                        tm.addTest(Test("Layer Verification Dumped Data", "Channel " + std::to_string(channel),
                                        s.toUtf8().constData()));
                        fails++;
                    } else {
                        tm.addTest(Test("Layer Verification Dumped Data", "Channel " + std::to_string(channel)));
                    }
                } else {
                    fails++;
                    if (channel < 4 || (channel == yolo.layer[i].out_channels - 1))
                        printf_error(" Reference Data not found [Channel: %i]!\n", channel);
                }
#endif  // VERIFY_EACH_LAYER_DUMPED_DATA
            }   // for channel
#ifdef VERIFY_EACH_LAYER_DUMPED_DATA
            if (fails == 0) {
                printf_success("\nAll %i Output-Channels of Layer %i / .number: %i are verified successfull!\n\n",
                               yolo.layer[i].out_channels, i, yolo.layer[i].number);
            } else {
                printf_error("\n%i/%i Output-Channels of Layer %i / .number: %i are verified not successfull!\n\n",
                             fails, yolo.layer[i].out_channels, i, yolo.layer[i].number);
                failed = true;
            }
#endif  // VERIFY_EACH_LAYER_DUMPED_DATA
#endif  // DUMP_EACH_LAYER_DATA_BINARY
#endif  // SIMULATION
            if (i == 0) {    // first layer done
                GPR::write32(rv_input_parsed, 1);
            }
//            printf_info("yolo.layer[%i].output.mm_base: %i\n", i, yolo.layer[i].output.mm_base);
//            printf_info("yolo.layer[%i].output.x: %i\n", i, yolo.layer[i].output.x);
//            printf_info("yolo.layer[%i].output.x_stride: %i\n", i, yolo.layer[i].output.x_stride);
//            printf_info("yolo.layer[%i].output.y: %i\n", i, yolo.layer[i].output.y);
//            printf_info("yolo.layer[%i].output.channels: %i\n", i, yolo.layer[i].output.channels);
        } // layers

#ifdef SIMULATION
        tm.save();
#endif
        aux_print_statistics(totalclock);
#ifndef SIMULATION // reset stats of csr
        mhpmcounter13::write(0);
        mhpmcounter12::write(0);
        mhpmcounter14::write(0);
        mhpmcounter5::write(0);
        mhpmcounter6::write(0);
        mhpmcounter4_ops::write(0);
        mhpmcounter3_ops::write(0);
        mhpmcounter7::write(0);
        mhpmcounter8::write(0);
        mhpmcounter9::write(0);
        mhpmcounter10::write(0);
#endif
#ifdef SIMULATION
        unsigned int mhz = int(1000 / core_->getRiscClockPeriod());
#else   // SIMULATION
        unsigned int mhz = get_gpr_risc_freq()/1000/1000;
#endif  // SIMULATION

        unsigned int us_per_run = totalclock / mhz;
        assert(us_per_run > 0);
        unsigned int fps = 1000000 / us_per_run;
        unsigned int fps_frac = (100000000 / us_per_run) - fps * 100;
        GPR::write32(rv_output_ready, 1);
        printf("CNN Inference Completed! \n");
        printf("\tRisc-V Clock Cycles: %i, [%i MHz: %u,%02i ms, %i,%02i FPS]\n", (unsigned int) totalclock, mhz,
               us_per_run/1000, 100*us_per_run/1000 - us_per_run/1000 * 100 , fps, fps_frac);

#ifdef SIMULATION
        break;
#endif  // SIMULATION
        /**
         * continue with next input
         */
    }   // rv running endless loop

    aux_print_debugfifo(0xbeefdead);
    aux_print_debugfifo(0xbeef0000); // really dead!
    sim_stop();
    printf("############################\n[END] CNN Finished. Exiting Application.. [Pls Return to me a 0xcafe].\n");

#ifdef SIMULATION
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_core_inst/rst_ni 0 0
    // run 200ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_req_i 1 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_we_i 1 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_be_i 4'hf 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_addr_i 32'h3ffffff8 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_wdata_i 32'h11000000 0 -cancel 20ns
    // run 1000ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_req_i 1 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_we_i 1 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_be_i 4'hf 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_addr_i 32'h3ffffffc 0 -cancel 20ns
    // force -freeze sim:/tb/design_1_i/vpro_axi_subsys_i/VPRO_0/U0/eisV_top_inst/eisV_data_distributor_inst/eisV_wdata_i 32'h01000000 0 -cancel 20ns
    // run 1000ns
    exit((failed) ? 1 : 0);
#else   // SIMULATION
    // sim trigger dump
    // using block ram's dump feature
//    *((volatile uint32_t *) (0x3fff0000)) = 0x11000000; // base
//    *((volatile uint32_t *) (0x3fff1000)) = 0x01000000; // size + trigger
    exit(0xcafe); // return to crt0.asm and loop forever
#endif  // SIMULATION
}
