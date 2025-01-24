--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Decode stage of the core. It decodes the instructions      --
--                 and hosts the register file.                               --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_id_stage is
    port(
        clk_i                            : in  std_ulogic; -- Gated clock
        rst_ni                           : in  std_ulogic;
        -- Processor Enable
        fetch_enable_i                   : in  std_ulogic; -- Delayed version so that clock can remain gated until fetch enabled
        wake_from_sleep_o                : out std_ulogic;
        -- Interrupt signals
        irq_i                            : in  std_ulogic_vector(31 downto 0);
        mie_bypass_i                     : in  std_ulogic_vector(31 downto 0); -- MIE CSR (bypass)
        mip_o                            : out std_ulogic_vector(31 downto 0); -- MIP CSR
        m_irq_enable_i                   : in  std_ulogic;
        irq_ack_o                        : out std_ulogic;
        irq_id_o                         : out std_ulogic_vector(4 downto 0);
        exc_cause_o                      : out std_ulogic_vector(4 downto 0);
        -- Status
        ctrl_busy_o                      : out std_ulogic;
        id_is_decoding_o                 : out std_ulogic;
        -- IF Interface
        if_instr_req_o                   : out std_ulogic;
        id_instr_valid_i                 : in  std_ulogic;
        id_instr_i                       : in  std_ulogic_vector(31 downto 0);
        id_is_compressed_instr_i         : in  std_ulogic;
        id_illegal_compressed_instr_i    : in  std_ulogic;
        if_pc_i                          : in  std_ulogic_vector(31 downto 0); -- @suppress "Unused port: if_pc_i is not used in eisv.eisV_id_stage(RTL)"
        id_pc_i                          : in  std_ulogic_vector(31 downto 0);
        pc_set_o                         : out std_ulogic;
        pc_mux_o                         : out pc_mux_sel_t;
        id_jump_target_o                 : out std_ulogic_vector(31 downto 0); -- jump and branch targets
        ex_jump_target_o                 : out std_ulogic_vector(31 downto 0);
        -- WB Data to RF and used for FW
        wb_regfile_waddr_i               : in  std_ulogic_vector(4 downto 0);
        wb_regfile_we_i                  : in  std_ulogic;
        wb_regfile_wdata_i               : in  std_ulogic_vector(31 downto 0);
        -- Stalls
        id_ready_o                       : out std_ulogic; -- ID stage is ready for the next instruction
        ex_ready_i                       : in  std_ulogic; -- EX stage is ready for the next instruction
        ex_valid_i                       : in  std_ulogic; -- EX stage is done
        -- Forwared Control 
        ex_fwd_i                         : in  fwd_t;
        mem_fwd_i                        : in  fwd_bundle_t(MEM_DELAY - 1 downto 0);
        wb_fwd_i                         : in  fwd_t;
        wb_ready_i                       : in  std_ulogic;
        -- From the Pipeline ID/EX
        ex_pipeline_o                    : out ex_pipeline_t;
        ex_vpro_op_o                     : out vpro_op_t;
        -- from ALU
        ex_branch_decision_i             : in  std_ulogic;
        ex_multicycle_i                  : in  std_ulogic;
        ex_regfile_data_a_after_fwd_i    : in  std_ulogic_vector(31 downto 0);
        -- CSR ID/EX
        ex_csr_access_o                  : out std_ulogic;
        ex_csr_op_o                      : out std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0);
        csr_cause_o                      : out std_ulogic_vector(5 downto 0);
        csr_save_if_o                    : out std_ulogic; -- control signal to save pc
        csr_save_id_o                    : out std_ulogic;
        csr_save_ex_o                    : out std_ulogic;
        csr_restore_mret_id_o            : out std_ulogic; -- control signal to restore pc
        csr_save_cause_o                 : out std_ulogic;
        ex_pc_o                          : out std_ulogic_vector(31 downto 0);
        -- Performance Counters
        id_mhpmevent_minstret_ff_o       : out std_ulogic;
        id_mhpmevent_load_ff_o           : out std_ulogic;
        id_mhpmevent_store_ff_o          : out std_ulogic;
        id_mhpmevent_jump_ff_o           : out std_ulogic;
        id_mhpmevent_branch_o            : out std_ulogic;
        id_mhpmevent_branch_taken_ff_o   : out std_ulogic;
        id_mhpmevent_compressed_ff_o     : out std_ulogic;
        id_mhpmevent_jr_stall_ff_o       : out std_ulogic;
        id_mhpmevent_imiss_ff_o          : out std_ulogic;
        id_mhpmevent_ld_stall_ff_o       : out std_ulogic;
        id_mhpmevent_mul_stall_ff_o      : out std_ulogic;
        id_mhpmevent_dmiss_ff_o          : out std_ulogic;
        id_mhpmevent_csr_instr_ff_o      : out std_ulogic;
        id_mhpmevent_div_multicycle_ff_o : out std_ulogic;
        id_perf_imiss_i                  : in  std_ulogic;
        id_perf_dmiss_i                  : in  std_ulogic
    );
end entity eisV_id_stage;

