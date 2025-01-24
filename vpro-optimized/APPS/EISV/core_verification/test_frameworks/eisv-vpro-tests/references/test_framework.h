#include <stdint.h>
#include <inttypes.h>
#include <string>
#include <cassert>
#include <limits>

#ifndef vpro_test_framework_h
#define vpro_test_framework_h

const uint16_t test_offsets[8] = { 0x0001, 0x0023, 0x00A2, 0x00B7, 0x00CC, 0x009D, 0x0049, 0x0090 };
                
template<typename T>
T reverse(T n, size_t b = sizeof(T) * 8) {
    assert(b <= std::numeric_limits<T>::digits);

    T rv = 0;

    for (size_t i = 0; i < b; ++i, n >>= 1) {
        rv = (rv << 1) | (n & 0x01);
    }

    return rv;
}

enum TESTS {
    TEST_IDLE = 0, // start index

    NOTHING,    // does nothing

    // MIPS
    MIPS_DIV,
    MIPS_LOOP,  // mips loop assign of index
    MIPS_FIBONACCI, // mips calc fibunacci
    MIPS_VARIABLE_VPRO,

    // DMA
    DMA_FPGA, // CNN based test (> 110x110 fails on ML605) - test should trigger this error by dma instructions
    DMA_FPGA2, // more than DMA_FPGA (interleaved VPRO instructions)
    DMA_VU_1DL_1DE,   // generated data by vpro 0x1000 & 0x2000
    DMA_VU_1DL_1DE_size1,  // in small grain dma transfers (size: 1)
    DMA_VU_1DL_2DE,   // same, to MM with 2D
    DMA_2DE_1DL_1DE,   // load SRC1 + store back 1D-1D
    DMA_2DE_1DL_2DE,   // to MM with 2D
    DMA_1DE_1DL_1DE,   // same
    DMA_1DE_1DL_2DE,   // to MM with 2D
    DMA_PADDING_ALL_1, // load 5x5 with 3x3 in middle. adjust base for having 3x3 in middle. adjust stride to use padding on correct mm input
    DMA_PADDING_ALL_2, // region in MM with stride // TODO
    DMA_PADDING_L,
    DMA_PADDING_R,
    DMA_PADDING_T,
    DMA_PADDING_B,
    DMA_PADDING_L_STRIDE,
    DMA_PADDING_R_STRIDE,
    DMA_PADDING_T_STRIDE,
    DMA_PADDING_B_STRIDE,
    DMA_PADDING_STRIDE,
    DMA_BROADCAST_LOAD_1D, // to multiple units
    DMA_BROADCAST_LOAD_2D, // to multiple units
    DMA_DCACHE_SHORT, //
    DMA_FIFO, //
    DMA_FIFO2, //
    DMA_LOOPER, //

    // LM ACCESS
    LOADB,  // byte load
    LOADBS, // byte load signed
    LOAD,   // word load
    LOADS,  // word load signed
    STOREA,  // store constant word
    STOREB,  // store increasing words
    LOADS_Shift_R,  // word load signed shift right
    LOADS_Shift_L,  // word load signed shift left

    // LOGIC
    AND,    // SRC1 & SRC2
    ANDN,   // SRC1 & !SRC2
    NAND,   // ! (SRC1 & SRC2)
    NOR,    // ! (SRC1 | SRC2)
    OR,     // SRC1 | SRC2
    ORN,    // SRC1 | !SRC2
    XNOR,   // SRC1 ^ !SRC2
    XOR,    // SRC1 ^ SRC2
    SHIFT_AR,   // SRC1 >> SRC2
    SHIFT_LR,   // '0' SRC1 >> SRC2
    SHIFT_AR_NEG,
    SHIFT_AR_POS,

    // ARITHMETIC
    SUB,    // SRC2 - SRC1  ¦ LOW 16 // TODO: reversed op order
    SUB2,   // SRC1 - IMM [0x1234]  ¦ LOW 16 // TODO: ...
    ADD,    // SRC1 + SRC2  ¦ LOW 16
    ADD2,   // SRC1 + IMM [0x1234]  ¦ LOW 16
    MULH,   // SRC1 * SRC2 ¦ HIGH 24 ¦ LOW 16
    MULHI,  // SRC1 * 0x1234 ¦ HIGH 24 ¦ LOW 16
    MULL,   // SRC1 * SRC2 ¦ LOW 24 ¦ LOW 16
    MULLI,  // SRC1 * 0x1234 ¦ LOW 24 ¦ LOW 16
    MACH,       // MACL_PRE (1*0x1234) + SRC1 * SRC2 ¦ HIGH 24 ¦ LOW 16
    MACH_PRE,   // 0 + SRC1 * SRC2 ¦ HIGH 24 ¦ LOW 16
    MACL,       // MACL_PRE (1*0x1234) + SRC1 * SRC2 ¦ LOW 24 ¦ LOW 16
    MACL_PRE,   // 0 + SRC1 * SRC2 ¦ LOW 24 ¦ LOW 16
    MULH_NEG,
    MULH_POS,
    MULL_NEG,
    MULL_POS,

