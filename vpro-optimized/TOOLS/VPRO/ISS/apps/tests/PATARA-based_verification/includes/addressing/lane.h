#ifndef P_LANE_H
#define P_LANE_H

#include <vpro.h>
#include <cstdint>
#include <vector>
#include "chain_memory.h"
#include "instructions/instruction.h"

class Lane {
   public:
    enum state {
        IDLE,
        BUSY_STALLED,
        BUSY,
        CHAINING_ACTIVE,
    } lane_state;

    Lane(LANE id,
        ChainMemory& own,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right,
        bool verbose = false);

    LANE m_id;
    Instruction* current_instr{nullptr};

    void iteration(int32_t* rf, int16_t* lm);

    [[nodiscard]] bool isBusy() const {
        return lane_state != IDLE;
    }

    void newInstruction(Instruction* inst);

    void reset(){
        m_z = 0;
        m_y = 0;
        m_x = 0;
//        m_accu = 0;
        current_instr = nullptr;
        lane_state = IDLE;
        restore_saved_state = false;
    }

    void resetAccu(int64_t value = 0){
        m_accu = value;
    }

   private:
    ChainMemory& own_chain;
    ChainMemory& left_chain;
    ChainMemory& right_chain;
    ChainMemory& ls_chain;

    size_t m_z{0}, m_y{0}, m_x{0};

    int64_t m_accu{0};

    bool restore_saved_state{false};
    bool verbose;
};

#endif