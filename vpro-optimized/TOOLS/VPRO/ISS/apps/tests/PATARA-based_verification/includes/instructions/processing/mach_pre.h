#ifndef P_MACH_PRE_H
#define P_MACH_PRE_H

#include "instructions/processing/processing.h"

class Mach_pre : public Processing {
   private:
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

   public:
    Mach_pre(LANE lane,
        uint32_t x_end,
        uint32_t y_end,
        uint32_t z_end,
        Addressing addr_dst,
        Addressing addr_src1,
        Addressing addr_src2,
        bool is_chain = false,
        bool update_flags = false,
        bool blocking = false);
    void vproInstruction();

    const char* getInstructionName() const override {
        return "MACH_PRE";
    }
};

#endif