--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-------------------------------------------------------------------------------------------
--                                                                                       --
-- Description:    Top level module of the RISC-V core.                                  --
--                                                                                       --
--                                                                                       --
--   Pipeline Stages:                                                                    --
--   IF       | ID                   |  EX    |  MEM   |  (optional) MEM2   |  WB        --
--   Bus access (Instructions)                                                           --
--               Decompress & Align                                                      --
--               Decode, RF Read                                                         --
--                                      ALU      (Mult)                                  --
--                                               Data Memory Access                      --
--                                                                             RF Write  --
--                                                                                       --
-------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_core is
    generic(
        NUM_MHPMCOUNTERS : natural := 16
    );
    port(
        clk_i             : in  std_ulogic;
        rst_ni            : in  std_ulogic;
        -- Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
        if_boot_addr_i    : in  std_ulogic_vector(31 downto 0);
        mtvec_addr_i      : in  std_ulogic_vector(31 downto 0);
        hart_id_i         : in  std_ulogic_vector(31 downto 0);
        -- Instruction memory interface
        if_instr_req_o    : out std_ulogic;
        if_instr_gnt_i    : in  std_ulogic;
        id_instr_rvalid_i : in  std_ulogic;
        if_instr_addr_o   : out std_ulogic_vector(31 downto 0);
        id_instr_rdata_i  : in  std_ulogic_vector(31 downto 0);
        -- Data memory interface
        mem_data_req_o    : out std_ulogic;
        mem_data_gnt_i    : in  std_ulogic;
        wb_data_rvalid_i  : in  std_ulogic;
        mem_data_we_o     : out std_ulogic;
        mem_data_be_o     : out std_ulogic_vector(3 downto 0);
        mem_data_addr_o   : out std_ulogic_vector(31 downto 0);
        mem_data_wdata_o  : out std_ulogic_vector(31 downto 0);
        wb_data_rdata_i   : in  std_ulogic_vector(31 downto 0);
        -- Interrupt s
        irq_i             : in  std_ulogic_vector(31 downto 0); -- CLINT interrupts + CLINT extension interrupts
        irq_ack_o         : out std_ulogic;
        irq_id_o          : out std_ulogic_vector(4 downto 0);
        -- CPU Control Signals
        fetch_enable_i    : in  std_ulogic;
        -- VPRO custom extension
        ex_vpro_bundle_o  : out vpro_bundle_t;
        ex_vpro_rdy_i     : in  std_ulogic
    );
end entity eisV_core;