architecture RTL of eisV_id_stage is

    -- Source/Destination register instruction index
    constant REG_S1_MSB : natural := 19;
    constant REG_S1_LSB : natural := 15;

    constant REG_S2_MSB : natural := 24;
    constant REG_S2_LSB : natural := 20;

    constant REG_D_MSB : natural := 11;
    constant REG_D_LSB : natural := 7;

    --
    -- ID Stage
    --
    -- Decoder/Controller ID stage internal signals
    signal id_deassert_we                        : std_ulogic;
    signal id_ctrl_transfer_insn_in_id           : branch_t;
    signal id_ctrl_transfer_insn_in_dec          : branch_t;
    signal id_control_ready                      : std_ulogic;
    signal id_valid_int                          : std_ulogic;
    signal id_is_decoding_int                    : std_ulogic;
    signal id_mul_hazard                         : std_ulogic;
    signal id_ready_int                          : std_ulogic;
    signal id_mhpmevent_branch_ff                : std_ulogic;
    signal id_opa_fw_sel, id_opb_fw_sel          : forward_sel_t;
    signal id_jt_hazard                          : std_ulogic;
    signal id_load_hazard                        : std_logic;
    signal id_instruction_type                   : instr_type_t;
    signal id_instr_valid_ff, id_instr_valid_int : std_ulogic;

    -- stalls
    signal id_jr_stall   : std_ulogic;
    signal id_load_stall : std_ulogic;
    signal id_mul_stall  : std_ulogic;

    -- Immediate decoding and sign extension
    signal id_imm_i_type  : std_ulogic_vector(31 downto 0);
    signal id_imm_iz_type : std_ulogic_vector(31 downto 0); -- @suppress "signal id_imm_iz_type is never read"
    signal id_imm_s_type  : std_ulogic_vector(31 downto 0);
    signal id_imm_sb_type : std_ulogic_vector(31 downto 0);
    signal id_imm_u_type  : std_ulogic_vector(31 downto 0);
    signal id_imm_uj_type : std_ulogic_vector(31 downto 0);
    signal id_imm_z_type  : std_ulogic_vector(31 downto 0);
    --    signal id_imm_s2_type : std_ulogic_vector(31 downto 0);
    --    signal id_imm_bi_type : std_ulogic_vector(31 downto 0);
    --    signal id_imm_s3_type : std_ulogic_vector(31 downto 0);
    --    signal id_imm_vs_type : std_ulogic_vector(31 downto 0);
    --    signal id_imm_vu_type : std_ulogic_vector(31 downto 0);

    signal id_imm_a : std_ulogic_vector(31 downto 0); -- contains the immediate for operand b
    signal id_imm_b : std_ulogic_vector(31 downto 0); -- contains the immediate for operand b

    signal id_jump_target : std_ulogic_vector(31 downto 0); -- calculated jump target (-> EX -> IF)

    -- Signals running between controller and int_controller
    signal irq_req_ctrl : std_ulogic;
    --    signal irq_sec_ctrl : std_ulogic;
    signal irq_wu_ctrl  : std_ulogic;
    signal irq_id_ctrl  : std_ulogic_vector(4 downto 0);

    -- Register file interface
    signal id_regfile_data_a : std_ulogic_vector(31 downto 0);
    signal id_regfile_data_b : std_ulogic_vector(31 downto 0);
    signal id_regfile_addr_a : std_ulogic_vector(4 downto 0);
    signal id_regfile_addr_b : std_ulogic_vector(4 downto 0);
    signal id_regfile_waddr  : std_ulogic_vector(4 downto 0);
    signal id_regfile_alu_we : std_ulogic;
    signal id_rega_used_dec  : std_ulogic;
    signal id_regb_used_dec  : std_ulogic;

    -- ALU Control
    signal id_alu_en           : std_ulogic;
    signal id_alu_operator     : alu_op_t;
    signal id_alu_op_a_mux_sel : op_a_sel_t;
    signal id_alu_op_b_mux_sel : op_b_sel_t;

    signal id_imm_a_mux_sel                : op_a_immediate_sel_t;
    signal id_imm_b_mux_sel                : op_b_immediate_sel_t;
    signal id_ctrl_transfer_target_mux_sel : jump_target_mux_sel_t;

    -- Multiplier Control
    signal id_mult_operator    : mult_operator_t; -- multiplication operation selection
    signal id_mult_en          : std_ulogic; -- multiplication is used instead of ALU
    signal id_mult_signed_mode : std_ulogic_vector(1 downto 0); -- Signed mode multiplication at the output of the controller, and before the pipe registers

    -- Register Write Control
    signal id_regfile_we : std_ulogic;

    -- Data Memory Control
    signal id_data_we       : lsu_op_t;
    signal id_data_type     : memory_data_type_t;
    signal id_data_sign_ext : std_ulogic;
    signal id_data_req      : std_ulogic;

    -- CSR control
    signal id_csr_access : std_ulogic;
    signal id_csr_op     : std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0);

    -- Forwarding
    signal id_operand_b : std_ulogic_vector(31 downto 0);
    signal id_operand_a : std_ulogic_vector(31 downto 0);

    -- Performance counters
    signal id_valid_ff : std_ulogic;
    signal id_minstret : std_ulogic;

    -- Hazard Detection Signals
    signal id_opa_match_ex, id_opb_match_ex                     : boolean;
    signal id_opa_match_mem1, id_opb_match_mem1                 : boolean;
    signal id_opa_match_mem2, id_opb_match_mem2                 : boolean;
    signal id_opa_match_mem3, id_opb_match_mem3                 : boolean;
    signal id_opa_match_wb, id_opb_match_wb                     : boolean; -- for jalr ( no forward path )
    signal id_load_hazard_ff, id_jt_hazard_ff, id_mul_hazard_ff : std_ulogic;

    -- Stall Signals
    signal id_stall_instr_ff, id_stall_instr_int                       : std_ulogic_vector(31 downto 0);
    signal id_stall_illegal_compress_ff, id_stall_illegal_compress_int : std_ulogic;
    signal id_stall_is_compressed_ff, id_stall_is_compressed_int       : std_ulogic;
    signal id_stall_buffering                                          : std_ulogic;
    signal id_operand_stall                                            : std_ulogic;

    --
    -- EX Stage
    --
    -- Operands
    signal ex_alu_op_a_mux_sel_ff                     : op_a_sel_t;
    signal ex_alu_op_b_mux_sel_ff                     : op_b_sel_t;
    signal ex_operand_a_pre_ff, ex_operand_b_pre_ff   : std_ulogic_vector(31 downto 0);
    signal ex_regfile_data_a_ff, ex_regfile_data_b_ff : std_ulogic_vector(31 downto 0);
    signal ex_opa_fw_sel_ff, ex_opb_fw_sel_ff         : forward_sel_t;
    -- LSU
    signal ex_lsu_data_we_ff                          : lsu_op_t;
    signal ex_lsu_data_type_ff                        : memory_data_type_t;
    signal ex_lsu_data_sign_ext_ff                    : std_ulogic;
    signal ex_regfile_lsu_we_ff                       : std_ulogic;
    -- ALU & Mult
    signal ex_alu_en_ff                               : std_ulogic;
    signal ex_alu_operator_ff                         : alu_op_t;
    signal ex_regfile_alu_we_ff                       : std_ulogic;
    signal ex_regfile_alu_waddr_ff                    : std_ulogic_vector(4 downto 0);
    signal ex_mult_en_ff                              : std_ulogic;
    signal ex_mult_operator_ff                        : mult_operator_t;
    signal ex_mult_signed_mode_ff                     : std_ulogic_vector(1 downto 0);
    -- CSR
    signal ex_csr_op_ff                               : std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0);
    signal ex_csr_access_ff                           : std_ulogic;
    -- Control
    signal ex_imm_i_type_ff                           : std_ulogic_vector(31 downto 0);
    signal ex_jalr_ff                                 : std_ulogic;
    signal ex_pc_ff                                   : std_ulogic_vector(31 downto 0);
    signal ex_jump_target_ff                          : std_ulogic_vector(31 downto 0);
    signal ex_branch_taken_ex                         : std_ulogic;
    signal ex_branch_in_ff, ex_lsu_data_req_ff        : std_ulogic;

    -- VPRO Custom Extension
    signal id_vpro_op, ex_vpro_op_ff : vpro_op_t;
    signal ex_regfile_addr_a_ff      : std_ulogic_vector(4 downto 0);

