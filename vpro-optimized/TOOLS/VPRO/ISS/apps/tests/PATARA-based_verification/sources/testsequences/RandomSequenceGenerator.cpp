//
// Created by gesper on 06.03.24.
//

#include "testsequences/RandomSequenceGenerator.h"
#include "helper.h"
#include "random/random_lib.h"
#include "instructions/processing/and.h"
#include "testsequences/ParallelConflictTest.h"

RandomSequenceGenerator::RandomSequenceGenerator(const unsigned int seq_length, const uint64_t init_seed) :
      sequence_length(seq_length) {
    if (0x5f21c6b8a155e0c1 != init_seed) {
        printf_warning("[RandomSequenceGenerator] Init Seed: %li\n", init_seed);
    }
    init_rand_seed(init_seed);

    testRandomSequence = static_cast<TestSequence*>(malloc(sizeof(TestSequence)));
    testRandomSequence = new (testRandomSequence) TestSequence(1000);
    testRandomSequence->clear();
}

Instruction* RandomSequenceGenerator::generateRandomInstruction() {
    auto* instr = new GenericInstruction();

    // Chaining Out Flag
    instr->setChaining((next_uint32() % max_prob) < chain_prob_default);

    // update flag
    if ((next_uint32() % max_prob) < chain_prob_default)
        instr->setFlagUpdate(true);

    // Operation
    auto op = randomOp();
    bool sourceChainPossible = true;
    if (is_loadstore(op)) {
        instr->setLane(LS);
        if (op != Operation::STORE)
            instr->setChaining(true);
        else
            instr->setChaining(false);
    } else {
        instr->setLane(static_cast<LANE>((next_uint32() % 3) + 1));
        if (!chainChecker.isProcessingBroadcastInstructionChainPossible() &&
            instr->getLane() == L0_1){
            sourceChainPossible = false;
        }
    }
    instr->setOperation(op);

    if (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI){
        instr->setChaining(false);
    }

    if (instr->getIsChain())
        sourceChainPossible = false;

    if (is_loadstore(op)) {
        instr->setSRC1(generateRandomAddress(Address::Type::SRC1, 0, 0));  // set SRC1 to addr
        instr->setSRC2(generateRandomAddress(Address::Type::SRC2, 0, max_prob));  // set SRC2 to imm
        instr->getSrc2()->setImmediate(int(next_uint32() % 8192));
    } else if (instr->getLane() == L0_1) {
        instr->setSRC1(generateRandomAddress(Address::Type::SRC1,
            sourceChainPossible? chain_prob_default : 0,
            imm_prop_default,
            0));  // L0_1 may not use Neighbor chain input
        if (instr->getSrc1()->getIsChain()){
            sourceChainPossible = false;
            // TODO: fix, this is a workaround to disable both sources are chaining inputs.
            //  Finalize would generate one producing instr.
            //  Then (still blocking), no other instruction gets issues/last will be deleted
        }
        instr->setSRC2(generateRandomAddress(Address::Type::SRC2,
            sourceChainPossible? chain_prob_default : 0,
            imm_prop_default,
            0));  // L0_1 may not use Neighbor chain input
        instr->setDST(generateRandomAddress(Address::Type::DST, 0, 0));  // no chain, no imm
        if (instr->getSrc1()->getIsChain() || instr->getSrc2()->getIsChain()){
            instr->setChaining(false);
        }
    } else {
        instr->setSRC1(generateRandomAddress(Address::Type::SRC1,
            sourceChainPossible? chain_prob_default : 0));
        if (instr->getSrc1()->getIsChain()){
            sourceChainPossible = false;
            // TODO: fix, this is a workaround to disable both sources are chaining inputs.
            //  Finalize would generate one producing instr.
            //  Then (still blocking), no other instruction gets issues/last will be deleted
        }
        instr->setSRC2(generateRandomAddress(Address::Type::SRC2,
            sourceChainPossible? chain_prob_default : 0));
        instr->setDST(generateRandomAddress(Address::Type::DST, 0, 0));  // no chain, no imm
    }

    // check mac reset registers, only take src2 accordingly
    if (instr->getOperation() == Operation::MACL || instr->getOperation() == Operation::MACH){
        if (DefaultConfiurationModes::MAC_INIT_SOURCE == VPRO::MAC_INIT_SOURCE::IMM &&
            DefaultConfiurationModes::MAC_RESET_MODE != VPRO::MAC_RESET_MODE::NEVER) {
            if (!(instr->getSrc2()->getIsChain() || instr->getSrc2()->getIsImmediate())){
                instr->setSRC2(generateRandomAddress(Address::Type::SRC2,
                    fifty_fifty_prob, fifty_fifty_prob));
            }
        } else if (DefaultConfiurationModes::MAC_INIT_SOURCE == VPRO::MAC_INIT_SOURCE::ADDR &&
                   DefaultConfiurationModes::MAC_RESET_MODE != VPRO::MAC_RESET_MODE::NEVER){
            if (!(instr->getSrc2()->getIsChain() || instr->getSrc2()->getIsAddress())){
                instr->setSRC2(generateRandomAddress(Address::Type::SRC2,
                    fifty_fifty_prob, 0));
            }
        }
    }

    uint x, y, z;
    generateRandomXYZ(instr, x, y, z);
    instr->setxEnd(x);
    instr->setyEnd(y);
    instr->setzEnd(z);

    return instr->create();
}

