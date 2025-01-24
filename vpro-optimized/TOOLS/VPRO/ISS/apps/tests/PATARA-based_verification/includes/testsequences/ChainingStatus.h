//
// Created by gesper on 08.03.24.
//

#ifndef PATARA_BASED_VERIFICATION_CHAININGSTATUS_H
#define PATARA_BASED_VERIFICATION_CHAININGSTATUS_H

#include "LaneChainingFifoOut.h"
#include "instructions/processing/processing.h"
#include "instructions/loadstore/loadstore.h"
#include "instructions/loadstore/store.h"
#include "instructions/processing/processing.h"
#include "instructions/FifoMemory.h"

/**
 * For Random Generation, the generating process needs to keep track of chaining to avoid
 * deadlocks. This class represents the object with all relevant information to track the chaining
 * components of the generated instructions.
 */
class ChainingStatus {
   public:
    static constexpr int hazardCheckEntries = 6;

   private:
    LaneChainingFifoOut lsChain{LS};
    LaneChainingFifoOut l0Chain{L0};
    LaneChainingFifoOut l1Chain{L1};

    bool verbose = false;

    int getChainDataAvailableAmount(Addressing addr, LANE thisLane);

    bool areLanesLimitingIssue(Processing *proc_instr, uint &count, LANE thislane,
        LaneChainingFifoOut* other1, LANE other1ln,
        LaneChainingFifoOut* other2, LANE other2ln);

    /**
     * additional constraint for Hardware:
     *  if load -> L0, then L1 may not use load as source
     *      (chain is several cycles busy, no detection of new instruction begin)
     *  when source get filled
     */
    struct verticalChainBlocking_s{
        bool blockingActive{false};
        LANE sourceLane{};
        LANE blockCheckLane{};
        int blockCycles{};
    } verticalChainBlocking;

    bool lastInstrNoneBlockingOrOnlyLS{true};

    FifoMemory dstAddrBufferL0{};
    FifoMemory dstAddrBufferL1{};
    static void pushDstAddr(Processing* instr, FifoMemory &fifo);
    static bool isReadAddr(Processing* instr, FifoMemory& fifo);

    void issueIsPossible(Instruction* instr,
                         Processing *proc_instr,
                         LoadStore *ls_instr,
                         Store *s_instr);

   public:

    explicit ChainingStatus(bool verbose = false) : verbose(verbose) {reset();}

    bool issueIfPossible(Instruction* instr);

    void printStatus();

    [[nodiscard]] bool lsBlocking() const {return lsChain.isBlocking();}
    [[nodiscard]] bool l0Blocking() const {return l0Chain.isBlocking();}
    [[nodiscard]] bool l1Blocking() const {return l1Chain.isBlocking();}

    [[nodiscard]] int lsRemainingEntries() const {return lsChain.getEntryCount();}
    [[nodiscard]] int l0RemainingEntries() const {return l0Chain.getEntryCount();}
    [[nodiscard]] int l1RemainingEntries() const {return l1Chain.getEntryCount();}

    [[nodiscard]] int lsAwaitEntries(LANE ln) const {return lsChain.getAwaitCount(ln);}
    [[nodiscard]] int l0AwaitEntries(LANE ln) const {return l0Chain.getAwaitCount(ln);}
    [[nodiscard]] int l1AwaitEntries(LANE ln) const {return l1Chain.getAwaitCount(ln);}

    void updateChains();

    [[nodiscard]] bool isProcessingBroadcastInstructionChainPossible() const;

    void reset();
};

#endif  //PATARA_BASED_VERIFICATION_CHAININGSTATUS_H
