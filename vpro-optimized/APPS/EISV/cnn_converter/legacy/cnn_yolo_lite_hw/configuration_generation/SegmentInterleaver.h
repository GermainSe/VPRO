//
// Created by gesper on 06.04.22.
//

#ifndef CNN_YOLO_LITE_HW_SEGMENTINTERLEAVER_H
#define CNN_YOLO_LITE_HW_SEGMENTINTERLEAVER_H

#include <helper.h>

class SegmentInterleaver {

public:
    SegmentInterleaver(QList<COMMAND_SEGMENT> &command_final_list) :
            command_final_list(command_final_list) {

    }

    QList<COMMAND_SEGMENT> interleave();

private:
    QList<COMMAND_SEGMENT> &command_final_list;
};


#endif //CNN_YOLO_LITE_HW_SEGMENTINTERLEAVER_H
