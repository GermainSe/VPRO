#ifndef P_LOADSTORE_H
#define P_LOADSTORE_H

#include <cstdint>
#include "addressing/addressing.h"
#include "instructions/instruction.h"

class LoadStore : public Instruction {
   protected:
    uint32_t m_offset;
    Addressing m_src;

    Addressing m_dst{true, DST_ADDR(0, 0, 0, 0), Address::Type::DST};
    Addressing m_src2;  // offset / immediate!

   public:
    LoadStore(uint32_t x_end,
        uint32_t y_end,
        uint32_t z_end,
        uint32_t offset,
        Addressing src);
    virtual void vproInstruction() = 0;
    virtual void riscvInstruction(int32_t* rf,
        int16_t* lm,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        int64_t& accu,
        ChainMemory& out_chain,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right) = 0;

    bool isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right);

    bool isInputChain(){return false; };    // default for Load

    // getter
    uint32_t getOffset() const;
    Addressing &getSrc();

    Addressing *getSrc1() override {return &m_src;}
    Addressing *getSrc2() override {return &m_src2;}
    Addressing *getDst() override {return &m_dst;}
    // setter

    void updateOperandAddresses() override;

    const char* getInstructionName() const override {
        return "<undefined loadstore>";
    }

    const char* getOperands(char* buf) const override {
        char a[256];
        m_src.c_str(a);

        sprintf(buf, "                           SRC:  %s, Imm: %4u (0x%04x)        ", a, m_offset, m_offset);
        return buf;
    }
};
#endif