begin

    assert (MEM_DELAY = 1 or MEM_DELAY = 2 or MEM_DELAY = 3) report "MEM_DELAY needs to be 1, 2 or 3!" severity failure;

    process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            id_load_hazard_ff            <= '0';
            id_jt_hazard_ff              <= '0';
            id_mul_hazard_ff             <= '0';
            id_stall_illegal_compress_ff <= '0';
            id_stall_is_compressed_ff    <= '0';
            id_instr_valid_ff            <= '0';
            id_stall_instr_ff            <= (others => '0');
        elsif rising_edge(clk_i) then
            id_load_hazard_ff  <= id_load_hazard;
            id_jt_hazard_ff    <= id_jt_hazard;
            id_mul_hazard_ff   <= id_mul_hazard;
            id_stall_buffering <= '0';
            if (id_jr_stall = '1' or id_load_stall = '1' or id_mul_stall = '1') then -- TODO: check if ( ... and wb_rdy = '0') needed?
                id_stall_instr_ff            <= id_instr_i;
                id_stall_illegal_compress_ff <= id_illegal_compressed_instr_i;
                id_stall_is_compressed_ff    <= id_is_compressed_instr_i;
                id_instr_valid_ff            <= id_instr_valid_i;
                -- decode should still decode last instr. which caused this stall
                -- already includes id_control_ready = 0 
                id_stall_buffering           <= '1';
            end if;
        end if;
    end process;

    id_stall_instr_int            <= id_instr_i when id_stall_buffering = '0' else
                                     id_stall_instr_ff;
    id_stall_illegal_compress_int <= '0' --
                                     -- coverage off
                                     when not C_EXTENSION else
                                     id_illegal_compressed_instr_i when id_stall_buffering = '0' else
                                     id_stall_illegal_compress_ff;
    -- coverage on
    id_stall_is_compressed_int <= id_is_compressed_instr_i when id_stall_buffering = '0' else
                                  id_stall_is_compressed_ff;
    id_instr_valid_int         <= id_instr_valid_i when id_stall_buffering = '0' else
                                  id_instr_valid_ff;

    id_ready_int <=                     --((not id_stall_buffering) and  -- TODO: check
                    (ex_ready_i and id_control_ready); -- and (not ex_jalr));
    -- not ready = not reading incoming instruction from IF (causing instruction ist parsed and inside registered fsm logic of the controller)
    id_ready_o   <= id_ready_int;
    id_valid_int <= (not ex_branch_taken_ex) and (not id_operand_stall) and id_instr_valid_i; -- if ex branch taken, invalidate id -- and (not ex_jalr) 

    -----------------------------------------------
    -- Instruction Decoder
    -----------------------------------------------
    decoder_i : eisV_decoder
        port map(
            id_deassert_we_i                  => id_deassert_we,
            -- controller related signals
            id_instruction_type_o             => id_instruction_type,
            id_rega_used_o                    => id_rega_used_dec,
            id_regb_used_o                    => id_regb_used_dec,
            -- from IF/ID pipeline
            id_instr_rdata_i                  => id_stall_instr_int,
            id_illegal_c_insn_i               => id_stall_illegal_compress_int,
            -- ALU signals
            id_alu_en_o                       => id_alu_en,
            id_alu_operator_o                 => id_alu_operator,
            id_alu_op_a_mux_sel_o             => id_alu_op_a_mux_sel,
            id_alu_op_b_mux_sel_o             => id_alu_op_b_mux_sel,
            id_imm_a_mux_sel_o                => id_imm_a_mux_sel,
            id_imm_b_mux_sel_o                => id_imm_b_mux_sel,
            -- MUL signals
            id_mult_operator_o                => id_mult_operator,
            id_mult_int_en_o                  => id_mult_en,
            id_mult_signed_mode_o             => id_mult_signed_mode,
            -- Register file control signals
            id_regfile_mem_we_o               => id_regfile_we,
            id_regfile_alu_we_o               => id_regfile_alu_we,
            -- CSR control signals
            id_csr_access_o                   => id_csr_access,
            id_csr_op_o                       => id_csr_op,
            -- Data bus interface
            id_data_req_o                     => id_data_req,
            id_data_we_o                      => id_data_we,
            id_data_type_o                    => id_data_type,
            id_data_sign_extension_o          => id_data_sign_ext,
            -- jump/branches
            id_ctrl_transfer_insn_in_dec_o    => id_ctrl_transfer_insn_in_dec,
            id_ctrl_transfer_insn_in_o        => id_ctrl_transfer_insn_in_id,
            id_ctrl_transfer_target_mux_sel_o => id_ctrl_transfer_target_mux_sel,
            id_vpro_op_o                      => id_vpro_op
        );

    -- immediate extraction and sign extension
    process(id_stall_instr_int)
    begin
        id_imm_i_type              <= (others => id_stall_instr_int(31));
        id_imm_i_type(11 downto 0) <= id_stall_instr_int(31 downto 20);

        id_imm_iz_type              <= (others => '0');
        id_imm_iz_type(11 downto 0) <= id_stall_instr_int(31 downto 20);

        id_imm_s_type              <= (others => id_stall_instr_int(31));
        id_imm_s_type(11 downto 0) <= id_stall_instr_int(31 downto 25) & id_stall_instr_int(11 downto 7);

        id_imm_sb_type              <= (others => id_stall_instr_int(31));
        id_imm_sb_type(12 downto 0) <= id_stall_instr_int(31) & id_stall_instr_int(7) & id_stall_instr_int(30 downto 25) & id_stall_instr_int(11 downto 8) & "0";

        id_imm_u_type               <= (others => '0');
        id_imm_u_type(31 downto 12) <= id_stall_instr_int(31 downto 12);

        id_imm_uj_type              <= (others => id_stall_instr_int(31));
        id_imm_uj_type(19 downto 0) <= id_stall_instr_int(19 downto 12) & id_stall_instr_int(20) & id_stall_instr_int(30 downto 21) & "0";

        -- immediate for CSR manipulatin (zero extended)
        id_imm_z_type             <= (others => '0');
        id_imm_z_type(4 downto 0) <= id_stall_instr_int(REG_S1_MSB downto REG_S1_LSB);
    end process;

    --------------------------------------------------------
    -- Operand A
    --------------------------------------------------------
    -- Immediate Mux for operand A
    immediate_a_mux : process(id_imm_a_mux_sel, id_imm_z_type)
    begin
        case (id_imm_a_mux_sel) is
            when IMMA_Z    => id_imm_a <= id_imm_z_type;
            when IMMA_ZERO => id_imm_a <= (others => '0');
        end case;
    end process;

    id_operand_a <= id_pc_i when id_alu_op_a_mux_sel = OP_A_CURRPC else
                    id_imm_a;
    ------------------------------------------------------
    --  Operand B
    ------------------------------------------------------
    -- Immediate Mux for operand B
    immediate_b_mux : process(id_imm_b_mux_sel, id_imm_i_type, id_imm_s_type, id_imm_u_type, id_stall_is_compressed_int)
    begin
        case (id_imm_b_mux_sel) is
            when IMMB_I => id_imm_b <= id_imm_i_type;
            when IMMB_S => id_imm_b <= id_imm_s_type;
            when IMMB_U => id_imm_b <= id_imm_u_type;
            when IMMB_PCINCR =>
                if C_EXTENSION and id_stall_is_compressed_int = '1' then
                    id_imm_b <= x"00000002";
                else
                    id_imm_b <= x"00000004";
                end if;
        end case;
    end process;

    id_operand_b <= id_imm_b;

    ------------------------------------------------------------------
    --  Jump Target
    ------------------------------------------------------------------
    jump_target_mux : process(id_ctrl_transfer_target_mux_sel, id_imm_i_type, id_imm_sb_type, id_imm_uj_type, id_pc_i, id_regfile_data_a)
    begin
        if JALR_TARGET_ADDER_IN_ID then
            id_jump_target <= std_ulogic_vector(unsigned(id_regfile_data_a) + unsigned(id_imm_i_type)); -- FIMXE: Forward? instead of hazard cycle?! -- @suppress "Dead code"
        else
            id_jump_target <= (others => '-');
        end if;

        case (id_ctrl_transfer_target_mux_sel) is
            when JT_JAL  => id_jump_target <= std_ulogic_vector(unsigned(id_pc_i) + unsigned(id_imm_uj_type));
            when JT_COND => id_jump_target <= std_ulogic_vector(unsigned(id_pc_i) + unsigned(id_imm_sb_type));
            when others =>              --JT_JALR =>
        end case;
    end process;
    id_jump_target_o <= id_jump_target;

    ---------------------------------------------------------
    -- Register File
    ---------------------------------------------------------
    -- register addresses 
    id_regfile_addr_a <=                --
                                        -- coverage off
                         id_stall_instr_int(REG_D_MSB downto REG_D_LSB) when (id_vpro_op = VPRO_LI and VPRO_CUSTOM_EXTENSION) else
                         -- coverage on
                         id_stall_instr_int(REG_S1_MSB downto REG_S1_LSB);
    id_regfile_addr_b <= id_stall_instr_int(REG_S2_MSB downto REG_S2_LSB);
    id_regfile_waddr  <= id_stall_instr_int(REG_D_MSB downto REG_D_LSB);

    register_file_i : eisV_register_file_ff
        generic map(
            ADDR_WIDTH => 5,
            DATA_WIDTH => 32
        )
        port map(
            clk_i        => clk_i,
            rst_ni       => rst_ni,
            -- Read port a
            id_raddr_a_i => id_regfile_addr_a,
            id_rdata_a_o => id_regfile_data_a,
            -- Read port b
            id_raddr_b_i => id_regfile_addr_b,
            id_rdata_b_o => id_regfile_data_b,
            -- Write port 
            wb_waddr_i   => wb_regfile_waddr_i,
            wb_wdata_i   => wb_regfile_wdata_i,
            wb_we_i      => wb_regfile_we_i
        );

    --------------------------------------------------------------------
    -- Core Controller
    --------------------------------------------------------------------
    controller_i : eisV_controller
        port map(
            clk_i                          => clk_i,
            rst_ni                         => rst_ni,
            fetch_enable_i                 => fetch_enable_i,
            -- from prefetcher
            if_instr_req_o                 => if_instr_req_o,
            -- to prefetcher
            pc_set_o                       => pc_set_o,
            pc_mux_o                       => pc_mux_o,
            exc_cause_o                    => exc_cause_o,
            -- from IF/ID pipeline
            id_instr_valid_i               => id_instr_valid_int,
            -- CSR Controller Signals
            csr_save_if_o                  => csr_save_if_o,
            csr_save_id_o                  => csr_save_id_o,
            csr_save_ex_o                  => csr_save_ex_o,
            csr_cause_o                    => csr_cause_o,
            csr_restore_mret_id_o          => csr_restore_mret_id_o,
            csr_save_cause_o               => csr_save_cause_o,
            -- decoder related signals
            id_deassert_we_o               => id_deassert_we,
            id_instruction_type_i          => id_instruction_type,
            id_ctrl_transfer_insn_in_dec_i => id_ctrl_transfer_insn_in_dec,
            -- jump/branch control
            ex_branch_taken_i              => ex_branch_taken_ex,
            -- Interrupt signals
            irq_req_ctrl_i                 => irq_req_ctrl,
            irq_id_ctrl_i                  => irq_id_ctrl,
            irq_wu_ctrl_i                  => irq_wu_ctrl,
            irq_ack_o                      => irq_ack_o,
            irq_id_o                       => irq_id_o,
            -- Hazard detecting signals
            id_jt_hazard_i                 => id_jt_hazard,
            id_load_hazard_i               => id_load_hazard,
            id_mul_hazard_i                => id_mul_hazard,
            id_jr_stall_o                  => id_jr_stall,
            id_ld_stall_o                  => id_load_stall,
            id_mul_stall_o                 => id_mul_stall,
            -- Wakeup Signal
            wake_from_sleep_o              => wake_from_sleep_o,
            id_control_ready_ff_o          => id_control_ready,
            -- Stall signals
            ex_valid_i                     => ex_valid_i,
            ex_ready_i                     => ex_ready_i,
            -- Performance Counters
            id_is_decoding_o               => id_is_decoding_int
        );

    ctrl_busy_o      <= id_is_decoding_int;
    id_is_decoding_o <= id_is_decoding_int;

    ---------------------------------------------------------
    -- Hazards
    ---------------------------------------------------------

    -- stall if ex not ready? -> id valid?

    process(ex_fwd_i, id_rega_used_dec, id_regb_used_dec, id_regfile_addr_a, id_regfile_addr_b, mem_fwd_i, wb_fwd_i, ex_ready_i)
    begin
        id_opa_match_ex <= ex_ready_i = '1' and id_regfile_addr_a = ex_fwd_i.waddr and (id_rega_used_dec = '1') and ex_fwd_i.wen = '1' and unsigned(id_regfile_addr_a) /= 0;
        id_opb_match_ex <= ex_ready_i = '1' and id_regfile_addr_b = ex_fwd_i.waddr and (id_regb_used_dec = '1') and ex_fwd_i.wen = '1' and unsigned(id_regfile_addr_b) /= 0;

        id_opa_match_mem1 <= ex_ready_i = '1' and id_regfile_addr_a = mem_fwd_i(0).waddr and (id_rega_used_dec = '1') and mem_fwd_i(0).wen = '1' and unsigned(id_regfile_addr_a) /= 0;
        id_opb_match_mem1 <= ex_ready_i = '1' and id_regfile_addr_b = mem_fwd_i(0).waddr and (id_regb_used_dec = '1') and mem_fwd_i(0).wen = '1' and unsigned(id_regfile_addr_b) /= 0;

        if MEM_DELAY > 1 then
            id_opa_match_mem2 <= ex_ready_i = '1' and id_regfile_addr_a = mem_fwd_i(1).waddr and (id_rega_used_dec = '1') and mem_fwd_i(1).wen = '1' and unsigned(id_regfile_addr_a) /= 0;
            id_opb_match_mem2 <= ex_ready_i = '1' and id_regfile_addr_b = mem_fwd_i(1).waddr and (id_regb_used_dec = '1') and mem_fwd_i(1).wen = '1' and unsigned(id_regfile_addr_b) /= 0;
        end if;

        if MEM_DELAY > 2 then
            id_opa_match_mem3 <= ex_ready_i = '1' and id_regfile_addr_a = mem_fwd_i(2).waddr and (id_rega_used_dec = '1') and mem_fwd_i(2).wen = '1' and unsigned(id_regfile_addr_a) /= 0;
            id_opb_match_mem3 <= ex_ready_i = '1' and id_regfile_addr_b = mem_fwd_i(2).waddr and (id_regb_used_dec = '1') and mem_fwd_i(2).wen = '1' and unsigned(id_regfile_addr_b) /= 0;
        end if;

        id_opa_match_wb <= ex_ready_i = '1' and id_regfile_addr_a = wb_fwd_i.waddr and (id_rega_used_dec = '1') and unsigned(id_regfile_addr_a) /= 0; -- and wb_fwd_i.wen = '1'
        id_opb_match_wb <= ex_ready_i = '1' and id_regfile_addr_b = wb_fwd_i.waddr and (id_regb_used_dec = '1') and unsigned(id_regfile_addr_b) /= 0;
    end process;

    ex_hazards : process(ex_fwd_i, mem_fwd_i, wb_fwd_i, id_load_hazard_ff, ex_ready_i, id_ctrl_transfer_target_mux_sel, id_jt_hazard_ff, id_mul_hazard_ff, id_opa_match_ex, id_opa_match_mem1, id_opa_match_mem2, id_opa_match_mem3, id_opb_match_ex, id_opb_match_mem1, id_opb_match_mem2, id_rega_used_dec, id_regfile_addr_a, id_opa_match_wb)
    begin
        id_jt_hazard   <= '0';
        id_load_hazard <= '0';
        id_mul_hazard  <= '0';

        -- JALR

        -- ID has JALR Instruction
        --  reads from Reg_a to get return address for new PC
        -- Either Condition will cause Hazard (stall)
        -- 1 cycle stall if EX has ALU  -- TODO
        -- 2 cycle stall if MUL  -- TODO
        -- x cycle stall if LD  -- TODO
        --  If Ex Stage will write to Register (too long forward path)
        --  If Mem Stage will write to Register (Ex Op or Load)
        --  If WB Stage writes (TODO: Forward logic?!)

        if (id_ctrl_transfer_target_mux_sel = JT_JALR and --
                (id_opa_match_ex or     -- in ex  stage alu op or load to this addr
                 id_opa_match_mem1 or   -- in mem stage alu op or load to this addr
                 (id_opa_match_wb and (wb_fwd_i.wen = '1' or wb_fwd_i.is_load = '1'))
                )) then
            id_jt_hazard <= '1';        -- hold a stall until wb becomes ready
        end if;
        if MEM_DELAY > 1 then
            if id_ctrl_transfer_target_mux_sel = JT_JALR and id_opa_match_mem2 then
                id_jt_hazard <= '1';
            end if;
        end if;
        if MEM_DELAY > 2 then
            if id_ctrl_transfer_target_mux_sel = JT_JALR and id_opa_match_mem3 then
                id_jt_hazard <= '1';
            end if;
        end if;
        if id_jt_hazard_ff = '1' and wb_fwd_i.wen = '0' and wb_fwd_i.is_load = '1' -- load source but no wb / miss
            then
            id_jt_hazard <= '1';        -- will not drop
        end if;

        -- MULT

        -- ID has Instruction ALU/MULT/LD/STORE
        --  A or B is read from Register
        -- Either Condition will cause Hazard (stall)
        --  If EX Stage is MULT (data avail after mem1)

        if MUL_IN_TWO_STAGES_EX_AND_MEM then
            if id_opa_match_ex and ex_fwd_i.is_mul = '1' then --  Mult OP Result is used as operand input
                id_mul_hazard <= '1';
            end if;
        end if;
        if MUL_IN_TWO_STAGES_EX_AND_MEM then
            if id_opb_match_ex and ex_fwd_i.is_mul = '1' then -- Mult OP Result is used as operand input
                id_mul_hazard <= '1';
            end if;
        end if;
        if id_mul_hazard_ff = '1' and ex_ready_i = '0' then -- TODO: not ex_rdy but mem1_rdy? (mul hazard from mem1)
            id_mul_hazard <= '1';       -- will not drop
        end if;

        -- Load

        -- ID has Instruction ALU/MULT/LD/STORE
        --  A or B is read from Register
        -- Either Condition will cause Hazard (stall)
        --  If EX Stage is LOAD 
        --  If MEM1 ... Stage is LOAD (MEM_DELAY > 1)

        -- EX is load
        -- next stage stall as well (ex -> mem [not yet loaded])
        --        if id_deassert_we = '0' then    -- current instruction not executed?
        -- if (id_ready_int = '0') -> pipeline will stall 
        if (id_opa_match_ex or id_opb_match_ex) and ex_fwd_i.is_load = '1' then
            id_load_hazard <= '1';
        end if;
        if MEM_DELAY > 1 then
            if (id_opa_match_mem1 or id_opb_match_mem1) and mem_fwd_i(0).is_load = '1' then
                id_load_hazard <= '1';
            end if;
        end if;
        if MEM_DELAY > 2 then
            if (id_opa_match_mem2 or id_opb_match_mem2) and mem_fwd_i(1).is_load = '1' then
                id_load_hazard <= '1';
            end if;
        end if;
        -- wb is handled in ex (non deterministic stall duration)
        if (id_load_hazard_ff = '1' and ex_ready_i = '0') -- nessecary to avoid drop of stalled instruction if ex not becomes rdy, TODO: not ex_ry but wb_rdy as load hazard comes from wb
            then
            id_load_hazard <= '1';      -- will not drop
        end if;

    end process;

    id_operand_stall <= id_load_stall or id_mul_stall or id_jr_stall;

    ---------------------------------------------------------
    -- FORWARDING
    ---------------------------------------------------------
    --   data to EX (input MUX -> calced in same cycle)
    --   data to MEM (input MUX -> stored in same cycle)
    --   data from Mem (output reg of EX/input reg in MEM)
    --   data from WB (output reg of MEM / data loaded in this cycle/input to RF in same cycle)
    ---------------------------------------------------------
    -- Ex stage Forwarding Mux
    ---------------------------------------------------------

    -- TODO: instead in EX stage check: wb and mem as input conditions, use mem and ex 
    -- buffer (then) id_fw_sel, so ex_fw_sel is a register content only!

    ex_fw_mux : process(id_opa_match_ex, id_opa_match_mem1, id_opa_match_mem2, id_opa_match_mem3, id_opb_match_ex, id_opb_match_mem1, id_opb_match_mem2, id_opb_match_mem3, id_opa_match_wb, id_opb_match_wb, wb_fwd_i.wen, wb_fwd_i.is_load)
    begin
        ------------------------
        -- Operand A
        ------------------------
        id_opa_fw_sel <= SEL_REGFILE;
        -- From WB
        -- to enable ex (nxt cycle) to stall, if data still not available
        -- only needed for loads, as other data is available (deterministic) -> stalls will make shure
        if id_opa_match_wb and (wb_fwd_i.wen = '0' and wb_fwd_i.is_load = '1') then
            id_opa_fw_sel <= SEL_FW_WB; -- TODO: wb_lst?
        end if;

        -- From MEM (higher prio)
        -- coverage off
        if (MEM_DELAY = 3) then
            if id_opa_match_mem3 then
                id_opa_fw_sel <= SEL_FW_WB;
            end if;
            if id_opa_match_mem2 then
                id_opa_fw_sel <= SEL_FW_MEM3;
            end if;
            if id_opa_match_mem1 then
                id_opa_fw_sel <= SEL_FW_MEM2;
            end if;
        end if;
        -- coverage on
        if (MEM_DELAY = 2) then
            if id_opa_match_mem2 then
                id_opa_fw_sel <= SEL_FW_WB;
            end if;
            if id_opa_match_mem1 then
                id_opa_fw_sel <= SEL_FW_MEM2;
            end if;
        end if;
        -- coverage off
        if (MEM_DELAY = 1) then
            if id_opa_match_mem1 then
                id_opa_fw_sel <= SEL_FW_WB;
            end if;
        end if;
        -- coverage on
        if id_opa_match_ex then
            id_opa_fw_sel <= SEL_FW_MEM1;
        end if;

        ------------------------
        -- Operand B
        ------------------------
        id_opb_fw_sel <= SEL_REGFILE;
        -- From WB
        -- to enable ex (nxt cycle) to stall, if data still not available
        -- only needed for loads, as other data is available (deterministic) -> stalls will make shure
        if id_opb_match_wb and (wb_fwd_i.wen = '0' and wb_fwd_i.is_load = '1') then
            id_opb_fw_sel <= SEL_FW_WB; -- TODO: wb_lst?
        end if;
        -- From MEM (higher prio)
        -- coverage off
        if (MEM_DELAY = 3) then
            if id_opb_match_mem3 then
                id_opb_fw_sel <= SEL_FW_WB;
            end if;
            if id_opb_match_mem2 then
                id_opb_fw_sel <= SEL_FW_MEM3;
            end if;
            if id_opb_match_mem1 then
                id_opb_fw_sel <= SEL_FW_MEM2;
            end if;
        end if;
        -- coverage on
        if (MEM_DELAY = 2) then
            if id_opb_match_mem2 then
                id_opb_fw_sel <= SEL_FW_WB;
            end if;
            if id_opb_match_mem1 then
                id_opb_fw_sel <= SEL_FW_MEM2;
            end if;
        end if;
        -- coverage off
        if (MEM_DELAY = 1) then
            if id_opb_match_mem1 then
                id_opb_fw_sel <= SEL_FW_WB;
            end if;
        end if;
        -- coverage on
        if id_opb_match_ex then
            id_opb_fw_sel <= SEL_FW_MEM1;
        end if;
    end process;

    ex_pipeline_o.lsu_data_type <= ex_lsu_data_type_ff;
    ex_pipeline_o.lsu_op        <= LSU_STORE when ex_lsu_data_req_ff = '1' and ex_lsu_data_we_ff = LSU_STORE else
                                   LSU_LOAD when ex_lsu_data_req_ff = '1' else
                                   LSU_NONE;

    ex_pipeline_o.lsu_wdata          <= ex_regfile_data_b_ff; -- regfile
    ex_pipeline_o.lsu_sign_ext       <= ex_lsu_data_sign_ext_ff;
    ex_pipeline_o.alu_op             <= ex_alu_en_ff;
    ex_pipeline_o.alu_operator       <= ex_alu_operator_ff;
    ex_pipeline_o.mult_op            <= ex_mult_en_ff;
    ex_pipeline_o.mult_operator      <= ex_mult_operator_ff;
    ex_pipeline_o.mult_signed_mode   <= ex_mult_signed_mode_ff;
    ex_pipeline_o.operand_a_data_reg <= ex_regfile_data_a_ff; -- regfile
    ex_pipeline_o.operand_b_data_reg <= ex_regfile_data_b_ff; -- regfile
    ex_pipeline_o.operand_a_data_pre <= ex_operand_a_pre_ff; -- immediate
    ex_pipeline_o.operand_b_data_pre <= ex_operand_b_pre_ff; -- immediate
    ex_pipeline_o.operand_a_data_mux <= ex_alu_op_a_mux_sel_ff; -- regfile or immediate mux sel
    ex_pipeline_o.operand_b_data_mux <= ex_alu_op_b_mux_sel_ff; -- regfile or immediate mux sel
    ex_pipeline_o.operand_a_fwd_src  <= ex_opa_fw_sel_ff; -- regfile data will be forward
    ex_pipeline_o.operand_b_fwd_src  <= ex_opb_fw_sel_ff; -- regfile data will be forward
    ex_pipeline_o.rf_waddr           <= ex_regfile_alu_waddr_ff;
    ex_pipeline_o.rf_wen             <= ex_regfile_alu_we_ff or ex_regfile_lsu_we_ff;
    ex_pipeline_o.branch             <= ex_branch_in_ff;
    ex_pipeline_o.ex_csr_access      <= ex_csr_access_ff;

    -- VPRO needs src1/rd address for vpro.li (address is immediate in fact)
    -- coverage off
    ex_pipeline_o.operand_a_addr <= ex_regfile_addr_a_ff when VPRO_CUSTOM_EXTENSION else (others => '-');
    -- coverage on

    ex_csr_op_o  <= ex_csr_op_ff;
    ex_pc_o      <= ex_pc_ff;
    ex_vpro_op_o <= ex_vpro_op_ff;

    process(ex_imm_i_type_ff, ex_jalr_ff, ex_jump_target_ff, ex_regfile_data_a_after_fwd_i)
    begin
        if JALR_TARGET_ADDER_IN_ID then
            ex_jump_target_o <= ex_jump_target_ff; -- @suppress "Dead code"
        else                            -- @suppress "Dead code"
            if ex_jalr_ff = '1' then
                ex_jump_target_o <= std_ulogic_vector(unsigned(ex_regfile_data_a_after_fwd_i) + unsigned(ex_imm_i_type_ff));
            else
                ex_jump_target_o <= ex_jump_target_ff;
            end if;
        end if;
    end process;

    ex_branch_taken_ex <= ex_branch_in_ff and ex_branch_decision_i;

    ------------------------------------------------------------------------
    --  Interrupt Controller
    ------------------------------------------------------------------------
    -- coverage off
    int_controller_i : eisV_interrupt_controller
        port map(
            clk_i          => clk_i,
            rst_ni         => rst_ni,
            -- External interrupt lines
            irq_i          => irq_i,
            -- to _controller
            irq_req_ctrl_o => irq_req_ctrl,
            irq_id_ctrl_o  => irq_id_ctrl,
            irq_wu_ctrl_o  => irq_wu_ctrl,
            -- To/from with cs_registers
            mie_bypass_i   => mie_bypass_i,
            mip_o          => mip_o,
            m_ie_i         => m_irq_enable_i
        );
    -- coverage on

    ---------------------------------------------------------------------------------
    --  ID - EX Pipeline Registers
    ---------------------------------------------------------------------------------
    ID_EX_PIPE_REGISTERS : process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            ex_alu_en_ff       <= '0';
            ex_alu_operator_ff <= ALU_SLTU;
            ex_jump_target_ff  <= (others => '0');

            ex_mult_operator_ff    <= MUL_L;
            ex_mult_en_ff          <= '0';
            ex_mult_signed_mode_ff <= "00";

            ex_regfile_alu_waddr_ff <= (others => '0');
            ex_regfile_alu_we_ff    <= '0';
            ex_regfile_lsu_we_ff    <= '0';

            ex_csr_access_ff <= '0';
            ex_csr_op_ff     <= CSR_OP_READ;

            ex_lsu_data_we_ff       <= LSU_LOAD;
            ex_lsu_data_type_ff     <= WORD;
            ex_lsu_data_sign_ext_ff <= '0';
            ex_lsu_data_req_ff      <= '0';

            ex_pc_ff        <= (others => '0');
            ex_alu_en_ff    <= '0';
            ex_mult_en_ff   <= '0';
            ex_branch_in_ff <= '0';

            ex_alu_op_a_mux_sel_ff <= OP_A_IMM;
            ex_alu_op_b_mux_sel_ff <= OP_B_IMM;

            ex_operand_a_pre_ff <= (others => '0');
            ex_operand_b_pre_ff <= (others => '0');

            ex_regfile_data_a_ff <= (others => '0');
            ex_regfile_data_b_ff <= (others => '0');

            ex_opa_fw_sel_ff <= SEL_REGFILE;
            ex_opb_fw_sel_ff <= SEL_REGFILE;

            -- coverage off
            if VPRO_CUSTOM_EXTENSION then -- @suppress "Dead code"
                ex_vpro_op_ff <= NONE;  -- @suppress "Dead code"
            end if;
            -- coverage on

            if not JALR_TARGET_ADDER_IN_ID then -- @suppress "Dead code"
                ex_imm_i_type_ff <= (others => '0');
                ex_jalr_ff       <= '0';
            end if;
        elsif rising_edge(clk_i) then
            -- coverage off
            if VPRO_CUSTOM_EXTENSION then -- @suppress "Dead code"
                -- defaulting to none to disable trigger of vpro instruction mutliple times (registered id output if id not valid / ex not rdy)
                ex_vpro_op_ff <= NONE;  -- @suppress "Dead code"
            end if;
            -- coverage on
            if ex_ready_i = '1' then
                if (id_valid_int = '1') then -- unstall the whole pipeline

                    if not JALR_TARGET_ADDER_IN_ID then -- @suppress "Dead code"
                        ex_imm_i_type_ff <= id_imm_i_type;
                        if id_ctrl_transfer_target_mux_sel = JT_JALR then
                            ex_jalr_ff <= '1';
                        else
                            ex_jalr_ff <= '0';
                        end if;
                    end if;

                    -- coverage off
                    if VPRO_CUSTOM_EXTENSION then -- @suppress "Dead code"
                        ex_vpro_op_ff <= id_vpro_op; -- @suppress "Dead code"
                    end if;
                    -- coverage on

                    ex_operand_a_pre_ff    <= id_operand_a;
                    ex_operand_b_pre_ff    <= id_operand_b;
                    ex_alu_op_a_mux_sel_ff <= id_alu_op_a_mux_sel;
                    ex_alu_op_b_mux_sel_ff <= id_alu_op_b_mux_sel;
                    ex_opa_fw_sel_ff       <= id_opa_fw_sel;
                    ex_opb_fw_sel_ff       <= id_opb_fw_sel;
                    ex_regfile_data_a_ff   <= id_regfile_data_a;
                    ex_regfile_data_b_ff   <= id_regfile_data_b;
                    ex_regfile_addr_a_ff   <= id_regfile_addr_a;

                    -- id forward due to fw mux is in EX stage
                    if id_opa_match_wb and wb_fwd_i.wen = '1' then -- TODO: if RF access is no longer sync, write the wb to additional regiter + use forward mux instead of here
                        ex_regfile_data_a_ff <= wb_regfile_wdata_i;
                    end if;
                    if id_opb_match_wb and wb_fwd_i.wen = '1' then -- TODO: if RF access is no longer sync, write the wb to additional regiter + use forward mux instead of here
                        ex_regfile_data_b_ff <= wb_regfile_wdata_i;
                    end if;

                    ex_alu_en_ff            <= id_alu_en;
                    ex_mult_en_ff           <= id_mult_en;
                    ex_alu_en_ff            <= id_alu_en;
                    ex_mult_en_ff           <= id_mult_en;
                    ex_alu_operator_ff      <= id_alu_operator;
                    ex_jump_target_ff       <= id_jump_target;
                    ex_mult_operator_ff     <= id_mult_operator;
                    ex_mult_signed_mode_ff  <= id_mult_signed_mode;
                    ex_regfile_lsu_we_ff    <= id_regfile_we;
                    ex_regfile_alu_waddr_ff <= id_regfile_waddr;
                    ex_regfile_alu_we_ff    <= id_regfile_alu_we;
                    ex_regfile_alu_waddr_ff <= id_regfile_waddr;
                    ex_csr_access_ff        <= id_csr_access;
                    ex_csr_op_ff            <= id_csr_op;
                    ex_lsu_data_req_ff      <= id_data_req;
                    ex_lsu_data_we_ff       <= id_data_we;
                    ex_lsu_data_type_ff     <= id_data_type;
                    ex_lsu_data_sign_ext_ff <= id_data_sign_ext;
                    ex_pc_ff                <= id_pc_i;
                    ex_branch_in_ff         <= '0';

                    if (id_ctrl_transfer_insn_in_id = BRANCH_COND) then
                        ex_branch_in_ff <= '1';
                    end if;
                else
                    -- EX stage is ready but we don't have a new instruction for it,
                    -- so we set all write enables to 0, but unstall the pipe
                    -- deassert we
                    ex_regfile_alu_we_ff <= '0';
                    ex_regfile_lsu_we_ff <= '0';
                    ex_lsu_data_we_ff    <= LSU_NONE;
                    ex_csr_op_ff         <= CSR_OP_READ;
                    ex_lsu_data_req_ff   <= '0';
                    ex_branch_in_ff      <= '0';
                    ex_alu_operator_ff   <= ALU_SLTU;
                    ex_mult_en_ff        <= '0';
                    ex_alu_en_ff         <= '0';
                    --                elsif (ex_csr_access_ff = '1') then
                    --In the EX stage there was a CSR access, to avoid multiple
                    --writes to the RF, disable regfile_alu_we_ex_o.
                    --Not doing it can overwrite the RF file with the currennt CSR value rather than the old one
                    --                        ex_regfile_alu_we_int <= '0';
                    --                elsif (id_valid_int = '1' and ex_ready_i = '0') then -- ex/mem not rdy
                end if;
            else
                -- stall case by ex / mem / wb stage (left propagated)
                -- if forward data is used, update source if nessecary

                -- for covarage: wb_wen = 0 never occurs, as wb always rdy / no cache

                -- id forward due to fw mux is in EX stage
                if ex_opa_fw_sel_ff = SEL_FW_WB and wb_fwd_i.wen = '1' then
                    ex_regfile_data_a_ff <= wb_regfile_wdata_i;
                    ex_opa_fw_sel_ff     <= SEL_REGFILE;
                end if;
                if ex_opb_fw_sel_ff = SEL_FW_WB and wb_fwd_i.wen = '1' then
                    ex_regfile_data_b_ff <= wb_regfile_wdata_i;
                    ex_opb_fw_sel_ff     <= SEL_REGFILE;
                end if;

                -- coverage off
                if (MEM_DELAY = 1) then
                    if ex_opa_fw_sel_ff = SEL_FW_MEM1 and wb_ready_i = '1' then -- mem -> wb will tick forward no matter if ex not rdy, fwd path get fixed here
                        ex_opa_fw_sel_ff <= SEL_FW_WB;
                    end if;
                    if ex_opb_fw_sel_ff = SEL_FW_MEM1 and wb_ready_i = '1' then
                        ex_opb_fw_sel_ff <= SEL_FW_WB;
                    end if;
                end if;
                -- coverage on
                if (MEM_DELAY = 2) then
                    if ex_opa_fw_sel_ff = SEL_FW_MEM2 and wb_ready_i = '1' then -- mem -> wb will tick forward no matter if ex not rdy, fwd path get fixed here
                        ex_opa_fw_sel_ff <= SEL_FW_WB;
                    end if;
                    if ex_opb_fw_sel_ff = SEL_FW_MEM2 and wb_ready_i = '1' then
                        ex_opb_fw_sel_ff <= SEL_FW_WB;
                    end if;
                end if;
                -- coverage off
                if (MEM_DELAY = 3) then
                    if ex_opa_fw_sel_ff = SEL_FW_MEM3 and wb_ready_i = '1' then -- mem -> wb will tick forward no matter if ex not rdy, fwd path get fixed here
                        ex_opa_fw_sel_ff <= SEL_FW_WB;
                    end if;
                    if ex_opb_fw_sel_ff = SEL_FW_MEM3 and wb_ready_i = '1' then
                        ex_opb_fw_sel_ff <= SEL_FW_WB;
                    end if;
                end if;
                -- coverage on
            end if;
        end if;
        --        end if;
    end process;

    ex_csr_access_o <= ex_csr_access_ff;

    -- Performance Counter Events
    -- Illegal/ecall are never counted as retired instructions. Note that actually issued instructions
    -- are being counted; the manner in which CSR instructions access the performance counters guarantees
    -- that this count will correspond to the retired isntructions count.
    id_minstret <= '1' when id_valid_int = '1' and ex_ready_i = '1' and id_is_decoding_int = '1' --
                   -- coverage off
                   and not (id_instruction_type = ILLEGAL or id_instruction_type = ECALL) --
                   -- coverage on
                   else
                   '0';
    id_mhpmevent_branch_o <= id_mhpmevent_branch_ff;

    process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            id_valid_ff                      <= '0';
            id_mhpmevent_minstret_ff_o       <= '0';
            id_mhpmevent_load_ff_o           <= '0';
            id_mhpmevent_store_ff_o          <= '0';
            id_mhpmevent_jump_ff_o           <= '0';
            id_mhpmevent_branch_ff           <= '0';
            id_mhpmevent_compressed_ff_o     <= '0';
            id_mhpmevent_branch_taken_ff_o   <= '0';
            id_mhpmevent_jr_stall_ff_o       <= '0';
            id_mhpmevent_imiss_ff_o          <= '0';
            id_mhpmevent_dmiss_ff_o          <= '0';
            id_mhpmevent_ld_stall_ff_o       <= '0';
            id_mhpmevent_mul_stall_ff_o      <= '0';
            id_mhpmevent_csr_instr_ff_o      <= '0';
            id_mhpmevent_div_multicycle_ff_o <= '0';
        elsif rising_edge(clk_i) then
            -- coverage off
            -- Helper signal
            id_valid_ff                <= id_valid_int;
            -- ID stage counts
            id_mhpmevent_minstret_ff_o <= id_minstret;
            id_mhpmevent_store_ff_o    <= '0';
            id_mhpmevent_load_ff_o     <= '0';
            case (id_data_we) is
                when LSU_LOAD =>
                    id_mhpmevent_load_ff_o <= id_minstret and id_data_req;
                when LSU_STORE =>
                    id_mhpmevent_store_ff_o <= id_minstret and id_data_req;
                when LSU_NONE =>
            end case;

            id_mhpmevent_jump_ff_o           <= '0';
            if (((id_ctrl_transfer_insn_in_id = BRANCH_JAL) or (id_ctrl_transfer_insn_in_id = BRANCH_JALR))) then
                id_mhpmevent_jump_ff_o <= id_minstret;
            end if;
            if ((id_ctrl_transfer_insn_in_id = BRANCH_COND)) then
                id_mhpmevent_branch_ff <= id_minstret;
            else
                id_mhpmevent_branch_ff <= '0';
            end if;
            -- coverage off
            id_mhpmevent_compressed_ff_o     <= id_minstret and id_stall_is_compressed_int;
            -- coverage on
            -- EX stage count
            id_mhpmevent_branch_taken_ff_o   <= id_mhpmevent_branch_ff and ex_branch_decision_i;
            -- IF stage count
            id_mhpmevent_imiss_ff_o          <= id_perf_imiss_i;
            id_mhpmevent_dmiss_ff_o          <= id_perf_dmiss_i;
            -- Jump-register-hazard; do not count stall on flushed instructions (id_valid_ff used to only count first cycle)
            id_mhpmevent_jr_stall_ff_o       <= id_jr_stall and id_valid_ff;
            -- Load-use-hazard; do not count stall on flushed instructions (id_valid_ff used to only count first cycle)
            id_mhpmevent_ld_stall_ff_o       <= id_load_stall and id_valid_ff;
            -- Load-use-hazard; do not count stall on flushed instructions (id_valid_ff used to only count first cycle)
            id_mhpmevent_mul_stall_ff_o      <= id_mul_stall and id_valid_ff;
            -- CSR Register access
            id_mhpmevent_csr_instr_ff_o      <= id_csr_access and id_minstret;
            -- Division multicycle active
            id_mhpmevent_div_multicycle_ff_o <= ex_multicycle_i;
            -- coverage on
        end if;
    end process;

    --  ------------------------------------------------------------------------------
    --  -- Assertions
    --  ------------------------------------------------------------------------------
    --  -- the instruction delivered to the ID stage should always be valid
    process(clk_i)
    begin
        if rising_edge(clk_i) then
            if id_instr_valid_int = '1' then
                assert (id_stall_illegal_compress_int = '0') report "Instruction is valid but illegal in ID Stage!" severity failure;
            end if;
        end if;
    end process;

end architecture RTL;

