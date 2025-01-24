//
// Created by gesper on 08.03.24.
//

#include "testsequences/ChainingStatus.h"

int ChainingStatus::getChainDataAvailableAmount(const Addressing addr, const LANE thisLane) {
    if (addr.getIsChain()) {
        LaneChainingFifoOut* consumeFifo = nullptr;
        switch (addr.getChainDir()) {
            case Addressing::CHAIN_DIR_LEFT:
            case Addressing::CHAIN_DIR_RIGHT:
                if (thisLane == L0) {
                    consumeFifo = &l1Chain;
                } else {
                    consumeFifo = &l0Chain;
                }
                break;
            case Addressing::CHAIN_DIR_LS:
                consumeFifo = &lsChain;
                break;
        }
        assert(consumeFifo != nullptr);
        return consumeFifo->getEntryCount();
    }
    return -1;
}

bool ChainingStatus::areLanesLimitingIssue(Processing *proc_instr, uint &count, LANE thislane,
    LaneChainingFifoOut* other1, LANE other1ln,
    LaneChainingFifoOut* other2, LANE other2ln){

    if (other1->isBlocking() && other2->isBlocking()) {
        // both other are blocking, this needs to be no chain or feed others (finish or fill + end)

        // not issuable if input chain data is not available
        if (proc_instr->getSrc1()->getIsChain())
            if (getChainDataAvailableAmount(*proc_instr->getSrc1(), proc_instr->getLane()) < count)
                return true;
        if (proc_instr->getSrc2()->getIsChain())
            if (getChainDataAvailableAmount(*proc_instr->getSrc2(), proc_instr->getLane()) < count)
                return true;

        // use of this chain data only if no deadlock is produced
        if (proc_instr->getIsChain()) {
            bool ok = false;
            if (other1->getAwaitCount(thislane) > 0){
                if (other1->getAwaitCount(thislane) >= count){
                    // other1 uses all/more this data. this instruction gets finished
                    if (other1->getAwaitCount(other2ln) > 0) {  // 3rd is also input
                        int chainAmount = min(other2->getEntryCount(), other1->getAwaitCount(other2ln));
                        assert(chainAmount >= 0);
                        if (chainAmount > count)    // ls has not all data -> would block / deadlock
                            return true;
                    }
                    ok = true;
                } else {
                    // l1 uses part of this data. l1 instruction gets finished
                    ok = true;
                }
                if (other1->getEntryCount() > 0) {  // is producing as well
                    // not possible if this lane is producing (but 3rd not using...)
                    ok = false; //if (other2->getAwaitCount(other1ln))
                    // TODO: possible if 3rd is using all (not if there are further dependencies)
                }
            }
            if (other2->getAwaitCount(thislane) > 0){
                if (other2->getAwaitCount(thislane) >= count){
                    // ls uses all/more this data. this instruction gets finished
                    if (other2->getAwaitCount(other1ln) > 0) {  // l0 also input
                        int chainAmount = min(other1->getEntryCount(), other2->getAwaitCount(other1ln));
                        if (chainAmount > count)    // l0 has not all data -> would block / deadlock
                            return true;
                    }
                    ok = true;
                } else {
                    // ls uses part of this data. ls instruction gets finished
                    ok = true;
                }
                if (other2->getEntryCount() > 0) {  // is producing as well
                    // not possible if this lane is producing (but 2nd not using...)
                    ok = false; //if (other1->getAwaitCount(other2ln))
                    // TODO: possible if 2nd is using all (not if there are further dependencies)
                }
            }
            if (!ok) return true;
        }
    }
    return false;
}