#include "random/xoroshiro128plus.h"
TestSequence* RandomSequenceGenerator::next() {
    if (verbose) {
        printf_success_highlight("[RandomSequence] next()\n");
        printf("Random: %lu, %lu\n", RANDOM_XOR::s[0], RANDOM_XOR::s[1]);
    }

    for (auto& i : testRandomSequence->getInstructions()) {
        delete i;
    }
    testRandomSequence->clear();
    chainChecker.reset();

    DefaultConfiurationModes::MAC_INIT_SOURCE = VPRO::MAC_INIT_SOURCE(next_uint32() % (VPRO::MAC_INIT_SOURCE::ZERO+1));
    while(DefaultConfiurationModes::MAC_INIT_SOURCE != VPRO::MAC_INIT_SOURCE::ZERO &&
           DefaultConfiurationModes::MAC_INIT_SOURCE != VPRO::MAC_INIT_SOURCE::IMM &&
           DefaultConfiurationModes::MAC_INIT_SOURCE != VPRO::MAC_INIT_SOURCE::ADDR)
        DefaultConfiurationModes::MAC_INIT_SOURCE = VPRO::MAC_INIT_SOURCE(next_uint32() % (VPRO::MAC_INIT_SOURCE::ZERO+1));

    DefaultConfiurationModes::MAC_RESET_MODE = VPRO::MAC_RESET_MODE(next_uint32() % (VPRO::MAC_RESET_MODE::X_INCREMENT+1));
    while(DefaultConfiurationModes::MAC_RESET_MODE != VPRO::MAC_RESET_MODE::NEVER &&
           DefaultConfiurationModes::MAC_RESET_MODE != VPRO::MAC_RESET_MODE::ONCE &&
           DefaultConfiurationModes::MAC_RESET_MODE != VPRO::MAC_RESET_MODE::X_INCREMENT &&
           DefaultConfiurationModes::MAC_RESET_MODE != VPRO::MAC_RESET_MODE::Y_INCREMENT &&
           DefaultConfiurationModes::MAC_RESET_MODE != VPRO::MAC_RESET_MODE::Z_INCREMENT)
        DefaultConfiurationModes::MAC_RESET_MODE = VPRO::MAC_RESET_MODE(next_uint32() % (VPRO::MAC_RESET_MODE::X_INCREMENT+1));

    DefaultConfiurationModes::MAC_H_BIT_SHIFT = int(next_uint32() % 25);
    DefaultConfiurationModes::MUL_H_BIT_SHIFT = int(next_uint32() % 25);

    uint cmd_gen_iteration = 0;

    while (testRandomSequence->getLength() < sequence_length) {
        Instruction* instruction = generateRandomInstruction();
        cmd_gen_iteration++;
        if (chainChecker.issueIfPossible(instruction)) {
            chainChecker.updateChains();
            if (verbose) {
                printf(" %s\n", instruction->c_str());
                //                printf(" -- Exec Possible! Append to random sequence... \n");
                chainChecker.printStatus();
            }
            testRandomSequence->append(instruction);  // who's gonna delete this object?
        } else {
            //            if (verbose) printf(" -- Exec impossible! Delete... \n");
            delete instruction;
        }
        if (cmd_gen_iteration > 30 * sequence_length){
            if (verbose)
                printf_warning("[Random Gen] Cmd Gen called over 30*%i (seq. length) times! Starting again...\n", sequence_length);
            return next();
        }
    }

    if (verbose) {
        printf_info("Finalizing open chains... TODO: missing receive waiting lanes...!\n");
        chainChecker.printStatus();
    }
    Instruction* last = generateFinalizeInstruction();
    while (last != nullptr) {
        cmd_gen_iteration++;
        if (chainChecker.issueIfPossible(last)) {
            chainChecker.updateChains();
            if (verbose) {
                printf(" %s \n", last->c_str());
                printf(" -- Exec Possible! Append to random sequence... \n");
                chainChecker.printStatus();
            }
            testRandomSequence->append(last);  // who's gonna delete this object?
        } else {
            //            if (verbose) printf(" -- Exec impossible! Delete... \n");
            delete last;
        }
        last = generateFinalizeInstruction();

        if (cmd_gen_iteration > 30 * sequence_length){
            if (verbose)
                printf_warning("[Random Gen] Cmd Gen called over 30*%i (seq. length) times! Starting again...\n", sequence_length);
            return next();
        }
    }

    // maximum 4 finalize instructions
    assert(testRandomSequence->getLength() <= sequence_length + 4);

    for (auto i : testRandomSequence->getInstructions()) {
        i->updateOperandAddresses();
    }

//    testRandomSequence->printInstructions("TO be checked for parallel issues.... ");
    ParallelConflictTest parallelConflictTester;
    for (auto instr : testRandomSequence->getInstructions()) {
        if (!parallelConflictTester.nextInstruction(instr)){
            // specific lane busy (chaining)
            //  -> blocking now [left in FIFO] -> finish chains, then repeat
            parallelConflictTester.tickChains();
            if (!parallelConflictTester.nextInstruction(instr)) {
                // conflict in parallel exec!
                if (verbose) {
                    printf_error("CONFLICT!\n");
                    printf_warning("%s\n", instr->c_str());
                    testRandomSequence->printInstructions("[conflict]");
                }
                return next();
            }
        }
    }
    if (parallelConflictTester.isBusy()){
        // conflict. no one reads output
        if (verbose){
            printf_error("CONFLICT. Not finishing!\n");
            testRandomSequence->printInstructions("[conflict]");
        }
        return next();
    }


    if (verbose) {
        printf_success_highlight(
            "[RandomSequence] next() finishes. Length: %zu\n", testRandomSequence->getLength());
    }
    return testRandomSequence;
}