    // SPECIAL
    ABS,    // |SRC1|  ¦ LOW 16
    MAX,    // MAX(SRC1, SRC2)
    MIN,    // MIN(SRC1, SRC2)
    MV_MI,  // MV SRC2 if SRC1 < 0 flag
    MV_NZ,  // MV SRC2 if SRC1 != zero flag
    MV_PL,  // MV SRC2 if SRC1 > 0 flag
    MV_ZE,  // MV SRC2 if SRC1 == zero flag
    BIT_REVERSAL,
    MIN_VECTOR_VAL,
    MAX_VECTOR_VAL,
    MIN_VECTOR_INDEX,
    MAX_VECTOR_INDEX,
    INDIRECT_LOAD,

    // VPRO FEATURES
    VPRO_COMPLEX_ADRS_EXT, // 6-bit in beta and xend
    VPRO_COMPLEX_ADRS_EXT2, // 6-bit in alpha and yend
    SHORT_VECTOR,   // 64 * length of 1
    MULH_SHIFT,
    MACH_SHIFT,
    BLOCKING_SIMPLE, // concated commands using results of previous (blocking flag req.)
    CHAINING_FLAGS, // chained flag data is used for mv_pl operation
    CMD_BROADCAST_UNITS, // same to different units dma stores only half per unit
    CMD_BROADCAST_LANES, // as broadcast units. store split to both lanes (both should compute same/broadcasted cmd)
    CMD_FIFO,   // 512 instruction [each 64 elements] (fifo overflow)
    // TODO: Unit Mask Test
    // TODO: Cluster Mask Test
    LOOP_SINGLE,
    LOOP_CASCADE,
    LOOP_MIX,

    // LS Lane
    LS_LANE0,    // use of id (LS) for mem cmds (requires chaining)
    LS_LANE1,    // use of id (LS) for mem cmds (requires chaining)
    LS_LANE2,    // use of id (LS) for mem cmds (requires chaining)
    LS_LANE3,    // use of id (LS) for mem cmds (requires chaining)
    LS_LANE4,    // use of id (LS) for mem cmds (requires chaining)

    // LS Lane
    CNN_28_K3,   //
    CNN_7_K3,    //
    CNN_28_K1,   //
    CNN_7_K1,    //

    TEST_END // index
};


#define REDBG    "\e[41m"
#define RED    "\e[91m" // 31
#define ORANGE "\e[93m"
#define BLACK  "\033[22;30m"
#define GREEN  "\e[32m"
#define LGREEN "\e[92m"
#define LYELLOW  "\e[93m"
#define YELLOW  "\e[33m"
#define MAGENTA "\e[95m" // or 35?
#define BLUE   "\e[36m" // 34 hard to read on thin clients
#define LBLUE   "\e[96m" // 94 hard to read on thin clients

#define INVERTED "\e[7m"
#define UNDERLINED "\e[4m"
#define BOLD "\e[1m"
#define RESET_COLOR "\e[m"

#define LIGHT "\e[2m"
//FIXME crash because of global define NORMAL and usage of same identifier in opencv/core.hpp
#define NORMAL_ "\e[22m"

