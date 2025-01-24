//
// Created by gesper on 24.06.22.
//

#include "StatisticAxi.h"
#include "../../../simulator/ISS.h"
#include "../../../simulator/helper/debugHelper.h"

#include "JSONHelpers.h"

StatisticAxi::StatisticAxi(ISS* core) : StatisticBase(core) {}

void StatisticAxi::tick() {
    StatisticBase::tick();
}

void StatisticAxi::print(QString& output) {
    QTextStream out(&output);
    out.setRealNumberNotation(QTextStream::FixedNotation);
    out.setRealNumberPrecision(2);

    out << "[AXI]  Statistics, Clock: " << MAGENTA << 1000 / core->getAxiClockPeriod() << " MHz"
        << RESET_COLOR << ", Total Clock Ticks: " << total_ticks
        << ", Runtime: " << total_ticks * core->getAxiClockPeriod() << "ns \n";
    out << "\n";
}

void StatisticAxi::print_json(QString& output) {
    QTextStream out(&output);
    out << JSON_OBJ_BEGIN;
    out << JSON_FIELD_FLOAT("clock_period", core->getAxiClockPeriod()) << ",";
    out << JSON_FIELD_INT("total_ticks", total_ticks);
    out << JSON_OBJ_END;
}

void StatisticAxi::reset() {
    StatisticBase::reset();
}