Instruction* RandomSequenceGenerator::generateFinalizeInstruction() {
    if (!chainChecker.l0Blocking() && !chainChecker.l1Blocking() && !chainChecker.lsBlocking()) {
        return nullptr;
    }

    auto* instr = new GenericInstruction();
    auto op = randomOp();
    while (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI){
        op = randomOp();
    }
    instr->setSRC1(generateRandomAddress(Address::Type::SRC1, 0));  // no chain default
    instr->setSRC2(generateRandomAddress(Address::Type::SRC2, 0));  // no chain default
    instr->setDST(generateRandomAddress(Address::Type::DST, 0, 0));
    uint x, y, z;
    int vl;

//    bool finishing_options[] = {
//        chainChecker.lsRemainingEntries() > 0 &&
//        (!chainChecker.l0Blocking() || !chainChecker.l1Blocking()),
//        chainChecker.l0RemainingEntries() > 0 &&
//        (!chainChecker.l1Blocking() || !chainChecker.lsBlocking()),
//        chainChecker.l1RemainingEntries() > 0 &&
//        (!chainChecker.l0Blocking() || !chainChecker.lsBlocking()),
//    };

    // finish single production chains
    if (chainChecker.l0RemainingEntries() > 0 &&    // output filled
        chainChecker.l0AwaitEntries(L1) == 0 && chainChecker.l0AwaitEntries(LS) == 0 && // no source
        (!chainChecker.l1Blocking() || !chainChecker.lsBlocking())) {
        // L0 data remains, either LS or L1 rdy
        if (!chainChecker.l1Blocking()) {
            instr->setLane(L1);
            while (!is_processing(op) || (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI))
                op = randomOp();
            instr->setSRC1(Addressing(SRC_CHAINING_NEIGHBOR_LANE));
        } else {
            instr->setLane(LS);
            op = Operation::STORE;
            instr->setSourceLane(L0);
        }
        vl = chainChecker.l0RemainingEntries();
    } else if (chainChecker.l1RemainingEntries() > 0 &&    // output filled
               chainChecker.l1AwaitEntries(L0) == 0 && chainChecker.l1AwaitEntries(LS) == 0 && // no source
               (!chainChecker.l0Blocking() || !chainChecker.lsBlocking())) {
        // L1 data remains, either LS or L0 rdy
        if (!chainChecker.l0Blocking()) {
            instr->setLane(L0);
            while (!is_processing(op) || (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI))
                op = randomOp();
            instr->setSRC1(Addressing(SRC_CHAINING_NEIGHBOR_LANE));
        } else {
            instr->setLane(LS);
            op = Operation::STORE;
            instr->setSourceLane(L1);
        }
        vl = chainChecker.l1RemainingEntries();
    } else if (chainChecker.lsRemainingEntries() > 0 &&    // output filled
               chainChecker.lsAwaitEntries(L0) == 0 && chainChecker.lsAwaitEntries(L1) == 0 && // no source
               (!chainChecker.l0Blocking() || !chainChecker.l1Blocking())) {
        // LS load remains, either L0 or L1 rdy
        while (!is_processing(op) || (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI))
            op = randomOp();
        // TODO: fix of...
        //      disable of L0_1 in finalize as synchronization not ensured! ->
        //      endless generate loop, checker will not issue this

        //        if (!chainChecker.l0Blocking() && !chainChecker.l1Blocking()) {  // L0 + L1 rdy
        //            instr->setLane(L0_1);
        //            instr->setSRC1(generateRandomAddress(Address::Type::SRC1,
        //                chain_prob_default,
        //                imm_prop_default,
        //                0));  // L0_1 may not use Neighbor chain input
        //            instr->setSRC2(generateRandomAddress(Address::Type::SRC2,
        //                chain_prob_default,
        //                imm_prop_default,
        //                0));                            // L0_1 may not use Neighbor chain input
        //        } else
        if (!chainChecker.l0Blocking())  // L0 rdy
            instr->setLane(L0);
        else if (!chainChecker.l1Blocking())  // L1 rdy
            instr->setLane(L1);
        setRandomSourceOperand(Addressing(SRC_LS_3D), instr);
        vl = chainChecker.lsRemainingEntries();
    } else {  // single producing done!?

        // finish single source chains
        instr->setChaining(true);
        if (chainChecker.lsAwaitEntries(L0) > 0 && chainChecker.lsAwaitEntries(L1) == 0) {
            // -> ls, l0 rdy
            instr->setLane(L0);
            while (!is_processing(op) || (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI))
                op = randomOp();
            vl = chainChecker.lsAwaitEntries(L0);
        } else if (chainChecker.lsAwaitEntries(L1) > 0 && chainChecker.lsAwaitEntries(L0) == 0) {
            // -> ls, l1 rdy
            instr->setLane(L1);
            while (!is_processing(op) || (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI))
                op = randomOp();
            vl = chainChecker.lsAwaitEntries(L1);
        } else if (chainChecker.l0AwaitEntries(L1) > 0 && chainChecker.l0AwaitEntries(LS) == 0) {
            // -> ls, l1 rdy
            instr->setLane(L1);
            while (!is_processing(op) || (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI))
                op = randomOp();
            vl = chainChecker.l0AwaitEntries(L1);
        } else if (chainChecker.l0AwaitEntries(LS) > 0 && chainChecker.l0AwaitEntries(L1) == 0) {
            // -> ls, l1 rdy
            instr->setLane(LS);
            while (!is_load(op))
                op = randomOp();
            vl = chainChecker.l0AwaitEntries(LS);
        } else if (chainChecker.l1AwaitEntries(L0) > 0 && chainChecker.l1AwaitEntries(LS) == 0) {
            // -> ls, l1 rdy
            instr->setLane(L0);
            while (!is_processing(op) || (op == Operation::MV_ZE || op == Operation::MV_PL || op == Operation::MV_NZ || op == Operation::MV_MI))
                op = randomOp();
            vl = chainChecker.l1AwaitEntries(L0);
        } else if (chainChecker.l1AwaitEntries(LS) > 0 && chainChecker.l1AwaitEntries(L0) == 0) {
            // -> ls, l1 rdy
            instr->setLane(LS);
            while (!is_load(op))
                op = randomOp();
            vl = chainChecker.l1AwaitEntries(LS);
        } else {
            if (chainChecker.l0Blocking() || chainChecker.l1Blocking() ||
                chainChecker.lsBlocking()) {
                printf_error("[Remaining Chain Data] not possible to retrieve. Check!\n");
                chainChecker.printStatus();
                delete instr;
                return nullptr;
            }
            vl = 0;
            x = 0;
            y = 0;
            z = 0;
            printf_error("[Remaining Chain Data] not possible to retrieve. no need!? Check!\n");
            return nullptr;
        }
    }

    instr->setOperation(op);
    if (is_loadstore(op)) {
        instr->setSRC1(generateRandomAddress(Address::Type::SRC1, 0, 0));  // set SRC1 to addr
        instr->setSRC2(generateRandomAddress(Address::Type::SRC2, 0, max_prob));  // set SRC2 to imm
        instr->getSrc2()->setImmediate(int(next_uint32() % 8192));
    }

    generateRandomXYZ(instr, x, y, z, vl);
    instr->setxEnd(x);
    instr->setyEnd(y);
    instr->setzEnd(z);
    return instr->create();
}