architecture RTL of eisV_core is

    -- Function: Merge EX pipeline records from different sources
    function merge_ex_pipeline_records(a : ex_pipeline_t; b : std_ulogic_vector) return ex_pipeline_t is
        variable output : ex_pipeline_t;
    begin
        output              := a;
        output.ex_csr_rdata := b;
        return output;
    end function merge_ex_pipeline_records;

    signal if_pc : std_ulogic_vector(31 downto 0); -- Program counter in IF stage
    signal id_pc : std_ulogic_vector(31 downto 0); -- Program counter in ID stage

    -- Pipeline Signals
    -- IF/ID signals
    signal if_instr_req_int            : std_ulogic; -- Id stage asserts a req to instruction core interface
    signal if_pc_set                   : std_ulogic;
    signal if_pc_mux_id                : pc_mux_sel_t; -- Mux selector for next PC
    signal if_m_exc_vec_pc_mux_id      : std_ulogic_vector(4 downto 0); -- Mux selector for vectored IRQ PC
    signal id_aligned_instr_valid      : std_ulogic;
    signal id_decompressed_instr       : std_ulogic_vector(31 downto 0);
    signal id_is_compressed_instr      : std_ulogic;
    signal id_illegal_compressed_instr : std_ulogic;
    signal exc_cause                   : std_ulogic_vector(4 downto 0);
    signal if_jump_target_id           : std_ulogic_vector(31 downto 0);
    -- ID/EX signals
    signal ex_pipeline, ex_pipeline_0  : ex_pipeline_t;
    -- Jump and branch target and decision (EX->IF)
    signal ex_branch_decision          : std_ulogic;
    signal ex_jump_target              : std_ulogic_vector(31 downto 0);
    -- EX/MEM signals
    signal mem_pipeline                : mem_pipeline_t;
    -- MEM/WB signals
    signal wb_pipeline                 : wb_pipeline_t;

    -- Forward Data Bundles
    signal ex_fwd_data  : fwd_t;
    signal mem_fwd_data : fwd_bundle_t(MEM_DELAY - 1 downto 0);
    signal wb_fwd_data  : fwd_t;

    -- stall control
    signal id_ready  : std_ulogic;
    signal ex_ready  : std_ulogic;
    signal ex_valid  : std_ulogic;
    signal mem_ready : std_ulogic;
    signal wb_ready  : std_ulogic;

    -- Interrupts
    signal m_irq_enable : std_ulogic;
    signal if_mepc      : std_ulogic_vector(31 downto 0);
    signal mie_bypass   : std_ulogic_vector(31 downto 0);
    signal mip          : std_ulogic_vector(31 downto 0);

    -- CSR
    signal ex_csr_op               : std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0);
    signal ex_csr_addr             : std_ulogic_vector(11 downto 0);
    signal ex_csr_addr_access_gate : std_ulogic_vector(11 downto 0);
    signal ex_csr_rdata            : std_ulogic_vector(31 downto 0);
    signal ex_csr_wdata            : std_ulogic_vector(31 downto 0);

    -- CSR control
    signal ex_csr_access       : std_ulogic;
    signal if_mtvec            : std_ulogic_vector(23 downto 0);
    signal mtvec_mode          : std_ulogic_vector(1 downto 0);
    signal csr_save_cause      : std_ulogic;
    signal csr_save_if         : std_ulogic;
    signal csr_save_id         : std_ulogic;
    signal csr_save_ex         : std_ulogic;
    signal csr_cause           : std_ulogic_vector(5 downto 0);
    signal csr_restore_mret_id : std_ulogic;
    signal if_csr_mtvec_init   : std_ulogic;
    signal ex_pc               : std_ulogic_vector(31 downto 0); -- PC of last executed branch

    -- Performance Counters
    signal mhpmevent_minstret       : std_ulogic;
    signal mhpmevent_load           : std_ulogic;
    signal mhpmevent_store          : std_ulogic;
    signal mhpmevent_jump           : std_ulogic;
    signal mhpmevent_branch         : std_ulogic;
    signal mhpmevent_branch_taken   : std_ulogic;
    signal mhpmevent_compressed     : std_ulogic;
    signal mhpmevent_jr_stall       : std_ulogic;
    signal mhpmevent_imiss          : std_ulogic;
    signal mhpmevent_dmiss          : std_ulogic;
    signal mhpmevent_ld_stall       : std_ulogic;
    signal mhpmevent_mul_stall      : std_ulogic;
    signal mhpmevent_csr_instr      : std_ulogic;
    signal mhpmevent_div_multicycle : std_ulogic;
    signal ex_multicycle            : std_ulogic;

    -- ID performance counter signals
    signal is_decoding      : std_ulogic; -- @suppress "signal is_decoding is never read"
    signal id_perf_imiss    : std_ulogic;
    signal wb_lsu_not_ready : std_ulogic;

    -- Wake signal
    signal ex_rdy                      : std_ulogic;
    signal ex_regfile_data_a_after_fwd : std_ulogic_vector(31 downto 0);
    signal ex_regfile_data_b_after_fwd : std_ulogic_vector(31 downto 0);

    -- for possible sleep / clock gating
    signal wake_from_sleep : std_ulogic; -- @suppress "signal wake_from_sleep is never read"
    signal ctrl_busy       : std_ulogic; -- @suppress "signal ctrl_busy is never read"
    signal if_busy         : std_ulogic; -- @suppress "signal if_busy is never read"
    signal mem_lsu_busy    : std_ulogic; -- @suppress "signal mem_lsu_busy is never read"
