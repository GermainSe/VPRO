//
// Created by gesper on 06.03.24.
//

#ifndef PATARA_BASED_VERIFICATION_RANDOMSEQUENCEGENERATOR_H
#define PATARA_BASED_VERIFICATION_RANDOMSEQUENCEGENERATOR_H

#include "ChainingStatus.h"
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

class RandomSequenceGenerator : public InstructionChainGenerator {
   public:
    explicit RandomSequenceGenerator(unsigned int seq_length = 5, uint64_t init_seed = 0x5f21c6b8a155e0c1);

    TestSequence* next() override;

   private:
    static const bool verbose = false;

    unsigned int sequence_length;

    static const unsigned int max_prob              = 100000; // ... of 100 000
    static const unsigned int fifty_fifty_prob      =  50000; // ... of 100 000

    static const unsigned int chain_prob_default    =  15000; // 15 %
    static const unsigned int imm_prop_default      =  25000; // 25 % -> addr: 60%

    /**
     * generated TestCase (by a call of next())
     */
    //    TestSequence* testChainSequence{};
    TestSequence* testRandomSequence{};

    /**
     * Using the randomness to generate any kind of valid Operation
     * @return
     */
    static Operation::Operation randomOp();

    static Addressing generateRandomAddress(Address::Type addr,
        unsigned int chain_prop = chain_prob_default,
        unsigned int imm_prop = imm_prop_default,
        unsigned int chain_source_neighbor_prop = fifty_fifty_prob);

    static void setRandomSourceOperand(Addressing addr,
        GenericInstruction * instr);

    void vproRegisterConfig(bool verbose) const override;

    /**
     * X, Y, and Z are required for instructions.
     * The length is (sometimes) set, e.g. when chains shall be finished.
     * @param x input variable -> gets set
     * @param y input variable -> gets set
     * @param z input variable -> gets set
     * @param length length to be distributed
     */
    static void generateRandomXYZ(GenericInstruction *instr, uint& x, uint& y, uint& z, int length = -1);

    /**
     * Creates a complete random instruction
     * @return
     */
    Instruction* generateRandomInstruction();

    /**
     * Finishes all open chains.
     * Depends on chainChecker Status (previously generated random instructions).
     * TODO: detect deadlocks -> remove instructions?
     * @return a single instruction to complete one of the chains
     */
    Instruction* generateFinalizeInstruction();

    /**
     * Status of current issued instructions in terms of chaining connection.
     * Gets updated when an instruction is created.
     * Holds the Fifo element count (producing chains) and the awaiting count (consuming chains)
     */
    ChainingStatus chainChecker{verbose};

};

#endif  //PATARA_BASED_VERIFICATION_RANDOMSEQUENCEGENERATOR_H
