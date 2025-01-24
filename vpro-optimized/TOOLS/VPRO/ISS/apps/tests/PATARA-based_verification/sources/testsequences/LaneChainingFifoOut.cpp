//
// Created by gesper on 08.03.24.
//

#include "testsequences/LaneChainingFifoOut.h"
#include "instructions/loadstore/loadstore.h"
#include "instructions/loadstore/store.h"
#include "instructions/processing/processing.h"

void LaneChainingFifoOut::generateData(Instruction* instr) {
    assert(instr->getIsChain() && "Instruction needs to have the chaining flag set!");
    assert(producingEntries <= 0 && "Lane still chaining out. This instruction locks cmd FIFO!");

    int element_count = (instr->getXEnd() + 1) * (instr->getYEnd() + 1) * (instr->getZEnd() + 1);
    producingEntries += element_count;
}

void LaneChainingFifoOut::consumeData(Instruction* instr) {
    auto proc_instr = dynamic_cast<Processing*>(instr);
    auto ls_instr = dynamic_cast<LoadStore*>(instr);
    auto s_instr = dynamic_cast<Store*>(instr);
    if (proc_instr != nullptr) {
        assert((proc_instr->getSrc1()->getIsChain() || proc_instr->getSrc2()->getIsChain()) &&
               "At least one Instruction Operands needs to use chaining!");
    } else if (ls_instr != nullptr) {
        assert(s_instr != nullptr && "Only store can consume chaining data!");
        assert(dynamic_cast<Store*>(instr)->getSourceLane() == lane &&
               "Store needs to use this lane!");
    }
    assert(lane != instr->getLane() && "Lane cannot consume its own data in chaining!");
    //    assert(filledEntries > 0 && "Lane not chaining");

    int element_count = (instr->getXEnd() + 1) * (instr->getYEnd() + 1) * (instr->getZEnd() + 1);
    producingEntries -= element_count;
}

void LaneChainingFifoOut::consumeData(int count) {
    //assert(producingEntries >= count); -> may read more than available -> in dept!
    producingEntries -= count;
}


bool LaneChainingFifoOut::isBlocking() const {
    if (producingEntries > 0) {  // holds data in its output fifo
        return true;
    }
    for (int awaitingEntrie : awaitingEntries) {  // waits for input data
        if (awaitingEntrie > 0) {
            return true;
        }
    }
    return false;
}

void LaneChainingFifoOut::awaitData(LANE readLane, int count) {
//    printf("Await new: %s, %i\n", print(readLane), count);
    assert(readLane == L0 || readLane == L1 || readLane == LS);
    if (readLane == L0) {
        awaitingEntries[0] += count;
    } else if (readLane == L1) {
        awaitingEntries[1] += count;
    } else if (readLane == LS) {
        awaitingEntries[2] += count;
    }
}

void LaneChainingFifoOut::printStatus() const {
    printf("Out FIFO Entries: %i -- Awaiting", producingEntries);
    LANE l = L0;
    for (int awaitingEntrie : awaitingEntries) {  // waits for input data
        printf(" [%s]: %i ", print(l) ,awaitingEntrie);

        if (l == L0) {
            l = L1;
        } else if (l == L1) {
            l = LS;
        }
    }
}
void LaneChainingFifoOut::reset() {
    producingEntries = 0;
    awaitingEntries[0] = 0;
    awaitingEntries[1] = 0;
    awaitingEntries[2] = 0;
}
