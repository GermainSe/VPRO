#ifndef P_INSTRUCTION_H
#define P_INSTRUCTION_H

#include <vpro.h>
#include <cstddef>
#include <cstdint>
#include "addressing/addressing.h"
#include "addressing/chain_memory.h"

class Instruction {
   protected:
    LANE m_lane;
    uint32_t m_x_end, m_y_end, m_z_end;
    bool m_is_chain;
    bool m_update_flags;
    bool m_blocking;

   public:
    Instruction(LANE lane, uint32_t x_end, uint32_t y_end, uint32_t z_end,
        bool update_flags, bool is_chain = false, bool blocking = false);
    virtual ~Instruction() = default;

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

    virtual bool isInputChainStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right) = 0;

    virtual bool isInputChain() = 0;

    // getter
    [[nodiscard]] LANE getLane() const {
        return m_lane;
    }
    [[nodiscard]] uint32_t getXEnd() const {
        return m_x_end;
    }
    [[nodiscard]] uint32_t getYEnd() const {
        return m_y_end;
    }
    [[nodiscard]] uint32_t getZEnd() const {
        return m_z_end;
    }
    [[nodiscard]] bool getIsChain() const {
        return m_is_chain;
    }
    [[nodiscard]] uint getLength() const {
        return (getXEnd() + 1) * (getYEnd() + 1) * (getZEnd() + 1);
    };

    [[nodiscard]] bool getUpdateFlags() const {
        return m_update_flags;
    };

    [[nodiscard]] bool getBlocking() const {
        return m_blocking;
    }

    [[nodiscard]] virtual Addressing* getDst() = 0;
    [[nodiscard]] virtual Addressing* getSrc1() = 0;
    [[nodiscard]] virtual Addressing* getSrc2() = 0;

    // setter
    void setLane(LANE lane) {
        m_lane = lane;
    }

    virtual void updateOperandAddresses() = 0;

    const char* c_str() const;

    virtual const char* getInstructionName() const {
        return "<undefined>";
    }

    virtual const char* getOperands(char* buf) const {
        return "<operands>";
    }

   protected:
    void writeRF(int32_t* rf, uint addr, int data){
        rf[addr] = data;
        if (m_update_flags){
            rf[VPRO_CFG::RF_SIZE + addr] = (data < 0);
            rf[VPRO_CFG::RF_SIZE*2 + addr] = (data == 0);
        }
    };
};

#endif