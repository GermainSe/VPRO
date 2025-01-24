//
// Created by gesper on 11.12.23.
//

#include "testsequences/InstructionSequenceGenerator.h"
#include "instructions/genericInstruction.h"
#include "constants.h"

InstructionSequenceGenerator::InstructionSequenceGenerator() {
    testSequence = static_cast<TestSequence*>(malloc(sizeof(TestSequence)));
    testSequence = new (testSequence) TestSequence(30);
    testSequence->clear();

    setChainGeneratorSequence(testSequence);
}

void InstructionSequenceGenerator::init(int x_end,
    int y_end,
    int z_end,
    Addressing dst,
    Addressing src1,
    Addressing src2,
    bool includeSingleInstructions,
    bool includeChains,
    bool includeSRC1,
    bool includeSRC2,
    bool variateMACHInitSource,
    bool variateMACHResetMode,
    bool variateMACHShifts,
    bool variateMULHShifts,
    bool useMachInitWhileLSchain,
    bool limitOperations,
    Operation::Operation limitedOp,
    bool limitLane,
    LANE laneLimit,
    bool introduceChainDelayCommands,
    int chainDelays,
    bool introduceBlockingChainCommands,
    bool introduceBlockingDelayCommands) {
    this->x_end = x_end;
    this->y_end = y_end;
    this->z_end = z_end;
    this->DST = dst;
    this->SRC1 = src1;
    this->SRC2 = src2;
    this->includeSingleInstructions = includeSingleInstructions;
    this->includeChains = includeChains;
    this->includeSRC1 = includeSRC1;
    this->includeSRC2 = includeSRC2;
    this->variateMACHInitSource = variateMACHInitSource;
    this->variateMACHResetMode = variateMACHResetMode;
    this->variateMACHShifts = variateMACHShifts;
    this->variateMULHShifts = variateMULHShifts;
    this->useMachInitWhileLSchain = useMachInitWhileLSchain;
    this->limitOperations = limitOperations;
    this->limitedOp = limitedOp;
    this->limitLane = limitLane;
    this->laneLimit = laneLimit;
    this->introduceChainDelayCommands = introduceChainDelayCommands;
    this->chainDelays = chainDelays;
    this->introduceBlockingChainCommands = introduceBlockingChainCommands;
    this->introduceBlockingDelayCommands = introduceBlockingDelayCommands;

    reset_instr();
    if (introduceChainDelayCommands){
        for (auto & instr : delayInstr) {
            instr.setBlocking(introduceBlockingDelayCommands);
            instr.setChaining(false);
            instr.setSRC1(Addressing(0, Address::Type::SRC1));              // 0
            instr.setOperation(Operation::NOP);                             // +
            instr.setSRC2(Addressing(0, Address::Type::SRC2));              // 0
            instr.setDST(Addressing(0, 0, 0, 0, Address::Type::DST));       // => RF [0]
            instr.setxEnd(0);
            instr.setyEnd(0);
            instr.setzEnd(chainDelays);
        }
        delayInstr[0].setzEnd(1023);  // blocking instruction to instruction FIFO first
        delayInstr[0].setyEnd(20);  // make it longer
//        delayInstr[0].setxEnd(63);  // even longer?
    }

    resetSingleInstructionRun();
    resetChainRun();

    currentRegisters.MACInitSource = DefaultConfiurationModes::MAC_INIT_SOURCE; //VPRO::MAC_INIT_SOURCE::NONE;
    currentRegisters.MACResetMode = DefaultConfiurationModes::MAC_RESET_MODE; //VPRO::MAC_RESET_MODE::NEVER;
    currentRegisters.MACHShift = DefaultConfiurationModes::MAC_H_BIT_SHIFT; //VPRO_CFG::MAX_SHIFT;
    currentRegisters.MULHShift = DefaultConfiurationModes::MUL_H_BIT_SHIFT; //VPRO_CFG::MAX_SHIFT;

    // count total number of generated sequences
    totalSequenceCnt = 0;
    currentSequenceCnt = 0;
    if (includeSingleInstructions) {
        totalSequenceCnt += getSingleSequenceCnt();
    }
    if (includeChains) {
        assert(includeSRC2 || includeSRC1);
        if (includeSRC1) {
            totalSequenceCnt += getChainSequenceCnt();
        }
        if (includeSRC2) {
            totalSequenceCnt += getChainSequenceCnt();
        }
    }

    int register_generate_loop = 1;                         // TODO only for single with MAC ...

    if (variateMACHInitSource) {
        assert(includeSingleInstructions);
        assert(!includeChains);
        assert(limitedOp == Operation::MACH);  // not meaningful if more ops variate this
        register_generate_loop *= 4;                 // const...
        currentRegisters.MACInitSource = VPRO::MAC_INIT_SOURCE::IMM;
    }
    if (variateMACHResetMode) {
        assert(includeSingleInstructions);
        assert(!includeChains);
        assert(limitedOp == Operation::MACH);  // not meaningful if more ops variate this
        register_generate_loop *= 5;                 // const...
        currentRegisters.MACResetMode = VPRO::MAC_RESET_MODE::ONCE;
    }
    if (variateMACHShifts) {
        assert(includeSingleInstructions);
        assert(!includeChains);
        assert(limitedOp == Operation::MACH);           // not meaningful if more ops variate this
        register_generate_loop *= (VPRO_CFG::MAX_SHIFT + 1);  // const...
        currentRegisters.MACHShift = 0;
    }
    if (variateMULHShifts) {
        assert(includeSingleInstructions);
        assert(!includeChains);
        assert(limitedOp == Operation::MULH || limitedOp == Operation::MULH_NEG || limitedOp == Operation::MULH_POS);           // not meaningful if more ops variate this
        register_generate_loop *= (VPRO_CFG::MAX_SHIFT + 1);  // const...
        currentRegisters.MULHShift = 0;
    }

    registerConfigsToCheck.reserve(register_generate_loop);

    for (int i = 0; i < register_generate_loop; ++i) {
        registerConfigsToCheck[i].MACInitSource = currentRegisters.MACInitSource;
        registerConfigsToCheck[i].MACResetMode = currentRegisters.MACResetMode;
        registerConfigsToCheck[i].MACHShift = currentRegisters.MACHShift;
        registerConfigsToCheck[i].MULHShift = currentRegisters.MULHShift;
    }

    int i = 1;
    // first switch all mach init sources (4)
    if (variateMACHInitSource) {
        for (int src : {VPRO::MAC_INIT_SOURCE::ADDR, VPRO::MAC_INIT_SOURCE::IMM, VPRO::MAC_INIT_SOURCE::ZERO}) {
            registerConfigsToCheck[i].MACInitSource = (VPRO::MAC_INIT_SOURCE)src;
            registerConfigsToCheck[i].MACResetMode = registerConfigsToCheck[i - 1].MACResetMode;
            registerConfigsToCheck[i].MACHShift = registerConfigsToCheck[i - 1].MACHShift;
            registerConfigsToCheck[i].MULHShift = registerConfigsToCheck[i - 1].MULHShift;
            i++;
        }
    }
    if (variateMACHResetMode) {
        // use all i instructions and repeat with new mac reset mode
        int base = i;
        for (int src : {VPRO::MAC_RESET_MODE::ONCE, VPRO::MAC_RESET_MODE::Z_INCREMENT, VPRO::MAC_RESET_MODE::Y_INCREMENT, VPRO::MAC_RESET_MODE::X_INCREMENT }) {
            for (int cmd = 0; cmd < base; ++cmd) {  // base to copy
                registerConfigsToCheck[i].MACInitSource =
                    registerConfigsToCheck[cmd].MACInitSource;
                registerConfigsToCheck[i].MACResetMode = (VPRO::MAC_RESET_MODE)src;
                registerConfigsToCheck[i].MACHShift = registerConfigsToCheck[cmd].MACHShift;
                registerConfigsToCheck[i].MULHShift = registerConfigsToCheck[cmd].MULHShift;
                i++;
            }
        }
    }
    if (variateMACHShifts) {
        // use all i instructions and repeat with new mac shift
        int base = i;
        for (uint src = 1; src <= VPRO_CFG::MAX_SHIFT; ++src) {
            for (int cmd = 0; cmd < base; ++cmd) {  // base to copy
                registerConfigsToCheck[i].MACInitSource =
                    registerConfigsToCheck[cmd].MACInitSource;
                registerConfigsToCheck[i].MACResetMode = registerConfigsToCheck[cmd].MACResetMode;
                registerConfigsToCheck[i].MACHShift = src;
                registerConfigsToCheck[i].MULHShift = registerConfigsToCheck[cmd].MULHShift;
                i++;
            }
        }
    }
    if (variateMULHShifts) {
        // use all i instructions and repeat with new mul shift
        int base = i;
        for (uint src = 1; src <= VPRO_CFG::MAX_SHIFT; ++src) {
            for (int cmd = 0; cmd < base; ++cmd) {  // base to copy
                registerConfigsToCheck[i].MACInitSource =
                    registerConfigsToCheck[cmd].MACInitSource;
                registerConfigsToCheck[i].MACResetMode = registerConfigsToCheck[cmd].MACResetMode;
                registerConfigsToCheck[i].MACHShift = registerConfigsToCheck[cmd].MACHShift;
                registerConfigsToCheck[i].MULHShift = src;
                i++;
            }
        }
    }
    maxRegisterIterations = i;
    currentRegisterIteratior = 0;

//    i = 0;
//    for (auto cfg : registerConfigsToCheck) {
//        printf("REG Config [%i] ", i);
//        printf("%i ", cfg.MACInitSource);
//        printf("%i ", cfg.MACResetMode);
//        printf("%i ", cfg.MACHShift);
//        printf("%i \n", cfg.MULHShift);
//        i++;
//    }

//        printf_success("totalSequenceCnt: %i\n", totalSequenceCnt);
//        printf_success("getChainSequenceCnt: %i\n", getChainSequenceCnt());
//        printf_success("getSingleSequenceCnt: %i\n", getSingleSequenceCnt());
//        printf_success("getProcessingOperationCnt: %i\n", getProcessingOperationCnt());
}

