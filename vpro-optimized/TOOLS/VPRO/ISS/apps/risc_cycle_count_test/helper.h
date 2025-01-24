// #################################################
// # VPRO instrinsics auxiliary library            #
// # --------------------------------------------- #
// # Stephan Nolting, IMS, Uni Hannover, 2017-2019 #
// #################################################

#ifndef isa_intrinsic_aux_lib
#define isa_intrinsic_aux_lib

#include <stdint.h>
#include <inttypes.h>


#include <assert.h>
// Right place to hide
// https://stackoverflow.com/questions/18165527/linker-unable-to-find-assert-fail
#pragma GCC visibility push(hidden)

// -----------------------------------------------------------------------------
// SYSTEM definitions
// -----------------------------------------------------------------------------
// e.g. for DMA writing to a specific units LM
#define LM_BASE_VU(u)   (u*(1<<22)) // lm base address of VU "u"


// -----------------------------------------------------------------------------
// OPCODE definitions
// -----------------------------------------------------------------------------
enum LANE{
    L0      = 0b001,
    L1      = 0b010,
    L0_1    = 0b011,
    LS      = 0b100 // some high bit
};


#define BLOCKING        0b1
#define BL              BLOCKING
#define NONBLOCKING     0b0
#define NBL             NONBLOCKING

// is source of chain?
#define IS_CHAIN        0b1
#define CH              IS_CHAIN
#define NO_CHAIN        0b0
#define NCH             NO_CHAIN

// function classe
#define CLASS_MEM       0b00
#define CLASS_ALU       0b01
#define CLASS_SPECIAL   0b10
#define CLASS_TRANSFER  0b11
#define CLASS_OTHER     99          // no HW representation / support

// function opcodes
// MEM class
#define OPCODE_LOAD                 0b0000
#define OPCODE_LOADB                0b0001
#define OPCODE_LOADS                0b0010
#define OPCODE_LOADBS               0b0011
#define OPCODE_LOADS_SHIFT_LEFT     0b0110
#define OPCODE_LOADS_SHIFT_RIGHT    0b0111
#define OPCODE_LOAD_REVERSE         0b0101
#define OPCODE_STORE                0b1000
#define OPCODE_STORE_SHIFT_LEFT     0b1001
#define OPCODE_STORE_SHIFT_RIGHT    0b1010
#define OPCODE_STORE_REVERSE        0b1011
// actual operation ("function macro")
#define FUNC_LOAD               CLASS_MEM, OPCODE_LOAD
#define FUNC_LOADS              CLASS_MEM, OPCODE_LOADS
#define FUNC_LOADB              CLASS_MEM, OPCODE_LOADB
#define FUNC_LOADBS             CLASS_MEM, OPCODE_LOADBS
#define FUNC_LOAD_SHIFT_RIGHT   CLASS_MEM, OPCODE_LOADS_SHIFT_RIGHT
#define FUNC_LOAD_SHIFT_LEFT    CLASS_MEM, OPCODE_LOADS_SHIFT_LEFT
#define FUNC_LOAD_REVERSE       CLASS_MEM, OPCODE_LOAD_REVERSE

#define FUNC_STORE              CLASS_MEM, OPCODE_STORE
#define FUNC_STORE_SHIFT_RIGHT  CLASS_MEM, OPCODE_STORE_SHIFT_RIGHT
#define FUNC_STORE_SHIFT_LEFT   CLASS_MEM, OPCODE_STORE_SHIFT_LEFT
#define FUNC_STORE_REVERSE      CLASS_MEM, OPCODE_STORE_REVERSE

// ALU class
#define OPCODE_ADD          0b0000
#define OPCODE_SUB          0b0001
#define OPCODE_MACL_PRE     0b0010
#define OPCODE_MACH_PRE     0b0011
#define OPCODE_MULL         0b0100
#define OPCODE_MACL         0b0101
#define OPCODE_MULH         0b0110
#define OPCODE_MACH         0b0111

#define OPCODE_XOR          0b1000
#define OPCODE_XNOR         0b1001
#define OPCODE_AND          0b1010
#define OPCODE_ANDN         0b1011
#define OPCODE_NAND         0b1100
#define OPCODE_OR           0b1101
#define OPCODE_ORN          0b1110
#define OPCODE_NOR          0b1111

