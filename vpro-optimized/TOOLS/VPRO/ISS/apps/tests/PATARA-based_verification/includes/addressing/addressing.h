#ifndef P_ADDRESSING_H
#define P_ADDRESSING_H

#include <vpro.h>
#include <cstddef>
#include <cstdint>
#include <string>
#include "chain_memory.h"

namespace Address {
/**
     * @brief enum class for address types
     */
enum class Type {
    SRC1 = 0,
    SRC2 = 1,
    DST = 2,
};
}  // namespace Address

class Addressing {
   private:
    int m_offset{}, m_alpha{}, m_beta{}, m_gamma{};
    int m_immediate{};
    bool m_is_immediate = false, m_is_chain = false;
    Address::Type m_address_type{Address::Type::SRC1};
    uint32_t m_address{};

    [[nodiscard]] const char* getChainedName() const;

   public:
    enum CHAIN_DIRECTION {
        CHAIN_DIR_LEFT,
        CHAIN_DIR_RIGHT,
        CHAIN_DIR_LS,
    };
    CHAIN_DIRECTION getChainDir() const;

    // constructor
    constexpr Addressing(bool c, int addr, Address::Type address_type) :
          m_address_type(address_type),
          m_address(addr)
    { };
    Addressing(int offset, int alpha, int beta, int gamma, Address::Type address_type);
    Addressing(int immediate, Address::Type address_type);
    explicit Addressing(uint32_t address);
    Addressing()= default;

    static Addressing fromAddr(uint32_t address) {
        auto adr = Addressing();
        adr.calculateParamsFromAddr(address);
        return adr;
    }

    // getter
    int getOffset() const;
    int getAlpha() const;
    int getBeta() const;
    int getGamma() const;
    int getImmediate(const bool skipCheck = false) const;
    uint32_t getAddress() const;
    bool getIsImmediate() const;
    bool getIsChain() const;
    bool getIsAddress() const;

    void setImmediate(int immediate);

    void setOffset(int offset){m_offset = offset;}
    void setAlpha(int alpha){m_alpha = alpha;}
    void setBeta(int beta){m_beta = beta;}
    void setGamma(int gamma){m_gamma = gamma;}

    void setOffsetRandom(int limit = MAX_OFFSET);
    void setAlphaRandom(int limit = MAX_ALPHA);
    void setBetaRandom(int limit = MAX_BETA);
    void setGammaRandom(int limit = MAX_GAMMA);

    void calculateAddress();
    int calculateAddress(const int& x, const int& y, const int& z, const bool skipCheck = false) const;

    void calculateParamsFromAddr(uint32_t address);

    bool checkStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right);

    int32_t getData(const int32_t* rf,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right);

    bool getNFlag(const int32_t* rf,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right) const;

    bool getZFlag(const int32_t* rf,
        const size_t& x,
        const size_t& y,
        const size_t& z,
        ChainMemory& ls,
        ChainMemory& left,
        ChainMemory& right) const;

    char* c_str(char* buf) const {
        if (m_is_immediate) {
            sprintf(buf, "IMM: %5i          ", getImmediate()); //  20 chars
        } else if (m_is_chain) {
            sprintf(buf, "Chain: %-12s ", getChainedName());
        } else {
            sprintf(buf, "%4u, %3i, %3i, %3i ", m_offset, m_alpha, m_beta, m_gamma);
        }
        return buf;
    }

    char *__c_str_vpro(char* buf) const {
        if (m_is_immediate) {
            sprintf(buf, "SRC_IMM_3D(%5i)", getImmediate()); //  20 chars
        } else if (m_is_chain) {
            switch (m_address) {
                case SRC_SEL_NEIGHBOR:              sprintf(buf, "SRC_CHAINING_NEIGHBOR_LANE");break;
//                case SRC_SEL_INDIRECT_NEIGHBOR:     sprintf(buf, "SRC_SEL_INDIRECT_NEIGHBOR"); break;
//                case SRC_SEL_INDIRECT_LS_LANE1:     sprintf(buf, "SRC_SEL_INDIRECT_LS_LANE1"); break;
//                case SRC_SEL_INDIRECT_LS_LANE0:     sprintf(buf, "SRC_SEL_INDIRECT_LS_LANE0"); break;
                case SRC_LS_3D:                     sprintf(buf, "SRC_LS_3D");                 break;
                case SRC_DONT_CARE_3D:              sprintf(buf, "SRC_DONT_CARE_3D");          break;
                default:                            sprintf(buf, "SRC_CHAINING_NEIGHBOR_LANE");
            }
        } else {
            sprintf(buf, "ADDR_4(%4u, %3i, %3i, %3i)", m_offset, m_alpha, m_beta, m_gamma);
        }
        return buf;
    }

};

#endif