Operation::Operation RandomSequenceGenerator::randomOp() {
    auto op = static_cast<Operation::Operation>(next_uint32() % Operation::END);
    while (op == Operation::NOP || op == Operation::NONE || op == Operation::Processing || op == Operation::LoadStore){
        op = static_cast<Operation::Operation>(next_uint32() % Operation::END);
    }
    return op;
}

template<int N, int maxC>
struct LUT
{
    constexpr LUT() : values(), count()
    {
        for (auto i = 1; i < N; ++i) {
            int factor = 0;
            for (auto j = 1; j < maxC; ++j) {
                if (i % j == 0){
                    values[i][factor] = j;
                    factor ++;
                }
            }
            count[i] = factor;
        }
    }
    uint values[N][maxC]{1};
    uint count[N]{0};
};
constexpr auto factors = LUT<1024+1, 63>();

// Function to generate a random prime factor of a given number
uint generateFactor(uint n, uint max_factor = MAX_Z_END) {
    uint rand_index = next_uint32() % factors.count[n];
    uint factor = factors.values[n][rand_index];
    assert(factor <= max_factor && "Factor needs to be smaller than max factor!");
    return factor;
}

void RandomSequenceGenerator::generateRandomXYZ(
    GenericInstruction* instr, uint& x, uint& y, uint& z, int length) {
    assert(length >= -1);
    assert(length != 0);
    assert(length <= 1024);  // TODO: lm address?!

    if (length == -1) {
        // random length
        length = (next_uint32() % 1024) + 1;
    }

    int iteration_count = 0;
    // factors according given length
    do {
        x = generateFactor(length, MAX_X_END);
        // Find the second factor
        uint remaining = length / x;
        y = generateFactor(remaining, MAX_Y_END);
        // Find the third factor
        z = remaining / y;

        x--;
        y--;
        z--;
        assert((x + 1) * (y + 1) * (z + 1) == (uint)length);
        iteration_count++;

        // smaller -> reducing alpha/beta/gamma faster with iteration
        int iteration_based_reduction_speed = 13;
        int iteration_reduction = (iteration_count / iteration_based_reduction_speed);
        int offset_factor = 3;

        if (is_loadstore(instr->getOperation())) {
            // SRC1 - addr
            instr->getSrc1()->setOffsetRandom(int(MAX_OFFSET) - offset_factor * iteration_reduction);
            instr->getSrc1()->setAlphaRandom(int(MAX_ALPHA) - iteration_reduction);
            instr->getSrc1()->setBetaRandom(int(MAX_BETA) - iteration_reduction);
            instr->getSrc1()->setGammaRandom(int(MAX_GAMMA) - iteration_reduction);

            // SRC2 - imm
            instr->getSrc2()->setImmediate(
                int(next_uint32() %
                    max(1,
                        min(8192 - 2 * iteration_reduction,
                            8192))));
        } else {
            if (!instr->getSrc1()->getIsChain() && !instr->getSrc1()->getIsImmediate()) {
                instr->getSrc1()->setOffsetRandom(int(MAX_OFFSET) - offset_factor * iteration_reduction);
                instr->getSrc1()->setAlphaRandom(int(MAX_ALPHA) - iteration_reduction);
                instr->getSrc1()->setBetaRandom(int(MAX_BETA) - iteration_reduction);
                instr->getSrc1()->setGammaRandom(int(MAX_GAMMA) - iteration_reduction);
            }
            if (!instr->getSrc2()->getIsChain() && !instr->getSrc2()->getIsImmediate()) {
                instr->getSrc2()->setOffsetRandom(int(MAX_OFFSET) - offset_factor * iteration_reduction);
                instr->getSrc2()->setAlphaRandom(int(MAX_ALPHA) - iteration_reduction);
                instr->getSrc2()->setBetaRandom(int(MAX_BETA) - iteration_reduction);
                instr->getSrc2()->setGammaRandom(int(MAX_GAMMA) - iteration_reduction);
            }
            if (!instr->getDst()->getIsChain() && !instr->getDst()->getIsImmediate()) {
                instr->getDst()->setOffsetRandom(int(MAX_OFFSET) - offset_factor * iteration_reduction);
                instr->getDst()->setAlphaRandom(int(MAX_ALPHA) - iteration_reduction);
                instr->getDst()->setBetaRandom(int(MAX_BETA) - iteration_reduction);
                instr->getDst()->setGammaRandom(int(MAX_GAMMA) - iteration_reduction);
            }
        }
        if (iteration_count > 1499) {
            if (verbose)
                printf_warning("Factorization [i: %i] X: %i, y: %i, z: %i [len: %i]\n",
                    iteration_count,
                    x,
                    y,
                    z,
                    length);
        }
        if (iteration_count > 1500) {
            printf_error(
                "[Iteration: %i] No XYZ factorization found for: vector length of %i\n",
                iteration_count,
                length);
            char buff[1024];
            printf_error("Instr: Src1 %s\n", instr->getSrc1()->c_str(buff));
            printf_error("Instr: Src2 %s\n", instr->getSrc2()->c_str(buff));
            printf_error("Instr: Dst  %s\n", instr->getDst()->c_str(buff));
            printf_error("Instr: %s\n", instr->c_str());
            exit(19);
        }

    } while (!instr->check(x, y, z, ChainingStatus::hazardCheckEntries));
    //    if (verbose)
    //        printf_success("Factorization [i: %i] X: %i, y: %i, z: %i [len: %i]\n", iteration_count, x, y, z, length);
}