#define OPCODE_DIVL         0b10000
#define OPCODE_DIVH         0b10001
// actual operation ("function macro")
#define FUNC_ADD      CLASS_ALU, OPCODE_ADD
#define FUNC_SUB      CLASS_ALU, OPCODE_SUB
#define FUNC_MULL     CLASS_ALU, OPCODE_MULL
#define FUNC_MULH     CLASS_ALU, OPCODE_MULH
#define FUNC_DIVL	  CLASS_ALU, OPCODE_DIVL    // no synth
#define FUNC_DIVH     CLASS_ALU, OPCODE_DIVH    // no synth - 5 bit
#define FUNC_MACL     CLASS_ALU, OPCODE_MACL
#define FUNC_MACH     CLASS_ALU, OPCODE_MACH
#define FUNC_MACL_PRE CLASS_ALU, OPCODE_MACL_PRE
#define FUNC_MACH_PRE CLASS_ALU, OPCODE_MACH_PRE
#define FUNC_XOR      CLASS_ALU, OPCODE_XOR
#define FUNC_XNOR     CLASS_ALU, OPCODE_XNOR
#define FUNC_AND      CLASS_ALU, OPCODE_AND
#define FUNC_ANDN     CLASS_ALU, OPCODE_ANDN
#define FUNC_NAND     CLASS_ALU, OPCODE_NAND
#define FUNC_OR       CLASS_ALU, OPCODE_OR
#define FUNC_ORN      CLASS_ALU, OPCODE_ORN
#define FUNC_NOR      CLASS_ALU, OPCODE_NOR

// Special class
#define OPCODE_SHIFT_LL     0b0000
#define OPCODE_SHIFT_LR     0b0001
#define OPCODE_SHIFT_AR     0b0011
#define OPCODE_ABS          0b0100
#define OPCODE_MIN          0b0110
#define OPCODE_MAX          0b0111
#define OPCODE_SHIFT_AR_NEG 0b1010
#define OPCODE_SHIFT_AR_POS 0b1011
#define OPCODE_LOOP_START   0b1000
#define OPCODE_LOOP_END     0b1001
#define OPCODE_LOOP_MASK    0b1100
#define OPCODE_MAX_VECTOR   0b1101
#define OPCODE_MIN_VECTOR   0b1110
#define OPCODE_BIT_REVERSAL 0b1111
// actual operation ("function macro")
#define FUNC_SHIFT_LL     CLASS_SPECIAL, OPCODE_SHIFT_LL
#define FUNC_SHIFT_LR     CLASS_SPECIAL, OPCODE_SHIFT_LR
#define FUNC_SHIFT_AR     CLASS_SPECIAL, OPCODE_SHIFT_AR
#define FUNC_ABS          CLASS_SPECIAL, OPCODE_ABS
#define FUNC_MIN          CLASS_SPECIAL, OPCODE_MIN
#define FUNC_MAX          CLASS_SPECIAL, OPCODE_MAX
#define FUNC_MIN_VECTOR   CLASS_SPECIAL, OPCODE_MIN_VECTOR
#define FUNC_MAX_VECTOR   CLASS_SPECIAL, OPCODE_MAX_VECTOR
#define FUNC_SHIFT_AR_NEG CLASS_SPECIAL, OPCODE_SHIFT_AR_NEG
#define FUNC_SHIFT_AR_POS CLASS_SPECIAL, OPCODE_SHIFT_AR_POS
#define FUNC_LOOP_START   CLASS_SPECIAL, OPCODE_LOOP_START
#define FUNC_LOOP_END     CLASS_SPECIAL, OPCODE_LOOP_END
#define FUNC_LOOP_MASK    CLASS_SPECIAL, OPCODE_LOOP_MASK
#define FUNC_BIT_REVERSAL CLASS_SPECIAL, OPCODE_BIT_REVERSAL

