//
// Created by gesper on 12.12.23.
//

#include "instructions/genericInstruction.h"
#include <algorithm>
#include <cstring>
#include <vector>
#include "instructions/FifoMemory.h"
#include "instructions/loadstore/load.h"
#include "instructions/loadstore/loadb.h"
#include "instructions/loadstore/loadbs.h"
#include "instructions/loadstore/loads.h"
#include "instructions/loadstore/store.h"
#include "instructions/processing/abs.h"
#include "instructions/processing/add.h"
#include "instructions/processing/and.h"
#include "instructions/processing/mach.h"
#include "instructions/processing/mach_pre.h"
#include "instructions/processing/macl.h"
#include "instructions/processing/macl_pre.h"
#include "instructions/processing/max.h"
#include "instructions/processing/min.h"
#include "instructions/processing/mulh.h"
#include "instructions/processing/mull.h"
#include "instructions/processing/mulh_neg.h"
#include "instructions/processing/mulh_pos.h"
#include "instructions/processing/mull_neg.h"
#include "instructions/processing/mull_pos.h"
#include "instructions/processing/nand.h"
#include "instructions/processing/nop.h"
#include "instructions/processing/nor.h"
#include "instructions/processing/or.h"
#include "instructions/processing/shift_ar.h"
#include "instructions/processing/shift_ar_neg.h"
#include "instructions/processing/shift_ar_pos.h"
#include "instructions/processing/shift_lr.h"
#include "instructions/processing/sub.h"
#include "instructions/processing/xnor.h"
#include "instructions/processing/xor.h"
#include "instructions/processing/mv_mi.h"
#include "instructions/processing/mv_pl.h"
#include "instructions/processing/mv_nz.h"
#include "instructions/processing/mv_ze.h"

bool IsPowerOfTwo(uint x) {
    // excludes 0 (is not a power of 2!)
    return (x != 0) && ((x & (x - 1)) == 0);
}

GenericInstruction::GenericInstruction(LANE lane, uint32_t xEnd, uint32_t yEnd, uint32_t zEnd)
    : Instruction(lane, xEnd, yEnd, zEnd, false, false) {
    std::vector<int> sizes = {sizeof(Add),
        sizeof(And),
        sizeof(Mach),
        sizeof(Macl),
        sizeof(Macl_pre),
        sizeof(Mach_pre),
        sizeof(Mulh),
        sizeof(Mull),
        sizeof(Nand),
        sizeof(Nor),
        sizeof(Nop),
        sizeof(Or),
        sizeof(Sub),
        sizeof(Xnor),
        sizeof(Xor),
        sizeof(Shift_lr),
        sizeof(Shift_ar),
        sizeof(Abs),
        sizeof(Min),
        sizeof(Max),
        sizeof(Load),
        sizeof(Loads),
        sizeof(Loadb),
        sizeof(Loadbs),
        sizeof(Store)};
    maxInstructionSize = *std::max_element(std::begin(sizes), std::end(sizes));

    resultingInstruction = (Instruction*)malloc(maxInstructionSize * 2);
}

GenericInstruction::GenericInstruction(): GenericInstruction(L0_1, 0, 0, 0) { }

void GenericInstruction::setOperation(Operation::Operation op) {
    if (getLane() == LS && !is_loadstore(op)) {
        printf_error(
            "Operation set to Generic Instruction failed! Lane is LS but Operation is not!\n");
        exit(1);
    } else if (getLane() != LS && !is_processing(op)) {
        printf_error(
            "Operation set to Generic Instruction failed! Lane is Processing but Operation is "
            "not!\n");
        exit(1);
    }
    m_op = op;
    isOperationSet = true;
}
void GenericInstruction::setxEnd(uint32_t xEnd) {
    m_x_end = xEnd;
}
void GenericInstruction::setyEnd(uint32_t yEnd) {
    m_y_end = yEnd;
}
void GenericInstruction::setzEnd(uint32_t zEnd) {
    m_z_end = zEnd;
}
void GenericInstruction::setDST(Addressing dst) {
    m_dst = dst;
}
void GenericInstruction::setSRC1(Addressing src1) {
    m_src1 = src1;
}
void GenericInstruction::setSRC2(Addressing src2) {
    m_src2 = src2;
}
void GenericInstruction::setChaining(bool chaining) {
    m_is_chain = chaining;
}
void GenericInstruction::setSourceLane(LANE lane) {
    m_sourcelane = lane;
}
void GenericInstruction::setBlocking(bool blocking) {
    m_blocking = blocking;
}
void GenericInstruction::setFlagUpdate(bool update) {
    m_flagUpdate = update;
}

