#ifndef P_PROCESSING_H
#define P_PROCESSING_H

#include "addressing/addressing.h"
#include "instructions/instruction.h"

class Processing : public Instruction {
   private:
    Addressing m_addr_dst, m_addr_src1, m_addr_src2;

   public:
    Processing(LANE lane,
        uint32_t x_end,
        uint32_t y_end,
        uint32_t z_end,
        Addressing addr_dst,
        Addressing addr_src1,
        Addressing addr_src2,
        bool is_chain = false,
        bool update_flags = false,
        bool blocking = false);
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

    // getter
    Addressing *getSrc1() override {return &m_addr_src1;}
    Addressing *getSrc2() override {return &m_addr_src2;}
    Addressing *getDst() override {return &m_addr_dst;}

    void updateOperandAddresses() override;

    // other functions
    bool isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right);
    bool isInputChain();

    int32_t getSrc1Data(const int32_t* rf,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right);

    int32_t getSrc2Data(const int32_t* rf,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right);

    const char* getInstructionName() const override {
        return "<undefined processing>";
    }

    const char* getOperands(char* buf) const override {
        char a[256];
        m_addr_dst.c_str(a);
        char b[256];
        m_addr_src1.c_str(b);
        char c[256];
        m_addr_src2.c_str(c);

        sprintf(buf, "DST: %s, SRC1: %s, SRC2: %s", a, b, c);

        return buf;
    }
};
#endif