void InstructionSequenceGenerator::init(const test_cfg_s& config) {
    init(config.x_end,
        config.y_end,
        config.z_end,
        config.dst,
        config.src1,
        config.src2,
        config.includeSingleInstructions,
        config.includeChains,
        config.includeSRC1,
        config.includeSRC2,
        config.variateMACHInitSource,
        config.variateMACHResetMode,
        config.variateMACHShifts,
        config.variateMULHShifts,
        config.useMachInitWhileLSchain,
        config.limitOperations,
        config.limitedOp,
        config.limitLane,
        config.laneLimit,
        config.introduceChainDelayCommands,
        config.chainDelays,
        config.introduceBlockingChainCommands,
        config.introduceBlockingDelayCommands);
}

void InstructionSequenceGenerator::vproRegisterConfig(bool verbose) const {
    DefaultConfiurationModes::MAC_INIT_SOURCE = currentRegisters.MACInitSource;
    DefaultConfiurationModes::MAC_RESET_MODE = currentRegisters.MACResetMode;
    DefaultConfiurationModes::MAC_H_BIT_SHIFT = currentRegisters.MACHShift;
    DefaultConfiurationModes::MUL_H_BIT_SHIFT = currentRegisters.MULHShift;

//    vpro_set_cluster_mask(DefaultConfiurationModes::CLUSTER_MASK);
//    vpro_set_unit_mask(DefaultConfiurationModes::UNIT_MASK);

    vpro_set_mac_init_source(currentRegisters.MACInitSource);
    vpro_set_mac_reset_mode(currentRegisters.MACResetMode);
    vpro_mac_h_bit_shift(currentRegisters.MACHShift);
    vpro_mul_h_bit_shift(currentRegisters.MULHShift);
    if (verbose){
        printf_info("VPRO registers set\n");
        printf_info(" | MAC Init Source: %s\n", print(currentRegisters.MACInitSource));
        printf_info(" | MAC Reset Mode: %s\n", print(currentRegisters.MACResetMode));
        printf_info(" | MACH Shift: %i\n", currentRegisters.MACHShift);
        printf_info(" | MULH Shift: %i\n", currentRegisters.MULHShift);
    }
}