bool ChainingStatus::issueIfPossible(Instruction* instr) {
    LaneChainingFifoOut* consumeFifoSrc1 = nullptr;
    LaneChainingFifoOut* consumeFifoSrc2 = nullptr;

    auto proc_instr = dynamic_cast<Processing*>(instr);
    auto ls_instr = dynamic_cast<LoadStore*>(instr);
    auto s_instr = dynamic_cast<Store*>(instr);

    //    if (verbose) {
    //        printf("[Chain Check]");
    //        printf(" %s\n", instr->c_str());
    //    }
    uint count = instr->getLength();
    if (proc_instr != nullptr) {                     // processing instruction
        if (instr->getLane() == L0) {                // lane 0 only
            if (l0Chain.isBlocking()) return false;  // lane 0 is rdy
            if (areLanesLimitingIssue(proc_instr, count, L0, &l1Chain, L1, &lsChain, LS)){
                return false;
            }
            if (isReadAddr(proc_instr, dstAddrBufferL0)) return false;
            if (proc_instr->getSrc1()->getIsChain()) {
                switch (proc_instr->getSrc1()->getChainDir()) {
                    case Addressing::CHAIN_DIR_LEFT:
                    case Addressing::CHAIN_DIR_RIGHT:
                        consumeFifoSrc1 = &l1Chain;
                        break;
                    case Addressing::CHAIN_DIR_LS:
                        consumeFifoSrc1 = &lsChain;
                        break;
                }
            }
            if (proc_instr->getSrc2()->getIsChain()) {
                switch (proc_instr->getSrc2()->getChainDir()) {
                    case Addressing::CHAIN_DIR_LEFT:
                    case Addressing::CHAIN_DIR_RIGHT:
                        consumeFifoSrc2 = &l1Chain;
                        break;
                    case Addressing::CHAIN_DIR_LS:
                        consumeFifoSrc2 = &lsChain;
                        break;
                }
            }
            if(verticalChainBlocking.blockingActive){
                if (verticalChainBlocking.blockCheckLane != L0){
                    if (verticalChainBlocking.sourceLane == LS){
                        if (consumeFifoSrc2 == &lsChain || consumeFifoSrc1 == &lsChain)
                            return false;
                    } else if (verticalChainBlocking.sourceLane == L1){
                        if (consumeFifoSrc2 == &l1Chain || consumeFifoSrc1 == &l1Chain)
                            return false;
                    }
                }
            }
            // L0 done
        } else if (instr->getLane() == L1) {         // lane 1 only
            if (l1Chain.isBlocking()) return false;  // lane 1 rdy
            if (areLanesLimitingIssue(proc_instr, count, L1, &l0Chain, L0, &lsChain, LS)){
                return false;
            }
            if (isReadAddr(proc_instr, dstAddrBufferL1)) return false;
            if (proc_instr->getSrc1()->getIsChain()) {
                switch (proc_instr->getSrc1()->getChainDir()) {
                    case Addressing::CHAIN_DIR_LEFT:
                    case Addressing::CHAIN_DIR_RIGHT:
                        consumeFifoSrc1 = &l0Chain;
                        break;
                    case Addressing::CHAIN_DIR_LS:
                        consumeFifoSrc1 = &lsChain;
                        break;
                }
            }
            if (proc_instr->getSrc2()->getIsChain()) {
                switch (proc_instr->getSrc2()->getChainDir()) {
                    case Addressing::CHAIN_DIR_LEFT:
                    case Addressing::CHAIN_DIR_RIGHT:
                        consumeFifoSrc2 = &l0Chain;
                        break;
                    case Addressing::CHAIN_DIR_LS:
                        consumeFifoSrc2 = &lsChain;
                        break;
                }
            }
            if(verticalChainBlocking.blockingActive){
                if (verticalChainBlocking.blockCheckLane != L1) {
                    if (verticalChainBlocking.sourceLane == LS){
                        if (consumeFifoSrc2 == &lsChain || consumeFifoSrc1 == &lsChain)
                            return false;
                    } else if (verticalChainBlocking.sourceLane == L0){
                        if (consumeFifoSrc2 == &l0Chain || consumeFifoSrc1 == &l0Chain)
                            return false;
                    }
                }
            }
            // L1 done
        } else if (instr->getLane() == L0_1) {  // L0_1
            if (l0Chain.isBlocking() || l1Chain.isBlocking()) return false;
            if (lsChain.isBlocking()) {
                if (instr->getIsChain()) {  // L0_1 produces
                    // ls either uses L0 or L1
                    // if smaller than count, ls becomes free, if larger, L0/L1 becomes free
                    // second lane is still blocking!
                    if (lsChain.getAwaitCount(L0) != 0 || lsChain.getAwaitCount(L1) != 0)
                        return false;
                    // if ls also produces. this is a deadlock
                    if (lsChain.getEntryCount() != 0) return false;
                } else if (proc_instr->getSrc1()->getIsChain() ||
                           proc_instr->getSrc2()->getIsChain()){ // uses LS
                    if (lsChain.getEntryCount() == 0) return false;
                    if (lsChain.getAwaitCount(L0) != 0 || lsChain.getAwaitCount(L1) != 0)
                        return false;
                }
            }
            if (isReadAddr(proc_instr, dstAddrBufferL0) || isReadAddr(proc_instr, dstAddrBufferL1)) return false;
            if (proc_instr->getSrc1()->getIsChain()) {
                switch (proc_instr->getSrc1()->getChainDir()) {
                    case Addressing::CHAIN_DIR_LEFT:
                    case Addressing::CHAIN_DIR_RIGHT:
                        assert(false && "L0_1 cannot use L0/L1 chain in operands! Deadlock!");
                        break;
                    case Addressing::CHAIN_DIR_LS:
                        consumeFifoSrc1 = &lsChain;
                        break;
                }
            }
            if (proc_instr->getSrc2()->getIsChain()) {
                switch (proc_instr->getSrc2()->getChainDir()) {
                    case Addressing::CHAIN_DIR_LEFT:
                    case Addressing::CHAIN_DIR_RIGHT:
                        assert(false && "L0_1 cannot use L0/L1 chain in operands! Deadlock!");
                        break;
                    case Addressing::CHAIN_DIR_LS:
                        consumeFifoSrc2 = &lsChain;
                        break;
                }
            }
            if(verticalChainBlocking.blockingActive){
                if (!(verticalChainBlocking.blockCheckLane == L1 || verticalChainBlocking.blockCheckLane == L0)) {
                    if (verticalChainBlocking.sourceLane == LS) {
                        if (consumeFifoSrc2 == &lsChain || consumeFifoSrc1 == &lsChain)
                            return false;
                    }
                }
            }
            if (consumeFifoSrc2 == &lsChain || consumeFifoSrc1 == &lsChain) {
                assert(!proc_instr->getIsChain() &&
                       "L0_1 cannot use and produce data in same instruction");
            }
            // L0_1 done
        }
    } else if (ls_instr != nullptr) {  // LS instruction
        if (lsChain.isBlocking()) return false;
        if (l1Chain.isBlocking() && l0Chain.isBlocking()){
            if (ls_instr->getIsChain()){ // load
                if (l1Chain.getAwaitCount(LS) == 0 && l0Chain.getAwaitCount(LS) == 0)
                    // no one uses load data -> deadlock  // TODO: check if other dependent on other?!
                    return false;
            } else { // store
                if (l1Chain.getEntryCount() == 0 && l0Chain.getEntryCount() == 0)
                    // no one produces store data -> deadlock // TODO: check if other dependent on other?!
                    return false;
            }
        }
        if (s_instr != nullptr) {
            switch (s_instr->getSourceLane()) {
                case L0:
                    consumeFifoSrc1 = &l0Chain;
                    break;
                case L1:
                    consumeFifoSrc1 = &l1Chain;
                    break;
                default:
                    assert(false && "Store either uses L0 or L1!");
            }
            assert(!ls_instr->getIsChain() && "Store cannot produce data");
            if(verticalChainBlocking.blockingActive){
                if (verticalChainBlocking.blockCheckLane != LS) {
                    if(verticalChainBlocking.sourceLane == L0){
                        if (consumeFifoSrc2 == &l0Chain || consumeFifoSrc1 == &l0Chain)
                            return false;
                    } else if (verticalChainBlocking.sourceLane == L1){
                        if (consumeFifoSrc2 == &l1Chain || consumeFifoSrc1 == &l1Chain)
                            return false;
                    }
                }
            }
        } else {  // LOAD
            assert(instr->getIsChain() && "Load instruction needs to be chain!");
        }
        // LS done
    } else {
        assert(false && "instance of either LoadStore or Processing!");
    }

    issueIsPossible(instr, proc_instr, ls_instr, s_instr);
    return true;
}

