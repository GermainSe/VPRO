//
// Created by gesper on 14.12.23.
//

#ifndef PATARA_BASED_VERIFICATION_TESTSEQUENCE_H
#define PATARA_BASED_VERIFICATION_TESTSEQUENCE_H

#include <vector>
#include "instructions/instruction.h"

class TestSequence {
   private:
    static constexpr int RESERVED_INSTRUCTION_VECTOR_SIZE = 300;

    const char * name;

   public:
    explicit TestSequence(int reserve = RESERVED_INSTRUCTION_VECTOR_SIZE);

    ~TestSequence(){
        for (auto &i : instructions){
            delete i;
        }
    }

    void clear();

    void setName(const char *name);

    /**
     * Getter for the instruction list of this test case
     */
    std::vector<Instruction*> getInstructions() {
        return instructions;
    }

    [[nodiscard]] size_t getLength() const {
        return instructions.size();
    }

    /**
     * prints the complete instruction list of this test case
     */
    void printInstructions(const char * prefix = "");

    /**
     * Creates a one-line string of this test sequence.
     * With all options: `Sequence: [L1->L0, OR->OR, (x:0, y:63, z:0), #Inst.: 2]`
     * @param buffer is required to be large enough (e.g. 80)
     * @param includeOpcode [optional, default: false] whether to print the opcodes of all instructions
     * @param includeOperands [optional, default: false] check if any (not LS) operand is IMM, else complex addr is used
     * @param includeVectorLen [optional, default: false] whether to print the vector limits of the first instruction
     * @return the buffer
     */
    char * c_str(char *buffer, bool includeOpcode = false, bool includeOperands = false, bool includeVectorLen = false);

    /**
     * checks if this TestCase can be executed
     * @return if it can be executed
     */
    bool check();

    /**
     * put another instruction to this test case
     * @param instr pointer to instruction to append (instruction gets not copied)
     */
    void append(Instruction* instr) {
        instructions.emplace_back(instr);
    }

    /**
     * put another instruction to this test case
     * @param instr pointer to instruction to append (instruction gets not copied)
     */
    void append(TestSequence* seq) {
        for (auto instr : seq->instructions) {
            instructions.emplace_back(instr);
        }
    }

    /**
     * remove and return last instruction from this TestCase
     * @return nullptr | last Instruction *
     */
    Instruction* popLast() {
        if (instructions.empty()) return nullptr;
        auto instr = instructions.back();
        instructions.pop_back();
        return instr;
    }

    const char* c_str_all(char *buffer);
    const char* c_str_vpro(char * buffer);
    const char* c_str_seq_gen(char *buffer);

    /**
     * Starts all related VPRO instructions
     */
    void vproExec();

   private:
    /**
     * generated list of instructions.
     * ready for execution / simulation.
     * instances are e.g. add, load, ...
     */
    std::vector<Instruction*> instructions;
};

#endif  //PATARA_BASED_VERIFICATION_TESTSEQUENCE_H