int InstructionSequenceGenerator::getProcessingOperationCnt() {
    // skipped:
    //    Operation::LoadStore
    //    Operation::Processing
    //    all LS operations: END - LoadStore

    return (Operation::LoadStore - Operation::Processing - 1);
}

int InstructionSequenceGenerator::getLSOperationCnt() {
    // skipped:
    //    Operation::LoadStore
    //    Operation::Processing
    //    all LS operations: END - LoadStore

    return (Operation::END - Operation::LoadStore - 1);
}

int InstructionSequenceGenerator::getSingleSequenceCnt() const {
    // x3 (L0, L1, L0_1) + LS
    if (!includeSingleInstructions)
        return 0;
    if (limitOperations) {
        if (limitLane){
            return 1;
        } else {
            if (limitedOp > Operation::LoadStore) {
                return 1;
            } else {
                return 3;
            }
        }
    } else {
        if (limitLane) {
            if (laneLimit == LS)
                return getLSOperationCnt();
            else
                return getProcessingOperationCnt();
        }
        else
            return 3 * getProcessingOperationCnt() + getLSOperationCnt();
    }
}

int InstructionSequenceGenerator::getChainSequenceCnt() const {
    // 6 -> count Chains with 2
    // 9 -> count Chains with 3

    if (!includeChains)
        return 0;
    if (limitOperations) {
        return InstructionChains::END - InstructionChains::NONE - 1;
    } else {
        return (InstructionChains::END - InstructionChains::NONE - 1) * (getProcessingOperationCnt() - 4);  // without moves
    }
}