Addressing RandomSequenceGenerator::generateRandomAddress(Address::Type addr,
    unsigned int chain_prop,
    unsigned int imm_prop,
    unsigned int chain_source_neighbor_prop) {
    // random selection
    uint rand = 1;
    if (chain_prop > 0 || imm_prop > 0) rand = next_uint32() % max_prob;

    bool chain = rand < chain_prop;
    bool imm = rand < (chain_prop + imm_prop);

    if (chain) {
        // Chaining Source
        if (chain_source_neighbor_prop == fifty_fifty_prob) {
            if (next_uint32() & 0b1) {  // 50% -> single bit 0/1
                // NEIGHBOR
                return Addressing(SRC_CHAINING_NEIGHBOR_LANE);
            } else {
                // LS
                return Addressing(SRC_LS_3D);
            }
        } else if (chain_source_neighbor_prop == 0) {
            return Addressing(SRC_LS_3D);
        } else {
            if (next_uint32() % max_prob < chain_source_neighbor_prop) {
                // NEIGHBOR
                return Addressing(SRC_CHAINING_NEIGHBOR_LANE);
            } else {
                // LS
                return Addressing(SRC_LS_3D);
            }
        }
    } else if (imm) {
        // Immediate
        return {DataFormat::signed24Bit((int)next_uint32()), addr};  // %  % ISA_IMMEDIATE_MASK_3D
    }
    // addressing source
    int offset = int(next_uint32() % (MAX_OFFSET+1));  // TODO biased parameters -> more smaller ones
    int alpha = int(next_uint32() % (MAX_ALPHA+1));
    int beta = int(next_uint32() % (MAX_BETA+1));
    int gamma = int(next_uint32() % (MAX_GAMMA+1));

    return {offset, alpha, beta, gamma, addr};
}