// Transfer class
#define OPCODE_MV_ZE        0b0000
#define OPCODE_MV_NZ        0b0001
#define OPCODE_MV_MI        0b0010
#define OPCODE_MV_PL        0b0011
#define OPCODE_MULL_NEG     0b0100
#define OPCODE_MULL_POS     0b0101
#define OPCODE_MULH_NEG     0b0110
#define OPCODE_MULH_POS     0b0111

#define OPCODE_VARIABLE_VPRO_INSTRUCTION     0b1111 // replaced by io register content in subsystem (todo...)
#define FUNC_VARIABLE_VPRO_INSTRUCTION    CLASS_TRANSFER, OPCODE_VARIABLE_VPRO_INSTRUCTION // replaced by io register content in subsystem (todo...)
// actual operation ("function macro")
#define FUNC_MV_ZE       CLASS_TRANSFER, OPCODE_MV_ZE
#define FUNC_MV_NZ       CLASS_TRANSFER, OPCODE_MV_NZ
#define FUNC_MV_MI       CLASS_TRANSFER, OPCODE_MV_MI
#define FUNC_MV_PL       CLASS_TRANSFER, OPCODE_MV_PL
#define FUNC_MULL_NEG    CLASS_TRANSFER, OPCODE_MULL_NEG
#define FUNC_MULL_POS    CLASS_TRANSFER, OPCODE_MULL_POS
#define FUNC_MULH_NEG    CLASS_TRANSFER, OPCODE_MULH_NEG
#define FUNC_MULH_POS    CLASS_TRANSFER, OPCODE_MULH_POS


// status flag update
#define FLAG_UPDATE    0b1
#define FU             FLAG_UPDATE
#define NO_FLAG_UPDATE 0b0
#define NFU            NO_FLAG_UPDATE

// src selection
#define SRC_SEL_ADDR   0b00
#define SRC_SEL_IMM    0b01
#define SRC_SEL_LS     0b10
#define SRC_SEL_CHAIN  0b11

/**
 * defines ISA attributes
 * x_end, y_end limit vector length
 *  [e.g. 4-bit used in instruction => max 15]
 * alpha, beta and offset are used for complex addressing
 *  [e.g. 5-bit used for each occurence in instruction => max 31]
 */
// 6-bit -> max 63
// 5-bit -> max 31
// 4-bit -> max 15

// original vpro config was: x_end/y_end [4-bit], alpha/beta [5-bit]
// Xilinx DSP allows all with 6-bit
// TODO: maybe xend/yend 5-bit, alpha/beta 7-bit? 32*32 enaugh to address complete RF, alpha beta allows flexibility
constexpr unsigned int ISA_X_END_LENGTH = 6;
constexpr unsigned int ISA_Y_END_LENGTH = 6;

constexpr unsigned int ISA_BETA_LENGTH = 6;
constexpr unsigned int ISA_ALPHA_LENGTH = 6;
constexpr unsigned int ISA_OFFSET_LENGTH = 10;

constexpr int MAX_X_END  = (1u << ISA_X_END_LENGTH) - 1;   // checked in simCore.cpp
constexpr int MAX_Y_END  = (1u << ISA_Y_END_LENGTH) - 1;   // checked in simCore.cpp

constexpr int MAX_BETA   = (1u << ISA_BETA_LENGTH) - 1;    // checked here
constexpr int MAX_ALPHA  = (1u << ISA_ALPHA_LENGTH) - 1;   // checked here
constexpr int MAX_OFFSET = (1u << ISA_OFFSET_LENGTH) - 1;  // checked here
// start of each parameter
constexpr unsigned int ISA_BETA_SHIFT = 0;
constexpr unsigned int ISA_ALPHA_SHIFT = ISA_BETA_SHIFT+ISA_BETA_LENGTH;
constexpr unsigned int ISA_OFFSET_SHIFT = ISA_ALPHA_SHIFT+ISA_ALPHA_LENGTH;

// for sim core, to return to 3 values from single uint32 here
constexpr unsigned int ISA_BETA_MASK = 0xffffffffu >> (32-ISA_BETA_LENGTH);
constexpr unsigned int ISA_ALPHA_MASK = 0xffffffffu >> (32-ISA_ALPHA_LENGTH);
constexpr unsigned int ISA_OFFSET_MASK = 0xffffffffu >> (32-ISA_OFFSET_LENGTH);

