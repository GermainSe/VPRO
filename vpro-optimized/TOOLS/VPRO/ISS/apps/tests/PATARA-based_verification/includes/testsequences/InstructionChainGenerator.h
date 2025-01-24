//
// Created by gesper on 06.03.24.
//

#ifndef PATARA_BASED_VERIFICATION_INSTRUCTIONCHAINGENERATOR_H
#define PATARA_BASED_VERIFICATION_INSTRUCTIONCHAINGENERATOR_H

#include "TestSequence.h"
#include "chains.h"
#include "test_env.h"
#include "constants.h"
#include "instructions/genericInstruction.h"
#include "vproOperands.h"

using namespace TEST_ENVS;

class InstructionChainGenerator {
   public:
    InstructionChainGenerator() = default;

    virtual TestSequence* next() = 0;

    void setChainGeneratorSequence(TestSequence* seq){
        testChainSequence = seq;
    }

    virtual void init(const test_cfg_s& config){

    }

    [[nodiscard]] virtual int getTotalSequences() const {
        return -1;
    }

    virtual void vproRegisterConfig(bool verbose) const {
        //    vpro_set_cluster_mask(DefaultConfiurationModes::CLUSTER_MASK);
        //    vpro_set_unit_mask(DefaultConfiurationModes::UNIT_MASK);
        vpro_set_mac_init_source(DefaultConfiurationModes::MAC_INIT_SOURCE);
        vpro_set_mac_reset_mode(DefaultConfiurationModes::MAC_RESET_MODE);
        vpro_mac_h_bit_shift(DefaultConfiurationModes::MAC_H_BIT_SHIFT);
        vpro_mul_h_bit_shift(DefaultConfiurationModes::MUL_H_BIT_SHIFT);
        if (verbose){
            printf_info("VPRO registers set\n");
            printf_info(" | MAC Init Source: %s\n", print(DefaultConfiurationModes::MAC_INIT_SOURCE));
            printf_info(" | MAC Reset Mode: %s\n", print(DefaultConfiurationModes::MAC_RESET_MODE));
            printf_info(" | MACH Shift: %i\n", DefaultConfiurationModes::MAC_H_BIT_SHIFT);
            printf_info(" | MULH Shift: %i\n", DefaultConfiurationModes::MUL_H_BIT_SHIFT);
        }
    }

   private:
    TestSequence* testChainSequence{};

   protected:
    /**
     * Current sequence parameters
     */
    int x_end{};
    int y_end{};
    int z_end{};

    Addressing DST{};
    Addressing SRC1{};
    Addressing SRC2{};

    GenericInstruction L0_instr{L0};
    GenericInstruction L1_instr{L1};
    GenericInstruction L0_1_instr{L0_1};
    GenericInstruction LS_instr{LS};

    /**
      * chain sequence gen variables
      */
    bool introduceBlockingChainCommands{}, introduceBlockingDelayCommands{};

    int current_test_sequence_chain{InstructionChains::NONE};

    Operand::Operand chain_generation_operand{Operand::Operand::SRC1};
    int chain_generation_operation_ls_src{};
    int chain_generation_operation_ls_dst{};
    int chain_generation_operation_l0{};
    int chain_generation_operation_l1{};

    uint32_t neighbor_chain_encoding{};

    /**
     * chain delays
     */
    bool introduceChainDelayCommands{};
    int chainDelays{};
    static constexpr int NUM_DELAY_INSTRUCTIONS = 4;
    GenericInstruction delayInstr[NUM_DELAY_INSTRUCTIONS];
    int delayInstructionIndexInSequence{};
    void createDelayInstruction(LANE lane);

    /**
     * generate the next instruction of chain instruction execution.
     * finaly generates instructions with all chain combinations.
     * e.g. LS -> L0, then LS -> L1, ...
     * e.g. next opcode (add), next operand (SRC1/SRC2 is chain) or next chain (L0->LS)
     * when all instruction chains have been generated, return false
     * @return if test instructions were generated and added to testcase (lastGenerated)
     */
    bool generateNextInstructionChains();

    /**
     * Generate instruction to form a chain.
     * Direction of chain is: src -> dst [dst_instr_chain_operand].
     * Operation is given in parameter.
     * New Instruction is generated and appended to instructions list.
     * SRC and DST are reset after.
     * @param src Instruction to generate the chain data. Lane is required. Operands are required
     *            to be set to a "default" value beforehand
     * @param dst Instruction to receive the chain data. Lane is required. Operands are required
     *            to be set to a "default" value beforehand
     * @param dst_instr_chain_operand The dst instruction uses the chain in this operand
     * @param src_op Operation of src instruction (e.g. if LOAD is used, the src need to be LS lane -
     *               parameter of lane needs to be set to the src instr beforehand)
     * @param dst_op Operation of chain destination / receiving instruction
     * @param default_dst default dst operand (e.g. src and dst default value)
     * @param default_src1 default src1 operand (e.g. src and dst default value)
     * @param default_src2 default src2 operand (e.g. src and dst default value)
     */
    void generateTwoChain(GenericInstruction& src,
        GenericInstruction& dst,
        Operand::Operand dst_instr_chain_operand,
        Operation::Operation src_op,
        Operation::Operation dst_op);

    /**
     * as generateTwoChain().
     * Three chains have one intermediate instruction (receives chain and generates data/chain)
     */
    void generateThreeChain(GenericInstruction& src,
        GenericInstruction& srcdst,
        GenericInstruction& dst,
        Operand::Operand srcdst_instr_chain_operand,
        Operand::Operand dst_instr_chain_operand,
        Operation::Operation src_op,
        Operation::Operation srcdst_op,
        Operation::Operation dst_op);

    /**
     * as generateTwoChain().
     * One generating Instruction. Two receiving instructions.
     * Generating order matters (generating instr before rec)
     */
    void generateOneTwoChain(GenericInstruction& src,
        GenericInstruction& dst,
        GenericInstruction& dst2,
        Operand::Operand dst_instr_chain_operand,
        Operand::Operand dst2_instr_chain_operand,
        Operation::Operation src_op,
        Operation::Operation dst_op,
        Operation::Operation dst2_op);

    /**
     * as generateTwoChain().
     * Two generating Instruction. One receiving instructions. Not LS. Both operands differ.
     * dst_instr_chain_operand: selects the src target of LS [simplified]
     *  TODO: check ISA - what if a generating issued after the receiving -> handle in HW exists!!!!!!
     */
    void generateTwoOneChain(GenericInstruction& src,
        GenericInstruction& src2,
        GenericInstruction& dst,
        Operand::Operand dst_instr_chain_operand,
        Operation::Operation src_op,
        Operation::Operation src2_op,
        Operation::Operation dst_op);

    /**
     * Reset the operands to the given default addressing (e.g. imm / complex)
     * using all instructions (static variables of this class)
     */
    void reset_instr();
};

#endif  //PATARA_BASED_VERIFICATION_INSTRUCTIONCHAINGENERATOR_H
