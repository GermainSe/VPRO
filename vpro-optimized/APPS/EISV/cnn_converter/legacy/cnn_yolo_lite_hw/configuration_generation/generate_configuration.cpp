//
// Created by gesper on 11.11.20.
//
#include <stdint.h>
#include <QFile>
#include <QRandomGenerator>

#include "yolo_lite_tf2.h" // CNN Weights
#include "../configuration_loader/yolo_configuration.h"

#include "LayerGeneration.h"
#include "SegmentGeneration.h"
#include "file_helper.h"
#include "segment_creation.h"
#include "../configuration_loader/yolo_loader.h"


//----------------------------------------------------------------------------------
//----------------------------------Main--------------------------------------------
//----------------------------------------------------------------------------------
int main(int argc, char *argv[]) {
    const QString layer_filename = "../bin/data/YOLO_config_layers.bin";
    const QString segments_filename = "../bin/data/YOLO_config_segments.bin";
    const QString weights_filename = "../bin/data/YOLO_config_weights.bin";

    auto loader = yolo_loader(true, false, true); // dma blocks ("interleaved" -> block, vpro, remaining dma)
//    auto loader = yolo_loader(true, true, false); // interleaved (dma, vpro, dma, vpro, ...)

    printf("HW Config: %i Clusters, %i Units per cl, %i parallel Lanes \n", VPRO_CFG::CLUSTERS, VPRO_CFG::UNITS, VPRO_CFG::parallel_Lanes);
    bool HW_SCORE_PRINT = false;
    if (HW_SCORE_PRINT) {
        LayerGeneration::printHWScore(loader.getLayers());
    }
//    loader.print(); // layer info

    printf_success("YOLO Layer defined! (Attributes loaded)\n");
    printf_success("YOLO Layer CONV Weights and Bias set! (Reference to weight arrays)\n");

    /**
     * Store Layer attributes to File
     */
    {
        printf("\n");
        std::string filename = layer_filename.toStdString();

        auto out = SaveNewObject(&(yolo.layer[0]), filename);
        for (unsigned int i = 1; i < layer_count; ++i) {
            SaveObject(out, &(yolo.layer[i]), filename);
        }
        out.close();
    }
    /**
     * Store WEIGHTS/BIAS attributes to File
     */
    {
        printf("\n");
        std::string filename = weights_filename.toStdString();
        // TODO: Check weights data!
        //     bias is correct but weights arent
#ifndef TESTRUN
        auto out = SaveNewObject(reinterpret_cast<WEIGHTS_REDUCED<3, 16> *>(yolo.weights[0]), filename);
        SaveObject(out, reinterpret_cast<WEIGHTS_REDUCED<16, 32> *>(yolo.weights[1]), filename);
        SaveObject(out, reinterpret_cast<WEIGHTS_REDUCED<32, 64> *>(yolo.weights[2]), filename);
        SaveObject(out, reinterpret_cast<WEIGHTS_REDUCED<64, 128> *>(yolo.weights[3]), filename);
        SaveObject(out, reinterpret_cast<WEIGHTS_REDUCED<128, 128> *>(yolo.weights[4]), filename);
        SaveObject(out, reinterpret_cast<WEIGHTS_REDUCED<128, 256> *>(yolo.weights[5]), filename);
        SaveObject(out, reinterpret_cast<WEIGHTS_REDUCED<256, 125, 1> *>(yolo.weights[6]), filename);
        out.close();
#else
        auto out = SaveNewObject(reinterpret_cast<WEIGHTS_REDUCED<TESTLAYER::test_layer_in_channels,TESTLAYER::test_layer_out_channels,TESTLAYER::test_layer_kernel> *>(yolo.weights[0]), filename);
        out.close();
#endif
    }

    /**
     * Store Command List to File
     */
    {
        auto list = loader.getCommandList();
        std::ofstream out;
        printf("\n");
        for (uint i = 0; i < layer_count; ++i) {
            QFile logfile(segments_filename + "_layer_" + QString::number(i) + "_log.txt");
            logfile.open(QIODevice::WriteOnly);
            int c = 0;
            for (auto &seg_index: list[i]) {
	            logfile.write("["+QString::number(c)+"]");
                logfile.write(commang_seg_qstring(seg_index));
                c++;
            }
            logfile.close();

            printf_info("%i B * %i Segments = %i kB\n", (sizeof(COMMAND_SEGMENT)), list[i].length(),
                        list[i].length() * (sizeof(COMMAND_SEGMENT)) / 1024);
            if (i == 0) {
                out = SaveNewObject(yolo.segments[i], segments_filename.toStdString(),
                                    list[i].length() * sizeof(COMMAND_SEGMENT));
            } else {
                SaveObject(out, yolo.segments[i], segments_filename.toStdString(),
                           list[i].length() * sizeof(COMMAND_SEGMENT));
            }
        }
    }

    printf("\n================================================================\n");
    printf("Binary files for Layer & Weights & Command Segments generated! \n");
    printf("================================================================\n");
#ifdef TESTRUN
    printf_warning("For Testrun..\n");
    printf_warning("Generating Random input data...\n");

    for (uint j = 0; j < yolo.layer[0].input.channels; ++j) {
        QString input_name = "../data/input"+QString::number(j)+"_rand_gen.bin";

        QVector<quint32> vector;
        vector.resize((yolo.layer[0].input.x + yolo.layer[0].input.x_stride)*yolo.layer[0].input.y); // 16-bit to out file...
        QRandomGenerator::global()->fillRange(vector.data(), vector.size());

        auto out = SaveNewObject(vector.data(), input_name.toStdString(), (yolo.layer[0].input.x + yolo.layer[0].input.x_stride)*yolo.layer[0].input.y*2);
        out.close();
        printf("Wrote out random Data for in channel %i with dimensions [ %i x %i ]\n", j, (yolo.layer[0].input.x + yolo.layer[0].input.x_stride), yolo.layer[0].input.y);
    }
#endif

    return 0;
}
