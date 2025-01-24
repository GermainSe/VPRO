//
// Created by gesper on 24.06.22.
//

#ifndef CONV2DADD_STATISTICBASE_H
#define CONV2DADD_STATISTICBASE_H

#include <QString>

class ISS;

class StatisticBase {
   public:
    StatisticBase();
    explicit StatisticBase(ISS* core);

    virtual void tick();

    virtual void print(QString& output);
    virtual void print_json(QString& output){};

    virtual void reset();

   protected:
    ISS* core;

    long total_ticks{0};
};

#endif  //CONV2DADD_STATISTICBASE_H
