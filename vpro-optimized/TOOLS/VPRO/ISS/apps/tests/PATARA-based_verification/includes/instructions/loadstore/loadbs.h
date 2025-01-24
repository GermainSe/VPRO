#ifndef P_LOADBS_H
#define P_LOADBS_H

#include "instructions/loadstore/loadstore.h"

class Loadbs : public LoadStore {
   private:
    Addressing m_immediate;

   public:
    Loadbs(uint32_t x_end,
        uint32_t y_end,
        uint32_t z_end,
        uint32_t offset,
        uint32_t src_offset,
        uint32_t src_alpha,
        uint32_t src_beta,
        uint32_t src_gamma);

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

    const char* getInstructionName() const override {
        return "LOADBS";
    }
};
#endif