//
// Created by gesper on 17.04.24.
//

#include "testsequences/ParallelConflictTest.h"
#include "instructions/loadstore/store.h"

bool ParallelConflictTest::nextInstruction(Instruction* pInstruction) {
    for (auto ln : {L0, L1, LS}) {
        if (runningChain[ln] > 0){
            remainingLength[ln]--;
            runningChain[ln]--;
        }
    }

    // if specific lane busy (chaining)
    //  -> blocking now [left in FIFO] -> top level will finish chains, then repeat
    if (pInstruction->getLane() == L0 && lane0 != nullptr) return false;
    if (pInstruction->getLane() == L1 && lane1 != nullptr) return false;
    if (pInstruction->getLane() == LS && lanels != nullptr) return false;
    if (pInstruction->getLane() == L0_1 && (lane0 != nullptr || lane1 != nullptr)) return false;
    if (!pInstruction->isInputChain() && !pInstruction->getIsChain()) {
        // no chaining. okay. exec is "done"
//        printf("no chaining! skipped check: %s\n", pInstruction->c_str());
        return true;
    }
//    printf_success("chaining instruction. check: %s\n", pInstruction->c_str());

    setInstr(pInstruction);
    addLength(pInstruction->getLength(), pInstruction->getLane());
//    printState();

    runChainsIfPresent();

    // cleanup
    for (auto ln : {L0, L1, LS}) {
        if (remainingLength[ln] == 0) unsetInstr(ln);
    }

    // this instruction (chain part) was stored. chain length extracted and saved if possible
    // instruction correctly done
    return true;
}

void ParallelConflictTest::runChainsIfPresentForOutChain(Instruction *outchain) {
    // extract chains which are runnable
    std::set<Instruction *> involvedLanes = getAvailableSourceLanes(outchain);
    involvedLanes.insert(outchain);

    // execute the chains which are runnable
    if (involvedLanes.size() == 3) {
        // three instr. chain
        Instruction* first = *std::next(involvedLanes.begin(), 0); // *involvedLanes.begin();
        Instruction* second = *std::next(involvedLanes.begin(), 1); // *(involvedLanes.begin()++);
        Instruction* third = *std::next(involvedLanes.begin(), 2); // *((involvedLanes.begin()++)++);
        auto length = getMaxChainLength(first, second, third);
//        printf_warning("three chain rdy! involved: %s, %s, %s, len: %i\n",
//            print(first->getLane()),
//            print(second->getLane()),
//            print(third->getLane()),
//            length);
        subLength(length, first->getLane());
        subLength(length, second->getLane());
        subLength(length, third->getLane());
    } else if (involvedLanes.size() == 2) {
        // two instr. chain
        Instruction* first = *std::next(involvedLanes.begin(), 0); // *involvedLanes.begin();
        Instruction* second = *std::next(involvedLanes.begin(), 1); // *(involvedLanes.begin()++);
        auto length = getMaxChainLength(first, second);
//        printf_warning("two chain rdy! involved: %s, %s, len: %i\n",
//            print(first->getLane()),
//            print(second->getLane()),
//            length);
        subLength(length, first->getLane());
        subLength(length, second->getLane());
    }
}

void ParallelConflictTest::runChainsIfPresent(){
    if (lane0 != nullptr && lane0->getIsChain()) {
        runChainsIfPresentForOutChain(lane0);
    }
    if (lane1 != nullptr && lane1->getIsChain()) {
        runChainsIfPresentForOutChain(lane1);
    }
    if (lanels != nullptr && lanels->getIsChain()) {
        runChainsIfPresentForOutChain(lanels);
    }
}

bool ParallelConflictTest::isBusy() {

    // finish chains
    finishChains();

    // cleanup
    for (auto ln : {L0, L1, LS}) {
        if (remainingLength[ln] == 0) unsetInstr(ln);
    }

    return (lane0 != nullptr || lane1 != nullptr || lanels != nullptr);
}

