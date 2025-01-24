//
// Created by gesper on 06.03.19.
//

#include "CommandBase.h"

bool CommandBase::is_done() {
    return true;
}

void CommandBase::print_class_type(FILE* out) const {
    switch (class_type) {
        case BASE:
            fprintf(out, "BASE ");
            break;
        case DMA:
            fprintf(out, "DMA  ");
            break;
        case VPRO:
            fprintf(out, "VPRO ");
            break;
        case SIM:
            fprintf(out, "SIM  ");
            break;
        default:
            fprintf(out, "Unknown Class-Type");
    }
}

QString CommandBase::get_class_type() const {
    switch (class_type) {
        case BASE:
            return {"BASE "};
        case DMA:
            return {"DMA  "};
        case VPRO:
            return {"VPRO "};
        case SIM:
            return {"SIM  "};
        default:
            return {"Unknown Class-Type"};
    }
}