void ChainingStatus::printStatus() {
    printf("[Chain LS]: ");
    lsChain.printStatus();
    printf("\n[Chain L0]: ");
    l0Chain.printStatus();
    printf("\n[Chain L1]: ");
    l1Chain.printStatus();
    printf("\n");
}

void ChainingStatus::updateChains() {
    bool l0_to_ls = false;
    bool l0_to_l1 = false;
    bool ls_to_l0 = false;
    bool ls_to_l1 = false;
    bool l1_to_ls = false;
    bool l1_to_l0 = false;
    int count;

    int l0_getReads = 0;
    int l1_getReads = 0;
    int ls_getReads = 0;

    int l0readCount_l1 = 0, lsreadCount_l1 = 0;
    if (l1Chain.getEntryCount() > 0) {
        if (l0Chain.getAwaitCount(L1) != 0) {
            if (l0Chain.getAwaitCount(LS) != 0) // if it also reads from LS
                l0readCount_l1 = min(min(l0Chain.getAwaitCount(L1), l1Chain.getEntryCount()),
                    min(l0Chain.getAwaitCount(LS), lsChain.getEntryCount())
                );
            else
                l0readCount_l1 = min(l0Chain.getAwaitCount(L1), l1Chain.getEntryCount());
        }
        if (lsChain.getAwaitCount(L1) != 0) {   // LS only reads from one other lane
            lsreadCount_l1 = min(lsChain.getAwaitCount(L1), l1Chain.getEntryCount());
        }
        if (l0readCount_l1 > 0 || lsreadCount_l1 > 0) {
            count = max(l0readCount_l1, lsreadCount_l1);
            l1_to_ls = count;
            l1_to_l0 = count;
            l1_getReads = count;
        }
    }
    int l1readCount_l0 = 0, lsreadCount_l0 = 0;
    if (l0Chain.getEntryCount() > 0) {
        if (l1Chain.getAwaitCount(L0) != 0) {
            if (l1Chain.getAwaitCount(LS) != 0)
                l1readCount_l0 = min(min(l1Chain.getAwaitCount(L0), l0Chain.getEntryCount()),
                    min(l1Chain.getAwaitCount(LS), lsChain.getEntryCount())
                );
            else
                l1readCount_l0 = min(l1Chain.getAwaitCount(L0), l0Chain.getEntryCount());
        }
        if (lsChain.getAwaitCount(L0) != 0) {
            lsreadCount_l0 = min(lsChain.getAwaitCount(L0), l0Chain.getEntryCount());
        }
        if (l1readCount_l0 > 0 || lsreadCount_l0 > 0) {
            count = max(l1readCount_l0, lsreadCount_l0);
            l0_to_ls = count;
            l0_to_l1 = count;
            l0_getReads = count;
        }
    }
    int l0readCount_ls = 0, l1readCount_ls = 0;
    if (lsChain.getEntryCount() > 0) {
        if (l0Chain.getAwaitCount(LS) > 0) {
            if (l0Chain.getAwaitCount(L1) != 0)
                l0readCount_ls = min(min(l0Chain.getAwaitCount(LS), lsChain.getEntryCount()),
                    min(l0Chain.getAwaitCount(L1), l1Chain.getEntryCount())
                );
            else
                l0readCount_ls = min(l0Chain.getAwaitCount(LS), lsChain.getEntryCount());
        }
        if (l1Chain.getAwaitCount(LS) > 0) {
            if (l1Chain.getAwaitCount(L0) != 0)
                l1readCount_ls = min(min(l1Chain.getAwaitCount(LS), lsChain.getEntryCount()),
                    min(l1Chain.getAwaitCount(L0), l0Chain.getEntryCount())
                );
            else
                l1readCount_ls = min(l1Chain.getAwaitCount(LS), lsChain.getEntryCount());
        }
        if (l0readCount_ls > 0 || l1readCount_ls > 0) {
            count = max(l0readCount_ls, l1readCount_ls);
            ls_to_l0 = count;
            ls_to_l1 = count;
            ls_getReads = count;
        }
    }

    // l0 output is read
    if (l0_getReads > 0){
        // check if l0 reads data as well
        if (l0Chain.getAwaitCount(L1) > 0) {
            l0_getReads = min(l0_getReads, -l0readCount_l1);
        }
        if (l0Chain.getAwaitCount(LS) > 0) {
            l0_getReads = min(l0_getReads, -l0readCount_ls);
        }
        if (l0readCount_l1 < 0)
            l0readCount_l1 = -l0_getReads;
        if (l0readCount_ls < 0)
            l0readCount_ls = -l0_getReads;
    }
    l0Chain.consumeData(l0_getReads);
    l0Chain.awaitData(L1, -l0readCount_l1);
    l0Chain.awaitData(LS, -l0readCount_ls);

    // l1 output is read
    if (l1_getReads > 0){
        // check if l1 reads data as well
        if (l1Chain.getAwaitCount(L0) > 0) {
            l1_getReads = min(l1_getReads, -l1readCount_l0);
        }
        if (l1Chain.getAwaitCount(LS) > 0) {
            l1_getReads = min(l1_getReads, -l1readCount_ls);
        }
        if (l1readCount_l0 < 0)
            l1readCount_l0 = -l1_getReads;
        if (l1readCount_ls < 0)
            l1readCount_ls = -l1_getReads;
    }
    l1Chain.consumeData(l1_getReads);
    l1Chain.awaitData(L0, -l1readCount_l0);
    l1Chain.awaitData(LS, -l1readCount_ls);

    // ls output is read
    if (ls_getReads > 0){
        // check if ls reads data as well
        if (lsChain.getAwaitCount(L0) > 0) {
            ls_getReads = min(ls_getReads, -lsreadCount_l0);
        }
        if (lsChain.getAwaitCount(L1) > 0) {
            ls_getReads = min(ls_getReads, -lsreadCount_l1);
        }
        if (lsreadCount_l0 < 0)
            lsreadCount_l0 = -ls_getReads;
        if (lsreadCount_l1 < 0)
            lsreadCount_l1 = -ls_getReads;
    }
    lsChain.consumeData(ls_getReads);
    lsChain.awaitData(L0, -lsreadCount_l0);
    lsChain.awaitData(LS, -lsreadCount_l1);

    if(l0_to_ls){
        verticalChainBlocking.blockingActive = true;
        verticalChainBlocking.blockCycles = l0_to_ls;
        verticalChainBlocking.blockCheckLane = LS;
        verticalChainBlocking.sourceLane = L0;
    }
    if(l0_to_l1){
        verticalChainBlocking.blockingActive = true;
        verticalChainBlocking.blockCycles = l0_to_l1;
        verticalChainBlocking.blockCheckLane = L1;
        verticalChainBlocking.sourceLane = L0;
    }
    if(ls_to_l0){
        verticalChainBlocking.blockingActive = true;
        verticalChainBlocking.blockCycles = ls_to_l0;
        verticalChainBlocking.blockCheckLane = L0;
        verticalChainBlocking.sourceLane = LS;
    }
    if(ls_to_l1){
        verticalChainBlocking.blockingActive = true;
        verticalChainBlocking.blockCycles = ls_to_l1;
        verticalChainBlocking.blockCheckLane = L1;
        verticalChainBlocking.sourceLane = LS;
    }
    if(l1_to_ls){
        verticalChainBlocking.blockingActive = true;
        verticalChainBlocking.blockCycles = l1_to_ls;
        verticalChainBlocking.blockCheckLane = LS;
        verticalChainBlocking.sourceLane = L1;
    }
    if(l1_to_l0){
        verticalChainBlocking.blockingActive = true;
        verticalChainBlocking.blockCycles = l1_to_l0;
        verticalChainBlocking.blockCheckLane = L0;
        verticalChainBlocking.sourceLane = L1;
    }

    //    called after generatedata(...)
}


