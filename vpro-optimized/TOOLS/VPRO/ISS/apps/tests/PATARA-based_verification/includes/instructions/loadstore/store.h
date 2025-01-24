#ifndef P_STORE_H
#define P_STORE_H

#include "instructions/loadstore/loadstore.h"

class Store : public LoadStore {
   private:
    LANE m_src_lane;
    Addressing m_immediate;

   public:
    Store(uint32_t x_end,
        uint32_t y_end,
        uint32_t z_end,
        uint32_t offset,
        uint32_t dst_offset,
        uint32_t dst_alpha,
        uint32_t dst_beta,
        uint32_t dst_gamma,
        LANE src_lane);

    void vproInstruction();
    void riscvInstruction(int32_t* rf,
        int16_t* lm,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        int64_t& accu,
        ChainMemory& out_chain,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right);

    bool isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right);
    bool isInputChain();

    const char* getInstructionName() const override {
        return "STORE";
    }

    LANE getSourceLane() const{
        return m_src_lane;
    }

    const char* getOperands(char* buf) const {
        char a[256];
        m_src.c_str(a);
        sprintf(buf, "Store (%s)                 SRC:  %s, Imm: %4u (0x%04x)        ", print(m_src_lane), a, getOffset(), getOffset());
        return buf;
    }
};
#endif