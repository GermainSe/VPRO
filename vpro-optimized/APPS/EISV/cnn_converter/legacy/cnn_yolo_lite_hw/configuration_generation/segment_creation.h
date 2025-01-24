//
// Created by gesper on 06.04.22.
//

#ifndef CNN_YOLO_LITE_HW_SEGMENT_CREATION_H
#define CNN_YOLO_LITE_HW_SEGMENT_CREATION_H

#include <QList>
#include <cnn_struct.h>

COMMAND_SEGMENT createSync();

QList<COMMAND_SEGMENT> *create_command_list(QList<QVector<SEGMENT *>> &segments, std::list<LAYER> &original_layers, bool set_base_addr_weights_to_elf_extraction = true, bool do_interleaving = false, bool do_dma_extension = false);

#endif //CNN_YOLO_LITE_HW_SEGMENT_CREATION_H
