//
// Created by gesper on 17.04.24.
//

#ifndef PATARA_BASED_VERIFICATION_PARALLELCONFLICTTEST_H
#define PATARA_BASED_VERIFICATION_PARALLELCONFLICTTEST_H

#include "instructions/instruction.h"
#include "instructions/loadstore/loadstore.h"
#include <set>

class ParallelConflictTest {

   public:
    ParallelConflictTest()= default;

    /**
     *
     * @param pInstruction
     * @return true if everything went fine
     */
    bool nextInstruction(Instruction* pInstruction);

    void tickChains();

    bool isBusy();

   private:

    unsigned int getMaxChainLength(Instruction* first, Instruction* second);
    unsigned int getMaxChainLength(Instruction* first, Instruction* second, Instruction* third);

    void addLength(unsigned int len, LANE lane);
    void subLength(unsigned int len, LANE lane);

    void runChainsIfPresent();
    void runChainsIfPresentForOutChain(Instruction *outchain);
    void finishChains();

    void setInstr(Instruction *instr);
    void unsetInstr(LANE lane);

    std::set<Instruction *> getAvailableSourceLanes(Instruction *instr, int depth = 0);

    // when stalling, these are remained to be produced
    unsigned int remainingLength[LS+1] = {0, 0, 0, 0, 0};
    unsigned int runningChain[LS+1] = {0, 0, 0, 0, 0};

    // when stalling these are currently blocking
    Instruction *lane0{nullptr};
    Instruction *lane1{nullptr};
    LoadStore *lanels{nullptr};

    void printState();
};

#endif  //PATARA_BASED_VERIFICATION_PARALLELCONFLICTTEST_H
