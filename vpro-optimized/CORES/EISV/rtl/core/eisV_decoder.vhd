--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Decoder                                                    --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_decoder is
    port(
        -- singals running to/from controller
        id_deassert_we_i                  : in  std_ulogic; -- deassert we, we are stalled or not active
        id_instruction_type_o             : out instr_type_t;
        id_rega_used_o                    : out std_ulogic; -- rs1 is used by current instruction
        id_regb_used_o                    : out std_ulogic; -- rs2 is used by current instruction
        -- from IF/ID pipeline
        id_instr_rdata_i                  : in  std_ulogic_vector(31 downto 0); -- instruction read from instr memory/cache
        id_illegal_c_insn_i               : in  std_ulogic; -- compressed instruction decode failed
        -- ALU signals
        id_alu_en_o                       : out std_ulogic; -- ALU enable
        id_alu_operator_o                 : out alu_op_t; --std_ulogic_vector(ALU_OP_WIDTH - 1 downto 0); -- ALU operation selection
        id_alu_op_a_mux_sel_o             : out op_a_sel_t; -- operand a selection: reg value, PC, immediate or zero
        id_alu_op_b_mux_sel_o             : out op_b_sel_t; -- operand b selection: reg value or immediate
        id_imm_a_mux_sel_o                : out op_a_immediate_sel_t; -- immediate selection for operand a
        id_imm_b_mux_sel_o                : out op_b_immediate_sel_t; -- immediate selection for operand b
        -- MUL related control signals
        id_mult_operator_o                : out mult_operator_t; -- Multiplication operation selection
        id_mult_int_en_o                  : out std_ulogic; -- perform integer multiplication
        id_mult_signed_mode_o             : out std_ulogic_vector(1 downto 0); -- Multiplication in signed mode
        -- register file related signals
        id_regfile_mem_we_o               : out std_ulogic; -- write enable for regfile
        id_regfile_alu_we_o               : out std_ulogic; -- write enable for 2nd regfile port
        -- CSR manipulation
        id_csr_access_o                   : out std_ulogic; -- access to CSR
        id_csr_op_o                       : out std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0); -- operation to perform on CSR
        -- LD/ST unit signals
        id_data_req_o                     : out std_ulogic; -- start transaction to data memory
        id_data_we_o                      : out lsu_op_t; -- data memory write enable
        id_data_type_o                    : out memory_data_type_t; --std_ulogic_vector(1 downto 0); -- data type on data memory: byte, half word or word
        id_data_sign_extension_o          : out std_ulogic; -- sign extension on read data from data memory
        -- jump/branches
        id_ctrl_transfer_insn_in_dec_o    : out branch_t; -- control transfer instruction without deassert
        id_ctrl_transfer_insn_in_o        : out branch_t; -- control transfer instructio is decoded
        id_ctrl_transfer_target_mux_sel_o : out jump_target_mux_sel_t; -- jump target selection
        -- vpro custom extension
        id_vpro_op_o                      : out vpro_op_t
    );
end entity eisV_decoder;

architecture RTL of eisV_decoder is

    -- write enable/request control
    signal id_regfile_mem_we     : std_ulogic;
    signal id_regfile_alu_we     : std_ulogic;
    signal id_data_req           : std_ulogic;
    signal id_csr_illegal        : std_ulogic;
    signal id_ctrl_transfer_insn : branch_t;

    signal id_csr_op : std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0);

    signal id_alu_en      : std_ulogic;
    signal id_mult_int_en : std_ulogic;

    signal id_illegal_insn_int : std_ulogic; -- illegal instruction encountered
    signal id_mret_insn_int    : std_ulogic; -- return from exception instruction encountered (M)
    signal id_ecall_insn_int   : std_ulogic; -- environment call (syscall) instruction encountered
    signal id_wfi_insn_int     : std_ulogic; -- pipeline flush is requested
    signal id_fencei_insn_int  : std_ulogic; -- fence.i instruction
    signal id_csr_status_int   : std_ulogic; -- access to xstatus CSR
    signal id_load_insn_int    : std_ulogic;