constexpr unsigned int ISA_COMPLEX_LENGTH = ISA_OFFSET_SHIFT + ISA_OFFSET_LENGTH; // equal immediate width... e.g. 20-bit
constexpr unsigned int signed_TOP_FILL = 0xffffffff << ISA_COMPLEX_LENGTH; // '1' to perform a sign extension e.g. for 20-bit: 0xFFF00000
constexpr unsigned int ISA_COMPLEX_MASK = 0xffffffffu >> (32-ISA_COMPLEX_LENGTH);

// -----------------------------------------------------------------------------
// Instruction macros
// -----------------------------------------------------------------------------
constexpr uint32_t complex_ADDR(uint32_t offset, uint32_t alpha, uint32_t beta) {
    offset <= MAX_OFFSET;
    alpha <= MAX_ALPHA;
    beta <= MAX_BETA;

    // not needed due to assert check.
//    uint32_t offset_masked = offset & ISA_OFFSET_MASK;
//    uint32_t alpha_masked = alpha & ISA_ALPHA_MASK;
//    uint32_t beta_masked = beta & ISA_BETA_MASK;

    unsigned int concat = (offset << ISA_OFFSET_SHIFT) | (alpha << ISA_ALPHA_SHIFT) | (beta << ISA_BETA_SHIFT);
//    concat = (concat & (1u<<(ISA_COMPLEX_LENGTH-1)))? (concat | signed_TOP_FILL) : concat; // & 0x80000 > 0
    return concat;
}

// destination
#define DST_ADDR(offset, alpha, beta)  complex_ADDR(offset, alpha, beta)
#define DST_DONT_CARE                  0
// source1
#define SRC1_ADDR(offset, alpha, beta)  SRC_SEL_ADDR, complex_ADDR(offset, alpha, beta)
// source2
#define SRC2_ADDR(offset, alpha, beta)  SRC_SEL_ADDR, complex_ADDR(offset, alpha, beta)

constexpr uint32_t S_EXT_20(uint32_t x) {
    x < (1u<<ISA_COMPLEX_LENGTH);
    return x; //((x & (1u<<(ISA_COMPLEX_LENGTH-1))) ? (x | signed_TOP_FILL) : x);
}

constexpr unsigned int ISA_CHAIN_ID_MASK = 0xffffffffu >> (32-ISA_COMPLEX_LENGTH-1); // to extract id in sim core
constexpr uint32_t CHAIN_ID_CUT(uint32_t id){
    // the upper bit of 20 chain source bits is used to differ betwenn neighbor and id chain source
    // if id chain source (only LS), the id has 19 bit available:
   id < (1u<<(ISA_COMPLEX_LENGTH-1));
    return id;
}

/**
 * In 3 blocks
 * all same encoding! -> just for readable code
 */
#define SRC1_IMM(imm)                   SRC_SEL_IMM, S_EXT_20(imm) // 20-bit imm will be sign-extended (at least 24-bit)
#define SRC1_CHAINING_LEFT              SRC_SEL_CHAIN, 0x8100 // use chaining from left side
#define SRC1_CHAINING_RIGHT             SRC_SEL_CHAIN, 0x8200 // use chaining from right side
#define SRC1_CHAINING_LEFT_DELAYED      SRC_SEL_CHAIN, 0x8102 // use chaining from left side, dont start chain yet
#define SRC1_CHAINING_RIGHT_DELAYED     SRC_SEL_CHAIN, 0x8202 // use chaining from right side, dont start chain yet
#define SRC1_CHAINING(id)               SRC_SEL_CHAIN, CHAIN_ID_CUT(id) // use chaining from Lane with ID...
#define SRC1_LS                         SRC_SEL_LS, 0       // use chaining from local LS
#define SRC1_LS_LEFT                    SRC_SEL_LS, 0x8100  // use chaining from left side
#define SRC1_LS_LEFT_DELAYED            SRC_SEL_LS, 0x8102  // use chaining from left side
#define SRC1_LS_RIGHT                   SRC_SEL_LS, 0x8200  // use chaining from right side
#define SRC1_LS_RIGHT_DELAYED           SRC_SEL_LS, 0x8202  // use chaining from right side
#define SRC1_LS_DELAYED                 SRC_SEL_LS, 0x0002  // use chaining from local LS but not starting // bit for delayed is 0b10
#define SRC1_DONT_CARE                  SRC_SEL_ADDR, 0

