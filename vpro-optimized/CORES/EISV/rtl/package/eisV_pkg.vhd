--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Design Name:    RISC-V processor core                                      --
--                                                                            --
-- Description:    Defines for various constants used by the processor core.  --
--                                                                            --
--------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
package eisV_pkg is

    ------------------------------------------------
    -- Configurations
    ------------------------------------------------
    -- EISV
    -- Cache size in bytes (IC) --
    -- 2^ic_log2_num_lines_c * 2^ic_log2_line_size_c * 4 Bytes
    constant ic_log2_num_lines_c : natural                        := 5; -- log2 of number of cache lines (i-cache)                  4: 16
    constant ic_log2_line_size_c : natural                        := 3; -- log2 of size of cache line    (i-cache) x ic_cache_word_width_c bit!
    constant dc_log2_num_lines_c : natural                        := 3; -- log2 of number of cache lines (d-cache)                  - 5 ~ 32 lines            - 3 ~ 8 lines
    constant dc_log2_line_size_c : natural                        := 6; -- log2 of size of cache line    (d-cache) x dc_cache_word_width_c bit!
    constant io_area_begin_c     : std_ulogic_vector(31 downto 0) := x"C0000000"; -- where does the IO area start?
    
    constant dc_cache_word_width_c : natural := 512;
    constant ic_cache_word_width_c : natural := 512;

    -- ICache
    -- INSTR_WORD_COUNT = 4 for ASIC
    -- MEM_WORD_WIDTH = 128
    -- WORD_WIDTH = 32
    -- icache ram addr width = LOG2_LINE_SIZE + LOG2_NUM_LINES + log2((MEMORY_WORD_WIDTH / WORD_WIDTH) / INSTR_WORD_COUNT) = LOG2_LINE_SIZE + LOG2_NUM_LINES
    -- icache ram word width = 32

    -- DCache
    -- INSTR_WORD_COUNT = 8 for ASIC
    -- MEM_WORD_WIDTH = 128
    -- WORD_WIDTH = 32
    -- LOG2_ASSOCIATIVITY = 1
    -- dcache ram addr width = LOG2_LINE_SIZE + LOG2_NUM_LINES + LOG2_ASSOCIATIVTY + log2((MEMORY_WORD_WIDTH / WORD_WIDTH) / INSTR_WORD_COUNT) = LOG2_LINE_SIZE + LOG2_NUM_LINES + LOG2_ASSOCIATIVTY - 1
    -- dcache ram word width = 32

    -- JALR uses the pc data from Registerfile to jump to a specific addr (rs)
    -- the data is added to an immediate in ID (regfile read + add) or EX (ID: RF read, EX: add)
    -- hazards are handled as well 
    constant JALR_TARGET_ADDER_IN_ID : boolean := false;

    -- Multiply Operations can use two stages (EX+MEM)
    -- if needed by following op (input data is mult result), this can cause additional hazards (handled by ID)
    -- if no two cycle Multiply, the mul still could be multicycle (mulh) and cause stalls
    -- if two cycle Multiply, multicycle still possible (2 cycles without stall)
    constant MUL_IN_TWO_STAGES_EX_AND_MEM : boolean := true;

    -- does this core implement the Risc-V C extension
    -- if so, additional alignment buffer (IF/ID) and C-Decompression MUX are used
    constant C_EXTENSION : boolean := false;

    constant MUL_CYCLES_L : natural := 2;
    constant MUL_CYCLES_H : natural := 2;

    constant VPRO_CUSTOM_EXTENSION : boolean := true;

    constant MEM_DELAY : natural := 2;
    
    constant generate_dcache_access_trace : boolean := true;
    
    ------------------------------------------------
    --    ___         ____          _             --
    --   / _ \ _ __  / ___|___   __| | ___  ___   --
    --  | | | | '_ \| |   / _ \ / _` |/ _ \/ __|  --
    --  | |_| | |_) | |__| (_) | (_| |  __/\__ \  --
    --   \___/| .__/ \____\___/ \__,_|\___||___/  --
    --        |_|                                 --
    ------------------------------------------------

    constant OPCODE_SYSTEM    : std_ulogic_vector(6 downto 0) := "1110011";
    constant OPCODE_FENCE     : std_ulogic_vector(6 downto 0) := "0001111";
    constant OPCODE_OP        : std_ulogic_vector(6 downto 0) := "0110011";
    constant OPCODE_OPIMM     : std_ulogic_vector(6 downto 0) := "0010011";
    constant OPCODE_STORE     : std_ulogic_vector(6 downto 0) := "0100011";
    constant OPCODE_LOAD      : std_ulogic_vector(6 downto 0) := "0000011";
    constant OPCODE_BRANCH    : std_ulogic_vector(6 downto 0) := "1100011";
    constant OPCODE_JALR      : std_ulogic_vector(6 downto 0) := "1100111";
    constant OPCODE_JAL       : std_ulogic_vector(6 downto 0) := "1101111";
    constant OPCODE_AUIPC     : std_ulogic_vector(6 downto 0) := "0010111";
    constant OPCODE_LUI       : std_ulogic_vector(6 downto 0) := "0110111";
    constant OPCODE_OP_FP     : std_ulogic_vector(6 downto 0) := "1010011";
    constant OPCODE_OP_FMADD  : std_ulogic_vector(6 downto 0) := "1000011";
    constant OPCODE_OP_FNMADD : std_ulogic_vector(6 downto 0) := "1001111";
    constant OPCODE_OP_FMSUB  : std_ulogic_vector(6 downto 0) := "1000111";
    constant OPCODE_OP_FNMSUB : std_ulogic_vector(6 downto 0) := "1001011";
    constant OPCODE_STORE_FP  : std_ulogic_vector(6 downto 0) := "0100111";
    constant OPCODE_LOAD_FP   : std_ulogic_vector(6 downto 0) := "0000111";
    constant OPCODE_AMO       : std_ulogic_vector(6 downto 0) := "0101111";
    constant OPCODE_CUSTOM_0  : std_ulogic_vector(6 downto 0) := "0001011";
    constant OPCODE_CUSTOM_1  : std_ulogic_vector(6 downto 0) := "0101011";

    type vpro_op_t is (NONE, VPRO_LI, VPRO_LW, DMA_LW);

    type vpro_bundle_t is record
        vpro_op           : vpro_op_t;
        valid             : std_ulogic;
        regfile_op_a      : std_ulogic_vector(31 downto 0);
        regfile_op_a_addr : std_ulogic_vector(4 downto 0);
        regfile_op_b      : std_ulogic_vector(31 downto 0);
        imm_s_type        : std_ulogic_vector(11 downto 0);
        imm_u_type        : std_ulogic_vector(19 downto 0);
    end record;

    --    -- Atomic operations
    --    constant AMO_LR   : std_ulogic_vector(4 downto 0) := "00010";
    --    constant AMO_SC   : std_ulogic_vector(4 downto 0) := "00011";
    --    constant AMO_SWAP : std_ulogic_vector(4 downto 0) := "00001";
    --    constant AMO_ADD  : std_ulogic_vector(4 downto 0) := "00000";
    --    constant AMO_XOR  : std_ulogic_vector(4 downto 0) := "00100";
    --    constant AMO_AND  : std_ulogic_vector(4 downto 0) := "01100";
    --    constant AMO_OR   : std_ulogic_vector(4 downto 0) := "01000";
    --    constant AMO_MIN  : std_ulogic_vector(4 downto 0) := "10000";
    --    constant AMO_MAX  : std_ulogic_vector(4 downto 0) := "10100";
    --    constant AMO_MINU : std_ulogic_vector(4 downto 0) := "11000";
    --    constant AMO_MAXU : std_ulogic_vector(4 downto 0) := "11100";
    ------------------------------------------------------------------------------
    --      _    _    _   _    ___                       _   _                  --
    --     / \  | |  | | | |  / _ \ _ __   ___ _ __ __ _| |_(_) ___  _ __  ___  --
    --    / _ \ | |  | | | | | | | | '_ \ / _ \ '__/ _` | __| |/ _ \| '_ \/ __| --
    --   / ___ \| |__| |_| | | |_| | |_) |  __/ | | (_| | |_| | (_) | | | \__ \ --
    --  /_/   \_\_____\___/   \___/| .__/ \___|_|  \__,_|\__|_|\___/|_| |_|___/ --
    --                             |_|                                          --
    ------------------------------------------------------------------------------

    type alu_op_t is (ALU_ADD, ALU_SUB,
                      ALU_XOR, ALU_OR, ALU_AND,
                      ALU_SRA, ALU_SRL, ALU_SLL,
                      ALU_LTS, ALU_LTU, ALU_GES, ALU_GEU, ALU_EQ, ALU_NE,
                      ALU_SLTS, ALU_SLTU,
                      ALU_DIVU, ALU_DIV, ALU_REMU, ALU_REM
                     );
    -- Mul
    type mult_operator_t is (MUL_L, MUL_H);

    -- FSM state encoding
    type ctrl_state_t is (RESET, BOOT_SET, SLEEP, DECODE, NOP_INSERT_FIRST, NOP_INSERT_SECOND
    );

    type prefetch_state_e is (
        IDLE,
        BRANCH_WAIT);

    type mult_state_e is (
        IDLE_MULT,
        STEP0,
        STEP1,
        STEP2,
        FINISH);

    ---------------------------------------------------------
    --   LSU
    ---------------------------------------------------------

    type memory_data_type_t is (BYTE, HALFWORD, WORD);

    type lsu_op_t is (LSU_NONE, LSU_LOAD, LSU_STORE);

    ---------------------------------------------------------
    --    ____ ____    ____            _     _             --
    --   / ___/ ___|  |  _ \ ___  __ _(_)___| |_ ___ _ __  --
    --  | |   \___ \  | |_) / _ \/ _` | / __| __/ _ \ '__| --
    --  | |___ ___) | |  _ <  __/ (_| | \__ \ ||  __/ |    --
    --   \____|____/  |_| \_\___|\__, |_|___/\__\___|_|    --
    --                           |___/                     --
    ---------------------------------------------------------

    ---------------------------------------------------------
    -- User Custom CSRs
    ---------------------------------------------------------

    -- User Hart ID
    constant CSR_UHARTID : std_ulogic_vector(11 downto 0) := x"CC0"; -- Custom CSR. User Hart ID

    ---------------------------------------------------------
    -- Machine CSRs
    ---------------------------------------------------------

    -- Machine trap setup
    constant CSR_MSTATUS : std_ulogic_vector(11 downto 0) := x"300";
    constant CSR_MISA    : std_ulogic_vector(11 downto 0) := x"301";
    constant CSR_MIE     : std_ulogic_vector(11 downto 0) := x"304";
    constant CSR_MTVEC   : std_ulogic_vector(11 downto 0) := x"305";

    -- Performance counters
    constant CSR_MCOUNTEREN    : std_ulogic_vector(11 downto 0) := x"306";
    constant CSR_MCOUNTINHIBIT : std_ulogic_vector(11 downto 0) := x"320";
    constant CSR_MHPMEVENT3    : std_ulogic_vector(11 downto 0) := x"323";
    constant CSR_MHPMEVENT4    : std_ulogic_vector(11 downto 0) := x"324";
    constant CSR_MHPMEVENT5    : std_ulogic_vector(11 downto 0) := x"325";
    constant CSR_MHPMEVENT6    : std_ulogic_vector(11 downto 0) := x"326";
    constant CSR_MHPMEVENT7    : std_ulogic_vector(11 downto 0) := x"327";
    constant CSR_MHPMEVENT8    : std_ulogic_vector(11 downto 0) := x"328";
    constant CSR_MHPMEVENT9    : std_ulogic_vector(11 downto 0) := x"329";
    constant CSR_MHPMEVENT10   : std_ulogic_vector(11 downto 0) := x"32A";
    constant CSR_MHPMEVENT11   : std_ulogic_vector(11 downto 0) := x"32B";
    constant CSR_MHPMEVENT12   : std_ulogic_vector(11 downto 0) := x"32C";
    constant CSR_MHPMEVENT13   : std_ulogic_vector(11 downto 0) := x"32D";
    constant CSR_MHPMEVENT14   : std_ulogic_vector(11 downto 0) := x"32E";
    constant CSR_MHPMEVENT15   : std_ulogic_vector(11 downto 0) := x"32F";
    constant CSR_MHPMEVENT16   : std_ulogic_vector(11 downto 0) := x"330";
    constant CSR_MHPMEVENT17   : std_ulogic_vector(11 downto 0) := x"331";
    constant CSR_MHPMEVENT18   : std_ulogic_vector(11 downto 0) := x"332";
    constant CSR_MHPMEVENT19   : std_ulogic_vector(11 downto 0) := x"333";
    constant CSR_MHPMEVENT20   : std_ulogic_vector(11 downto 0) := x"334";
    constant CSR_MHPMEVENT21   : std_ulogic_vector(11 downto 0) := x"335";
    constant CSR_MHPMEVENT22   : std_ulogic_vector(11 downto 0) := x"336";
    constant CSR_MHPMEVENT23   : std_ulogic_vector(11 downto 0) := x"337";
    constant CSR_MHPMEVENT24   : std_ulogic_vector(11 downto 0) := x"338";
    constant CSR_MHPMEVENT25   : std_ulogic_vector(11 downto 0) := x"339";
    constant CSR_MHPMEVENT26   : std_ulogic_vector(11 downto 0) := x"33A";
    constant CSR_MHPMEVENT27   : std_ulogic_vector(11 downto 0) := x"33B";
    constant CSR_MHPMEVENT28   : std_ulogic_vector(11 downto 0) := x"33C";
    constant CSR_MHPMEVENT29   : std_ulogic_vector(11 downto 0) := x"33D";
    constant CSR_MHPMEVENT30   : std_ulogic_vector(11 downto 0) := x"33E";
    constant CSR_MHPMEVENT31   : std_ulogic_vector(11 downto 0) := x"33F";

    -- Machine trap handling
    constant CSR_MSCRATCH : std_ulogic_vector(11 downto 0) := x"340";
    constant CSR_MEPC     : std_ulogic_vector(11 downto 0) := x"341";
    constant CSR_MCAUSE   : std_ulogic_vector(11 downto 0) := x"342";
    constant CSR_MTVAL    : std_ulogic_vector(11 downto 0) := x"343";
    constant CSR_MIP      : std_ulogic_vector(11 downto 0) := x"344";

    -- Hardware Performance Monitor
    constant CSR_MCYCLE        : std_ulogic_vector(11 downto 0) := x"B00";
    constant CSR_MINSTRET      : std_ulogic_vector(11 downto 0) := x"B02";
    constant CSR_MHPMCOUNTER3  : std_ulogic_vector(11 downto 0) := x"B03";
    constant CSR_MHPMCOUNTER4  : std_ulogic_vector(11 downto 0) := x"B04";
    constant CSR_MHPMCOUNTER5  : std_ulogic_vector(11 downto 0) := x"B05";
    constant CSR_MHPMCOUNTER6  : std_ulogic_vector(11 downto 0) := x"B06";
    constant CSR_MHPMCOUNTER7  : std_ulogic_vector(11 downto 0) := x"B07";
    constant CSR_MHPMCOUNTER8  : std_ulogic_vector(11 downto 0) := x"B08";
    constant CSR_MHPMCOUNTER9  : std_ulogic_vector(11 downto 0) := x"B09";
    constant CSR_MHPMCOUNTER10 : std_ulogic_vector(11 downto 0) := x"B0A";
    constant CSR_MHPMCOUNTER11 : std_ulogic_vector(11 downto 0) := x"B0B";
    constant CSR_MHPMCOUNTER12 : std_ulogic_vector(11 downto 0) := x"B0C";
    constant CSR_MHPMCOUNTER13 : std_ulogic_vector(11 downto 0) := x"B0D";
    constant CSR_MHPMCOUNTER14 : std_ulogic_vector(11 downto 0) := x"B0E";
    constant CSR_MHPMCOUNTER15 : std_ulogic_vector(11 downto 0) := x"B0F";
    constant CSR_MHPMCOUNTER16 : std_ulogic_vector(11 downto 0) := x"B10";
    constant CSR_MHPMCOUNTER17 : std_ulogic_vector(11 downto 0) := x"B11";
    constant CSR_MHPMCOUNTER18 : std_ulogic_vector(11 downto 0) := x"B12";
    constant CSR_MHPMCOUNTER19 : std_ulogic_vector(11 downto 0) := x"B13";
    constant CSR_MHPMCOUNTER20 : std_ulogic_vector(11 downto 0) := x"B14";
    constant CSR_MHPMCOUNTER21 : std_ulogic_vector(11 downto 0) := x"B15";
    constant CSR_MHPMCOUNTER22 : std_ulogic_vector(11 downto 0) := x"B16";
    constant CSR_MHPMCOUNTER23 : std_ulogic_vector(11 downto 0) := x"B17";
    constant CSR_MHPMCOUNTER24 : std_ulogic_vector(11 downto 0) := x"B18";
    constant CSR_MHPMCOUNTER25 : std_ulogic_vector(11 downto 0) := x"B19";
    constant CSR_MHPMCOUNTER26 : std_ulogic_vector(11 downto 0) := x"B1A";
    constant CSR_MHPMCOUNTER27 : std_ulogic_vector(11 downto 0) := x"B1B";
    constant CSR_MHPMCOUNTER28 : std_ulogic_vector(11 downto 0) := x"B1C";
    constant CSR_MHPMCOUNTER29 : std_ulogic_vector(11 downto 0) := x"B1D";
    constant CSR_MHPMCOUNTER30 : std_ulogic_vector(11 downto 0) := x"B1E";
    constant CSR_MHPMCOUNTER31 : std_ulogic_vector(11 downto 0) := x"B1F";

    constant CSR_MCYCLEH        : std_ulogic_vector(11 downto 0) := x"B80";
    constant CSR_MINSTRETH      : std_ulogic_vector(11 downto 0) := x"B82";
    constant CSR_MHPMCOUNTER3H  : std_ulogic_vector(11 downto 0) := x"B83";
    constant CSR_MHPMCOUNTER4H  : std_ulogic_vector(11 downto 0) := x"B84";
    constant CSR_MHPMCOUNTER5H  : std_ulogic_vector(11 downto 0) := x"B85";
    constant CSR_MHPMCOUNTER6H  : std_ulogic_vector(11 downto 0) := x"B86";
    constant CSR_MHPMCOUNTER7H  : std_ulogic_vector(11 downto 0) := x"B87";
    constant CSR_MHPMCOUNTER8H  : std_ulogic_vector(11 downto 0) := x"B88";
    constant CSR_MHPMCOUNTER9H  : std_ulogic_vector(11 downto 0) := x"B89";
    constant CSR_MHPMCOUNTER10H : std_ulogic_vector(11 downto 0) := x"B8A";
    constant CSR_MHPMCOUNTER11H : std_ulogic_vector(11 downto 0) := x"B8B";
    constant CSR_MHPMCOUNTER12H : std_ulogic_vector(11 downto 0) := x"B8C";
    constant CSR_MHPMCOUNTER13H : std_ulogic_vector(11 downto 0) := x"B8D";
    constant CSR_MHPMCOUNTER14H : std_ulogic_vector(11 downto 0) := x"B8E";
    constant CSR_MHPMCOUNTER15H : std_ulogic_vector(11 downto 0) := x"B8F";
    constant CSR_MHPMCOUNTER16H : std_ulogic_vector(11 downto 0) := x"B90";
    constant CSR_MHPMCOUNTER17H : std_ulogic_vector(11 downto 0) := x"B91";
    constant CSR_MHPMCOUNTER18H : std_ulogic_vector(11 downto 0) := x"B92";
    constant CSR_MHPMCOUNTER19H : std_ulogic_vector(11 downto 0) := x"B93";
    constant CSR_MHPMCOUNTER20H : std_ulogic_vector(11 downto 0) := x"B94";
    constant CSR_MHPMCOUNTER21H : std_ulogic_vector(11 downto 0) := x"B95";
    constant CSR_MHPMCOUNTER22H : std_ulogic_vector(11 downto 0) := x"B96";
    constant CSR_MHPMCOUNTER23H : std_ulogic_vector(11 downto 0) := x"B97";
    constant CSR_MHPMCOUNTER24H : std_ulogic_vector(11 downto 0) := x"B98";
    constant CSR_MHPMCOUNTER25H : std_ulogic_vector(11 downto 0) := x"B99";
    constant CSR_MHPMCOUNTER26H : std_ulogic_vector(11 downto 0) := x"B9A";
    constant CSR_MHPMCOUNTER27H : std_ulogic_vector(11 downto 0) := x"B9B";
    constant CSR_MHPMCOUNTER28H : std_ulogic_vector(11 downto 0) := x"B9C";
    constant CSR_MHPMCOUNTER29H : std_ulogic_vector(11 downto 0) := x"B9D";
    constant CSR_MHPMCOUNTER30H : std_ulogic_vector(11 downto 0) := x"B9E";
    constant CSR_MHPMCOUNTER31H : std_ulogic_vector(11 downto 0) := x"B9F";

    constant CSR_CYCLE        : std_ulogic_vector(11 downto 0) := x"C00";
    constant CSR_INSTRET      : std_ulogic_vector(11 downto 0) := x"C02";
    constant CSR_HPMCOUNTER3  : std_ulogic_vector(11 downto 0) := x"C03";
    constant CSR_HPMCOUNTER4  : std_ulogic_vector(11 downto 0) := x"C04";
    constant CSR_HPMCOUNTER5  : std_ulogic_vector(11 downto 0) := x"C05";
    constant CSR_HPMCOUNTER6  : std_ulogic_vector(11 downto 0) := x"C06";
    constant CSR_HPMCOUNTER7  : std_ulogic_vector(11 downto 0) := x"C07";
    constant CSR_HPMCOUNTER8  : std_ulogic_vector(11 downto 0) := x"C08";
    constant CSR_HPMCOUNTER9  : std_ulogic_vector(11 downto 0) := x"C09";
    constant CSR_HPMCOUNTER10 : std_ulogic_vector(11 downto 0) := x"C0A";
    constant CSR_HPMCOUNTER11 : std_ulogic_vector(11 downto 0) := x"C0B";
    constant CSR_HPMCOUNTER12 : std_ulogic_vector(11 downto 0) := x"C0C";
    constant CSR_HPMCOUNTER13 : std_ulogic_vector(11 downto 0) := x"C0D";
    constant CSR_HPMCOUNTER14 : std_ulogic_vector(11 downto 0) := x"C0E";
    constant CSR_HPMCOUNTER15 : std_ulogic_vector(11 downto 0) := x"C0F";
    constant CSR_HPMCOUNTER16 : std_ulogic_vector(11 downto 0) := x"C10";
    constant CSR_HPMCOUNTER17 : std_ulogic_vector(11 downto 0) := x"C11";
    constant CSR_HPMCOUNTER18 : std_ulogic_vector(11 downto 0) := x"C12";
    constant CSR_HPMCOUNTER19 : std_ulogic_vector(11 downto 0) := x"C13";
    constant CSR_HPMCOUNTER20 : std_ulogic_vector(11 downto 0) := x"C14";
    constant CSR_HPMCOUNTER21 : std_ulogic_vector(11 downto 0) := x"C15";
    constant CSR_HPMCOUNTER22 : std_ulogic_vector(11 downto 0) := x"C16";
    constant CSR_HPMCOUNTER23 : std_ulogic_vector(11 downto 0) := x"C17";
    constant CSR_HPMCOUNTER24 : std_ulogic_vector(11 downto 0) := x"C18";
    constant CSR_HPMCOUNTER25 : std_ulogic_vector(11 downto 0) := x"C19";
    constant CSR_HPMCOUNTER26 : std_ulogic_vector(11 downto 0) := x"C1A";
    constant CSR_HPMCOUNTER27 : std_ulogic_vector(11 downto 0) := x"C1B";
    constant CSR_HPMCOUNTER28 : std_ulogic_vector(11 downto 0) := x"C1C";
    constant CSR_HPMCOUNTER29 : std_ulogic_vector(11 downto 0) := x"C1D";
    constant CSR_HPMCOUNTER30 : std_ulogic_vector(11 downto 0) := x"C1E";
    constant CSR_HPMCOUNTER31 : std_ulogic_vector(11 downto 0) := x"C1F";

    constant CSR_CYCLEH        : std_ulogic_vector(11 downto 0) := x"C80";
    constant CSR_INSTRETH      : std_ulogic_vector(11 downto 0) := x"C82";
    constant CSR_HPMCOUNTER3H  : std_ulogic_vector(11 downto 0) := x"C83";
    constant CSR_HPMCOUNTER4H  : std_ulogic_vector(11 downto 0) := x"C84";
    constant CSR_HPMCOUNTER5H  : std_ulogic_vector(11 downto 0) := x"C85";
    constant CSR_HPMCOUNTER6H  : std_ulogic_vector(11 downto 0) := x"C86";
    constant CSR_HPMCOUNTER7H  : std_ulogic_vector(11 downto 0) := x"C87";
    constant CSR_HPMCOUNTER8H  : std_ulogic_vector(11 downto 0) := x"C88";
    constant CSR_HPMCOUNTER9H  : std_ulogic_vector(11 downto 0) := x"C89";
    constant CSR_HPMCOUNTER10H : std_ulogic_vector(11 downto 0) := x"C8A";
    constant CSR_HPMCOUNTER11H : std_ulogic_vector(11 downto 0) := x"C8B";
    constant CSR_HPMCOUNTER12H : std_ulogic_vector(11 downto 0) := x"C8C";
    constant CSR_HPMCOUNTER13H : std_ulogic_vector(11 downto 0) := x"C8D";
    constant CSR_HPMCOUNTER14H : std_ulogic_vector(11 downto 0) := x"C8E";
    constant CSR_HPMCOUNTER15H : std_ulogic_vector(11 downto 0) := x"C8F";
    constant CSR_HPMCOUNTER16H : std_ulogic_vector(11 downto 0) := x"C90";
    constant CSR_HPMCOUNTER17H : std_ulogic_vector(11 downto 0) := x"C91";
    constant CSR_HPMCOUNTER18H : std_ulogic_vector(11 downto 0) := x"C92";
    constant CSR_HPMCOUNTER19H : std_ulogic_vector(11 downto 0) := x"C93";
    constant CSR_HPMCOUNTER20H : std_ulogic_vector(11 downto 0) := x"C94";
    constant CSR_HPMCOUNTER21H : std_ulogic_vector(11 downto 0) := x"C95";
    constant CSR_HPMCOUNTER22H : std_ulogic_vector(11 downto 0) := x"C96";
    constant CSR_HPMCOUNTER23H : std_ulogic_vector(11 downto 0) := x"C97";
    constant CSR_HPMCOUNTER24H : std_ulogic_vector(11 downto 0) := x"C98";
    constant CSR_HPMCOUNTER25H : std_ulogic_vector(11 downto 0) := x"C99";
    constant CSR_HPMCOUNTER26H : std_ulogic_vector(11 downto 0) := x"C9A";
    constant CSR_HPMCOUNTER27H : std_ulogic_vector(11 downto 0) := x"C9B";
    constant CSR_HPMCOUNTER28H : std_ulogic_vector(11 downto 0) := x"C9C";
    constant CSR_HPMCOUNTER29H : std_ulogic_vector(11 downto 0) := x"C9D";
    constant CSR_HPMCOUNTER30H : std_ulogic_vector(11 downto 0) := x"C9E";
    constant CSR_HPMCOUNTER31H : std_ulogic_vector(11 downto 0) := x"C9F";

    -- Machine information
    constant CSR_MVENDORID : std_ulogic_vector(11 downto 0) := x"F11";
    constant CSR_MARCHID   : std_ulogic_vector(11 downto 0) := x"F12";
    constant CSR_MIMPID    : std_ulogic_vector(11 downto 0) := x"F13";
    constant CSR_MHARTID   : std_ulogic_vector(11 downto 0) := x"F14";

    -- CSR operations
    constant CSR_OP_WIDTH : natural := 2;

    constant CSR_OP_READ  : std_ulogic_vector(1 downto 0) := "00";
    constant CSR_OP_WRITE : std_ulogic_vector(1 downto 0) := "01";
    constant CSR_OP_SET   : std_ulogic_vector(1 downto 0) := "10";
    constant CSR_OP_CLEAR : std_ulogic_vector(1 downto 0) := "11";

    -- CSR interrupt pending/enable bits
    constant CSR_MSIX_BIT      : natural := 3;
    constant CSR_MTIX_BIT      : natural := 7;
    constant CSR_MEIX_BIT      : natural := 11;
    constant CSR_MFIX_BIT_LOW  : natural := 16;
    constant CSR_MFIX_BIT_HIGH : natural := 31;

    -- Machine Architecture ID (https://github.com/riscv/riscv-isa-manual/blob/master/marchid.md)
    constant MARCHID : std_ulogic_vector(31 downto 0) := x"00000000";

    -- Machine Vendor ID
    constant MVENDORID : std_ulogic_vector(31 downto 0) := x"00000000";

    -----------------------------------------------
    --   ___ ____    ____  _                     --
    --  |_ _|  _ \  / ___|| |_ __ _  __ _  ___   --
    --   | || | | | \___ \| __/ _` |/ _` |/ _ \  --
    --   | || |_| |  ___) | || (_| | (_| |  __/  --
    --  |___|____/  |____/ \__\__,_|\__, |\___|  --
    --                              |___/        --
    -----------------------------------------------

    type instr_type_t is (
        ILLEGAL,
        MRET,
        CSR,
        FENCEI,
        WFI,
        ECALL,
        BRANCH,
        LOAD,
        NORMAL
    );

    -- forwarding operand mux
    type forward_sel_t is (
        SEL_REGFILE,
        SEL_FW_MEM1,
        SEL_FW_MEM2,
        SEL_FW_MEM3,                    -- maybe unneeded
        SEL_FW_WB
    );

    -- operand a selection
    type op_a_sel_t is (
        OP_A_REGA,
        --        OP_A_REGB,
        OP_A_CURRPC,
        OP_A_IMM,
        OP_A_STALL_BUFFER
    );

    type op_a_immediate_sel_t is (
        IMMA_Z,
        IMMA_ZERO
    );

    -- operand b selection
    type op_b_sel_t is (
        --        OP_B_REGA,
        OP_B_REGB,
        OP_B_IMM,
        OP_B_STALL_BUFFER
    );

    type op_b_immediate_sel_t is (
        IMMB_I,
        IMMB_S,
        IMMB_U,
        IMMB_PCINCR
        --        IMMB_S2,
        --        IMMB_S3,
        --        IMMB_VS,
        --        IMMB_VU,
        --        IMMB_SHUF,
        --        IMMB_CLIP
        --        IMMB_BI
    );

    -- bit mask selection
    constant BMASK_A_ZERO : std_ulogic := '0';
    constant BMASK_A_S3   : std_ulogic := '1';

    constant BMASK_B_S2   : std_ulogic_vector(1 downto 0) := "00";
    constant BMASK_B_S3   : std_ulogic_vector(1 downto 0) := "01";
    constant BMASK_B_ZERO : std_ulogic_vector(1 downto 0) := "10";
    constant BMASK_B_ONE  : std_ulogic_vector(1 downto 0) := "11";

    constant BMASK_A_REG : std_ulogic := '0';
    constant BMASK_A_IMM : std_ulogic := '1';
    constant BMASK_B_REG : std_ulogic := '0';
    constant BMASK_B_IMM : std_ulogic := '1';

    -- multiplication immediates
    constant MIMM_ZERO : std_ulogic := '0';
    constant MIMM_S3   : std_ulogic := '1';

    -- operand c selection
    constant OP_C_REGC_OR_FWD : std_ulogic_vector(1 downto 0) := "00";
    constant OP_C_REGB_OR_FWD : std_ulogic_vector(1 downto 0) := "01";
    constant OP_C_JT          : std_ulogic_vector(1 downto 0) := "10";

    -- branch types
    type branch_t is (BRANCH_NONE, BRANCH_JAL, BRANCH_JALR, BRANCH_COND);

    -- jump target mux
    type jump_target_mux_sel_t is (JT_JAL, JT_JALR, JT_COND);

    -----------------------------------------------
    --   ___ _____   ____  _                     --
    --  |_ _|  ___| / ___|| |_ __ _  __ _  ___   --
    --   | || |_    \___ \| __/ _` |/ _` |/ _ \  --
    --   | ||  _|    ___) | || (_| | (_| |  __/  --
    --  |___|_|     |____/ \__\__,_|\__, |\___|  --
    --                              |___/        --
    -----------------------------------------------

    -- PC mux selector defines
    type pc_mux_sel_t is (PC_BOOT, PC_JUMP, PC_BRANCH, PC_EXCEPTION, PC_FENCEI, PC_MRET, PC_IRQ);

    -- Exception PC mux selector defines
    constant EXC_PC_EXCEPTION : std_ulogic_vector(2 downto 0) := "000";
    constant EXC_PC_IRQ       : std_ulogic_vector(2 downto 0) := "001";

    -- Exception Cause
    constant EXC_CAUSE_INSTR_FAULT  : std_ulogic_vector(4 downto 0) := "00001";
    constant EXC_CAUSE_ILLEGAL_INSN : std_ulogic_vector(4 downto 0) := "00010";
    constant EXC_CAUSE_LOAD_FAULT   : std_ulogic_vector(4 downto 0) := "00101";
    constant EXC_CAUSE_STORE_FAULT  : std_ulogic_vector(4 downto 0) := "00111";
    constant EXC_CAUSE_ECALL_MMODE  : std_ulogic_vector(4 downto 0) := "01011";

    -- Interrupt mask
    constant IRQ_MASK : std_ulogic_vector(31 downto 0) := x"FFFF0888";

    ------------------------------------------------
    -- Pipeline Records
    ------------------------------------------------
    -- from pipeline stage, data can be forwarded using this record type
    type fwd_t is record
        waddr   : std_ulogic_vector(04 downto 0);
        wen     : std_ulogic;
        valid   : std_ulogic;
        is_alu  : std_ulogic;
        is_mul  : std_ulogic;
        is_load : std_ulogic;
        wdata   : std_ulogic_vector(31 downto 0);
    end record;
    type fwd_bundle_t is array (natural range <>) of fwd_t;

    type ex_pipeline_t is record        -- valid in ex stage (input comes from pipeline register)
        -- CSR access
        ex_csr_access      : std_ulogic;
        ex_csr_rdata       : std_ulogic_vector(31 downto 0);
        -- Input from ID (RF or Imm + Mux Sel Signal)
        operand_a_data_reg : std_ulogic_vector(31 downto 0); -- regfile
        operand_b_data_reg : std_ulogic_vector(31 downto 0); -- regfile
        operand_a_data_pre : std_ulogic_vector(31 downto 0); -- immediate
        operand_b_data_pre : std_ulogic_vector(31 downto 0); -- immediate
        operand_a_data_mux : op_a_sel_t; -- regfile or immediate mux sel
        operand_b_data_mux : op_b_sel_t; -- regfile or immediate mux sel
        operand_a_fwd_src  : forward_sel_t;
        operand_b_fwd_src  : forward_sel_t;
        -- VPRO needs src1 address to identify immediates of vpro.li
        operand_a_addr     : std_ulogic_vector(4 downto 0); -- immediate
        -- Multiplier
        mult_operator      : mult_operator_t;
        mult_op            : std_ulogic; -- en
        mult_signed_mode   : std_ulogic_vector(1 downto 0);
        -- ALU
        alu_operator       : alu_op_t;
        alu_op             : std_ulogic; -- en
        -- Branch
        branch             : std_ulogic;
        -- LSU signals
        lsu_op             : lsu_op_t;
        lsu_wdata          : std_ulogic_vector(31 downto 0);
        lsu_data_type      : memory_data_type_t;
        lsu_sign_ext       : std_ulogic;
        -- RF access
        rf_waddr           : std_ulogic_vector(04 downto 0);
        rf_wen             : std_ulogic;
    end record;

    type mem_pipeline_t is record       -- valid in mem stage (input comes from pipeline register)
        rf_waddr      : std_ulogic_vector(04 downto 0);
        rf_wen        : std_ulogic;
        alu_wdata     : std_ulogic_vector(31 downto 0);
        mult_wdata    : std_ulogic_vector(31 downto 0); -- valid in +1 stage ?
        mult_op       : std_ulogic;     -- flag if mult data contained
        lsu_op        : lsu_op_t;
        lsu_data_type : memory_data_type_t;
        lsu_sign_ext  : std_ulogic;
        lsu_addr      : std_ulogic_vector(31 downto 0);
        lsu_wdata     : std_ulogic_vector(31 downto 0);
    end record;

    type wb_pipeline_t is record        -- valid in wb stage (input comes from pipeline register)
        rf_waddr            : std_ulogic_vector(04 downto 0);
        rf_wen              : std_ulogic;
        alu_wdata           : std_ulogic_vector(31 downto 0);
        mult_wdata          : std_ulogic_vector(31 downto 0);
        mult_op             : std_ulogic; -- flag if mult data contained
        lsu_request_pending : lsu_op_t;
        lsu_data_type       : memory_data_type_t;
        lsu_sign_ext        : std_ulogic;
    end record;
    ------------------------------------------------
    -- functions / helper
    ------------------------------------------------
    function log2(x : positive) return natural; -- thieu
    function log2_bitwidth(x : positive) return natural;
    function bit_reverse_vector(a : in std_ulogic_vector) return std_ulogic_vector;
    function bit_repeat(N : natural; B : std_ulogic) return std_ulogic_vector;
    function convert_endianess(input : std_ulogic_vector) return std_ulogic_vector; -- thieu
    function convert_wordorder(input : std_ulogic_vector) return std_ulogic_vector; -- thieu

    ---------------- THIEU ---------------------
    -- DCache to VCP DMA command Width
    constant VCP_CMD_WORD_COUNT : natural := 16;
    type multi_cmd_t is array (0 to VCP_CMD_WORD_COUNT - 1) of std_ulogic_vector(31 downto 0); -- of MIPS I word width

    type eisv_debug_o_t is record
        instr_addr : std_ulogic_vector(31 downto 0); -- instr_addr
        instr_dat  : std_ulogic_vector(31 downto 0); -- instr_addr
        instr_req  : std_ulogic;        -- instr_addr
    end record;

    ---------------- THIEU ---------------------

end package eisV_pkg;
package body eisV_pkg is

    function log2_bitwidth(x : positive) return natural is
        variable i : natural;
    begin
        i := 0;
        while (2 ** i < x) and i < 31 loop
            i := i + 1;
        end loop;
        return i;
    end function;                       -- function log2_bitwidth

    function log2(x : positive) return natural is
        variable i : natural;
    begin
        i := 0;
        while (2 ** i < x) and i < 31 loop
            i := i + 1;
        end loop;
        return i;
    end function;                       -- function log2_bitwidth

    function bit_reverse_vector(a : in std_ulogic_vector)
    return std_ulogic_vector is
        variable result : std_ulogic_vector(a'RANGE);
        alias aa        : std_ulogic_vector(a'REVERSE_RANGE) is a;
    begin
        for i in aa'RANGE loop
            result(i) := aa(i);
        end loop;
        return result;
    end function;                       -- function bit_reverse_vector

    function bit_repeat(N : natural; B : std_ulogic)
    return std_ulogic_vector is
        variable result : std_ulogic_vector(1 to N);
    begin
        for i in 1 to N loop
            result(i) := B;
        end loop;
        return result;
    end function;                       -- function bit_repeat

    -- Function: Convert Endianess (Byte order) of std_ulogic_vector------------------------------
    -- required input size has to be divideable by 8! --------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function convert_endianess(input : std_ulogic_vector) return std_ulogic_vector is
        variable output_v  : std_ulogic_vector(input'range);
        variable high_byte : integer;
    begin
        high_byte := input'length / 8 - 1;
        for i in 0 to high_byte loop
            output_v(i * 8 + 7 downto i * 8) := input((high_byte - i) * 8 + 7 downto (high_byte - i) * 8);
        end loop;                       -- i
        return output_v;
    end function convert_endianess;

    -- convert e.g. 128-bit block of 32-bit words to reverse order
    function convert_wordorder(input : std_ulogic_vector) return std_ulogic_vector is
        variable output_v  : std_ulogic_vector(input'range);
        variable high_byte : integer;
    begin
        high_byte := input'length / 32 - 1;
        for i in 0 to high_byte loop
            output_v(i * 32 + 31 downto i * 32) := input((high_byte - i) * 32 + 31 downto (high_byte - i) * 32);
        end loop;                       -- i
        return output_v;
    end function convert_wordorder;
end package body eisV_pkg;
