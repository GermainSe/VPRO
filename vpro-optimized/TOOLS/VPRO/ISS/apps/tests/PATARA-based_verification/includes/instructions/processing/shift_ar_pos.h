#ifndef P_SHIFT_AR_POS_H
#define P_SHIFT_AR_POS_H

#include "instructions/processing/processing.h"

class Shift_ar_pos : public Processing {
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
    Shift_ar_pos(LANE lane,
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
        return "SHIFT_AR_POS";
    }
};

#endif