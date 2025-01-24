#include "addressing/addressing.h"
#include <vpro.h>
#include "constants.h"
#include "random/random_lib.h"

/**
 * @brief Construct a new 3D-Addressing object for Instructions; offset + alpha * x + beta * y + gamma * z
 *
 * @param offset
 * @param alpha
 * @param beta
 * @param gamma
 * @param address_type of enum: source 1, source 2 or destination
 */
Addressing::Addressing(int offset, int alpha, int beta, int gamma, Address::Type address_type)
    : m_offset(offset),
      m_alpha(alpha),
      m_beta(beta),
      m_gamma(gamma),
      m_address_type(address_type) {
    calculateAddress();
}
/**
 * @brief Construct a new Immediate Addressing object
 *
 * @param immediate 24 or 18 bits, depending on instruction
 * @param address_type of enum: source 1 or source 2
 */
Addressing::Addressing(int immediate, Address::Type address_type)
    : m_immediate(immediate),
      m_is_immediate(true),
      m_address_type(address_type) {
    calculateAddress();
}
/**
 * @brief Construct a new chain Addressing object
 *
 * @param chain_address same as vpro chain adress
 */
Addressing::Addressing(uint32_t chain_address) : m_is_chain(true), m_address(chain_address) {}

// private functions
/**
 * @brief used to create an vpro address object depending on the Addressing object variables
 *
 * @return uint32_t the vpro address object
 */
void Addressing::calculateAddress() {
    switch (m_address_type) {
        case Address::Type::DST:
            if (m_is_immediate || m_is_chain) {
                printf_error("destination: address required as type!\n");
                sim_stop();
                exit(1);
            } else {
                m_address = DST_ADDR(m_offset, m_alpha, m_beta, m_gamma);
            }
            break;
        case Address::Type::SRC1:
            if (m_is_immediate) {
                m_address = SRC1_IMM_3D(m_immediate);
            } else if (m_is_chain) {
                //                m_address = m_address;
            } else {
                m_address = SRC1_ADDR(m_offset, m_alpha, m_beta, m_gamma);
            }
            break;
        case Address::Type::SRC2:
            if (m_is_immediate) {
                m_address = SRC2_IMM_3D(m_immediate);
            } else if (m_is_chain) {
                //                m_address = m_address;
            } else {
                m_address = SRC2_ADDR(m_offset, m_alpha, m_beta, m_gamma);
            }
            break;
        default:
            printf_error("Addresstype not valid!\n");
            sim_stop();
            exit(1);
    }
}

// getter
/**
 * @brief get offset class variable. error if not 3d-address object
 *
 * @return int offset class variable
 */
int Addressing::getOffset() const {
    if (m_is_immediate) {
        printf_error("Immediate has no offset!\n");
        sim_stop();
        exit(1);
    } else {
        return m_offset;
    }
}
/**
 * @brief get alpha class variable. error if not 3d-address object
 *
 * @return int alpha class variable
 */
int Addressing::getAlpha() const {
    if (m_is_immediate) {
        printf_error("Immediate has no alpha!\n");
        sim_stop();
        exit(1);
    } else {
        return m_alpha;
    }
}
/**
 * @brief get beta class variable. error if not 3d-address object
 *
 * @return int beta class variable
 */
int Addressing::getBeta() const {
    if (m_is_immediate) {
        printf_error("Immediate has no beta!\n");
        sim_stop();
        exit(1);
    } else {
        return m_beta;
    }
}
/**
 * @brief get gamma class variable. error if not 3d-address object
 *
 * @return int gamma class variable
 */
int Addressing::getGamma() const {
    if (m_is_immediate) {
        printf_error("Immediate has no gamma!\n");
        sim_stop();
        exit(1);
    } else {
        return m_gamma;
    }
}
/**
 * @brief get immediate class variable. error if not immediate object
 *
 * @return int immediate class variable
 */
int Addressing::getImmediate(const bool skipCheck) const {
    if (!skipCheck && m_is_immediate) {
        return m_immediate;
    } else {
//        printf_warning("Address has no immediate! Reinterpreting as ...\n");
        return ((m_offset << ISA_OFFSET_SHIFT_3D) |
                (m_alpha << ISA_ALPHA_SHIFT_3D) |
                (m_beta << ISA_BETA_SHIFT_3D) |
                m_gamma);
    }
}
/**
 * @brief get address class variable
 *
 * @return uint32_t address class variable
 */
uint32_t Addressing::getAddress() const {
    return m_address;
}

/**
 * @brief get isImmediate class variable
 *
 * @return true address object is immediate
 * @return false address object is not an immediate
 */
bool Addressing::getIsImmediate() const {
    return m_is_immediate;
}

