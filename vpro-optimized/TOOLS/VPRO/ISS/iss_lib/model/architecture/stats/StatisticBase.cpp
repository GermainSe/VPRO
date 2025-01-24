//
// Created by gesper on 24.06.22.
//

#include "StatisticBase.h"
#include "../../../simulator/helper/debugHelper.h"

StatisticBase::StatisticBase() {}

StatisticBase::StatisticBase(ISS* core) : core(core) {}

void StatisticBase::tick() {
    total_ticks++;
}

void StatisticBase::print(QString& output) {
    output.asprintf("Total Clock Ticks: %li \n", total_ticks);
}

void StatisticBase::reset() {
    total_ticks = 0;
}