std::string testName(TESTS t) {
    switch (t) {
        case TEST_IDLE:
            return "IDLE";
        case NOTHING:
            return "NOTHING";

        case MIPS_DIV:
            return "MIPS_DIV";
        case MIPS_LOOP:
            return "MIPS_LOOP";
        case MIPS_FIBONACCI:
            return "MIPS_FIBONACCI";
        case MIPS_VARIABLE_VPRO:
            return "MIPS_VARIABLE_VPRO";

        case DMA_FPGA:
            return "DMA_FPGA";
        case DMA_FPGA2:
            return "DMA_FPGA2";
        case DMA_VU_1DL_1DE:
            return "DMA_VU_1DL_1DE";
        case DMA_VU_1DL_1DE_size1:
            return "DMA_VU_1DL_1DE_size1";
        case DMA_VU_1DL_2DE:
            return "DMA_VU_1DL_2DE";
        case DMA_2DE_1DL_1DE:
            return "DMA_2DE_1DL_1DE";
        case DMA_2DE_1DL_2DE:
            return "DMA_2DE_1DL_2DE";
        case DMA_1DE_1DL_1DE:
            return "DMA_1DE_1DL_1DE";
        case DMA_1DE_1DL_2DE:
            return "DMA_1DE_1DL_2DE";
        case DMA_PADDING_ALL_1:
            return "DMA_PADDING_ALL_1";
        case DMA_PADDING_ALL_2:
            return "DMA_PADDING_ALL_2";
        case DMA_PADDING_L:
            return "DMA_PADDING_L";
        case DMA_PADDING_R:
            return "DMA_PADDING_R";
        case DMA_PADDING_T:
            return "DMA_PADDING_T";
        case DMA_PADDING_B:
            return "DMA_PADDING_B";
        case DMA_PADDING_L_STRIDE:
            return "DMA_PADDING_L_STRIDE";
        case DMA_PADDING_R_STRIDE:
            return "DMA_PADDING_R_STRIDE";
        case DMA_PADDING_T_STRIDE:
            return "DMA_PADDING_T_STRIDE";
        case DMA_PADDING_B_STRIDE:
            return "DMA_PADDING_B_STRIDE";
        case DMA_PADDING_STRIDE:
            return "DMA_PADDING_STRIDE";
        case DMA_BROADCAST_LOAD_1D:
            return "DMA_BROADCAST_LOAD_1D";
        case DMA_BROADCAST_LOAD_2D:
            return "DMA_BROADCAST_LOAD_2D";
        case DMA_DCACHE_SHORT:
            return "DMA_DCACHE_SHORT_2D";
		case DMA_FIFO:
			return "DMA_FIFO";
		case DMA_FIFO2:
			return "DMA_FIFO2";
		case DMA_LOOPER:
    		return "DMA_LOOPER";
			
        case LOADB:
            return "LOADB";
        case LOADBS:
            return "LOADBS";
        case LOADS:
            return "LOADS";
        case LOAD:
            return "LOAD";
        case LOADS_Shift_R:
            return "LOADS_Shift_R";
        case LOADS_Shift_L:
            return "LOADS_Shift_L";
        case STOREA:
            return "STOREA";
        case STOREB:
            return "STOREB";
        case BIT_REVERSAL:
            return "BIT_REVERSAL";
        case MIN_VECTOR_VAL:
            return "MIN_VECTOR_VAL";
        case MAX_VECTOR_VAL:
            return "MAX_VECTOR_VAL";
        case MIN_VECTOR_INDEX:
            return "MIN_VECTOR_INDEX";
        case MAX_VECTOR_INDEX:
            return "MAX_VECTOR_INDEX";
        case INDIRECT_LOAD:
            return "INDIRECT_LOAD";

        case ADD:
            return "ADD";
        case ADD2:
            return "ADDI";
        case SUB:
            return "SUB";
        case SUB2:
            return "SUBI";

        case MULH_NEG:
            return "MULH_NEG";
        case MULH_POS:
            return "MULH_POS";
        case MULL_NEG:
            return "MULL_NEG";
        case MULL_POS:
            return "MULL_POS";
        case MULH:
            return "MULH";
        case MULHI:
            return "MULHI";
        case MULLI:
            return "MULLI";
        case MULL:
            return "MULL";
        case MACH:
            return "MACH";
        case MACH_PRE:
            return "MACH_PRE";
        case MACL:
            return "MACL";
        case MACL_PRE:
            return "MACL_PRE";

        case ABS:
            return "ABS";
        case MAX:
            return "MAX";
        case MIN:
            return "MIN";
        case MV_MI:
            return "MV_MI";
        case MV_NZ:
            return "MV_NZ";
        case MV_PL:
            return "MV_PL";
        case MV_ZE:
            return "MV_ZE";
        case SHIFT_AR:
            return "SHIFT_AR";
        case SHIFT_AR_NEG:
            return "SHIFT_AR_NEG";
        case SHIFT_AR_POS:
            return "SHIFT_AR_POS";
        case SHIFT_LR:
            return "SHIFT_LR";

        case AND:
            return "AND";
        case ANDN:
            return "ANDN";
        case NAND:
            return "NAND";
        case NOR:
            return "NOR";
        case OR:
            return "OR";
        case ORN:
            return "ORN";
        case XNOR:
            return "XNOR";
        case XOR:
            return "XOR";

        case VPRO_COMPLEX_ADRS_EXT:
            return "VPRO_COMPLEX_ADRS_EXT";
        case VPRO_COMPLEX_ADRS_EXT2:
            return "VPRO_COMPLEX_ADRS_EXT2";
        case SHORT_VECTOR:
            return "SHORT_VECTOR";
        case BLOCKING_SIMPLE:
            return "BLOCKING_SIMPLE";
        case MULH_SHIFT:
            return "MULH_SHIFT";
        case MACH_SHIFT:
            return "MACH_SHIFT";
        case CHAINING_FLAGS:
            return "CHAINING_FLAGS";
        case CMD_BROADCAST_UNITS:
            return "CMD_BROADCAST_UNITS";
        case CMD_BROADCAST_LANES:
            return "CMD_BROADCAST_LANES";
        case CMD_FIFO:
            return "CMD_FIFO";
        case LOOP_SINGLE:
            return "LOOP_SINGLE";
        case LOOP_CASCADE:
            return "LOOP_CASCADE";
        case LOOP_MIX:
            return "LOOP_MIX";

        case LS_LANE0:
            return "LS_LANE0";
        case LS_LANE1:
            return "LS_LANE1";
        case LS_LANE2:
            return "LS_LANE2";
        case LS_LANE3:
            return "LS_LANE3";
        case LS_LANE4:
            return "LS_LANE4";

        case CNN_28_K3:
            return "CNN_28_K3";
        case CNN_7_K3:
            return "CNN_7_K3";
        case CNN_28_K1:
            return "CNN_28_K1";
        case CNN_7_K1:
            return "CNN_7_K1";

        default:
            return "unknown";
    }
}