bool Addressing::getIsAddress() const {
    return !(m_is_immediate || m_is_chain);
}

/**
 * @brief get isChain class variable
 *
 * @return true address object is chained from the lane
 * @return false address object is not chained from the lane
 */
bool Addressing::getIsChain() const {
    return m_is_chain;
}

// public methods
/**
 * @brief calculates address for riscv instruction access to register file and memory for current iteration. offset + alpha * x + beta * y + gamma * z
 *
 * @param x
 * @param y
 * @param z
 * @return int the calculated address
 */
int Addressing::calculateAddress(const int& x, const int& y, const int& z, const bool skipCheck) const {
    if (!skipCheck && m_is_immediate) {
        printf_error("Immediate can't calculate an address.\n");
        sim_stop();
        exit(1);
    } else if (!skipCheck && m_is_chain) {
        printf_error("Chained address can't calculate an address.\n");
        sim_stop();
        exit(1);
    } else {
        int addr = m_offset + x * m_alpha + y * m_beta + z * m_gamma;
        assert(addr < VPRO_CFG::RF_SIZE || addr < VPRO_CFG::LM_SIZE);   // TODO: check based on lm / rf target
        return addr;
    }
}

bool Addressing::checkStall(ChainMemory& ls, ChainMemory& left, ChainMemory& right) {
    if (m_is_chain) {
        if (getChainDir() == CHAIN_DIR_LEFT) {
            return left.isEmpty();
        } else if (getChainDir() == CHAIN_DIR_RIGHT) {
            return right.isEmpty();
        } else if (getChainDir() == CHAIN_DIR_LS) {
            return ls.isEmpty();
        }
    }
    return false;
}

/**
 * @brief gets the data from the register file at the specific address calculated by the given values of x, y and z. If the object is a chained address or an immediate value it also returns it
 *
 * @param rf register file as array, pointer
 * @param x for address calculation
 * @param y for address calculation
 * @param z for address calculation
 * @param lane_chained array of the chained lane data from previous instructions in convoy
 * @return int32_t the data at the address in the register file, the immediate value or the chained data
 */
int32_t Addressing::getData(const int32_t* rf,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) {
    if (m_is_immediate) {
        return m_immediate;
    } else if (m_is_chain) {
        if (getChainDir() == CHAIN_DIR_LEFT) {
            return left.get();
        } else if (getChainDir() == CHAIN_DIR_RIGHT) {
            return right.get();
        } else if (getChainDir() == CHAIN_DIR_LS) {
            return ls.get();
        }
    } else {
        return rf[calculateAddress(x, y, z)];
    }
    return -1;
}

bool Addressing::getNFlag(const int32_t* rf,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) const{
        if (m_is_immediate) {
            return false;
        } else if (m_is_chain) {
            if (getChainDir() == CHAIN_DIR_LEFT) {
                return left.get_nflag();
            } else if (getChainDir() == CHAIN_DIR_RIGHT) {
                return right.get_nflag();
            } else if (getChainDir() == CHAIN_DIR_LS) {
                return ls.get_nflag();
            }
        } else {
            return rf[VPRO_CFG::RF_SIZE + calculateAddress(x, y, z)];
        }
        return false;
}

bool Addressing::getZFlag(const int32_t* rf,
    const size_t& x,
    const size_t& y,
    const size_t& z,
    ChainMemory& ls,
    ChainMemory& left,
    ChainMemory& right) const{
    if (m_is_immediate) {
        return false;
    } else if (m_is_chain) {
        if (getChainDir() == CHAIN_DIR_LEFT) {
            return left.get_zflag();
        } else if (getChainDir() == CHAIN_DIR_RIGHT) {
            return right.get_zflag();
        } else if (getChainDir() == CHAIN_DIR_LS) {
            return ls.get_zflag();
        }
    } else {
        return rf[VPRO_CFG::RF_SIZE*2 + calculateAddress(x, y, z)];
    }
    return false;
}