begin

    ---------------------------------------------
    -- Decoder
    ---------------------------------------------

    process(id_csr_illegal, id_csr_op, id_illegal_c_insn_i, id_instr_rdata_i)
        variable id1_alu_op_v : std_ulogic_vector(8 downto 0);
    begin
        id_ctrl_transfer_insn             <= BRANCH_NONE;
        id_ctrl_transfer_target_mux_sel_o <= JT_JAL;

        id_alu_en             <= '0';
        id_alu_operator_o     <= ALU_SLTU;
        id_alu_op_a_mux_sel_o <= OP_A_REGA;
        id_alu_op_b_mux_sel_o <= OP_B_REGB;
        id_imm_a_mux_sel_o    <= IMMA_ZERO;
        id_imm_b_mux_sel_o    <= IMMB_I;

        id_mult_operator_o    <= MUL_L;
        id_mult_int_en        <= '0';
        id_mult_signed_mode_o <= "00";

        id_regfile_mem_we <= '0';
        id_regfile_alu_we <= '0';

        id_csr_access_o   <= '0';
        id_csr_status_int <= '0';
        id_csr_illegal    <= '0';
        id_csr_op         <= CSR_OP_READ;
        id_mret_insn_int  <= '0';
        id_load_insn_int  <= '0';

        id_data_we_o             <= LSU_NONE;
        id_data_type_o           <= WORD;
        id_data_sign_extension_o <= '0';
        id_data_req              <= '0';

        id_illegal_insn_int <= '0';
        id_ecall_insn_int   <= '0';
        id_wfi_insn_int     <= '0';

        id_fencei_insn_int <= '0';

        id_rega_used_o <= '0';
        id_regb_used_o <= '0';

        id_vpro_op_o <= NONE;

        case (id_instr_rdata_i(6 downto 0)) is

            --------------------------------------
            -- Custom Instruction Extensions
            --------------------------------------
            -- coverage off 
            when OPCODE_CUSTOM_0 =>
                if VPRO_CUSTOM_EXTENSION then
                    id_imm_b_mux_sel_o    <= IMMB_U; -- 20-bit immediate
                    id_alu_op_b_mux_sel_o <= OP_B_IMM;
                    id_alu_op_a_mux_sel_o <= OP_A_REGA;
                    id_rega_used_o        <= '1';
                    id_vpro_op_o          <= VPRO_LI;
                -- vpro.li <src1_reg/imm>, imm_li
                --    imm_li: (all are [already] shifted << by 1)
                --        '19 downto '17: increment values [7 downto 5]
                --        '16: is_increment
                --        '15 downto '13: VPRO RF index
                --        '12 downto '1: parameter mask
                --        '0: trigger
                --    src1_reg/imm: / this is rd (mapped to src1 in id_stage)
                --        '4 downto '0: increment values [4 downto 0]
                else                    -- @suppress "Dead code"
                    id_illegal_insn_int <= '1';
                end if;
            when OPCODE_CUSTOM_1 =>
                if VPRO_CUSTOM_EXTENSION then
                    case (id_instr_rdata_i(14 downto 12)) is
                        when "001" =>
                            id_rega_used_o     <= '1';
                            id_regb_used_o     <= '1';
                            id_imm_b_mux_sel_o <= IMMB_S;
                            id_vpro_op_o       <= VPRO_LW;
                        -- vpro.lw <src1_reg>, <src2_reg>, imm_lw
                        --    imm_lw:
                        --        '11 downto '9: VPRO RF index
                        --        '8 downto '5: src2 index
                        --        '4 downto '1: src2 index
                        --        '0: trigger 

                        when "010" =>
                            id_rega_used_o     <= '1';
                            id_regb_used_o     <= '1';
                            id_imm_b_mux_sel_o <= IMMB_S;
                            id_vpro_op_o       <= DMA_LW;
                        -- vpro.dma.lw <src1_reg>, <src2_reg>, imm_lw
                        --    imm_lw:
                        --        '11 downto '9: DMA RF index
                        --        '8 downto '5: src2 index
                        --        '4 downto '1: src2 index
                        --        '0: trigger 

                        when others =>
                            id_illegal_insn_int <= '1';
                    end case;
                else                    -- @suppress "Dead code"
                    id_illegal_insn_int <= '1';
                end if;
            -- coverage on 

            --------------------------------------
            -- Jumps
            --------------------------------------
            when OPCODE_JAL =>          -- Jump and Link
                id_ctrl_transfer_target_mux_sel_o <= JT_JAL;
                id_ctrl_transfer_insn             <= BRANCH_JAL;
                -- Calculate and store PC+4
                id_alu_op_a_mux_sel_o             <= OP_A_CURRPC;
                id_alu_op_b_mux_sel_o             <= OP_B_IMM;
                id_imm_b_mux_sel_o                <= IMMB_PCINCR;
                id_alu_operator_o                 <= ALU_ADD;
                id_alu_en                         <= '1';
                id_regfile_alu_we                 <= '1';
            -- Calculate jump target (<= PC + UJ imm)
            when OPCODE_JALR =>         -- Jump and Link Register
                id_ctrl_transfer_target_mux_sel_o <= JT_JALR;
                id_ctrl_transfer_insn             <= BRANCH_JALR;
                -- Calculate and store PC+4
                id_alu_op_a_mux_sel_o             <= OP_A_CURRPC;
                id_alu_op_b_mux_sel_o             <= OP_B_IMM;
                id_imm_b_mux_sel_o                <= IMMB_PCINCR;
                id_alu_operator_o                 <= ALU_ADD;
                id_alu_en                         <= '1';
                id_regfile_alu_we                 <= '1';
                -- Calculate jump target (<= RS1 + I imm)
                id_rega_used_o                    <= '1';

                -- coverage off
                if (id_instr_rdata_i(14 downto 12) /= "000") then
                    id_ctrl_transfer_insn <= BRANCH_NONE;
                    id_regfile_alu_we     <= '0';
                    id_illegal_insn_int   <= '1';
                end if;
            -- coverage on

            when OPCODE_BRANCH =>       -- Branch
                id_ctrl_transfer_target_mux_sel_o <= JT_COND;
                id_ctrl_transfer_insn             <= BRANCH_COND;
                id_rega_used_o                    <= '1';
                id_regb_used_o                    <= '1';

                id_alu_en <= '1';
                case (id_instr_rdata_i(14 downto 12)) is
                    when "000" => id_alu_operator_o <= ALU_EQ;
                    when "001" => id_alu_operator_o <= ALU_NE;
                    when "100" => id_alu_operator_o <= ALU_LTS;
                    when "101" => id_alu_operator_o <= ALU_GES;
                    when "110" => id_alu_operator_o <= ALU_LTU;
                    when "111" => id_alu_operator_o <= ALU_GEU;
                    -- coverage off 
                    when others =>
                        id_alu_en           <= '0';
                        id_illegal_insn_int <= '1';
                        -- coverage on 
                end case;

            ----------------------------------
            -- Load Store
            ----------------------------------
            when OPCODE_STORE =>
                if (id_instr_rdata_i(6 downto 0) = OPCODE_STORE) then
                    id_data_req       <= '1';
                    id_data_we_o      <= LSU_STORE;
                    id_rega_used_o    <= '1';
                    id_regb_used_o    <= '1';
                    id_alu_operator_o <= ALU_ADD;
                    id_alu_en         <= '1';

                    if (id_instr_rdata_i(14) = '0') then
                        -- offset from immediate
                        id_imm_b_mux_sel_o    <= IMMB_S;
                        id_alu_op_b_mux_sel_o <= OP_B_IMM;
                    -- coverage off 
                    else
                        id_illegal_insn_int <= '1';
                        -- coverage on 
                    end if;

                    -- store size
                    case (id_instr_rdata_i(13 downto 12)) is
                        when "00" => id_data_type_o <= BYTE; --"10"; -- SB -- TODO: use encoding from instr_rdata_i
                        when "01" => id_data_type_o <= HALFWORD; --"01"; -- SH
                        when "10" => id_data_type_o <= WORD; --"00"; -- SW
                        -- coverage off 
                        when others =>
                            id_data_req         <= '0';
                            id_data_we_o        <= LSU_LOAD;
                            id_illegal_insn_int <= '1';
                            -- coverage on 
                    end case;
                -- coverage off
                else
                    id_illegal_insn_int <= '1';
                    -- coverage on
                end if;

            when OPCODE_LOAD =>
                if (id_instr_rdata_i(6 downto 0) = OPCODE_LOAD) then
                    id_data_we_o          <= LSU_LOAD;
                    id_load_insn_int      <= '1';
                    id_data_req           <= '1';
                    id_regfile_mem_we     <= '1';
                    id_rega_used_o        <= '1';
                    id_data_type_o        <= WORD; --"00";
                    -- offset from immediate
                    id_alu_operator_o     <= ALU_ADD;
                    id_alu_en             <= '1';
                    id_alu_op_b_mux_sel_o <= OP_B_IMM;
                    id_imm_b_mux_sel_o    <= IMMB_I;

                    -- sign/zero extension
                    id_data_sign_extension_o <= not id_instr_rdata_i(14);

                    -- load size
                    case (id_instr_rdata_i(13 downto 12)) is
                        when "00"   => id_data_type_o <= BYTE; -- -- LB -- TODO: use encoding from instr_rdata_i
                        when "01"   => id_data_type_o <= HALFWORD; -- -- LH
                        when "10"   => id_data_type_o <= WORD; ---- LW
                        -- coverage off 
                        when others => id_data_type_o <= WORD; -- -- illegal or reg-reg
                            -- coverage on 
                    end case;

                    -- coverage off 
                    -- reg-reg load (different encoding)
                    if (id_instr_rdata_i(14 downto 12) = "111") then
                        id_illegal_insn_int <= '1';
                    end if;
                    if (id_instr_rdata_i(14 downto 12) = "110") then
                        id_illegal_insn_int <= '1';
                    end if;
                    if (id_instr_rdata_i(14 downto 12) = "011") then
                        -- LD -> RV64 only
                        id_illegal_insn_int <= '1';
                    end if;
                else
                    id_illegal_insn_int <= '1';
                    -- coverage on 
                end if;

            -- coverage off 
            when OPCODE_AMO =>
                -- no atomic
                id_illegal_insn_int <= '1';
            -- coverage on 

            --------------------------
            -- ALU
            --------------------------
            when OPCODE_LUI =>          -- Load Upper Immediate
                id_alu_op_a_mux_sel_o <= OP_A_IMM;
                id_alu_op_b_mux_sel_o <= OP_B_IMM;
                id_imm_a_mux_sel_o    <= IMMA_ZERO;
                id_imm_b_mux_sel_o    <= IMMB_U;
                id_alu_operator_o     <= ALU_ADD;
                id_alu_en             <= '1';
                id_regfile_alu_we     <= '1';

            when OPCODE_AUIPC =>        -- Add Upper Immediate to PC
                id_alu_op_a_mux_sel_o <= OP_A_CURRPC;
                id_alu_op_b_mux_sel_o <= OP_B_IMM;
                id_imm_b_mux_sel_o    <= IMMB_U;
                id_alu_operator_o     <= ALU_ADD;
                id_alu_en             <= '1';
                id_regfile_alu_we     <= '1';

            when OPCODE_OPIMM =>        -- Register-Immediate ALU Operations
                id_alu_op_b_mux_sel_o <= OP_B_IMM;
                id_imm_b_mux_sel_o    <= IMMB_I;
                id_regfile_alu_we     <= '1';
                id_rega_used_o        <= '1';

                case (id_instr_rdata_i(14 downto 12)) is
                    when "000" =>
                        id_alu_en         <= '1';
                        id_alu_operator_o <= ALU_ADD; -- Add Immediate       -- TODO: use encoding from instr_rdata_i
                    when "010" =>
                        id_alu_en         <= '1';
                        id_alu_operator_o <= ALU_SLTS; -- Set to one if Lower Than Immediate
                    when "011" =>
                        id_alu_en         <= '1';
                        id_alu_operator_o <= ALU_SLTU; -- Set to one if Lower Than Immediate Unsigned
                    when "100" =>
                        id_alu_en         <= '1';
                        id_alu_operator_o <= ALU_XOR; -- Exclusive Or with Immediate
                    when "110" =>
                        id_alu_en         <= '1';
                        id_alu_operator_o <= ALU_OR; -- Or with Immediate
                    when "111" =>
                        id_alu_en         <= '1';
                        id_alu_operator_o <= ALU_AND; -- And with Immediate

                    when "001" =>
                        id_alu_en         <= '1';
                        id_alu_operator_o <= ALU_SLL; -- Shift Left Logical by Immediate
                        -- coverage off
                        if (id_instr_rdata_i(31 downto 25) /= "0000000") then
                            id_illegal_insn_int <= '1';
                        end if;
                    -- coverage on

                    when "101" =>
                        if (id_instr_rdata_i(31 downto 25) = "0000000") then
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SRL; -- Shift Right Logical by Immediate
                        elsif (id_instr_rdata_i(31 downto 25) = "0100000") then
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SRA; -- Shift Right Arithmetically by Immediate
                        -- coverage off 
                        else
                            id_illegal_insn_int <= '1';
                        end if;
                    when others =>
                        id_illegal_insn_int <= '1';
                        -- coverage on 
                end case;

            when OPCODE_OP =>           -- Register-Register ALU operation
                -- coverage off 
                -- PREFIX 11
                if (id_instr_rdata_i(31 downto 30) = "11") then
                    id_illegal_insn_int <= '1';
                elsif (id_instr_rdata_i(31 downto 30) = "10") and (id_instr_rdata_i(29 downto 25) = "00000") then -- PREFIX 10 and REGISTER BIT-MANIPULATION
                    id_illegal_insn_int <= '1';
                else                    -- PREFIX 00/01
                    -- coverage on 
                    -- non bit-manipulation instructions
                    id_regfile_alu_we <= '1';
                    id_rega_used_o    <= '1';
                    id_regb_used_o    <= '1';

                    id1_alu_op_v := id_instr_rdata_i(30 downto 25) & id_instr_rdata_i(14 downto 12);
                    case (id1_alu_op_v) is
                        -- RV32I ALU operations
                        when "000000000" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_ADD; -- Add   -- TODO: use encoding from instr_rdata_i
                        when "100000000" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SUB; -- Sub
                        when "000000010" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SLTS; -- Set Lower Than
                        when "000000011" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SLTU; -- Set Lower Than Unsigned
                        when "000000100" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_XOR; -- Xor
                        when "000000110" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_OR; -- Or
                        when "000000111" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_AND; -- And
                        when "000000001" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SLL; -- Shift Left Logical
                        when "000000101" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SRL; -- Shift Right Logical
                        when "100000101" =>
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_SRA; -- Shift Right Arithmetic
                        when "000001000" => -- mul
                            id_alu_en          <= '0';
                            id_mult_int_en     <= '1';
                            id_mult_operator_o <= MUL_L;
                        when "000001001" => -- mulh
                            id_alu_en             <= '0';
                            id_mult_signed_mode_o <= "11";
                            id_mult_int_en        <= '1';
                            id_mult_operator_o    <= MUL_H;
                        when "000001010" => -- mulhsu
                            id_alu_en             <= '0';
                            id_mult_signed_mode_o <= "01";
                            id_mult_int_en        <= '1';
                            id_mult_operator_o    <= MUL_H;
                        when "000001011" => -- mulhu
                            id_alu_en             <= '0';
                            id_mult_signed_mode_o <= "00";
                            id_mult_int_en        <= '1';
                            id_mult_operator_o    <= MUL_H;
                        when "000001100" => -- div
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_DIV;
                        when "000001101" => -- divu
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_DIVU;
                        when "000001110" => -- rem
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_REM;
                        when "000001111" => -- remu
                            id_alu_en         <= '1';
                            id_alu_operator_o <= ALU_REMU;

                        -- coverage off
                        when others =>
                            id_illegal_insn_int <= '1';
                            -- coverage on
                    end case;
                end if;

            ------------------------------------------------
            -- Special OPs
            ------------------------------------------------
            when OPCODE_FENCE =>
                case (id_instr_rdata_i(14 downto 13)) is
                    when "00" =>        -- FENCE: flush pipeline
                        id_fencei_insn_int <= '1';
                    -- (12) = '0' => FENCE (FENCE.I instead, a bit more conservative)
                    -- (12) = '1' => FENCE.I

                    -- coverage off 
                    when others =>
                        id_illegal_insn_int <= '1';
                        -- coverage on 
                end case;

            when OPCODE_SYSTEM =>
                if (id_instr_rdata_i(14 downto 12) = "000") then
                    -- non CSR related SYSTEM instructions
                    -- coverage off
                    if (unsigned(id_instr_rdata_i(19 downto 15)) = 0 and unsigned(id_instr_rdata_i(11 downto 7)) = 0) then
                        -- coverage on
                        case (id_instr_rdata_i(31 downto 20)) is
                            when x"302" => -- mret
                                id_mret_insn_int <= '1';
                            -- coverage off 
                            when x"000" => -- ECALL
                                -- environment (system) call
                                id_ecall_insn_int <= '1';
                            when x"105" => -- wfi
                                id_wfi_insn_int <= '1';
                            --                            when x"001" => -- ebreak, debugger trap
                            --                            when x"002" => -- uret
                            --                            when x"7b2" => -- dret
                            when others =>
                                id_illegal_insn_int <= '1';
                                -- coverage on 
                        end case;
                    -- coverage off
                    else
                        id_illegal_insn_int <= '1';
                    end if;
                else
                    -- instruction to read/modify CSR
                    id_csr_access_o       <= '1';
                    id_regfile_alu_we     <= '1';
                    id_alu_op_b_mux_sel_o <= OP_B_IMM;
                    id_imm_a_mux_sel_o    <= IMMA_Z;
                    id_imm_b_mux_sel_o    <= IMMB_I; -- CSR address is encoded in I imm

                    if (id_instr_rdata_i(14) = '1') then
                        -- rs1 field is used as immediate
                        id_alu_op_a_mux_sel_o <= OP_A_IMM;
                    else
                        id_rega_used_o        <= '1';
                        id_alu_op_a_mux_sel_o <= OP_A_REGA;
                    end if;

                    -- instr_rdata_i(19 downto 14) = rs or immediate value
                    --   if set or clear with rs=x0 or imm=0,
                    --   then do not perform a write action
                    case (id_instr_rdata_i(13 downto 12)) is
                        when "01" => id_csr_op <= CSR_OP_WRITE;
                        when "10" =>
                            if unsigned(id_instr_rdata_i(19 downto 15)) = 0 then
                                id_csr_op <= CSR_OP_READ;
                            else
                                id_csr_op <= CSR_OP_SET;
                            end if;
                        when "11" =>
                            if (unsigned(id_instr_rdata_i(19 downto 15)) = 0) then
                                id_csr_op <= CSR_OP_READ;
                            else
                                id_csr_op <= CSR_OP_CLEAR;
                            end if;
                        when others => id_csr_illegal <= '1';
                    end case;

                    if (unsigned(id_instr_rdata_i(29 downto 28)) > 3) then -- unsigned(id_csr_current_priv_lvl_i)
                        -- No access to higher privilege CSR
                        id_csr_illegal <= '1';
                    end if;
                    -- Determine if CSR access is illegal
                    case (id_instr_rdata_i(31 downto 20)) is
                        --  Writes to read only CSRs results in illegal instruction
                        when CSR_MVENDORID|  CSR_MARCHID| CSR_MIMPID|  CSR_MHARTID =>
                            if (id_csr_op /= CSR_OP_READ) then
                                id_csr_illegal <= '1';
                            end if;

                        -- These are valid CSR registers
                        when CSR_MSTATUS|   CSR_MEPC|  CSR_MTVEC|  CSR_MCAUSE =>
                            -- Not illegal| but treat as status CSR for side effect handling
                            id_csr_status_int <= '1';

                        -- These are valid CSR registers
                        when CSR_MISA|    CSR_MIE| CSR_MSCRATCH|  CSR_MTVAL|   CSR_MIP =>
                            -- do nothing| not illegal

                            -- Hardware Performance Monitor
                        when CSR_MCYCLE|
              CSR_MINSTRET|
              CSR_MHPMCOUNTER3|
              CSR_MHPMCOUNTER4|  CSR_MHPMCOUNTER5|  CSR_MHPMCOUNTER6|  CSR_MHPMCOUNTER7|
              CSR_MHPMCOUNTER8|  CSR_MHPMCOUNTER9|  CSR_MHPMCOUNTER10| CSR_MHPMCOUNTER11|
              CSR_MHPMCOUNTER12| CSR_MHPMCOUNTER13| CSR_MHPMCOUNTER14| CSR_MHPMCOUNTER15|
              CSR_MHPMCOUNTER16| CSR_MHPMCOUNTER17| CSR_MHPMCOUNTER18| CSR_MHPMCOUNTER19|
              CSR_MHPMCOUNTER20| CSR_MHPMCOUNTER21| CSR_MHPMCOUNTER22| CSR_MHPMCOUNTER23|
              CSR_MHPMCOUNTER24| CSR_MHPMCOUNTER25| CSR_MHPMCOUNTER26| CSR_MHPMCOUNTER27|
              CSR_MHPMCOUNTER28| CSR_MHPMCOUNTER29| CSR_MHPMCOUNTER30| CSR_MHPMCOUNTER31|
              CSR_MCYCLEH|
              CSR_MINSTRETH|
              CSR_MHPMCOUNTER3H|
              CSR_MHPMCOUNTER4H|  CSR_MHPMCOUNTER5H|  CSR_MHPMCOUNTER6H|  CSR_MHPMCOUNTER7H|
              CSR_MHPMCOUNTER8H|  CSR_MHPMCOUNTER9H|  CSR_MHPMCOUNTER10H| CSR_MHPMCOUNTER11H|
              CSR_MHPMCOUNTER12H| CSR_MHPMCOUNTER13H| CSR_MHPMCOUNTER14H| CSR_MHPMCOUNTER15H|
              CSR_MHPMCOUNTER16H| CSR_MHPMCOUNTER17H| CSR_MHPMCOUNTER18H| CSR_MHPMCOUNTER19H|
              CSR_MHPMCOUNTER20H| CSR_MHPMCOUNTER21H| CSR_MHPMCOUNTER22H| CSR_MHPMCOUNTER23H|
              CSR_MHPMCOUNTER24H| CSR_MHPMCOUNTER25H| CSR_MHPMCOUNTER26H| CSR_MHPMCOUNTER27H|
              CSR_MHPMCOUNTER28H| CSR_MHPMCOUNTER29H| CSR_MHPMCOUNTER30H| CSR_MHPMCOUNTER31H|
              CSR_MCOUNTINHIBIT|
              CSR_MHPMEVENT3|
              CSR_MHPMEVENT4|  CSR_MHPMEVENT5|  CSR_MHPMEVENT6|  CSR_MHPMEVENT7|
              CSR_MHPMEVENT8|  CSR_MHPMEVENT9|  CSR_MHPMEVENT10| CSR_MHPMEVENT11|
              CSR_MHPMEVENT12| CSR_MHPMEVENT13| CSR_MHPMEVENT14| CSR_MHPMEVENT15|
              CSR_MHPMEVENT16| CSR_MHPMEVENT17| CSR_MHPMEVENT18| CSR_MHPMEVENT19|
              CSR_MHPMEVENT20| CSR_MHPMEVENT21| CSR_MHPMEVENT22| CSR_MHPMEVENT23|
              CSR_MHPMEVENT24| CSR_MHPMEVENT25| CSR_MHPMEVENT26| CSR_MHPMEVENT27|
              CSR_MHPMEVENT28| CSR_MHPMEVENT29| CSR_MHPMEVENT30| CSR_MHPMEVENT31 =>
                            -- Not illegal| but treat as status CSR to get accurate counts
                            id_csr_status_int <= '1';

                        -- Hardware Performance Monitor (unprivileged read-only mirror CSRs)
                        when CSR_CYCLE|
              CSR_INSTRET|
              CSR_HPMCOUNTER3|
              CSR_HPMCOUNTER4|  CSR_HPMCOUNTER5|  CSR_HPMCOUNTER6|  CSR_HPMCOUNTER7|
              CSR_HPMCOUNTER8|  CSR_HPMCOUNTER9|  CSR_HPMCOUNTER10| CSR_HPMCOUNTER11|
              CSR_HPMCOUNTER12| CSR_HPMCOUNTER13| CSR_HPMCOUNTER14| CSR_HPMCOUNTER15|
              CSR_HPMCOUNTER16| CSR_HPMCOUNTER17| CSR_HPMCOUNTER18| CSR_HPMCOUNTER19|
              CSR_HPMCOUNTER20| CSR_HPMCOUNTER21| CSR_HPMCOUNTER22| CSR_HPMCOUNTER23|
              CSR_HPMCOUNTER24| CSR_HPMCOUNTER25| CSR_HPMCOUNTER26| CSR_HPMCOUNTER27|
              CSR_HPMCOUNTER28| CSR_HPMCOUNTER29| CSR_HPMCOUNTER30| CSR_HPMCOUNTER31|
              CSR_CYCLEH|
              CSR_INSTRETH|
              CSR_HPMCOUNTER3H|
              CSR_HPMCOUNTER4H|  CSR_HPMCOUNTER5H|  CSR_HPMCOUNTER6H|  CSR_HPMCOUNTER7H|
              CSR_HPMCOUNTER8H|  CSR_HPMCOUNTER9H|  CSR_HPMCOUNTER10H| CSR_HPMCOUNTER11H|
              CSR_HPMCOUNTER12H| CSR_HPMCOUNTER13H| CSR_HPMCOUNTER14H| CSR_HPMCOUNTER15H|
              CSR_HPMCOUNTER16H| CSR_HPMCOUNTER17H| CSR_HPMCOUNTER18H| CSR_HPMCOUNTER19H|
              CSR_HPMCOUNTER20H| CSR_HPMCOUNTER21H| CSR_HPMCOUNTER22H| CSR_HPMCOUNTER23H|
              CSR_HPMCOUNTER24H| CSR_HPMCOUNTER25H| CSR_HPMCOUNTER26H| CSR_HPMCOUNTER27H|
              CSR_HPMCOUNTER28H| CSR_HPMCOUNTER29H| CSR_HPMCOUNTER30H| CSR_HPMCOUNTER31H =>
                            -- Read-only and readable from user mode only if the bit of mcounteren is set
                            if (id_csr_op /= CSR_OP_READ) then
                                id_csr_illegal <= '1';
                            else
                                id_csr_status_int <= '1';
                            end if;     -- This register only exists in user mode
                        when CSR_MCOUNTEREN =>
                            id_csr_illegal <= '1';

                        -- UHARTID access  (non ISA -> Ext)
                        when CSR_UHARTID =>

                        when others => id_csr_illegal <= '1';

                    end case;           -- case (instr_rdata_i(31 downto 20))
                    id_illegal_insn_int <= id_csr_illegal;
                end if;

            when others =>
                id_illegal_insn_int <= '1';
        end case;

        -- make sure invalid compressed instruction causes an exception
        if (id_illegal_c_insn_i = '1') then
            id_illegal_insn_int <= '1';
        end if;
        -- coverage on
    end process;

    -- deassert we signals (in case of stalls)
    process(id_alu_en, id_csr_op, id_ctrl_transfer_insn, id_data_req, id_deassert_we_i, id_mult_int_en, id_regfile_alu_we, id_regfile_mem_we)
    begin
        if (id_deassert_we_i = '1') then
            id_alu_en_o                <= '0';
            id_mult_int_en_o           <= '0';
            id_regfile_mem_we_o        <= '0';
            id_regfile_alu_we_o        <= '0';
            id_data_req_o              <= '0';
            id_csr_op_o                <= CSR_OP_READ;
            id_ctrl_transfer_insn_in_o <= BRANCH_NONE;
        else
            id_alu_en_o                <= id_alu_en;
            id_mult_int_en_o           <= id_mult_int_en;
            id_regfile_mem_we_o        <= id_regfile_mem_we;
            id_regfile_alu_we_o        <= id_regfile_alu_we;
            id_data_req_o              <= id_data_req;
            id_csr_op_o                <= id_csr_op;
            id_ctrl_transfer_insn_in_o <= id_ctrl_transfer_insn;
        end if;
    end process;

    id_ctrl_transfer_insn_in_dec_o <= id_ctrl_transfer_insn;

    id_instruction_type_o <=            --
                             -- coverage off
                             WFI when (id_wfi_insn_int = '1') else
                             -- coverage on
                             FENCEI when (id_fencei_insn_int = '1') else
                             -- coverage off
                             ILLEGAL when (id_illegal_insn_int = '1') else
                             -- coverage on
                             MRET when (id_mret_insn_int = '1') else
                             CSR when (id_csr_status_int = '1') else
                             -- coverage off
                             ECALL when (id_ecall_insn_int = '1') else
                             -- coverage on
                             BRANCH when (id_ctrl_transfer_insn = BRANCH_JALR or id_ctrl_transfer_insn = BRANCH_JAL) else
                             LOAD when (id_load_insn_int = '1') else
                             NORMAL;

end architecture RTL;
