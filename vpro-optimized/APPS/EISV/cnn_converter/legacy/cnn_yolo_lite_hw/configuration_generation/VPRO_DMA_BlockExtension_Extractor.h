//
// Created by gesper on 14.10.22.
//

#ifndef CNN_YOLO_LITE_HW_VPRO_DMA_BLOCKEXTENSION_EXTRACTOR_H
#define CNN_YOLO_LITE_HW_VPRO_DMA_BLOCKEXTENSION_EXTRACTOR_H

#include <helper.h>
#include <QList>

class VPRO_DMA_BlockExtension_Extractor {

public:
    VPRO_DMA_BlockExtension_Extractor(QList<COMMAND_SEGMENT> &command_final_list) :
            command_final_list(command_final_list) {

    }

    QList<COMMAND_SEGMENT> generate();

private:
    COMMAND_SEGMENT generate_DMABlock_Command(uint32_t count);

    QList<COMMAND_SEGMENT> &command_final_list;
};


#endif //CNN_YOLO_LITE_HW_VPRO_DMA_BLOCKEXTENSION_EXTRACTOR_H