Addressing::CHAIN_DIRECTION Addressing::getChainDir() const {
    if (not m_is_chain) {
        printf_error("Only chained address can be used to get chained lane number.\n");
        sim_stop();
        exit(1);
    }
    switch ((m_address >> ISA_COMPLEX_LENGTH_3D) & ISA_SEL_LEN_MASK) {
        case SRC_SEL_NEIGHBOR:
        case SRC_SEL_INDIRECT_NEIGHBOR:
        case SRC_SEL_INDIRECT_LS_LANE0:
//        case SRC_CHAINING_LEFT_3D:
//        case SRC_CHAINING_LEFT_DELAYED_3D:
//        case SRC_LS_LEFT_3D:
//        case SRC_LS_LEFT_DELAYED_3D:
//        case SRC_CHAINING_LEFT_2D:
//        case SRC_CHAINING_LEFT_DELAYED_2D:
//        case SRC_LS_LEFT_2D:
//        case SRC_LS_LEFT_DELAYED_2D:
            return CHAIN_DIR_LEFT;

        case SRC_SEL_INDIRECT_LS_LANE1:
//        case SRC_CHAINING_RIGHT_3D:
//        case SRC_CHAINING_RIGHT_DELAYED_3D:
//        case SRC_LS_RIGHT_3D:
//        case SRC_LS_RIGHT_DELAYED_3D:
//        case SRC_CHAINING_RIGHT_2D:
//        case SRC_CHAINING_RIGHT_DELAYED_2D:
//        case SRC_LS_RIGHT_2D:
//        case SRC_LS_RIGHT_DELAYED_2D:
            return CHAIN_DIR_RIGHT;

        case SRC_SEL_LS:
        case SRC_SEL_INDIRECT_LS:
//        case SRC_LS_3D:
//        case SRC_LS_DELAYED_3D:
//        case SRC_LS_2D:
//        case SRC_LS_DELAYED_2D:
            return CHAIN_DIR_LS;

        case SRC_DONT_CARE_3D:
        default:
            printf_error("Addresstype not valid!\n");
            sim_stop();
            exit(1);
    }
}

const char* Addressing::getChainedName() const {
    switch (m_address) {
        case SRC_SEL_NEIGHBOR:
            return "NEIGHBOR";

        case SRC_SEL_INDIRECT_NEIGHBOR:
            return "INDIRECT_NEIGHBOR";

        case SRC_SEL_INDIRECT_LS_LANE1:
            return "LANE0";

        case SRC_SEL_INDIRECT_LS_LANE0:
            return "LANE1";

        case SRC_LS_3D:
            return "LS";

        case SRC_DONT_CARE_3D:
            return "DONT_CARE";

        default:
            auto dir = getChainDir();
            if (dir == CHAIN_DIR_LS)
                return "LS";
            else if (dir == CHAIN_DIR_LEFT)
                return "LEFT";
            else //if (dir == CHAIN_DIR_RIGHT)
                return "RIGHT";
    }
}
void Addressing::setImmediate(int immediate) {
    m_immediate = immediate;
    m_is_immediate = true;
}
void Addressing::calculateParamsFromAddr(uint32_t address) {
    m_offset = int32_t ((address >> ISA_OFFSET_SHIFT_3D) & ISA_OFFSET_MASK);
    m_alpha =  int32_t ((address >> ISA_ALPHA_SHIFT_3D) & ISA_ALPHA_MASK);
    m_beta =  int32_t ((address >> ISA_BETA_SHIFT_3D) & ISA_BETA_MASK);
    m_gamma =  int32_t ((address >> ISA_GAMMA_SHIFT_3D) & ISA_GAMMA_MASK);
    m_immediate = ((m_offset << ISA_OFFSET_SHIFT_3D) |
                   (m_alpha << ISA_ALPHA_SHIFT_3D) |
                   (m_beta << ISA_BETA_SHIFT_3D) |
                   m_gamma);
    if (m_immediate & 1 << (ISA_COMPLEX_LENGTH_3D-1)){
        m_immediate |= ~ISA_IMMEDIATE_MASK_3D;
    }
    switch ((address >> ISA_COMPLEX_LENGTH_3D) & ISA_SEL_LEN_MASK) {
        case SRC_SEL_NEIGHBOR:
        case SRC_SEL_INDIRECT_NEIGHBOR:
        case SRC_SEL_INDIRECT_LS_LANE0:
        case SRC_SEL_INDIRECT_LS_LANE1:
        case SRC_SEL_LS:
        case SRC_SEL_INDIRECT_LS:
            m_is_chain = true;
            break;
        case SRC_SEL_IMM:
            m_is_immediate = true;
            break;
        default:
            break;
    }
    m_address = address;
}

void Addressing::setOffsetRandom(const int limit) {
    m_offset = (int)(next_uint32() % max(1, min(limit, (int)MAX_OFFSET)));
}
void Addressing::setAlphaRandom(const int limit) {
    m_alpha = (int)(next_uint32() % max(1, min(limit, (int)MAX_ALPHA)));
}
void Addressing::setBetaRandom(const int limit) {
    m_beta = (int)(next_uint32() % max(1, min(limit, (int)MAX_BETA)));
}
void Addressing::setGammaRandom(const int limit) {
    m_gamma = (int)(next_uint32() % max(1, min(limit, (int)MAX_GAMMA)));
}