bool ChainingStatus::isProcessingBroadcastInstructionChainPossible() const {
    return lastInstrNoneBlockingOrOnlyLS;
}
void ChainingStatus::reset() {
    lastInstrNoneBlockingOrOnlyLS = true;
    l0Chain.reset();
    l1Chain.reset();
    lsChain.reset();
    verticalChainBlocking.blockingActive = false;
    dstAddrBufferL0.reset();
    dstAddrBufferL1.reset();
}

void ChainingStatus::issueIsPossible(Instruction* instr,
                                     Processing *proc_instr,
                                     LoadStore *ls_instr,
                                     Store *s_instr) {
    uint count = instr->getLength();

    if (proc_instr != nullptr) {                     // processing instruction
        LaneChainingFifoOut *consumeFifoSrc1 = nullptr;
        LaneChainingFifoOut *consumeFifoSrc2 = nullptr;
        if (proc_instr->getSrc1()->getIsChain()) {
            switch (proc_instr->getSrc1()->getChainDir()) {
                case Addressing::CHAIN_DIR_LEFT:
                case Addressing::CHAIN_DIR_RIGHT:
                    if (instr->getLane() == L0)
                        consumeFifoSrc1 = &l1Chain;
                    else    // L1
                        consumeFifoSrc1 = &l0Chain;
                    break;
                case Addressing::CHAIN_DIR_LS:
                    consumeFifoSrc1 = &lsChain;
                    break;
            }
        }
        if (proc_instr->getSrc2()->getIsChain()) {
            switch (proc_instr->getSrc2()->getChainDir()) {
                case Addressing::CHAIN_DIR_LEFT:
                case Addressing::CHAIN_DIR_RIGHT:
                    if (instr->getLane() == L0)
                        consumeFifoSrc2 = &l1Chain;
                    else    // L1
                        consumeFifoSrc2 = &l0Chain;
                    break;
                case Addressing::CHAIN_DIR_LS:
                    consumeFifoSrc2 = &lsChain;
                    break;
            }
        }
        if (instr->getLane() == L0) {                // lane 0 only
            // L0
            if(verticalChainBlocking.blockingActive){
                if (verticalChainBlocking.blockCheckLane == L0)
                    verticalChainBlocking.blockingActive = false;
                else {
                    verticalChainBlocking.blockCycles -= (int)count;
                    if (verticalChainBlocking.blockCycles <= 0)
                        verticalChainBlocking.blockingActive = false;
                }
            }
            if (consumeFifoSrc2 == &lsChain || consumeFifoSrc1 == &lsChain) {
                l0Chain.awaitData(LS, (int)count);
            }
            if (consumeFifoSrc2 == &l1Chain || consumeFifoSrc1 == &l1Chain) {
                l0Chain.awaitData(L1, (int)count);
            }
            if (proc_instr->getIsChain()) {
                l0Chain.generateData(instr);
            }
            // for hazard detection remember last dst addresses of this instruction
            pushDstAddr(proc_instr, dstAddrBufferL0);
        } else if (instr->getLane() == L1){
            // L1
            if(verticalChainBlocking.blockingActive){
                if (verticalChainBlocking.blockCheckLane == L1)
                    verticalChainBlocking.blockingActive = false;
                else{
                    verticalChainBlocking.blockCycles -= (int)count;
                    if (verticalChainBlocking.blockCycles <= 0)
                        verticalChainBlocking.blockingActive = false;
                }
            }
            if (consumeFifoSrc2 == &lsChain || consumeFifoSrc1 == &lsChain) {
                l1Chain.awaitData(LS, (int)count);
            }
            if (consumeFifoSrc2 == &l0Chain || consumeFifoSrc1 == &l0Chain) {
                l1Chain.awaitData(L0, (int)count);
            }
            if (proc_instr->getIsChain()) {
                l1Chain.generateData(instr);
            }
            // for hazard detection remember last dst addresses of this instruction
            pushDstAddr(proc_instr, dstAddrBufferL1);
        } else{ // if (instr->getLane() == L0_1)
            //L0_1
            if(verticalChainBlocking.blockingActive) {
                if (verticalChainBlocking.blockCheckLane == L1 ||
                    verticalChainBlocking.blockCheckLane == L0)
                    verticalChainBlocking.blockingActive = false;
                else {
                    verticalChainBlocking.blockCycles -= (int)count;
                    if (verticalChainBlocking.blockCycles <= 0)
                        verticalChainBlocking.blockingActive = false;
                }
            }
            if (consumeFifoSrc2 == &lsChain || consumeFifoSrc1 == &lsChain) {
                assert(!proc_instr->getIsChain() &&
                       "L0_1 cannot use and produce data in same instruction");
                l1Chain.awaitData(LS, (int)count);
                l0Chain.awaitData(LS, (int)count);
            }
            if (proc_instr->getIsChain()) {
                l1Chain.generateData(instr);
                l0Chain.generateData(instr);
            }
            // for hazard detection remember last dst addresses of this instruction
            pushDstAddr(proc_instr, dstAddrBufferL0);
            pushDstAddr(proc_instr, dstAddrBufferL1);
        }
        if (proc_instr->getBlocking()){
            dstAddrBufferL0.reset();
            dstAddrBufferL1.reset();
        }
    } else {     // if (ls_instr != nullptr){
        // LS
        if(verticalChainBlocking.blockingActive){
            if (verticalChainBlocking.blockCheckLane == LS)
                verticalChainBlocking.blockingActive = false;
            else{
                verticalChainBlocking.blockCycles -= (int)count;
                if (verticalChainBlocking.blockCycles <= 0)
                    verticalChainBlocking.blockingActive = false;
            }
        }
        if (s_instr != nullptr) {
            lsChain.awaitData(s_instr->getSourceLane(), (int)count);
        } else {
            lsChain.generateData(instr);
        }
    }

    if (lastInstrNoneBlockingOrOnlyLS){
        if (proc_instr != nullptr){
            if (!proc_instr->getBlocking() && instr->getLane() != L0_1) {
                // if not blocking and not L0_1 instr
                lastInstrNoneBlockingOrOnlyLS = false;
            }
        }
        // LS instr -> keep going
    } else {
        if (proc_instr != nullptr){
            if (proc_instr->getBlocking()) {
                // if blocking
                lastInstrNoneBlockingOrOnlyLS = true;
            }
        }
    }
}

