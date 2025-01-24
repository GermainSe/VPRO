//
// Created by gesper on 24.06.22.
//

#ifndef CONV2DADD_STATISTICRISC_H
#define CONV2DADD_STATISTICRISC_H

#include "StatisticBase.h"

class StatisticRisc : public StatisticBase {
   public:
    explicit StatisticRisc(ISS* core);

    void tick() override;

    void print(QString& output) override;
    void print_json(QString& output) override;

    void reset() override;
};

#endif  //CONV2DADD_STATISTICRISC_H