void InstructionSequenceGenerator::printErrorState(){
    printf_warning("  [SINGLE INSTR] current_test_sequence_single_lane: %s\n",
        print(current_test_sequence_single_lane));
    printf_warning("  [SINGLE INSTR] current_test_sequence_single_operation: %s\n",
        Operation::print((Operation::Operation)current_test_sequence_single_operation));

    printf_warning("  [CHAINS] chain_generation_operand: %s\n",
        Operand::print((Operand::Operand)chain_generation_operand));
    printf_warning("  [CHAINS] current_test_sequence_chain: %s\n",
        InstructionChains::print(
            (InstructionChains::InstructionChains)current_test_sequence_chain));
    printf_warning("  [CHAINS] chain_generation_operation_l0: %s\n",
        Operation::print((Operation::Operation)chain_generation_operation_l0));
    printf_warning("  [CHAINS] chain_generation_operation_l1: %s\n",
        Operation::print((Operation::Operation)chain_generation_operation_l1));
}

void InstructionSequenceGenerator::resetSingleInstructionRun(){
    // single instruction sequences
    current_test_sequence_single_operation = Operation::END;
    current_test_sequence_single_lane = LS;  // gets reduced to L0_1 -> L1 -> L0
    if (limitLane){
        current_test_sequence_single_lane = laneLimit;
    }
}

void InstructionSequenceGenerator::resetChainRun(){
    // chain sequences
    current_test_sequence_chain = InstructionChains::END;
    if (!includeSRC1)  // only src2
        chain_generation_operand = Operand::SRC2;
    else
        chain_generation_operand = Operand::SRC1;
    chain_generation_operation_ls_src = Operation::LOADS;
    chain_generation_operation_ls_dst = Operation::STORE;
    chain_generation_operation_l0 = Operation::LoadStore;
    nextOperation(chain_generation_operation_l0);
    chain_generation_operation_l1 = Operation::LoadStore;
    nextOperation(chain_generation_operation_l1);

    neighbor_chain_encoding = SRC1_CHAINING_LEFT_3D;
}

