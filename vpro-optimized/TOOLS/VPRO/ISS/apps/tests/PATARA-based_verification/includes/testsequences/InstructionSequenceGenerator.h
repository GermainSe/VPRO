//
// Created by gesper on 11.12.23.
//

#ifndef PATARA_BASED_VERIFICATION_INSTRUCTIONSEQUENCEGENERATOR_H
#define PATARA_BASED_VERIFICATION_INSTRUCTIONSEQUENCEGENERATOR_H

#include "InstructionChainGenerator.h"
#include "TestSequence.h"
#include "addressing/addressing.h"
#include "addressing/lane.h"
#include "chains.h"
#include "instructions/genericInstruction.h"
#include "instructions/loadstore/load.h"
#include "instructions/processing/add.h"
#include "instructions/processing/mach.h"
#include "instructions/processing/mull.h"
#include "memory.h"
#include "test_env.h"
#include "vproOperands.h"

using namespace TEST_ENVS;

/**
 * Class to generate instruction sequences (alias testcases) for the VPRO.
 * The sequence which gets generated can be configured (e.g. by test_cfg_s struct -> init(...)).
 * This generator is called by next() -> returns nullptr if Testsequence is not filled with
 * new instructions. Else, a (constant) sequence is returned with a new sequence in content.
 *
 * This Class inherits from instructionChainGenerator
 *
 * e.g. generate all possible chain combinations, add delay instructions in between
 *      (and at begin to fill cmd fifo),
 *      repeat for chaining to both source operands, repeat for all possible operations,
 *      use blocking flag on chain end, or on delay instructions
 * e.g. test all instructions, limit lane, variate mach shift register values, reset source and mode
 *      (only possible if operation is limited to mach)
 */
class InstructionSequenceGenerator : public InstructionChainGenerator{
   public:
    InstructionSequenceGenerator();

    void init(int x_end,
        int y_end,
        int z_end,
        Addressing dst,
        Addressing src1,
        Addressing src2,
        bool includeSingleInstructions = true,
        bool includeChains = true,
        bool includeSRC1 = true,
        bool includeSRC2 = true,
        bool variateMACHInitSource = false,
        bool variateMACHResetMode = false,
        bool variateMACHShifts = false,
        bool variateMULHShifts = false,
        bool useMachInitWhileLSchain = false,
        bool limitOperations = false,
        Operation::Operation limitedOp = Operation::NOR,
        bool limitLane = false,
        LANE laneLimit = L0_1,
        bool introduceChainDelayCommands = false,
        int chainDelays = 1,
        bool introduceBlockingChainCommands = false,
        bool introduceBlockingDelayCommands = false);

    void init(const test_cfg_s& config) override;

    TestSequence* next() override;

    [[nodiscard]] int getTotalSequences() const override {
        return totalSequenceCnt * maxRegisterIterations;
    }

    /**
     * Execute the VPRO register set calls to set the current special register configuration
     * @param verbose whether to print the written data
     */
    void vproRegisterConfig(bool verbose) const override;

   private:
    /**
     * generated TestCase (by a call of next())
     */
    TestSequence* testSequence{};

    /**
     * Flags for Single Instruction Tests
     */
    bool includeSingleInstructions{}, includeChains{}, includeSRC1{}, includeSRC2{};

    /**
     * limit Lane and Operation
     */
    bool limitLane{false};
    LANE laneLimit{L0_1};
    bool limitOperations{false};
    Operation::Operation limitedOp{Operation::Operation::NOP};

    /**
     * Register iteration
     */
    bool variateMACHInitSource{}, variateMACHResetMode{};
    bool variateMACHShifts{}, variateMULHShifts{};
    bool useMachInitWhileLSchain{};
    struct register_config_s {
        VPRO::MAC_INIT_SOURCE MACInitSource{VPRO::MAC_INIT_SOURCE::ZERO};
        VPRO::MAC_RESET_MODE MACResetMode{VPRO::MAC_RESET_MODE::NEVER};
        uint MACHShift{0};
        uint MULHShift{0};
    } currentRegisters;
    std::vector<register_config_s> registerConfigsToCheck;
    int currentRegisterIteratior{0};
    int maxRegisterIterations{0};


    /**
     * print helper called when error occurs during sequence generation
     */
    void printErrorState();


    bool nextOperation(int& operation) const;
    bool nextLane(LANE& lane);
    static bool nextChain(int& chain);

    void resetSingleInstructionRun();
    void resetChainRun();

    /**
     * counter functions for sequence length determination
     */
    static int getProcessingOperationCnt();
    static int getLSOperationCnt();
    [[nodiscard]] int getSingleSequenceCnt() const;
    [[nodiscard]] int getChainSequenceCnt() const;

    /**
     * remaining test variables
     */
    int totalSequenceCnt{0};
    int currentSequenceCnt{0};

    int current_test_sequence_single_operation{Operation::NONE};
    LANE current_test_sequence_single_lane{};
};

#endif  //PATARA_BASED_VERIFICATION_INSTRUCTIONSEQUENCEGENERATOR_H