unsigned int ParallelConflictTest::getMaxChainLength(
    Instruction* first, Instruction* second, Instruction* third) {
    return min(min(remainingLength[first->getLane()] - runningChain[first->getLane()],
                   remainingLength[second->getLane()] - runningChain[second->getLane()]),
                   remainingLength[third->getLane()] - runningChain[third->getLane()]);
}
unsigned int ParallelConflictTest::getMaxChainLength(Instruction* first, Instruction* second) {
    return min(remainingLength[first->getLane()] - runningChain[first->getLane()],
               remainingLength[second->getLane()] - runningChain[second->getLane()]);
}
void ParallelConflictTest::addLength(unsigned int len, LANE lane) {
    remainingLength[lane] += len;
}
void ParallelConflictTest::subLength(unsigned int len, LANE lane) {
//    printf("SUB Len: remain[%s] = %i, sub: %i\n ", print(lane), remainingLength[lane], len);
//    assert(remainingLength[lane] >= len);
    runningChain[lane] += len;
//    remainingLength[lane] -= len;
}
void ParallelConflictTest::setInstr(Instruction* instr) {
    if (instr->getLane() == L0) {
        lane0 = instr;
    }
    if (instr->getLane() == L1) {
        lane1 = instr;
    }
    if (instr->getLane() == LS) {
        lanels = dynamic_cast<LoadStore*>(instr);
        assert(lanels != nullptr);
    }
    if (instr->getLane() == L0_1) {
        lane0 = instr;
        lane1 = instr;
    }
}