Instruction* GenericInstruction::create() {
    memset((void*)resultingInstruction, 0, maxInstructionSize);

    switch (m_op) {
        case Operation::NOP:
            return new (resultingInstruction)
                Nop(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::ADD:
            return new (resultingInstruction)
                Add(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::SUB:
            return new (resultingInstruction)
                Sub(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MULL:
            return new (resultingInstruction)
                Mull(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MULH:
            return new (resultingInstruction)
                Mulh(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MULL_POS:
            return new (resultingInstruction)
                Mull_pos(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MULH_POS:
            return new (resultingInstruction)
                Mulh_pos(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MULL_NEG:
            return new (resultingInstruction)
                Mull_neg(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MULH_NEG:
            return new (resultingInstruction)
                Mulh_neg(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MACL:
            return new (resultingInstruction)
                Macl(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MACL_PRE:
            return new (resultingInstruction)
                Macl_pre(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MACH:
            return new (resultingInstruction)
                Mach(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MACH_PRE:
            return new (resultingInstruction)
                Mach_pre(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::XOR:
            return new (resultingInstruction)
                Xor(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::XNOR:
            return new (resultingInstruction)
                Xnor(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::AND:
            return new (resultingInstruction)
                And(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::NAND:
            return new (resultingInstruction)
                Nand(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::OR:
            return new (resultingInstruction)
                Or(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::NOR:
            return new (resultingInstruction)
                Nor(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::SHIFT_LR:
            return new (resultingInstruction)
                Shift_lr(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::SHIFT_AR:
            return new (resultingInstruction)
                Shift_ar(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::SHIFT_AR_NEG:
            return new (resultingInstruction)
                Shift_ar_neg(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::SHIFT_AR_POS:
            return new (resultingInstruction)
                Shift_ar_pos(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::ABS:
            return new (resultingInstruction)
                Abs(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MIN:
            return new (resultingInstruction)
                Min(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MAX:
            return new (resultingInstruction)
                Max(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MV_MI:
            return new (resultingInstruction)
                Mv_mi(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MV_NZ:
            return new (resultingInstruction)
                Mv_nz(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MV_PL:
            return new (resultingInstruction)
                Mv_pl(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::MV_ZE:
            return new (resultingInstruction)
                Mv_ze(getLane(), m_x_end, m_y_end, m_z_end, m_dst, m_src1, m_src2, m_is_chain, m_flagUpdate, m_blocking);
        case Operation::LOAD:
            assert(m_is_chain == true);
            assert(m_src2.getIsImmediate() && !m_src1.getIsImmediate() && !m_src1.getIsChain() &&
                   "LOAD: SRC1 needs to be addr and SRC2 IMM!");
            return new (resultingInstruction) Load(m_x_end, m_y_end, m_z_end,
                m_src2.getImmediate(),
                m_src1.getOffset(), m_src1.getAlpha(), m_src1.getBeta(), m_src1.getGamma());
        case Operation::LOADS:
            assert(m_is_chain == true);
            assert(m_src2.getIsImmediate() && !m_src1.getIsImmediate() && !m_src1.getIsChain() &&
                   "LOAD: SRC1 needs to be addr and SRC2 IMM!");
            return new (resultingInstruction) Loads(m_x_end, m_y_end, m_z_end,
                m_src2.getImmediate(),
                m_src1.getOffset(), m_src1.getAlpha(), m_src1.getBeta(), m_src1.getGamma());
        case Operation::LOADB:
            assert(m_is_chain == true);
            assert(m_src2.getIsImmediate() && !m_src1.getIsImmediate() && !m_src1.getIsChain() &&
                   "LOAD: SRC1 needs to be addr and SRC2 IMM!");
            return new (resultingInstruction) Loadb(m_x_end, m_y_end, m_z_end,
                m_src2.getImmediate(),
                m_src1.getOffset(), m_src1.getAlpha(), m_src1.getBeta(), m_src1.getGamma());
        case Operation::LOADBS:
            assert(m_is_chain == true);
            assert(m_src2.getIsImmediate() && !m_src1.getIsImmediate() && !m_src1.getIsChain() &&
                   "LOAD: SRC1 needs to be addr and SRC2 IMM!");
            return new (resultingInstruction) Loadbs(m_x_end, m_y_end, m_z_end,
                m_src2.getImmediate(),
                m_src1.getOffset(), m_src1.getAlpha(), m_src1.getBeta(), m_src1.getGamma());
        case Operation::STORE:
            assert(m_is_chain == false);
            assert(m_src2.getIsImmediate() && !m_src1.getIsImmediate() && !m_src1.getIsChain() &&
                   "STORE: SRC1 needs to be addr and SRC2 IMM!");
            return new (resultingInstruction) Store(m_x_end, m_y_end, m_z_end,
                m_src2.getImmediate(),
                m_src1.getOffset(), m_src1.getAlpha(), m_src1.getBeta(), m_src1.getGamma(),
                m_sourcelane);
        default:
            printf_warning("Generic Instruction create(): Operation not specified/implemented!\n");
            exit(1);
    }
}
void GenericInstruction::reset(Addressing& default_dst,
    Addressing& default_src1,
    Addressing& default_src2,
    int xend,
    int yend,
    int zend) {
    setBlocking(false);
    setFlagUpdate(false);
    setChaining(false);
    setSRC1(default_src1);
    setSRC2(default_src2);
    if (getLane() == LS){
        getSrc2()->setImmediate(getSrc2()->getImmediate());
    }
    setDST(default_dst);
    setxEnd(xend);
    setyEnd(yend);
    setzEnd(zend);
}

// single instance of a FIFO for checking hazards within one vector instruction
static FifoMemory buffer;

bool GenericInstruction::check(uint& x, uint& y, uint& z, const int hazardCheckEntries) const {
    // check if operand addressing is in range
    bool isLengthfit;
    // Load-Store addresses LM
    if (is_loadstore(getOperation())) {
        assert(!m_src1.getIsChain() && !m_src1.getIsImmediate());  // SRC1 addr
        assert(!m_src1.getIsChain() && m_src2.getIsImmediate());   // SRC2 imm
        uint src1 = m_src1.getOffset() + x * m_src1.getAlpha() + y * m_src1.getBeta() +
                    z * m_src1.getGamma();
        isLengthfit = (src1 + m_src2.getImmediate() < VPRO_CFG::LM_SIZE);
    } else {
        // Processing addresses RF
        bool src1_overflow = false;
        bool src2_overflow = false;
        bool dst_overflow = false;
        if (!m_src1.getIsChain() && !m_src1.getIsImmediate()) {
            uint src1 = m_src1.getOffset() + x * m_src1.getAlpha() + y * m_src1.getBeta() +
                        z * m_src1.getGamma();
            src1_overflow |= (src1 >= VPRO_CFG::RF_SIZE);
        }
        if (!m_src2.getIsChain() && !m_src2.getIsImmediate()) {
            uint src2 = m_src2.getOffset() + x * m_src2.getAlpha() + y * m_src2.getBeta() +
                        z * m_src2.getGamma();
            src2_overflow |= (src2 >= VPRO_CFG::RF_SIZE);
        }
        if (!m_dst.getIsChain() && !m_dst.getIsImmediate()) {
            uint dst =
                m_dst.getOffset() + x * m_dst.getAlpha() + y * m_dst.getBeta() + z * m_dst.getGamma();
            dst_overflow |= (dst >= VPRO_CFG::RF_SIZE);
        }
        isLengthfit = !(src1_overflow || src2_overflow || dst_overflow);
    }
    // shortcut to avoid hazard checking
    if (!isLengthfit) return isLengthfit;

    // check Hazards: if SRC1 or SRC2 uses DST 
    //  (vertical execution could cause dependencies of vector iteration)
    bool isWARRAWconflict = false;
    // irrelevant if LS or NOP -> skip
    if (!is_loadstore(getOperation()) && getOperation() != Operation::NOP){
        bool is_src1_addr = !m_src1.getIsImmediate() && !m_src1.getIsChain();
        bool is_src2_addr = !m_src2.getIsImmediate() && !m_src2.getIsChain();
        if (is_src1_addr || is_src2_addr){
            buffer.reset();
            int fill = 0;
            // iterate vector, fill dst address buffer, check if src reads dst address
            for (uint zi = 0; zi <= z; ++zi) {
                for (uint yi = 0; yi <= y; ++yi) {
                    for (uint xi = 0; xi <= x; ++xi) {
                        if (!buffer.FIFO_in(m_dst.getOffset() +
                                     m_dst.getAlpha() * xi +
                                     m_dst.getBeta() * yi +
                                     m_dst.getGamma() * zi))
                            printf_error("isConflictWARRAW(). FIFO wr ERROR!\n");

                        if (is_src1_addr && is_src2_addr){
                            if (buffer.FIFO_contains(
                                    m_src1.getOffset() +
                                        m_src1.getAlpha() * xi +
                                        m_src1.getBeta() * yi +
                                        m_src1.getGamma() * zi,
                                    m_src2.getOffset() +
                                        m_src2.getAlpha() * xi +
                                        m_src2.getBeta() * yi +
                                        m_src2.getGamma() * zi
                                    )){
                                isWARRAWconflict = true;
                            }
                        } else {
                            if (is_src1_addr){  // only src1 is addr
                                if (buffer.FIFO_contains(
                                        m_src1.getOffset() +
                                            m_src1.getAlpha() * xi +
                                            m_src1.getBeta() * yi +
                                            m_src1.getGamma() * zi
                                        )){
                                    isWARRAWconflict = true;
                                }
                            } else {    // only src2 is addr
                                if (buffer.FIFO_contains(
                                        m_src2.getOffset() +
                                            m_src2.getAlpha() * xi +
                                            m_src2.getBeta() * yi +
                                            m_src2.getGamma() * zi
                                        )){
                                    isWARRAWconflict = true;
                                }
                            }
                        }

                        if (fill >= hazardCheckEntries){ // TODO: Hardware Pipeline offset for WAR/RAW conflicts?!
                            if (!buffer.FIFO_pop())
                                printf_error("isConflictWARRAW(). FIFO pop ERROR!\n");
                        } else {
                            fill++;
                        }
                    }   // x
                }   //y
            }   //z
        }   // one src operand is address -> do check
    }   // processing op -> check for hazards

    return !isWARRAWconflict;
}
