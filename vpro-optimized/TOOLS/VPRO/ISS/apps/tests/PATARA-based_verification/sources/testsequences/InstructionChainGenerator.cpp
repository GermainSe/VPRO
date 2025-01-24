//
// Created by gesper on 06.03.24.
//
#include "testsequences/InstructionChainGenerator.h"

bool InstructionChainGenerator::generateNextInstructionChains() {
    delayInstructionIndexInSequence = 0;
    createDelayInstruction(L0_1);   // cmd FIFO blocking instruction
    // loop all valid chains
    if (current_test_sequence_chain > 0) {
        // TODO:
        //   command splitting (random)
        //   command order (dst/src first) if possible
        //  --
        //  TODO: indirect addressing [later]
        //    indirect from L0 to L1 [DST, SRC1, SRC2]
        //    indirect from L0 to LS [DST, SRC1, SRC2]
        //    indirect from L1 to L0 [DST, SRC1, SRC2]
        //    indirect from L1 to LS [DST, SRC1, SRC2]
        //    indirect from LS to L0 [DST, SRC1, SRC2]
        //    indirect from LS to L1 [DST, SRC1, SRC2]
        //    both to LS [DST, SRC1, SRC2]*2
        //    both to L0 [DST, SRC1, SRC2]*2
        //    both to L1 [DST, SRC1, SRC2]*2

        switch (current_test_sequence_chain) {
            case InstructionChains::LS_L0:
                generateTwoChain(LS_instr,
                    L0_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_ls_src,
                    (Operation::Operation)chain_generation_operation_l0);
                break;
            case InstructionChains::LS_L1:
                generateTwoChain(LS_instr,
                    L1_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_ls_src,
                    (Operation::Operation)chain_generation_operation_l1);
                break;
            case InstructionChains::LS_L01:
                generateOneTwoChain(LS_instr,
                    L0_instr,
                    L1_instr,
                    chain_generation_operand,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_ls_src,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_l1);
                break;
            case InstructionChains::LS_L0_L1:
                generateThreeChain(LS_instr,
                    L0_instr,
                    L1_instr,
                    chain_generation_operand,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_ls_src,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_l1);
                break;
            case InstructionChains::LS_L1_L0:
                generateThreeChain(LS_instr,
                    L1_instr,
                    L0_instr,
                    chain_generation_operand,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_ls_src,
                    (Operation::Operation)chain_generation_operation_l1,
                    (Operation::Operation)chain_generation_operation_l0);
                break;
            case InstructionChains::L0_LS:
                generateTwoChain(L0_instr,
                    LS_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_ls_dst);
                break;
            case InstructionChains::L1_LS:
                generateTwoChain(L1_instr,
                    LS_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l1,
                    (Operation::Operation)chain_generation_operation_ls_dst);
                break;
            case InstructionChains::L0_L1:
                generateTwoChain(L0_instr,
                    L1_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_l1);
                break;
            case InstructionChains::L1_L0:
                generateTwoChain(L1_instr,
                    L0_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l1,
                    (Operation::Operation)chain_generation_operation_l0);
                break;
            case InstructionChains::L0_L1_LS:
                generateThreeChain(L0_instr,
                    L1_instr,
                    LS_instr,
                    chain_generation_operand,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_l1,
                    (Operation::Operation)chain_generation_operation_ls_dst);
                break;
            case InstructionChains::L1_L0_LS:
                generateThreeChain(L1_instr,
                    L0_instr,
                    LS_instr,
                    chain_generation_operand,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l1,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_ls_dst);
                break;
            case InstructionChains::L0_LS1:
                generateOneTwoChain(L0_instr,
                    LS_instr,
                    L1_instr,
                    chain_generation_operand,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_ls_dst,
                    (Operation::Operation)chain_generation_operation_l1);
                break;
            case InstructionChains::L1_LS0:
                generateOneTwoChain(L1_instr,
                    LS_instr,
                    L0_instr,
                    chain_generation_operand,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_l1,
                    (Operation::Operation)chain_generation_operation_ls_dst,
                    (Operation::Operation)chain_generation_operation_l0);
                break;
            case InstructionChains::LS0_L1:
                generateTwoOneChain(LS_instr,
                    L0_instr,
                    L1_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_ls_src,
                    (Operation::Operation)chain_generation_operation_l0,
                    (Operation::Operation)chain_generation_operation_l1);
                break;
            case InstructionChains::LS1_L0:
                generateTwoOneChain(LS_instr,
                    L1_instr,
                    L0_instr,
                    chain_generation_operand,
                    (Operation::Operation)chain_generation_operation_ls_src,
                    (Operation::Operation)chain_generation_operation_l1,
                    (Operation::Operation)chain_generation_operation_l0);
                break;
            default:
                printf_error("Chain does not exist!");
                return false;
        }
        testChainSequence->setName(InstructionChains::print(
            static_cast<InstructionChains::InstructionChains>(current_test_sequence_chain)));
        return true;
    }
    return false;
}