begin

    --------------------------------------------------
    --  IF
    --------------------------------------------------
    -- Mux selector for vectored IRQ PC
    if_m_exc_vec_pc_mux_id <= (others => '0') when (mtvec_mode = "00") else exc_cause;

    if_stage_i : eisV_if_stage
        port map(
            clk_i                         => clk_i,
            rst_ni                        => rst_ni,
            -- instruction cache interface
            if_instr_req_o                => if_instr_req_o,
            if_instr_addr_o               => if_instr_addr_o,
            if_instr_gnt_i                => if_instr_gnt_i,
            id_instr_rvalid_i             => id_instr_rvalid_i,
            id_instr_rdata_i              => id_instr_rdata_i,
            -- instruction request control
            if_req_i                      => if_instr_req_int,
            id_aligned_instr_valid_o      => id_aligned_instr_valid,
            id_decompressed_instr_o       => id_decompressed_instr,
            id_is_compressed_instr_o      => id_is_compressed_instr,
            id_illegal_compressed_instr_o => id_illegal_compressed_instr,
            -- control signals
            id_pc_set_i                   => if_pc_set,
            if_pc_mux_i                   => if_pc_mux_id,
            if_mepc_i                     => if_mepc, -- exception return address
            -- trap vector location
            if_m_trap_base_addr_i         => if_mtvec,
            -- boot address
            if_boot_addr_i                => if_boot_addr_i,
            if_m_exc_vec_pc_mux_i         => if_m_exc_vec_pc_mux_id,
            if_csr_mtvec_init_o           => if_csr_mtvec_init,
            -- Jump targets
            if_jump_target_id_i           => if_jump_target_id,
            if_jump_target_ex_i           => ex_jump_target,
            id_pc_i                       => id_pc,
            -- current pcs
            id_pc_o                       => id_pc,
            if_pc_o                       => if_pc,
            if_ready_o                    => open,
            -- pipeline stalls
            id_ready_i                    => id_ready,
            if_busy_o                     => if_busy,
            if_perf_imiss_o               => id_perf_imiss
        );

    -------------------------------------------------
    --  ID
    -------------------------------------------------
    id_stage_i : eisV_id_stage
        port map(
            clk_i                            => clk_i,
            rst_ni                           => rst_ni,
            -- Processor Enable
            fetch_enable_i                   => fetch_enable_i, -- Delayed version so that clock can remain gated until fetch enabled
            wake_from_sleep_o                => wake_from_sleep, -- Wakeup Signal
            -- Interrupt Signals
            irq_i                            => irq_i,
            mie_bypass_i                     => mie_bypass,
            mip_o                            => mip,
            m_irq_enable_i                   => m_irq_enable,
            irq_ack_o                        => irq_ack_o,
            irq_id_o                         => irq_id_o,
            exc_cause_o                      => exc_cause,
            -- Status
            ctrl_busy_o                      => ctrl_busy,
            id_is_decoding_o                 => is_decoding,
            -- IF Interface
            if_instr_req_o                   => if_instr_req_int,
            id_instr_valid_i                 => id_aligned_instr_valid,
            id_instr_i                       => id_decompressed_instr,
            id_is_compressed_instr_i         => id_is_compressed_instr,
            id_illegal_compressed_instr_i    => id_illegal_compressed_instr,
            if_pc_i                          => if_pc,
            id_pc_i                          => id_pc,
            pc_set_o                         => if_pc_set,
            pc_mux_o                         => if_pc_mux_id,
            id_jump_target_o                 => if_jump_target_id, -- jump and branch targets
            ex_jump_target_o                 => ex_jump_target,
            -- WB Data to RF and used for FW
            wb_regfile_waddr_i               => wb_fwd_data.waddr,
            wb_regfile_we_i                  => wb_fwd_data.wen,
            wb_regfile_wdata_i               => wb_fwd_data.wdata,
            -- Stalls
            id_ready_o                       => id_ready,
            ex_ready_i                       => ex_rdy,
            ex_valid_i                       => ex_valid,
            -- Forwared Control 
            ex_fwd_i                         => ex_fwd_data,
            mem_fwd_i                        => mem_fwd_data,
            wb_fwd_i                         => wb_fwd_data,
            wb_ready_i                       => wb_ready,
            -- From the Pipeline ID/EX
            ex_pipeline_o                    => ex_pipeline_0,
            ex_vpro_op_o                     => ex_vpro_bundle_o.vpro_op,
            -- from ALU
            ex_branch_decision_i             => ex_branch_decision,
            ex_multicycle_i                  => ex_multicycle,
            ex_regfile_data_a_after_fwd_i    => ex_regfile_data_a_after_fwd,
            -- CSR ID/EX
            ex_csr_access_o                  => ex_csr_access,
            ex_csr_op_o                      => ex_csr_op,
            csr_cause_o                      => csr_cause,
            csr_save_if_o                    => csr_save_if, -- control signal to save pc
            csr_save_id_o                    => csr_save_id,
            csr_save_ex_o                    => csr_save_ex,
            csr_restore_mret_id_o            => csr_restore_mret_id, -- control signal to restore pc
            csr_save_cause_o                 => csr_save_cause,
            ex_pc_o                          => ex_pc,
            -- Performance Counters
            id_mhpmevent_minstret_ff_o       => mhpmevent_minstret,
            id_mhpmevent_load_ff_o           => mhpmevent_load,
            id_mhpmevent_store_ff_o          => mhpmevent_store,
            id_mhpmevent_jump_ff_o           => mhpmevent_jump,
            id_mhpmevent_branch_o            => mhpmevent_branch,
            id_mhpmevent_branch_taken_ff_o   => mhpmevent_branch_taken,
            id_mhpmevent_compressed_ff_o     => mhpmevent_compressed,
            id_mhpmevent_jr_stall_ff_o       => mhpmevent_jr_stall,
            id_mhpmevent_imiss_ff_o          => mhpmevent_imiss,
            id_mhpmevent_ld_stall_ff_o       => mhpmevent_ld_stall,
            id_mhpmevent_mul_stall_ff_o      => mhpmevent_mul_stall,
            id_mhpmevent_dmiss_ff_o          => mhpmevent_dmiss,
            id_mhpmevent_csr_instr_ff_o      => mhpmevent_csr_instr,
            id_mhpmevent_div_multicycle_ff_o => mhpmevent_div_multicycle,
            id_perf_imiss_i                  => id_perf_imiss,
            id_perf_dmiss_i                  => wb_lsu_not_ready
        );

    assert (wb_fwd_data.wen = '1' and wb_fwd_data.valid = '1') or wb_fwd_data.wen /= '1'
    report "wb_fwd_data will write data to RF but those data are not valid (assumed data in this stage to be always valid!)" severity failure;

    -----------------------------------------------------
    --  EX
    -----------------------------------------------------
    ex_stage_i : eisV_ex_stage
        port map(
            clk_i                => clk_i,
            rst_ni               => rst_ni,
            ex_ready_o           => ex_ready,
            ex_valid_o           => ex_valid,
            mem_ready_i          => mem_ready,
            ex_pipeline_i        => ex_pipeline,
            mem_pipeline_o       => mem_pipeline,
            ex_fwd_o             => ex_fwd_data,
            mem_fwd_i            => mem_fwd_data,
            wb_fwd_i             => wb_fwd_data,
            ex_csr_wdata_o       => ex_csr_wdata,
            ex_csr_addr_o        => ex_csr_addr,
            ex_branch_decision_o => ex_branch_decision,
            ex_multicycle_o      => ex_multicycle,
            ex_operand_a_o       => ex_regfile_data_a_after_fwd,
            ex_operand_b_o       => ex_regfile_data_b_after_fwd
        );

    ex_rdy <= ex_ready and ex_vpro_rdy_i when VPRO_CUSTOM_EXTENSION else ex_ready;

    -- coverage off
    ex_vpro_bundle_o.regfile_op_a      <= ex_regfile_data_a_after_fwd when VPRO_CUSTOM_EXTENSION else (others => '-');
    ex_vpro_bundle_o.regfile_op_b      <= ex_regfile_data_b_after_fwd when VPRO_CUSTOM_EXTENSION else (others => '-');
    ex_vpro_bundle_o.regfile_op_a_addr <= ex_pipeline.operand_a_addr when VPRO_CUSTOM_EXTENSION else (others => '-');
    ex_vpro_bundle_o.valid             <= ex_valid when VPRO_CUSTOM_EXTENSION else '-';
    ex_vpro_bundle_o.imm_s_type        <= ex_pipeline.operand_b_data_pre(11 downto 0) when VPRO_CUSTOM_EXTENSION else (others => '-');
    ex_vpro_bundle_o.imm_u_type        <= ex_pipeline.operand_b_data_pre(31 downto 12) when VPRO_CUSTOM_EXTENSION else (others => '-');
    -- coverage on

    -----------------------------------------------------
    -- MEM Stage  
    -----------------------------------------------------
    mem_stage_i : eisV_mem_stage
        port map(
            clk_i            => clk_i,
            rst_ni           => rst_ni,
            mem_ready_o      => mem_ready,
            wb_ready_i       => wb_ready,
            mem_pipeline_i   => mem_pipeline,
            wb_pipeline_o    => wb_pipeline,
            mem_fwd_data_o   => mem_fwd_data,
            mem_busy_o       => mem_lsu_busy,
            mem_data_req_o   => mem_data_req_o,
            mem_data_gnt_i   => mem_data_gnt_i,
            mem_data_addr_o  => mem_data_addr_o,
            mem_data_we_o    => mem_data_we_o,
            mem_data_be_o    => mem_data_be_o,
            mem_data_wdata_o => mem_data_wdata_o
        );
    -----------------------------------------------------
    -- WB Stage  
    -----------------------------------------------------
    wb_stage_i : eisV_wb_stage
        port map(
            clk_i            => clk_i,
            rst_ni           => rst_ni,
            wb_ready_o       => wb_ready,
            wb_pipeline_i    => wb_pipeline,
            wb_fwd_data_o    => wb_fwd_data,
            wb_data_rdata_i  => wb_data_rdata_i,
            wb_data_rvalid_i => wb_data_rvalid_i
        );

    wb_lsu_not_ready <= (not wb_ready) or (not mem_ready);

    --------------------------------------
    --   Control and Status Registers   --
    --------------------------------------
    -- coverage off
    cs_registers_i : eisV_cs_register
        generic map(
            IMPLEMENTED_COUNTERS_G => NUM_MHPMCOUNTERS
        )
        port map(
            clk_i                      => clk_i,
            rst_ni                     => rst_ni,
            -- Hart ID from outside
            hart_id_i                  => hart_id_i,
            if_mtvec_o                 => if_mtvec,
            mtvec_mode_o               => mtvec_mode,
            -- mtvec address
            mtvec_addr_i               => mtvec_addr_i,
            -- Interface to CSRs (SRAM like)
            if_csr_mtvec_init_i        => if_csr_mtvec_init,
            ex_csr_addr_i              => ex_csr_addr_access_gate,
            ex_csr_wdata_i             => ex_csr_wdata,
            ex_csr_op_i                => ex_csr_op,
            ex_csr_rdata_o             => ex_csr_rdata, -- async read
            -- Interrupt related control signals
            mie_bypass_o               => mie_bypass,
            mip_i                      => mip,
            m_irq_enable_o             => m_irq_enable,
            if_mepc_o                  => if_mepc,
            if_pc_i                    => if_pc,
            id_pc_i                    => id_pc,
            ex_pc_i                    => ex_pc,
            csr_save_if_i              => csr_save_if,
            csr_save_id_i              => csr_save_id,
            csr_save_ex_i              => csr_save_ex,
            csr_restore_mret_i         => csr_restore_mret_id,
            csr_cause_i                => csr_cause,
            csr_save_cause_i           => csr_save_cause,
            -- performance counter related signals
            mhpmevent_minstret_i       => mhpmevent_minstret,
            mhpmevent_load_i           => mhpmevent_load,
            mhpmevent_store_i          => mhpmevent_store,
            mhpmevent_jump_i           => mhpmevent_jump,
            mhpmevent_branch_i         => mhpmevent_branch,
            mhpmevent_branch_taken_i   => mhpmevent_branch_taken,
            mhpmevent_compressed_i     => mhpmevent_compressed,
            mhpmevent_jr_stall_i       => mhpmevent_jr_stall,
            mhpmevent_imiss_i          => mhpmevent_imiss,
            mhpmevent_dmiss_i          => mhpmevent_dmiss,
            mhpmevent_ld_stall_i       => mhpmevent_ld_stall,
            mhpmevent_mul_stall_i      => mhpmevent_mul_stall,
            mhpmevent_csr_instr_i      => mhpmevent_csr_instr,
            mhpmevent_div_multicycle_i => mhpmevent_div_multicycle
        );
    -- coverage on

    ex_pipeline             <= merge_ex_pipeline_records(ex_pipeline_0, ex_csr_rdata);
    ex_csr_addr_access_gate <= ex_csr_addr when (ex_csr_access = '1') else (others => '0');

end architecture RTL;