TestSequence* InstructionSequenceGenerator::next() {
    /**
     * single instr.
     *      LS operations
     *      other lanes
     *          each with all operations
     *
     * chains
     *      when all chains done, next operation
     *          when all operations done, next operand (SRC1, SRC2)
     */

    // generate new Sequence
    testSequence->clear();

    // special register test -> loop everything in it
    while (currentRegisterIteratior < maxRegisterIterations){

        if (currentSequenceCnt < getSingleSequenceCnt() && includeSingleInstructions) {
            /**
             * single Instruction Test Sequences
             */
            if (!nextOperation(current_test_sequence_single_operation)) {
                // all operations done
                if (!nextLane(current_test_sequence_single_lane)) {
                    // all lanes done
                    printf_warning("InstructionSequenceGenerator::next() SingleSequence. No Next Lane. "
                        "Current:\n");
                    printErrorState();
                } else {  // new lane, start with operations again
                    current_test_sequence_single_operation = Operation::END;
                    nextOperation(current_test_sequence_single_operation);
                }
            }

            // if LS is active, but operation already changed to no LS operation, switch to next lane
            if (current_test_sequence_single_lane == LANE::LS &&
                current_test_sequence_single_operation <= Operation::LoadStore){
                if (!nextLane(current_test_sequence_single_lane)) {
                    // all lanes done -- limitedLane?
                    printf_warning("InstructionSequenceGenerator::next() No Next Lane. "
                        "Current:\n");
                    printErrorState();
                }
            }

            if (current_test_sequence_single_lane == LANE::LS) {
                /**
                 * if LS test -> add two instructions
                 */
                reset_instr();
                if (current_test_sequence_single_operation == Operation::STORE){
                    // store always from same lane/operation! -> only tested in chaining test?
                    L1_instr.setOperation(Operation::ADD);
                    L1_instr.setChaining(true);
                    LS_instr.setSourceLane(L1);
                    assert(!LS_instr.getSrc1()->getIsChain() && !LS_instr.getSrc1()->getIsImmediate());
                    testSequence->append(L1_instr.create());
                    LS_instr.setBlocking(true); // TODO: no blocking store included in chains... / this has no parameter setting
                    testSequence->setName("(L1->) LS");
                } else {    // some load
                    L0_1_instr.setOperation(Operation::ADD);
                    L0_1_instr.setSRC1(Addressing(SRC_LS_3D));
                    LS_instr.setChaining(true);
                    assert(!LS_instr.getSrc1()->getIsChain() && !LS_instr.getSrc1()->getIsImmediate());
                    testSequence->append(L0_1_instr.create());
                    testSequence->setName("(L0_1<-) LS");
                }
                LS_instr.setOperation(static_cast<Operation::Operation>(current_test_sequence_single_operation));
                testSequence->append(LS_instr.create());
            } else {
                if (useMachInitWhileLSchain && current_test_sequence_single_operation == Operation::MACH){
                    GenericInstruction* instr = &L0_1_instr;
                    if (current_test_sequence_single_lane == LANE::L0) {
                        instr = &L0_instr;
                    } else if (current_test_sequence_single_lane == LANE::L1) {
                        instr = &L1_instr;
                    }
                    /**
                     * Overwrite SRC2 to use chain data from LS.
                     * keep previous address (imm / addr) to enable reset with corresponding source/value
                     * basic syntax:
                     *   // complex_ADDR_3D(SRC_SEL_LS, init_offset, init_alpha, init_beta, init_gamma)
                     *   // SRC_IMM_3D(imm, SRC_SEL_LS)
                     */
                    uint32_t addr = SRC_IMM_3D(SRC2.getAddress(), SRC_SEL_LS);
                    auto chain_src2_addr = Addressing(addr);
                    chain_src2_addr.calculateParamsFromAddr(addr);
                    instr->reset(DST, SRC1, chain_src2_addr, x_end, y_end, z_end);
                    instr->setOperation(
                        static_cast<Operation::Operation>(current_test_sequence_single_operation));
                    testSequence->append(instr->create());
                    // corresponding LS Loads instruction
                    LS_instr.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
                    LS_instr.setOperation(Operation::LOADS);
                    LS_instr.setChaining(true);
                    testSequence->append(LS_instr.create());
                    testSequence->setName("LS -> MACH (reset)");
                } else {
                    /**
                     * regular processing lane is tested with a single instruction
                     */
                    GenericInstruction* instr = &L0_1_instr;
                    if (current_test_sequence_single_lane == LANE::L0) {
                        instr = &L0_instr;
                    } else if (current_test_sequence_single_lane == LANE::L1) {
                        instr = &L1_instr;
                    }

                    instr->reset(DST, SRC1, SRC2, x_end, y_end, z_end);
                    instr->setOperation(
                        static_cast<Operation::Operation>(current_test_sequence_single_operation));
                    testSequence->append(instr->create());
                    testSequence->setName(print(instr->getLane()));
                }
            }
        } else if (currentSequenceCnt < totalSequenceCnt) { // getSingleSequenceCnt() + 2 * getChainSequenceCnt()) {
            assert(includeChains);
            /**
             * Chain Sequence Tests
             */
            // all 2x for both operands (for chain target)
            if (currentSequenceCnt == getSingleSequenceCnt() + getChainSequenceCnt()) {
                // both in use, second block, first sequence call
                // reset operand + chain loop
                chain_generation_operand = Operand::SRC2;
                current_test_sequence_chain = InstructionChains::END;
                chain_generation_operation_l0 = Operation::LoadStore;
                nextOperation(chain_generation_operation_l0);
                chain_generation_operation_l1 = Operation::LoadStore;
                nextOperation(chain_generation_operation_l1);
//                printf_success("NEXT SRC Operand...\n");
            }

            // loop chain, if done loop operation
            if (!nextChain(current_test_sequence_chain)) {
                // TODO: loop of operation. To be fixed...
                while (static_cast<Operation::Operation>(chain_generation_operation_l0) == Operation::MV_PL ||
                       static_cast<Operation::Operation>(chain_generation_operation_l0) == Operation::MV_MI ||
                       static_cast<Operation::Operation>(chain_generation_operation_l0) == Operation::MV_NZ ||
                       static_cast<Operation::Operation>(chain_generation_operation_l0) == Operation::MV_ZE){
                    if (!nextOperation(chain_generation_operation_l0) ||
                        !nextOperation(chain_generation_operation_l1)) {
                        printf_warning(
                            "InstructionSequenceGenerator::next() next chain resets operations which failed!\n");
                        printErrorState();
                    }
                }

                current_test_sequence_chain = InstructionChains::END;
                // new operation. start with first chain again
                if (!nextChain(current_test_sequence_chain)) {
                    printf_warning("InstructionSequenceGenerator::next() next chain is none!\n");
                    printErrorState();
                }
            }

            // generate the Sequence for this operands, operations, chain
            if (!generateNextInstructionChains()) {
                printf_warning(
                    "InstructionSequenceGenerator::next() generateNextInstructionChains failed!\n");
                printErrorState();
            }
            // generation done
        } else {    // nothing more to generate
            if (currentRegisterIteratior + 1 < maxRegisterIterations){
                // another round with other register config available
                resetSingleInstructionRun();
                resetChainRun();

                // continue with new register -> new sequence to use it
                currentRegisters = registerConfigsToCheck[currentRegisterIteratior];
                currentRegisterIteratior++;
                currentSequenceCnt = 0;
                continue;
            }
            // all done. return no sequence
            return nullptr;
        }
        currentSequenceCnt++;
        break;  // return this sequence. registers have been configured
    }
    return testSequence;
}

