//
// Created by gesper on 24.06.22.
//

#ifndef CONV2DADD_STATISTICDMA_H
#define CONV2DADD_STATISTICDMA_H

#include <map>
#include "../../commands/CommandDMA.h"
#include "StatisticBase.h"

class StatisticDma : public StatisticBase {
    struct executedCommands_s {
        // counter of transferred elements
        uint32_t e2l_elements_transferred{0};
        uint32_t l2e_elements_transferred{0};

        // counter of command types
        uint32_t e2l_1d_transfer_cmds{0};
        uint32_t e2l_2d_transfer_cmds{0};
        uint32_t l2e_1d_transfer_cmds{0};
        uint32_t l2e_2d_transfer_cmds{0};

        void operator+=(const executedCommands_s& ref) {
            this->e2l_elements_transferred += ref.e2l_elements_transferred;
            this->l2e_elements_transferred += ref.l2e_elements_transferred;
            this->e2l_1d_transfer_cmds += ref.e2l_1d_transfer_cmds;
            this->e2l_2d_transfer_cmds += ref.e2l_2d_transfer_cmds;
            this->l2e_1d_transfer_cmds += ref.l2e_1d_transfer_cmds;
            this->l2e_2d_transfer_cmds += ref.l2e_2d_transfer_cmds;
        }
    };

   public:
    explicit StatisticDma(ISS* core);

    void tick() override;
    void addExecutedCommand(const CommandDMA* cmd, const int& cluster);

    void print(QString& output) override;
    void print_json(QString& output) override;

    void reset() override;

   private:
    unsigned long totalDMAActive = 0;
    unsigned long totalDMAInActive = 0;
    unsigned long anyDMAActive = 0;

    // for each cluster
    std::map<uint32_t, executedCommands_s> executedCommands{};
};

#endif  //CONV2DADD_STATISTICDMA_H