#define SRC2_IMM(imm)                   SRC_SEL_IMM, S_EXT_20(imm) // 20-bit imm will be sign-extended (at least 24-bit)
#define SRC2_CHAINING_LEFT              SRC_SEL_CHAIN, 0x8100 // use chaining from left side
#define SRC2_CHAINING_RIGHT             SRC_SEL_CHAIN, 0x8200 // use chaining from right side
#define SRC2_CHAINING_LEFT_DELAYED      SRC_SEL_CHAIN, 0x8102 // use chaining from left side, dont start chain yet
#define SRC2_CHAINING_RIGHT_DELAYED     SRC_SEL_CHAIN, 0x8202 // use chaining from right side, dont start chain yet
#define SRC2_CHAINING(id)               SRC_SEL_CHAIN, CHAIN_ID_CUT(id) // use chaining from Lane with ID...
#define SRC2_LS                         SRC_SEL_LS, 0       // use chaining from local LS
#define SRC2_LS_LEFT                    SRC_SEL_LS, 0x8100  // use chaining from left side
#define SRC2_LS_LEFT_DELAYED            SRC_SEL_LS, 0x8102  // use chaining from left side
#define SRC2_LS_RIGHT                   SRC_SEL_LS, 0x8200  // use chaining from right side
#define SRC2_LS_RIGHT_DELAYED           SRC_SEL_LS, 0x8202  // use chaining from right side
#define SRC2_LS_DELAYED                 SRC_SEL_LS, 0x0002  // use chaining from local LS but not starting
#define SRC2_DONT_CARE                  SRC_SEL_ADDR, 0

#define SRC_IMM(imm)                   SRC_SEL_IMM, S_EXT_20(imm) // 20-bit imm will be sign-extended (at least 24-bit)
#define SRC_CHAINING_LEFT              SRC_SEL_CHAIN, 0x8100 // use chaining from left side
#define SRC_CHAINING_RIGHT             SRC_SEL_CHAIN, 0x8200 // use chaining from right side
#define SRC_CHAINING_LEFT_DELAYED      SRC_SEL_CHAIN, 0x8102 // use chaining from left side, dont start chain yet
#define SRC_CHAINING_RIGHT_DELAYED     SRC_SEL_CHAIN, 0x8202 // use chaining from right side, dont start chain yet
#define SRC_CHAINING(id)               SRC_SEL_CHAIN, CHAIN_ID_CUT(id) // use chaining from Lane with ID...
#define SRC_LS                         SRC_SEL_LS, 0       // use chaining from local LS
#define SRC_LS_LEFT                    SRC_SEL_LS, 0x8100  // use chaining from left side
#define SRC_LS_LEFT_DELAYED            SRC_SEL_LS, 0x8102  // use chaining from left side
#define SRC_LS_RIGHT                   SRC_SEL_LS, 0x8200  // use chaining from right side
#define SRC_LS_RIGHT_DELAYED           SRC_SEL_LS, 0x8202  // use chaining from right side
#define SRC_LS_DELAYED                 SRC_SEL_LS, 0x0002  // use chaining from local LS but not starting
#define SRC_DONT_CARE                  SRC_SEL_ADDR, 0

// -----------------------------------------------------------------------------
// VPRO pre-defined instruction
// -----------------------------------------------------------------------------

// This macro might be used to insulate two consecutive vector instructions, which process less than 10 elements (= depth of pipeline) and also access the SAME elements.
// Since the lanes do not support forwarding, a dummy delay using this NOP command has to be used!
#define vpro_nop __builtin_vpro_instruction_word(0, NONBLOCKING, NO_CHAIN, FUNC_ADD, NO_FLAG_UPDATE, DST_ADDR(0, 0, 0), SRC1_ADDR(0, 0, 0), SRC2_IMM(0), 2, 3);

#pragma GCC visibility pop

#endif // isa_intrinsic_aux_lib

