//
// Created by gesper on 08.03.24.
//

#ifndef PATARA_BASED_VERIFICATION_LANECHAININGFIFOOUT_H
#define PATARA_BASED_VERIFICATION_LANECHAININGFIFOOUT_H

#include "instructions/instruction.h"

class LaneChainingFifoOut {
   public:
    explicit LaneChainingFifoOut(LANE lane) : lane(lane) {}

    /**
     * The lane of this FIFO is generating data.
     * add to producing entry count
     * @param instr
     */
    void generateData(Instruction* instr);

    /**
     * Some lane is using the data from this fifo
     * @param instr
     */
    void consumeData(Instruction* instr);
    void consumeData(int count);

    /**
     * This lane reads from another lane's fifo (no data available)
     */
    void awaitData(LANE readLane, int count);

    [[nodiscard]] bool isBlocking() const;

    [[nodiscard]] int getEntryCount() const {
        return producingEntries;
    }

    [[nodiscard]] int getAwaitCount(LANE readLane) const {
        if (readLane == L0) {
            return awaitingEntries[0];
        } else if (readLane == L1) {
            return awaitingEntries[1];
        } else if (readLane == LS) {
            return awaitingEntries[2];
        }
        printf_error("AwaitCount read from invalid LANE!\n");
        return 0;
    }

    void printStatus() const;

    void reset();

   private:
    LANE lane;

    int producingEntries{0};
    int awaitingEntries[3] = {0, 0, 0};
};

#endif  //PATARA_BASED_VERIFICATION_LANECHAININGFIFOOUT_H