void RandomSequenceGenerator::setRandomSourceOperand(Addressing addr, GenericInstruction* instr) {
    if (next_uint32() & 0b1) {  // 50% -> single bit 0/1
        instr->setSRC1(addr);
    } else {
        instr->setSRC2(addr);
    }
}
void RandomSequenceGenerator::vproRegisterConfig(bool verbose) const {
//    InstructionChainGenerator::vproRegisterConfig(verbose);
//    vpro_set_cluster_mask(DefaultConfiurationModes::CLUSTER_MASK);
//    vpro_set_unit_mask(DefaultConfiurationModes::UNIT_MASK);
    vpro_set_mac_init_source(DefaultConfiurationModes::MAC_INIT_SOURCE);
    vpro_set_mac_reset_mode(DefaultConfiurationModes::MAC_RESET_MODE);
    vpro_mac_h_bit_shift(DefaultConfiurationModes::MAC_H_BIT_SHIFT);
    vpro_mul_h_bit_shift(DefaultConfiurationModes::MUL_H_BIT_SHIFT);

    if (verbose){
        printf_info("VPRO registers set\n");
        printf_info(" | MAC Init Source: %s\n", print(DefaultConfiurationModes::MAC_INIT_SOURCE));
        printf_info(" | MAC Reset Mode: %s\n", print(DefaultConfiurationModes::MAC_RESET_MODE));
        printf_info(" | MACH Shift: %i\n", DefaultConfiurationModes::MAC_H_BIT_SHIFT);
        printf_info(" | MULH Shift: %i\n", DefaultConfiurationModes::MUL_H_BIT_SHIFT);
    }
}