int32_t *execute(TESTS t, uint16_t *opa, uint16_t *opb, int NUM_TEST_ENTRIES = 64) {
    auto result = new int32_t[1024](); // init to zero
    int64_t accu = 0;

    int32_t a = 0, b = 1, c, x, y;

    int min = std::numeric_limits<int>::max();
    int max = std::numeric_limits<int>::min();
    int index = 0;

    /**
     * CONV - CNN:
     */
    int16_t kernel[] = {623, 555, -51, -59, 52, 5599, -8711, -125, -2117};
//    int16_t kernel[] = {1, 0, 0, 0, 0, 0, 0, 0, 0};
    int16_t kernel2[] = {2, 4, 2, 4, 8, 4, 2, 4, 2};
    int16_t bias[] = {10};
    int16_t bias2[] = {20};
    int kernel_load_shift_right = 1;
    int conv_result_shift_right = 3;
    int bias_shift_right = -1;
    int store_shift_right = 1;
    auto inputdata = new int16_t[1024]();
    auto outputdata = new int16_t[1024]();
    auto outputdata2 = new int16_t[1024]();

    for (int i = 0; i < 64; i++) {
            result[i] = 0xdead;
    }

    switch (t) {
        case MIPS_DIV:
            for (int i = 0; i < 64; i++) {
                if (opb[i] != 0)
                    result[i] = int16_t(((int32_t(int32_t(int16_t(opa[i]) << 16u) / int16_t(opb[i])) << 1u) >> 16u));
            }
            break;
        case NOTHING:
            for (int i = 0; i < 64; i++) {
                result[i] = 0xdead;
            }
            break;

        case MIPS_LOOP:
            for (int i = 0; i < 64; i++) {
                result[i] = i;
            }
            break;

        case MIPS_FIBONACCI:
            for (int i = 0; i < 64; i++) {
                c = a + b;
                b = a;
                a = c;
                result[i] = c;
            }
            break;

        case DMA_FPGA:
        case DMA_FPGA2:
        case DMA_VU_1DL_1DE:
        case DMA_VU_1DL_1DE_size1:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = i;
//                if (i < 32)
//                    result[i] = 0x1000;
//                else
//                    result[i] = 0x2000;
            }
            break;
        case DMA_VU_1DL_2DE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                if (i < 32)
                    result[i] = 0x1000;
                else
                    result[i] = 0x2000;
            }
            break;
        case DMA_2DE_1DL_1DE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                int row = i / 4;
                int col = i % 4;
                if (i < 32) // left half
                    result[i] = int16_t(opa[row * 8 + col]);
                else    // right
                    result[i] = int16_t(opa[4 + (row - 8) * 8 + col]);
            }
            break;
        case DMA_2DE_1DL_2DE: // same order
        case DMA_1DE_1DL_1DE:
        case DMA_1DE_1DL_2DE:
        case DMA_BROADCAST_LOAD_1D:
        case DMA_BROADCAST_LOAD_2D:
        case DMA_DCACHE_SHORT:
        case DMA_LOOPER:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int16_t(opa[i]);
            }
            break;

        case DMA_PADDING_L:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (x == 0) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
            }
            break;
        case DMA_PADDING_R:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (x == 7) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
            }
            break;
        case DMA_PADDING_T:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (y == 0) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
            }
            break;
        case DMA_PADDING_B:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (y == 7) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
            }
            break;

        case DMA_PADDING_ALL_1:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (x == 0 || x == 7 || y == 0 || y == 7) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
            }
            break;
        case DMA_PADDING_ALL_2:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (x == 0 || x == 1 || x == 6 || x == 7 || y == 0 || y == 1 || y == 6 || y == 7) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
            }
            break;
        case DMA_PADDING_STRIDE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = 0;
            }
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (x == 0 || x == 7 || y == 0 || y == 7) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
                if (x == 7 && y > 0) // stride apply
                    index++;
            }
            break;
        case DMA_PADDING_B_STRIDE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = 0;
            }
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (y == 7) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
                if (x == 7) // stride apply
                    index++;
            }
            break;
        case DMA_PADDING_R_STRIDE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = 0;
            }
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (x == 7) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
                if (x == 7) // stride apply
                    index++;
            }
            break;
        case DMA_PADDING_T_STRIDE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = 0;
            }
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (y == 0) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
                if (x == 7 && y > 0) // stride apply
                    index++;
            }
            break;
        case DMA_PADDING_L_STRIDE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = 0;
            }
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                x = i % 8;
                y = i / 8;
                if (x == 0) {
                    result[i] = 0xbaaa; // pad value
                } else {
                    result[i] = int16_t(opa[index]);
                    index++;
                }
                if (x == 7) // stride apply
                    index++;
            }
            break;

        case ABS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = abs(int16_t(opa[i]));
            }
            break;
        case DMA_FIFO:
        case DMA_FIFO2:
        case MIPS_VARIABLE_VPRO:
        case ADD:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opa[i])) + int32_t(int16_t(opb[i]));
            }
            break;
        case VPRO_COMPLEX_ADRS_EXT:
        case ADD2:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opa[i])) + 0x1234;
            }
            break;
        case VPRO_COMPLEX_ADRS_EXT2:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = opa[i] & 0x1234;
            }
            break;
        case AND:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = opa[i] & opb[i];
            }
            break;
        case ANDN:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = opa[i] & ~opb[i];
            }
            break;
        case LOADB:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = opa[i] & 0x00ff;
            }
            break;
        case LOADBS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (opa[i] & 0x00ff);
                if (opa[i] & 0x0080)
                    result[i] |= 0xff00;
                result[i] = int16_t(result[i]);
            }
            break;
        case LOAD:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = uint16_t(opa[i]);
            }
            break;
        case LOADS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int16_t(opa[i]);
            }
            break;
        case MACL:
            accu = 0x1234;
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu += int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                accu = uint64_t(accu) & uint64_t(0xffffff); // max 48 bit
                result[i] = uint16_t(accu);
            }
            break;
        case MACH:
            accu = 0x1234;
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu += int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                #if BITWIDTH_REDUCE_TO_16_BIT == 1
                result[i] = uint16_t(accu >> 16);
                #else
                result[i] = uint16_t(accu >> 24);
                #endif
            }
            break;
        case MACL_PRE:
            accu = 0;
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu += int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                result[i] = uint16_t(accu);
            }
            break;
        case MACH_PRE:
            accu = 0;
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu += int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                #if BITWIDTH_REDUCE_TO_16_BIT == 1
                result[i] = uint16_t(accu >> 16);
                #else
                result[i] = uint16_t(accu >> 24);
                #endif
            }
            break;
        case MAX:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (int16_t(opa[i]) > int16_t(opb[i])) ? opa[i] : opb[i];
            }
            break;
        case MIN:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (int16_t(opa[i]) < int16_t(opb[i])) ? opa[i] : opb[i];
            }
            break;
        case MULH_NEG:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                if (int16_t(opa[i]) < 0)
		            #if BITWIDTH_REDUCE_TO_16_BIT == 1
		            result[i] = uint16_t(accu >> 16);
		            #else
		            result[i] = uint16_t(accu >> 24);
		            #endif
                else
                    result[i] = int16_t(opa[i]);
            }
            break;
        case MULH_POS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                if (int16_t(opa[i]) > 0)
		            #if BITWIDTH_REDUCE_TO_16_BIT == 1
		            result[i] = uint16_t(accu >> 16);
		            #else
		            result[i] = uint16_t(accu >> 24);
		            #endif
                else
                    result[i] = int16_t(opa[i]);
            }
            break;
        case MULH:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                #if BITWIDTH_REDUCE_TO_16_BIT == 1
                result[i] = uint16_t(accu >> 16);
                #else
                result[i] = uint16_t(accu >> 24);
                #endif
            }
            break;
        case MULHI:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(0x1234));
                #if BITWIDTH_REDUCE_TO_16_BIT == 1
                result[i] = uint16_t(accu >> 16);
                #else
                result[i] = uint16_t(accu >> 24);
                #endif
            }
            break;
        case MULL_NEG:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                if (int16_t(opa[i]) < 0)
                    result[i] = uint16_t(accu & 0xffff);
                else
                    result[i] = int16_t(opa[i]);
            }
            break;
        case MULL_POS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                if (int16_t(opa[i]) > 0)
                    result[i] = uint16_t(accu & 0xffff);
                else
                    result[i] = int16_t(opa[i]);
            }
            break;
        case MULLI:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(0x1234));
                result[i] = uint16_t(accu & 0xffff);
            }
            break;
        case MULL:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                result[i] = uint16_t(accu & 0xffff);
            }
            break;
        case MV_MI:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                if (int16_t(opa[i]) < 0)
                    result[i] = opb[i];
                else
                    result[i] = 0xdead;
            }
            break;
        case MV_NZ:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                if (opa[i] != 0)
                    result[i] = opb[i];
                else
                    result[i] = 0xdead;
            }
            break;
        case MV_PL:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                if (int16_t(opa[i]) >= 0) // TODO: >= is performed here!
                    result[i] = opb[i];
                else
                    result[i] = 0xdead;
            }
            break;
        case MV_ZE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                if (opa[i] == 0)
                    result[i] = opb[i];
                else
                    result[i] = 0xdead;
            }
            break;
        case NAND:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = ~(opa[i] & opb[i]);
            }
            break;
        case NOR:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = ~(opa[i] | opb[i]);
            }
            break;
        case OR:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (opa[i] | opb[i]);
            }
            break;
        case ORN:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (opa[i] | ~opb[i]);
            }
            break;
        case LOADS_Shift_L:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (int32_t(int16_t(opa[i])) << 13);
            }
            break;
        case LOADS_Shift_R:
        case SHIFT_AR:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (int32_t(int16_t(opa[i])) >> 13);
            }
            break;
        case SHIFT_AR_POS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (int32_t(int16_t(opa[i])) >> 13);
                if (int16_t(opa[i]) < 0)
                    result[i] = int32_t(int16_t(opa[i]));
            }
            break;
        case SHIFT_AR_NEG:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (int32_t(int16_t(opa[i])) >> 13);
                if (int16_t(opa[i]) > 0)
                    result[i] = int32_t(int16_t(opa[i]));
            }
            break;
        case SHIFT_LR:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                #if BITWIDTH_REDUCE_TO_16_BIT == 1
                result[i] = uint32_t((uint32_t(int32_t(int16_t(opa[i]))) & 0xffffu) >> 13u);
                #else
                result[i] = uint32_t((uint32_t(int32_t(int16_t(opa[i]))) & 0xffffffu) >> 13u);
                #endif
            }
            break;
        case BIT_REVERSAL:
            for (uint32_t i = 0u; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = reverse(int32_t(int16_t(opa[i])), 24);
            }
            break;
        case MIN_VECTOR_VAL:
            for (uint32_t i = 0u; i < NUM_TEST_ENTRIES; ++i) {
                if (int32_t(int16_t(opa[i])) < min)
                    min = int32_t(int16_t(opa[i]));
                result[i] = min;
            }
            break;
        case MAX_VECTOR_VAL:
            for (uint32_t i = 0u; i < NUM_TEST_ENTRIES; ++i) {
                if (int32_t(int16_t(opa[i])) > max)
                    max = int32_t(int16_t(opa[i]));
                result[i] = max;
            }
            break;
        case MIN_VECTOR_INDEX:
            for (uint32_t i = 0u; i < NUM_TEST_ENTRIES; ++i) {
                if (int32_t(int16_t(opa[i])) < min) {
                    min = int32_t(int16_t(opa[i]));
                    index = i;
                }
                result[i] = index;
            }
            break;
        case MAX_VECTOR_INDEX:
            for (uint32_t i = 0u; i < NUM_TEST_ENTRIES; ++i) {
                if (int32_t(int16_t(opa[i])) > max) {
                    max = int32_t(int16_t(opa[i]));
                    index = i;
                }
                result[i] = index;
            }
            break;
        case INDIRECT_LOAD:
            {
                for (uint32_t i = 0u; i < 8; ++i) {
                    result[i] = 255 - test_offsets[i];
                }
            }
            break;


        case SUB:   // TODO: Reversed operands
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opb[i])) - int32_t(int16_t(opa[i]));
            }
            break;
        case SUB2:   // TODO: Reversed operands
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(0x1234)) - int32_t(int16_t(opa[i]));
            }
            break;
        case STOREA:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int64_t(int16_t(0x1234));
            }
            break;
        case STOREB:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int64_t(int16_t(i));
            }
            break;
        case XNOR:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (opa[i] ^ ~opb[i]);
            }
            break;
        case XOR:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = (opa[i] ^ opb[i]);
            }
            break;

        case CMD_BROADCAST_UNITS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opa[i]));
            }
            break;
        case CMD_BROADCAST_LANES:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opa[i])) + 0x1234;
            }
            break;
        case LOOP_SINGLE:
        case LOOP_CASCADE:
        case LOOP_MIX:
        case CMD_FIFO:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opa[i]));
            }
            break;
        case SHORT_VECTOR:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opa[i]));
            }
            break;
        case CHAINING_FLAGS:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                if ((int32_t(int16_t(opa[i] & 0xff)) - int32_t(0x7f)) >= 0)
                    result[i] = 0xff;
                else
                    result[i] = 0;
            }
            break;
        case BLOCKING_SIMPLE:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = 0;
            }
            result[0] = int32_t(int16_t(opa[0])) + 0x1234;
            result[1] = int32_t(0x1234) + result[0];
            result[2] = int32_t(0x1234) + result[1];
            result[3] = int32_t(0x1234) + result[2];
            result[4] = int32_t(0x1234) + result[3];
            break;
        case MACH_SHIFT:
            accu = 0;
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu += int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                result[i] = uint16_t(accu >> 9);
            }
            break;
        case MULH_SHIFT:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                accu = int64_t(int16_t(opa[i])) * int64_t(int16_t(opb[i]));
                result[i] = uint16_t(accu >> 9);
            }
            break;
        case LS_LANE0:
        case LS_LANE1:
//        case LS_LANE2:
        case LS_LANE3:
        case LS_LANE4:
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                result[i] = int32_t(int16_t(opa[i]));
            }
            break;

        case CNN_28_K3: {
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                inputdata[i] = int16_t(opa[i]);
                inputdata[i+NUM_TEST_ENTRIES] = int16_t(opb[i]);
            }
            int image_dim = 28, kernel_dim = 3;
            for (int ix = 0; ix < image_dim; ++ix) {
                for (int iy = 0; iy < image_dim; ++iy) {
                    int64_t output_pixel = (bias[0] >> bias_shift_right) << conv_result_shift_right;
                    int64_t output_pixel2 = (bias2[0] >> bias_shift_right) << conv_result_shift_right;
                    for (int kx = 0; kx < kernel_dim; ++kx) {
                        for (int ky = 0; ky < kernel_dim; ++ky) {
                            output_pixel += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                      ky * (image_dim + kernel_dim - 1)] *
                                            (kernel[kx + ky * kernel_dim] >> kernel_load_shift_right);
                            output_pixel2 += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                       ky * (image_dim + kernel_dim - 1)] *
                                             (kernel2[kx + ky * kernel_dim] >> kernel_load_shift_right);
                        }
                    }
                    outputdata[ix + iy * image_dim] = (output_pixel >> conv_result_shift_right) >> store_shift_right;
                    outputdata2[ix + iy * image_dim] = (output_pixel2 >> conv_result_shift_right) >> store_shift_right;
                }
            }
            for (int i = 0; i < 1024; ++i){
                result[i] = 0xdead;
            }
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i] = outputdata[i];
            }
            assert (image_dim*image_dim+180 <= 1024);   // avoid overflow of result_array (size: 1024)
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i+180] = outputdata2[i];
            }
        }
            break;
        case CNN_7_K3: {
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                inputdata[i] = int16_t(opa[i]);
                inputdata[i+NUM_TEST_ENTRIES] = int16_t(opb[i]);
            }
            int image_dim = 7, kernel_dim = 3;
            for (int ix = 0; ix < image_dim; ++ix) {
                for (int iy = 0; iy < image_dim; ++iy) {
                    int64_t output_pixel = (bias[0] >> bias_shift_right) << conv_result_shift_right;
                    int64_t output_pixel2 = (bias2[0] >> bias_shift_right) << conv_result_shift_right;
                    for (int kx = 0; kx < kernel_dim; ++kx) {
                        for (int ky = 0; ky < kernel_dim; ++ky) {
                            output_pixel += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                      ky * (image_dim + kernel_dim - 1)] *
                                            (kernel[kx + ky * kernel_dim] >> kernel_load_shift_right);
                            output_pixel2 += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                       ky * (image_dim + kernel_dim - 1)] *
                                             (kernel2[kx + ky * kernel_dim] >> kernel_load_shift_right);
                        }
                    }
                    outputdata[ix + iy * image_dim] = (output_pixel >> conv_result_shift_right) >> store_shift_right;
                    outputdata2[ix + iy * image_dim] = (output_pixel2 >> conv_result_shift_right) >> store_shift_right;
                }
            }
            for (int i = 0; i < 1024; ++i){
                result[i] = 0xdead;
            }
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i] = outputdata[i];
            }
            assert (image_dim*image_dim+180 <= 1024);   // avoid overflow of result_array (size: 1024)
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i+180] = outputdata2[i];
            }
        }
            break;
        case CNN_28_K1: {
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                inputdata[i] = int16_t(opa[i]);
                inputdata[i+NUM_TEST_ENTRIES] = int16_t(opb[i]);
            }
            int image_dim = 28, kernel_dim = 1;
            for (int ix = 0; ix < image_dim; ++ix) {
                for (int iy = 0; iy < image_dim; ++iy) {
                    int64_t output_pixel = (bias[0] >> bias_shift_right) << conv_result_shift_right;
                    int64_t output_pixel2 = (bias2[0] >> bias_shift_right) << conv_result_shift_right;
                    for (int kx = 0; kx < kernel_dim; ++kx) {
                        for (int ky = 0; ky < kernel_dim; ++ky) {
                            output_pixel += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                      ky * (image_dim + kernel_dim - 1)] *
                                            (kernel[kx + ky * kernel_dim] >> kernel_load_shift_right);
                            output_pixel2 += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                      ky * (image_dim + kernel_dim - 1)] *
                                            (kernel2[kx + ky * kernel_dim] >> kernel_load_shift_right);
                        }
                    }
                    outputdata[ix + iy * image_dim] = (output_pixel >> conv_result_shift_right) >> store_shift_right;
                    outputdata2[ix + iy * image_dim] = (output_pixel2 >> conv_result_shift_right) >> store_shift_right;
                }
            }
            for (int i = 0; i < 1024; ++i){
                result[i] = 0xdead;
            }
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i] = outputdata[i];
            }
            assert (image_dim*image_dim+180 <= 1024);   // avoid overflow of result_array (size: 1024)
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i+180] = outputdata2[i];
            }
        }
            break;
        case CNN_7_K1: {
            for (int i = 0; i < NUM_TEST_ENTRIES; ++i) {
                inputdata[i] = int16_t(opa[i]);
                inputdata[i+NUM_TEST_ENTRIES] = int16_t(opb[i]);
            }
            int image_dim = 7, kernel_dim = 1;
            for (int ix = 0; ix < image_dim; ++ix) {
                for (int iy = 0; iy < image_dim; ++iy) {
                    int64_t output_pixel = (bias[0] >> bias_shift_right) << conv_result_shift_right;
                    int64_t output_pixel2 = (bias2[0] >> bias_shift_right) << conv_result_shift_right;
                    for (int kx = 0; kx < kernel_dim; ++kx) {
                        for (int ky = 0; ky < kernel_dim; ++ky) {
                            output_pixel += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                      ky * (image_dim + kernel_dim - 1)] *
                                            (kernel[kx + ky * kernel_dim] >> kernel_load_shift_right);
                            output_pixel2 += inputdata[ix + (image_dim + kernel_dim - 1) * iy + kx +
                                                       ky * (image_dim + kernel_dim - 1)] *
                                             (kernel2[kx + ky * kernel_dim] >> kernel_load_shift_right);
                        }
                    }
                    outputdata[ix + iy * image_dim] = (output_pixel >> conv_result_shift_right) >> store_shift_right;
                    outputdata2[ix + iy * image_dim] = (output_pixel2 >> conv_result_shift_right) >> store_shift_right;
                }
            }
            for (int i = 0; i < 1024; ++i){
                result[i] = 0xdead;
            }
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i] = outputdata[i];
            }
            assert (image_dim*image_dim+180 <= 1024);   // avoid overflow of result_array (size: 1024)
            for (int i = 0; i < image_dim*image_dim; ++i) {
                result[i+180] = outputdata2[i];
            }
        }
            break;

        default:
      //      console.printf_error("execute of unknown function!");
      //      console.printf_error_(testName(t));
        break;
    }

//    for (int i = 0; i < 1024; ++i) {
//        result[i] = uint32_t(result[i]) & 0x0000ffff;
//    }
    return result;
}
#endif
