//
// Created by gesper on 12.12.23.
//

#ifndef PATARA_BASED_VERIFICATION_GENERICINSTRUCTION_H
#define PATARA_BASED_VERIFICATION_GENERICINSTRUCTION_H

#include "instruction.h"
#include "vproOperations.h"

class GenericInstruction : public Instruction {
   public:
    /**
     * The Generic Instruction is an Instruction which is not yet specialized
     * It requires to call setOperation(...) for configuration.
     * Then, to create a specific Instruction (e.g. Add) the create() function is used.
     * @param lane
     * @param xEnd
     * @param yEnd
     * @param zEnd
     */
    explicit GenericInstruction(LANE lane, uint32_t xEnd = 0, uint32_t yEnd = 0, uint32_t zEnd = 0);

    GenericInstruction();

    ~GenericInstruction() override = default;

//    void setLane(LANE lane);
    void setOperation(Operation::Operation op);
    void setxEnd(uint32_t xEnd);
    void setyEnd(uint32_t yEnd);
    void setzEnd(uint32_t zEnd);
    void setDST(Addressing dst);
    void setSRC1(Addressing src1);
    void setSRC2(Addressing src2);
    void setChaining(bool chaining = true);
    void setSourceLane(LANE lane);
    void setBlocking(bool blocking);
    void setFlagUpdate(bool update);

    [[nodiscard]] Operation::Operation getOperation() const {return m_op;}
    Addressing *getSrc1() override {return &m_src1;}
    Addressing *getSrc2() override {return &m_src2;}
    Addressing *getDst() override {return &m_dst;}

    /**
     * Reset the operands to the given default addressing (e.g. imm / complex)
     * @param inst instruction to be resetted
     */
    void reset(Addressing& default_dst, Addressing& default_src1, Addressing& default_src2,
        int xend, int yend, int zend);

    /**
     * Generate the defined instruction
     * @return a new Instruction(), e.g. Add(...) as defined by parameters
     */
    Instruction* create();

    // fake Instruction functions -> this is a Generator, do not use!
    void vproInstruction() override {
        printf_error(
            "[Error!]Generic Instruction should not be executed on VPRO!\nThis is a Generator!\n");
        exit(1);
    }
    void riscvInstruction(int32_t* rf,
        int16_t* lm,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        int64_t& accu,
        ChainMemory& out_chain,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right) override {
        printf_error(
            "[Error!]Generic Instruction should not be executed on Risc-V!\nThis is a "
            "Generator!\n");
        exit(1);
    }
    bool isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right) override {
        printf_error(
            "[Error!]Generic Instruction should not be evaluated by isInputChainStall!\nThis is a "
            "Generator!\n");
        exit(1);
    }
    bool isInputChain() override {
        printf_error(
            "[Error!]Generic Instruction should not be evaluated by isInputChain!\nThis is a "
            "Generator!\n");
        exit(1);
    }

    const char* getInstructionName() const override {
        return "<Generic Instruction>";
    }

    const char* getOperands(char* buf) const override {
        return "<Generic Operand!>";
    }

    void updateOperandAddresses() override {
        printf_warning("Generic Instruction. updateOperandAddress no available!\n");
    }

    bool check(uint& x, uint& y, uint& z, int hazardCheckEntries = 8) const;

   private:
    bool isOperationSet{false};
    Operation::Operation m_op{Operation::NONE};

    Addressing m_dst{0, Address::Type::SRC1};
    Addressing m_src1{0, Address::Type::SRC1};
    Addressing m_src2{0, Address::Type::SRC1};

    LANE m_sourcelane{L0};   // for ls store -> id of lane

    bool m_blocking{false}, m_flagUpdate{false};

    size_t maxInstructionSize{};
    Instruction *resultingInstruction{};
};

#endif  //PATARA_BASED_VERIFICATION_GENERICINSTRUCTION_H