bool InstructionSequenceGenerator::nextOperation(int& operation) const {
    if (limitOperations) {
        if (operation != limitedOp) {
            operation = limitedOp;
            return true;
        } else {
            return false;
        }
    }
    operation--;
    if ( current_test_sequence_single_lane != LS ){
        // skip LS operations
        while (operation >= Operation::LoadStore) {
            operation--;
        }
    }
    while (operation == Operation::END || operation == Operation::LoadStore ||
           operation == Operation::Processing) {
        operation--;
    }
    if (operation <= 0)
        return false;
    else
        return true;
}

bool InstructionSequenceGenerator::nextLane(LANE& lane) {
    // only for single instructions (chains include the lane)
    if (limitLane){
        if (lane == laneLimit){
            return false;
        } else {
            lane = laneLimit;   // should never occur (init/start is == laneLimit)
            return true;
        }
    } else {
        if (lane == LS) {
            lane = L0_1;
            return true;
        } else if (lane == L0_1) {
            lane = L1;
            return true;
        } else if (lane == L1) {
            lane = L0;
            return true;
        } else {
            return false;
        }
    }
}

bool InstructionSequenceGenerator::nextChain(int& chain) {
    chain--;
    if (chain <= InstructionChains::NONE)
        return false;
    else
        return true;
}