std::set<Instruction*> ParallelConflictTest::getAvailableSourceLanes(
    Instruction* instr, int depth) {
    std::set<Instruction*> lanes;
    assert(depth < 3);

    if (instr->getIsChain()) {
        switch (instr->getLane()) {
            case L0:
                if (lane1 != nullptr) {
                    if ((lane1->getSrc1()->getIsChain() &&
                            (lane1->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                lane1->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_RIGHT)) ||
                        (lane1->getSrc2()->getIsChain() &&
                            (lane1->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                lane1->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_RIGHT))) {
                        // lane1 uses (this)lane0 as src
                        if ((lane1->getSrc1()->getIsChain() &&
                                lane1->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LS) ||
                            (lane1->getSrc2()->getIsChain() &&
                                lane1->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LS)) {
                            // lane1 uses LS as well
                            assert(!lane1->getIsChain()); // it cannot use both + produce at same
                            if (lanels != nullptr && lanels->getIsChain()) {
                                lanes.insert(lane1);
                                lanes.insert(lanels);
                            }
                        } else {
                            if (lane1->getIsChain()) {
                                // lane1 produces as well
                                auto srclanes = getAvailableSourceLanes(lane1);
                                if (!srclanes.empty()) {
                                    lanes.insert(lane1);
                                    assert(srclanes.size() == 1);
                                    lanes.insert(*srclanes.begin());
                                }
                            } else {
                                lanes.insert(lane1);
                            }
                        }
                    }
                }
                if (lanels != nullptr) {
                    auto* i = dynamic_cast<Store*>(lanels);
                    if (i != nullptr) {
                        if (i->getSourceLane() == L0) {
                            lanes.insert(lanels);
                        }
                    }
                }
                break;
            case L1:
                if (lane0 != nullptr) {
                    if ((lane0->getSrc1()->getIsChain() &&
                            (lane0->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                lane0->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_RIGHT)) ||
                        (lane0->getSrc2()->getIsChain() &&
                            (lane0->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                lane0->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_RIGHT))) {
                        // lane0 uses (this)lane1 as src
                        if ((lane0->getSrc1()->getIsChain() &&
                                lane0->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LS) ||
                            (lane0->getSrc2()->getIsChain() &&
                                lane0->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LS)) {
                            // lane0 uses LS as well
                            assert(!lane0->getIsChain()); // it cannot use both + produce at same
                            if (lanels != nullptr && lanels->getIsChain()) {
                                lanes.insert(lane0);
                                lanes.insert(lanels);
                            }
                        } else {
                            if (lane0->getIsChain()) {
                                // lane0 produces as well
                                auto srclanes = getAvailableSourceLanes(lane0);
                                if (!srclanes.empty()) {
                                    lanes.insert(lane0);
                                    assert(srclanes.size() == 1);
                                    lanes.insert(*srclanes.begin());
                                }
                            } else {
                                lanes.insert(lane0);
                            }
                        }
                    }
                }
                if (lanels != nullptr) {
                    auto* i = dynamic_cast<Store*>(lanels);
                    if (i != nullptr) {
                        if (i->getSourceLane() == L1) {
                            lanes.insert(lanels);
                        }
                    }
                }
                break;
            case LS:
                if (lane0 != nullptr) {
                    if ((lane0->getSrc1()->getIsChain() &&
                            lane0->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LS) ||
                        (lane0->getSrc2()->getIsChain() &&
                            lane0->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LS)) {
                        if ((lane0->getSrc1()->getIsChain() &&
                                (lane0->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                    lane0->getSrc1()->getChainDir() ==
                                        Addressing::CHAIN_DIR_RIGHT)) ||
                            (lane0->getSrc2()->getIsChain() &&
                                (lane0->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                    lane0->getSrc2()->getChainDir() ==
                                        Addressing::CHAIN_DIR_RIGHT))) {
                            if (lane1 != nullptr && lane1->getIsChain()) {
                                lanes.insert(lane0);
                                lanes.insert(lane1);
                            }
                        } else {
                            if (lane0->getIsChain()) {
                                auto srclanes = getAvailableSourceLanes(lane0);
                                if (!srclanes.empty()) {
                                    lanes.insert(lane0);
                                    assert(srclanes.size() == 1);
                                    lanes.insert(*srclanes.begin());
                                }
                            } else {
                                lanes.insert(lane0);
                            }
                        }
                    }
                }
                if (lane1 != nullptr) {
                    if ((lane1->getSrc1()->getIsChain() &&
                            lane1->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LS) ||
                        (lane1->getSrc2()->getIsChain() &&
                            lane1->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LS)) {
                        if ((lane1->getSrc1()->getIsChain() &&
                                (lane1->getSrc1()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                    lane1->getSrc1()->getChainDir() ==
                                        Addressing::CHAIN_DIR_RIGHT)) ||
                            (lane1->getSrc2()->getIsChain() &&
                                (lane1->getSrc2()->getChainDir() == Addressing::CHAIN_DIR_LEFT ||
                                    lane1->getSrc2()->getChainDir() ==
                                        Addressing::CHAIN_DIR_RIGHT))) {
                            if (lane0 != nullptr && lane0->getIsChain()) {
                                lanes.insert(lane0);
                                lanes.insert(lane1);
                            }
                        } else {
                            if (lane1->getIsChain()) {
                                auto srclanes = getAvailableSourceLanes(lane1);
                                if (!srclanes.empty()) {
                                    lanes.insert(lane1);
                                    assert(srclanes.size() == 1);
                                    lanes.insert(*srclanes.begin());
                                }
                            } else {
                                lanes.insert(lane1);
                            }
                        }
                    }
                }
                break;
            case L0_1:
                if (lanels != nullptr) {
                    auto* i = dynamic_cast<Store*>(lanels);
                    if (i != nullptr) {
                        if (i->getSourceLane() == L0) {
                            lanes.insert(lanels);
                        }
                        if (i->getSourceLane() == L1) {
                            lanes.insert(lanels);
                        }
                    }
                }
                break;
        }
    }

    return lanes;
}
void ParallelConflictTest::unsetInstr(LANE lane) {
    switch (lane) {
        case L0:
            lane0 = nullptr;
            break;
        case L1:
            lane1 = nullptr;
            break;
        case LS:
            lanels = nullptr;
            break;
        default:
            printf_error("unsetlane not possuble. L0_1?!");
            exit(1);
    }
}
void ParallelConflictTest::printState() {
    printf("\t[L0]: ");
    if (lane0 != nullptr) {
        printf("%s: ", lane0->getInstructionName());
        printf("%s %s", lane0->getIsChain() ? "out" : "", lane0->isInputChain() ? "in" : "");
        printf(" %i\n", remainingLength[L0]);
    } else {
        printf("\n");
    }
    printf("\t[L1]: ");
    if (lane1 != nullptr) {
        printf("%s: ", lane1->getInstructionName());
        printf("%s %s", lane1->getIsChain() ? "out" : "", lane1->isInputChain() ? "in" : "");
        printf(" %i\n", remainingLength[L1]);
    } else {
        printf("\n");
    }
    printf("\t[LS]: ");
    if (lanels != nullptr) {
        printf("%s: ", lanels->getInstructionName());
        printf("%s %s", lanels->getIsChain() ? "out" : "", lanels->isInputChain() ? "in" : "");
        printf(" %i\n", remainingLength[LS]);
    } else {
        printf("\n");
    }
}
void ParallelConflictTest::finishChains() {
    // finish chains
    for (auto ln : {L0, L1, LS}) {
        if (runningChain[ln] > 0){
//            printf_info("Finishing %s\n", print(ln));
            if (runningChain[ln] > remainingLength[ln]){
                printf_error("Parallel fail!\n");
                printState();
                exit(1);
            } else {
                remainingLength[ln] -= runningChain[ln];
                runningChain[ln] = 0;
                if (remainingLength[ln] == 0) unsetInstr(ln);
            }
        }
    }
//    printState();
}
void ParallelConflictTest::tickChains() {
    finishChains();
}