void InstructionChainGenerator::createDelayInstruction(const LANE lane){
    if (introduceChainDelayCommands && lane != LS){
        assert(delayInstructionIndexInSequence < NUM_DELAY_INSTRUCTIONS);
        delayInstr[delayInstructionIndexInSequence].setLane(lane);
        testChainSequence->append(delayInstr[delayInstructionIndexInSequence].create());
        delayInstructionIndexInSequence++;
    }
}

// TODO (for all following):
//  - SRC1_CHAINING_LEFT_3D
//      not only "left", also right?. depending on dst.getLane() / src.getLane()
//  - ...->setOffset(0);
//      only for LS relevant. from maybe param from SRC1/SRC2/or static random offset (lm)

void InstructionChainGenerator::generateThreeChain(GenericInstruction& src,
    GenericInstruction& srcdst,
    GenericInstruction& dst,
    Operand::Operand srcdst_instr_chain_operand,
    Operand::Operand dst_instr_chain_operand,
    Operation::Operation src_op,
    Operation::Operation srcdst_op,
    Operation::Operation dst_op) {
    // reset for generate
    src.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    srcdst.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    dst.reset(DST, SRC1, SRC2, x_end, y_end, z_end);

    // activate output chaining for src operation
    src.setOperation(src_op);
    src.setChaining(true);

    // activate output chaining for intermediate instruction
    srcdst.setOperation(srcdst_op);
    srcdst.setChaining(true);
    // offset only for LS relevant -> not intermediate instruction

    // use chaining as input in dst
    dst.setOperation(dst_op);

    if (dst.getLane() == LS) {  // Store to LS
        dst_instr_chain_operand = Operand::DST;
    }
    switch (dst_instr_chain_operand) {
        case Operand::SRC1:
            if (srcdst.getLane() == LS)
                dst.setSRC1(Addressing(SRC1_LS_3D));
            else {
                dst.setSRC1(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::SRC2:
            if (srcdst.getLane() == LS)
                dst.setSRC2(Addressing(SRC1_LS_3D));
            else {
                dst.setSRC2(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::DST:
            assert(dst.getLane() == LS);
            dst.setSourceLane(srcdst.getLane());
            break;
    }

    switch (srcdst_instr_chain_operand) {
        case Operand::SRC1:
            if (src.getLane() == LS)
                srcdst.setSRC1(Addressing(SRC1_LS_3D));
            else {
                srcdst.setSRC1(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::SRC2:
            if (src.getLane() == LS)
                srcdst.setSRC2(Addressing(SRC1_LS_3D));
            else {
                srcdst.setSRC2(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::DST:
            assert(srcdst.getLane() == LS);
            assert(false);  // Impossible! Store cannot be an intermediate instruction
    }

    if (introduceBlockingChainCommands){
        dst.setBlocking(true);
    }
    testChainSequence->append(src.create());
    createDelayInstruction(srcdst.getLane());
    testChainSequence->append(srcdst.create());
    createDelayInstruction(dst.getLane());
    testChainSequence->append(dst.create());
    createDelayInstruction(dst.getLane());
}

void InstructionChainGenerator::generateTwoChain(GenericInstruction& src,
    GenericInstruction& dst,
    Operand::Operand dst_instr_chain_operand,
    Operation::Operation src_op,
    Operation::Operation dst_op) {
    // reset for generate
    src.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    dst.reset(DST, SRC1, SRC2, x_end, y_end, z_end);

    // activate output chaining for src operation
    src.setOperation(src_op);
    src.setChaining(true);

    // use chaining as input in dst
    dst.setOperation(dst_op);

    if (dst.getLane() == LS) {  // Store to LS
        dst_instr_chain_operand = Operand::DST;
    }
    switch (dst_instr_chain_operand) {
        case Operand::SRC1:
            if (src.getLane() == LS)
                dst.setSRC1(Addressing(SRC1_LS_3D));
            else {
                dst.setSRC1(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::SRC2:
            if (src.getLane() == LS)
                dst.setSRC2(Addressing(SRC1_LS_3D));
            else {
                dst.setSRC2(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::DST:
            assert(dst.getLane() == LS);
            dst.setSourceLane(src.getLane());
            break;
    }

    if (introduceBlockingChainCommands){
        dst.setBlocking(true);
    }
    testChainSequence->append(src.create());
    createDelayInstruction(dst.getLane());
    testChainSequence->append(dst.create());
    createDelayInstruction(dst.getLane());
}

void InstructionChainGenerator::generateOneTwoChain(GenericInstruction& src,
    GenericInstruction& dst,
    GenericInstruction& dst2,
    Operand::Operand dst_instr_chain_operand,
    Operand::Operand dst2_instr_chain_operand,
    Operation::Operation src_op,
    Operation::Operation dst_op,
    Operation::Operation dst2_op) {
    // reset for next generate
    src.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    dst.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    dst2.reset(DST, SRC1, SRC2, x_end, y_end, z_end);

    // activate output chaining for src operation
    src.setOperation(src_op);
    src.setChaining(true);

    // use chaining as input in both dst
    dst.setOperation(dst_op);
    dst2.setOperation(dst2_op);

    if (dst.getLane() == LS) {  // Store to LS
        dst_instr_chain_operand = Operand::DST;
    }
    if (dst2.getLane() == LS) {  // Store to LS
        dst2_instr_chain_operand = Operand::DST;
    }
    switch (dst_instr_chain_operand) {
        case Operand::SRC1:
            if (src.getLane() == LS)
                dst.setSRC1(Addressing(SRC1_LS_3D));
            else {
                dst.setSRC1(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::SRC2:
            if (src.getLane() == LS)
                dst.setSRC2(Addressing(SRC1_LS_3D));
            else {
                dst.setSRC2(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::DST:
            assert(dst.getLane() == LS);
            dst.setSourceLane(src.getLane());
            break;
    }

    switch (dst2_instr_chain_operand) {
        case Operand::SRC1:
            if (src.getLane() == LS)
                dst2.setSRC1(Addressing(SRC1_LS_3D));
            else {
                dst2.setSRC1(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::SRC2:
            if (src.getLane() == LS)
                dst2.setSRC2(Addressing(SRC1_LS_3D));
            else {
                dst2.setSRC2(Addressing(neighbor_chain_encoding));
                neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                            ? SRC1_CHAINING_RIGHT_3D
                                            : SRC1_CHAINING_LEFT_3D;
            }
            break;
        case Operand::DST:
            assert(dst2.getLane() == LS);
            dst2.setSourceLane(src.getLane());
            break;
    }

    if (introduceBlockingChainCommands){
        src.setBlocking(true);
    }
    testChainSequence->append(dst.create());
    createDelayInstruction(dst2.getLane());
    testChainSequence->append(dst2.create());
    createDelayInstruction(src.getLane());
    testChainSequence->append(src.create());
    createDelayInstruction(src.getLane());
}

void InstructionChainGenerator::generateTwoOneChain(GenericInstruction& src,
    GenericInstruction& src2,
    GenericInstruction& dst,
    Operand::Operand dst_instr_chain_operand,
    Operation::Operation src_op,
    Operation::Operation src2_op,
    Operation::Operation dst_op) {
    // reset for next generate
    src.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    src2.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    dst.reset(DST, SRC1, SRC2, x_end, y_end, z_end);

    // activate output chaining for src operation
    src.setOperation(src_op);
    src.setChaining(true);

    // activate output chaining for src operation
    src2.setOperation(src2_op);
    src2.setChaining(true);

    // use chaining as input in dst
    dst.setOperation(dst_op);

    assert(dst.getLane() != LS);  // TODO: only for indirect addr
    switch (dst_instr_chain_operand) {
        case Operand::SRC1:
            dst.setSRC1(Addressing(SRC1_LS_3D));
            dst.setSRC2(Addressing(neighbor_chain_encoding));
            neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                        ? SRC1_CHAINING_RIGHT_3D
                                        : SRC1_CHAINING_LEFT_3D;
            break;
        case Operand::SRC2:
            dst.setSRC2(Addressing(SRC1_LS_3D));
            dst.setSRC1(Addressing(neighbor_chain_encoding));
            neighbor_chain_encoding = (neighbor_chain_encoding == SRC1_CHAINING_LEFT_3D)
                                        ? SRC1_CHAINING_RIGHT_3D
                                        : SRC1_CHAINING_LEFT_3D;
            break;
        case Operand::DST:
            printf_error("DST cannot be!\n");
            assert(false);  // cannot occur -> no LS store chain to (DST)
    }

    if (introduceBlockingChainCommands){
        dst.setBlocking(true);
    }
    testChainSequence->append(src.create());
    createDelayInstruction(src2.getLane());
    testChainSequence->append(src2.create());
    createDelayInstruction(dst.getLane());
    testChainSequence->append(dst.create());
    createDelayInstruction(dst.getLane());
}

void InstructionChainGenerator::reset_instr() {
    L0_instr.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    L1_instr.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    L0_1_instr.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
    LS_instr.reset(DST, SRC1, SRC2, x_end, y_end, z_end);
}