void ChainingStatus::pushDstAddr(Processing* instr, FifoMemory& fifo) {
    FifoMemory tmp{};

    // append addr reverse (last first)
    int c = 0;
    for (int z = (int)instr->getZEnd(); z >= 0 && c < hazardCheckEntries; --z) {
        for (int y = (int)instr->getYEnd(); y >= 0 && c < hazardCheckEntries; --y) {
            for (int x = (int)instr->getXEnd(); x >= 0 && c < hazardCheckEntries; --x) {
                uint dstAddr = instr->getDst()->getOffset() +
                               x * instr->getDst()->getAlpha() +
                               y * instr->getDst()->getBeta() +
                               z * instr->getDst()->getGamma();
                tmp.FIFO_in((int)dstAddr);
                c++;    // only the last few addresses
            }
        }
    }

    // empty tmp reverse
    uint fifo_cnt = fifo.count();
    while(tmp.buffer.write != tmp.buffer.read){
        tmp.buffer.write--;
        fifo.FIFO_in(tmp.buffer.data[tmp.buffer.write]);
        if (fifo_cnt > hazardCheckEntries){  // pop oldest if count exceeds '8'/entries
            fifo.FIFO_pop();
        } else {    // this addr was added
            fifo_cnt++;
        }
    }
}
bool ChainingStatus::isReadAddr(Processing* instr, FifoMemory& fifo) {
    bool is_src1_addr = !instr->getSrc1()->getIsImmediate() && !instr->getSrc1()->getIsChain();
    bool is_src2_addr = !instr->getSrc2()->getIsImmediate() && !instr->getSrc2()->getIsChain();
    if (is_src1_addr || is_src2_addr){
        // iterate vector, check if src reads dst address
        int c = 0;
        for (uint zi = 0; zi <= instr->getZEnd(); ++zi) {
            for (uint yi = 0; yi <= instr->getYEnd(); ++yi) {
                for (uint xi = 0; xi <= instr->getXEnd(); ++xi) {
                    if (is_src1_addr && is_src2_addr){
                        if (fifo.FIFO_contains(
                                instr->getSrc1()->getOffset() +
                                    instr->getSrc1()->getAlpha() * xi +
                                    instr->getSrc1()->getBeta() * yi +
                                    instr->getSrc1()->getGamma() * zi,
                                instr->getSrc2()->getOffset() +
                                    instr->getSrc2()->getAlpha() * xi +
                                    instr->getSrc2()->getBeta() * yi +
                                    instr->getSrc2()->getGamma() * zi
                                )){
                            return true;
                        }
                    } else {
                        if (is_src1_addr){  // only src1 is addr
                            if (fifo.FIFO_contains(
                                    instr->getSrc1()->getOffset() +
                                    instr->getSrc1()->getAlpha() * xi +
                                    instr->getSrc1()->getBeta() * yi +
                                    instr->getSrc1()->getGamma() * zi
                                    )){
                                return true;
                            }
                        } else {    // only src2 is addr
                            if (fifo.FIFO_contains(
                                    instr->getSrc2()->getOffset() +
                                    instr->getSrc2()->getAlpha() * xi +
                                    instr->getSrc2()->getBeta() * yi +
                                    instr->getSrc2()->getGamma() * zi
                                    )){
                                return true;
                            }
                        }
                    }
                    c++;
                    if (c >= hazardCheckEntries) return false;
                }   // x
            }   //y
        }   //z
    }   // one src operand is address -> do check
    return false;
}
