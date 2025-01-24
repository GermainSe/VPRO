--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System, Single Lane Top Entity                    #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;    -- or_reduce

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity lane_top is
    generic(
        minmax_instance_g       : boolean := false;
        bit_reversal_instance_g : boolean := false;
        LANE_LABLE_g            : string  := "unknown"
    );
    port(
        -- global control --
        clk_i                     : in  std_ulogic; -- global clock, rising edge
        rst_i                     : in  std_ulogic; -- global reset, async, polarity: see package
        -- instruction interface --
        cmd_i                     : in  vpro_command_t;
        cmd_we_i                  : in  std_ulogic;
        cmd_busy_o                : out std_ulogic;
        cmd_req_o                 : out std_ulogic;
        cmd_isblocking_o          : out std_ulogic;
        mul_shift_i               : in  std_ulogic_vector(04 downto 0);
        mac_shift_i               : in  std_ulogic_vector(04 downto 0);
        mac_init_source_i         : in  MAC_INIT_SOURCE_t;
        mac_reset_mode_i          : in  MAC_RESET_MODE_t;
        -- chaining (data + flags) --
        lane_chain_input_i        : in  lane_chain_data_input_t;
        lane_chain_input_read_o   : out lane_chain_data_input_read_t;
        lane_chain_output_o       : out lane_chain_data_output_t;
        lane_chain_output_stall_i : in  std_ulogic
    );
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of lane_top : entity is "true";
end lane_top;

architecture rtl of lane_top is

    -- looping variables --
    signal stall_vector_increment : std_ulogic                                           := '0';
    signal vector_increment_reset : std_ulogic                                           := '0';
    signal x_cnt                  : std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0) := (others => '0');
    signal y_cnt                  : std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0) := (others => '0');
    signal z_cnt                  : std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0) := (others => '0');
    signal final_iteration        : std_ulogic                                           := '0';

    signal first_iteration, first_iteration_nxt : pipe1_t(0 to num_pstages_c - 1) := (others => '0');

    -- register file access --
    signal src2_addr                : std_ulogic_vector(09 downto 0); -- from addressing units / including stall 
    signal src1_addr, src1_addr_nxt : pipe10_t(0 to num_pstages_c - 1);

    signal rf_we, rf_we_no_stall, rf_we_nxt                : std_ulogic                                          := '0';
    signal rf_flag_we, rf_flag_we_no_stall, rf_flag_we_nxt : std_ulogic                                          := '0';
    -- register destination address --
    signal dst_addr, dst_addr_nxt                          : pipe10_t(0 to num_pstages_c - 1)                    := (others => (others => '0')); -- from addressing units
    signal src1_rdata, src2_rdata                          : std_ulogic_vector(rf_data_width_c - 1 downto 0)     := (others => '0'); -- actual data read from register file (BRAM)
    signal src1_flag_data                                  : std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0) := (others => '0');
    signal src1_rflag                                      : std_ulogic_vector(01 downto 0)                      := (others => '0'); -- actual flags read from register file (BRAM)
    signal rf_write_data, rf_write_data_nxt                : std_ulogic_vector(rf_data_width_c - 1 downto 0)     := (others => '0'); -- register file write data
    signal rf_write_flag, rf_write_flag_nxt                : std_ulogic_vector(01 downto 0)                      := (others => '0'); -- register file write flag
    signal rf_rd_ce, rf_wr_ce                              : std_ulogic                                          := '0';

    -- control arbiter --
    type arbiter_t is (S_IDLE, S_START_EXECUTE, S_EXECUTE);
    signal arbiter, arbiter_nxt : arbiter_t      := S_IDLE;
    signal cmd_reg, cmd_reg_nxt : vpro_command_t := vpro_cmd_zero_c; -- instruction register (input register)

    -- command register -- 
    signal vcmd, vcmd_nxt           : pipeCmd_t(0 to num_pstages_c - 1);
    signal enable, enable_nxt       : pipe1_t(0 to num_pstages_c - 1) := (others => '0'); -- enable stage
    signal condition, condition_nxt : pipe1_t(0 to num_pstages_c - 1) := (others => '0'); -- conditional check result

    --	signal enable_last_valid, enable_last_valid_nxt, enable_stall_exclusive : pipe1_t( 0 to num_pstages_c - 1); -- enable stage without stall
    signal pipline_isblocking           : std_ulogic                      := '0';

    -- alu --
    signal address_dsp_ce, alu_dsp_ce   : std_ulogic;
    signal alu_opa, alu_opb, alu_opc    : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal alu_opa_buf, alu_opa_buf_nxt : std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- including flags
    signal alu_opb_buf, alu_opb_buf_nxt : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal alu_opa_sel, alu_opa_sel_nxt : std_ulogic;
    signal alu_opb_sel, alu_opb_sel_nxt : std_ulogic;
    signal alu_result                   : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal old_flags, old_flags_nxt     : std_ulogic_vector(01 downto 0);
    signal new_alu_flags                : std_ulogic_vector(01 downto 0);
    signal src1_src, src1_src_nxt       : operand_src_t;
    signal src2_src, src2_src_nxt       : operand_src_t;

    -- register for global configuration registers -- 
    signal mul_shift, mac_shift : std_ulogic_vector(04 downto 0);
    --attribute keep : string;
    --attribute keep of alu_opa_buf : signal is "true";
    --attribute keep of alu_opb_buf : signal is "true";
    --attribute keep of alu_opa_sel : signal is "true";
    --attribute keep of alu_opb_sel : signal is "true";

    -- chaining buffer --
    signal lane_chain_src, lane_chain_src_nxt : pipe1_t(0 to num_pstages_c - 1);
--coverage off
    signal lane_chain_adr, lane_chain_adr_nxt : pipe1_t(0 to num_pstages_c - 1);
--coverage on
    signal ls_chain_src, ls_chain_src_nxt     : pipe1_t(0 to num_pstages_c - 1);
--coverage off
    signal ls_chain_adr, ls_chain_adr_nxt     : pipe1_t(0 to num_pstages_c - 1);
--coverage on
    signal stall_pipeline_chain_out_ff        : std_ulogic := '0';
    signal chain_o_nxt, chain_o_no_stall      : chain_data_t;

    -- stall
    -- stalls pipeline all before out rd stage
    constant pipeline_chain_out_stage_c                             : natural                         := 9;
    signal stall_pipeline_chain_in_ff                               : std_ulogic                      := '0';
    -- stalls pipeline all before in rd stage
    constant pipeline_chain_in_stage_c                              : natural                         := 3;            
--coverage off
    signal stall_pipeline_chain_in_adr_ff                           : pipe1_t(0 to num_pstages_c - 1) := (others => '0'); -- registers for input stall caused by indirect addressing            
--coverage on
    constant pipeline_chain_in_adr_stage_c                          : natural                         := 1;
    signal stall_pipeline_chain_in_ff2, stall_pipeline_chain_in_nxt : std_ulogic;            
--coverage off
    signal stall_pipeline_chain_in_adr_nxt                          : std_ulogic;            
--coverage on

    -- offset
    signal src1_offset : std_ulogic_vector(vpro_cmd_src1_offset_len_c - 1 downto 0);
    signal src2_offset : std_ulogic_vector(vpro_cmd_src2_offset_len_c - 1 downto 0);
    signal dst_offset  : std_ulogic_vector(vpro_cmd_dst_offset_len_c - 1 downto 0);

    signal dsp_a_result, dsp_b_result, dsp_c_result : std_ulogic_vector(9 downto 0);

    -- min/max vector uses calculated address as result if selected 
    signal min_max_address_nxt, min_max_address : std_ulogic_vector(09 downto 0);
    signal reset_accu, reset_accu_nxt           : pipe1_t(0 to num_pstages_c - 1);
    signal mac_init_source                      : MAC_INIT_SOURCE_t;
    signal mac_reset_mode                       : MAC_RESET_MODE_t;
    signal vector_incr_xend                     : std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
    signal vector_incr_yend                     : std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
    signal vector_incr_zend                     : std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
    
    signal block_pipeline : std_ulogic_vector(5 downto 0);
begin

    -- stall logic
    address_dsp_ce <= '1' when ((stall_pipeline_chain_in_ff or stall_pipeline_chain_out_ff) = '0') and --    
--coverage off
(stall_pipeline_chain_in_adr_ff(1) = '0') --
-- coverage on
else
                      '0';
    alu_dsp_ce     <= '1' when (stall_pipeline_chain_out_ff = '0') else '0';
    rf_rd_ce       <= '1' when ((stall_pipeline_chain_in_ff2 or stall_pipeline_chain_out_ff) = '0') else
                      '0';
    rf_wr_ce       <= '1' when (stall_pipeline_chain_out_ff = '0') else '0';

    -- Blocking Logic depends on cmd up to stage 4
    -- 	 if stage 5 is blocking, next cmd can start next cycle
    -- 	 next cmd reads from RF when current stage 5 has completed the whole pipeline (stage 9 - wb)
    
    block_pipeline(0) <= vcmd_nxt(0).blocking(0) and enable_nxt(0);
    block_pipeline(1) <= vcmd(0).blocking(0) and enable(0);
    block_pipeline(2) <= vcmd(1).blocking(0) and enable(1);
    block_pipeline(3) <= vcmd(2).blocking(0) and enable(2);
    block_pipeline(4) <= vcmd(3).blocking(0) and enable(3);
    block_pipeline(5) <= vcmd(4).blocking(0) and enable(4);
    
    pipline_isblocking <= or_reduce(block_pipeline);
    
--    pipline_isblocking <= (vcmd_nxt(0).blocking(0) and enable_nxt(0)) or --
--                          (vcmd(0).blocking(0) and enable(0)) or --
--                          (vcmd(1).blocking(0) and enable(1)) or --
--                          (vcmd(2).blocking(0) and enable(2)) or --
--                          (vcmd(3).blocking(0) and enable(3)) or --
--                          (vcmd(4).blocking(0) and enable(4)); -- or --
    --((5) and enable(5));   -- no longer needed, as the blocking signal is buffered in unit's cmd ctrl unit one cycle

    cmd_isblocking_o <= pipline_isblocking;

    -- Control FSM (basically Stage 0 to start new commands) -------------------------------------
    -- -------------------------------------------------------------------------------------------
    control_arbiter_comb : process(arbiter, cmd_i, cmd_we_i, final_iteration, cmd_reg, stall_pipeline_chain_in_ff, 
        stall_pipeline_chain_out_ff, stall_pipeline_chain_in_adr_ff(0)
    )
    begin
        -- defaults --
        arbiter_nxt              <= arbiter; -- arbiter
        cmd_reg_nxt              <= cmd_reg; -- instruction register
        cmd_req_o                <= '0';
        cmd_busy_o               <= '1';
        vector_increment_reset   <= '0';

        -- state machine --
        case arbiter is
            when S_IDLE =>              -- no instruction is executed. wait for new instruction to arrive
                if (stall_pipeline_chain_out_ff = '0') then --
                    if (stall_pipeline_chain_in_ff = '0') then --
                        --coverage off
                        if (stall_pipeline_chain_in_adr_ff(0) = '0') then
                            --coverage on
                            vector_increment_reset <= '1'; -- to disable unneeded toggle of counter signals 
                            cmd_req_o              <= '1';
                            if (cmd_we_i = '1') then -- valid instruction
                                cmd_reg_nxt <= cmd_i;
                                arbiter_nxt <= S_START_EXECUTE;
                            else
                                cmd_busy_o <= '0';
                            end if;
                        end if;
                    end if;
                end if;

            when S_START_EXECUTE =>
                if (stall_pipeline_chain_out_ff = '0') then --
                    if (stall_pipeline_chain_in_ff = '0') then --
                        --coverage off
                        if (stall_pipeline_chain_in_adr_ff(0) = '0' ) then
                            --coverage on
                            vector_increment_reset <= '1';
                            arbiter_nxt            <= S_EXECUTE;
                        end if;
                    end if;
                end if;

            when S_EXECUTE =>           -- execute command, buffer is empty
                if (stall_pipeline_chain_out_ff = '0') then --
                    if (stall_pipeline_chain_in_ff = '0') then --
                        --coverage off
                        if (stall_pipeline_chain_in_adr_ff(0) = '0') then
                            --coverage on

                            if (final_iteration = '1') then -- all iterations done?
                                arbiter_nxt <= S_IDLE;
                                cmd_req_o   <= '1';
                            end if;
                            if (cmd_we_i = '1') then
                                cmd_reg_nxt <= cmd_i;
                                arbiter_nxt <= S_START_EXECUTE;
                            end if;
                        end if;
                    end if;
                end if;
                
        end case;
    end process control_arbiter_comb;

    -- FSM - sync --
    control_arbiter_sync : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then -- @suppress "Incomplete reset branch: missing asynchronous reset for registers 'cmd_buffer_ff', 'cmd_reg'"
            arbiter <= S_IDLE;
        --                cmd_reg <= vpro_cmd_zero_c;
        elsif rising_edge(clk_i) then
            arbiter       <= arbiter_nxt;
            cmd_reg       <= cmd_reg_nxt; -- no stall, due to FSM storing incoming cmd
        end if;
    end process control_arbiter_sync;

    -- Index Counters (Stage 0)  -----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    stall_vector_increment <= stall_pipeline_chain_in_ff or stall_pipeline_chain_out_ff
--coverage off
 or stall_pipeline_chain_in_adr_ff(0)
--coverage on
    ;

    vector_incr_xend <= cmd_reg.x_end;
    vector_incr_yend <= cmd_reg.y_end;
    vector_incr_zend <= cmd_reg.z_end;
    index_incrementer : vector_incrementer
        port map(
            clk_i             => clk_i,
            stall_i           => stall_vector_increment,
            reset_i           => vector_increment_reset,
            x_end_i           => vector_incr_xend,
            y_end_i           => vector_incr_yend,
            z_end_i           => vector_incr_zend,
            x_o               => x_cnt,
            y_o               => y_cnt,
            z_o               => z_cnt,
            final_iteration_o => final_iteration
        );
    -- Pipeline Register (Stage 0 to end)---------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    process(x_cnt, y_cnt, z_cnt, mac_reset_mode)
    begin
        reset_accu_nxt(1) <= '0';
        case (mac_reset_mode) is
            when NEVER =>
            when ONCE =>
                if unsigned(x_cnt) = 0 and unsigned(y_cnt) = 0 and unsigned(z_cnt) = 0 then
                    reset_accu_nxt(1) <= '1';
                end if;
            when Z_INCREMENT =>
                if unsigned(x_cnt) = 0 and unsigned(y_cnt) = 0 then
                    reset_accu_nxt(1) <= '1';
                end if;
            when Y_INCREMENT =>
                if unsigned(x_cnt) = 0 then
                    reset_accu_nxt(1) <= '1';
                end if;
            when X_INCREMENT =>
                reset_accu_nxt(1) <= '1';
        end case;
    end process;

    reset_accu_nxt(2 to reset_accu'length - 1) <= reset_accu(1 to reset_accu'length - 1 - 1);

    -- Instruction Decoding --
    vcmd_nxt(0) <= cmd_reg;
    vcmd_nxt(1 to vcmd'length - 1) <= vcmd(0 to vcmd'length - 1 - 1);

    first_iteration_nxt(0)                                   <= vector_increment_reset;
    first_iteration_nxt(1 to first_iteration_nxt'length - 1) <= first_iteration(0 to first_iteration'length - 2);

    assert enable(0) = '0' or (enable(0) = '1' and vcmd(0).fu_sel /= fu_memory_c) report "ALU Lane got a memory command!" severity error;

    enable_nxt_process : process(enable, old_flags, arbiter, vcmd, stall_pipeline_chain_in_ff, stall_pipeline_chain_in_adr_ff(0), final_iteration, condition)
        variable n_v, z_v : std_ulogic;
    begin
        enable_nxt(0)                      <= '1';
        enable_nxt(1 to enable'length - 1) <= enable(0 to enable'length - 1 - 1);

        condition_nxt(0)                         <= '-';
        condition_nxt(1 to condition'length - 1) <= condition(0 to condition'length - 1 - 1);

        -- Enable (stage 0) --------------------------------------------------------
        -- -------------------------------------------------------------------------
        if (arbiter = S_IDLE) or (arbiter = S_EXECUTE and final_iteration = '1') then -- execute command
            enable_nxt(0) <= '0';
        end if;

        -- Condition Check (stage 6) --------------------------------------------------------------
        -- ----------------------------------------------------------------------------------------
        -- extract flags --
        z_v := old_flags(z_fbus_c);
        n_v := old_flags(n_fbus_c);

        -- is conditional operation at all? --
        condition_nxt(7) <= '1';
        if (vcmd(6).fu_sel = fu_condmove_c) then -- conditional operation
            -- condition fullfilled? --
            case vcmd(6).func is        -- take cond directly from the instruction reg
                when func_mv_ze_c =>
                    condition_nxt(7) <= z_v;
                    enable_nxt(7)    <= enable(6) and z_v; -- no move ?
                when func_mv_nz_c =>
                    condition_nxt(7) <= not z_v;
                    enable_nxt(7)    <= enable(6) and not z_v; -- no move ?
                when func_mv_mi_c =>
                    condition_nxt(7) <= n_v;
                    enable_nxt(7)    <= enable(6) and n_v; -- no move ?
                when func_mv_pl_c =>
                    condition_nxt(7) <= not n_v;
                    enable_nxt(7)    <= enable(6) and not n_v; -- no move ?
                when func_mull_neg_c | func_mulh_neg_c | func_shift_ar_neg_c =>
                    condition_nxt(7) <= n_v;
                when func_mull_pos_c | func_mulh_pos_c | func_shift_ar_pos_c =>
                    condition_nxt(7) <= not n_v;
                when others =>
                    enable_nxt(7)    <= '0';   -- func_nop_c
                    condition_nxt(7) <= '1';
            end case;
        end if;

        -- if stall due to address or data chaining, fill in with no enable from in stage
        if (stall_pipeline_chain_in_ff = '1') then
            enable_nxt(pipeline_chain_in_stage_c + 1) <= '0';
        end if;            
--coverage off
        if (stall_pipeline_chain_in_adr_ff(0) = '1') then
            enable_nxt(pipeline_chain_in_adr_stage_c + 1) <= '0';
        end if;            
--coverage on

    end process enable_nxt_process;

    -- with reset --
    pipeline_regs_rst : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then
            enable <= (others => '0');
        elsif rising_edge(clk_i) then
            enable <= enable_nxt;

            -- Stall?            
--coverage off
            if (stall_pipeline_chain_in_adr_ff(0) = '1') then
                for i in 0 to pipeline_chain_in_adr_stage_c loop
                    enable(i) <= enable(i);
                end loop;
            end if;            
--coverage on
            if (stall_pipeline_chain_in_ff = '1') then
                for i in 0 to pipeline_chain_in_stage_c loop
                    enable(i) <= enable(i);
                end loop;
            end if;
            if (stall_pipeline_chain_out_ff = '1') then
                for i in 0 to pipeline_chain_out_stage_c loop
                    enable(i) <= enable(i);
                end loop;
            end if;
        end if;
    end process pipeline_regs_rst;

    -- without reset --
    pipeline_regs : process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- no stall 
            vcmd            <= vcmd_nxt;
            first_iteration <= first_iteration_nxt;
            dst_addr        <= dst_addr_nxt;
            src1_addr       <= src1_addr_nxt;
            old_flags       <= old_flags_nxt;
            -- alu operand buffer --
            alu_opa_buf     <= alu_opa_buf_nxt;
            alu_opb_buf     <= alu_opb_buf_nxt;
            alu_opa_sel     <= alu_opa_sel_nxt;
            alu_opb_sel     <= alu_opb_sel_nxt;
            reset_accu      <= reset_accu_nxt;
            -- global register buffer --
            mul_shift       <= mul_shift_i;
            mac_shift       <= mac_shift_i;
            mac_init_source <= mac_init_source_i;
            mac_reset_mode  <= mac_reset_mode_i;

            -- data & address chaining            
--coverage off
            lane_chain_adr <= lane_chain_adr_nxt;   
            ls_chain_adr   <= ls_chain_adr_nxt;         
--coverage on
            lane_chain_src <= lane_chain_src_nxt;
            ls_chain_src   <= ls_chain_src_nxt;
            src1_src       <= src1_src_nxt;
            src2_src       <= src2_src_nxt;

            condition <= condition_nxt;

            if (stall_pipeline_chain_in_ff2 = '1') or (stall_pipeline_chain_out_ff = '1') --            
--coverage off
or (stall_pipeline_chain_in_adr_ff(3) = '1') --
--coverage on
then
                alu_opa_buf <= alu_opa_buf;
                alu_opb_buf <= alu_opb_buf;
                alu_opa_sel <= alu_opa_sel;
                alu_opb_sel <= alu_opb_sel;
            end if;

            if (stall_pipeline_chain_in_ff = '1') or (stall_pipeline_chain_out_ff = '1') --            
--coverage off
or (stall_pipeline_chain_in_adr_ff(2) = '1') --            
--coverage on
then
                vcmd            <= vcmd;
                first_iteration <= first_iteration;
                old_flags       <= old_flags;
                reset_accu      <= reset_accu;

                lane_chain_adr <= lane_chain_adr;
                ls_chain_adr   <= ls_chain_adr;
                lane_chain_src <= lane_chain_src;
                ls_chain_src   <= ls_chain_src;
                src1_src       <= src1_src;
                src2_src       <= src2_src;
            end if;

            if (stall_pipeline_chain_in_ff = '1') then
                for i in 0 to pipeline_chain_in_stage_c loop
                    condition(i)   <= condition(i);
                end loop;
            end if;
            
--coverage off
            if (stall_pipeline_chain_in_adr_ff(0) = '1') then
                for i in 0 to pipeline_chain_in_adr_stage_c loop
                    condition(i)   <= condition(i);
                end loop;
            end if;            
--coverage on

            if (stall_pipeline_chain_out_ff = '1') then
                dst_addr  <= dst_addr;
                src1_addr <= src1_addr;
                for i in 0 to pipeline_chain_out_stage_c loop -- equal for all stages -- REMOVE (i)?
                    condition(i)   <= condition(i);
                    dst_addr(i)    <= dst_addr(i);
                    src1_addr(i)   <= src1_addr(i);
                end loop;
            end if;

            if (arbiter = S_IDLE) then  -- no matter if stall, due to new cmd start even if stall (if idle)
                vcmd               <= vcmd_nxt;
                first_iteration(0) <= first_iteration_nxt(0);
            end if;
        end if;
    end process pipeline_regs;

    -- Chain Input Decode for Indirect Adressing (stage 0) ---------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- chain active for stage 1 chain_rd_o signal            
--coverage off
    lane_chain_adr_nxt(0) <= '1' when ((vcmd_nxt(0).src1_sel = srcsel_indirect_chain_neighbor_c) or --
                                       (vcmd_nxt(0).src2_sel = srcsel_indirect_chain_neighbor_c) or --
                                       (vcmd_nxt(0).dst_sel = srcsel_indirect_chain_neighbor_c)) and (enable_nxt(0) = '1') else
                             '0';
    ls_chain_adr_nxt(0) <= '1' when ((vcmd_nxt(0).src1_sel = srcsel_indirect_chain_ls_c) or (vcmd_nxt(0).src2_sel = srcsel_indirect_chain_ls_c) or (vcmd_nxt(0).dst_sel = srcsel_indirect_chain_ls_c)) and (enable_nxt(0) = '1') else
                           '0';

    lane_chain_adr_nxt(1 to lane_chain_adr'length - 1) <= lane_chain_adr(0 to lane_chain_adr'length - 1 - 1);
    ls_chain_adr_nxt(1 to ls_chain_adr'length - 1)     <= ls_chain_adr(0 to ls_chain_adr'length - 1 - 1);            
--coverage on
        
    -- select source of offsets (stage 2)
    src1_offset_mux_i : addressing_offset_mux
        generic map(OFFSET_WIDTH_g => vpro_cmd_dst_offset_len_c)
        port map(
            cmd_src_sel_i => vcmd(2).src1_sel,
            cmd_offset_i  => vcmd(2).src1_offset,
            chain_input_i => lane_chain_input_i,
            offset_o      => src1_offset
        );
    src2_offset_mux_i : addressing_offset_mux
        generic map(OFFSET_WIDTH_g => vpro_cmd_src2_offset_len_c)
        port map(
            cmd_src_sel_i => vcmd(2).src2_sel,
            cmd_offset_i  => vcmd(2).src2_offset,
            chain_input_i => lane_chain_input_i,
            offset_o      => src2_offset
        );                
    dst_offset_mux_i : addressing_offset_mux
        generic map(OFFSET_WIDTH_g => vpro_cmd_dst_offset_len_c)
        port map(
            cmd_src_sel_i => vcmd(2).dst_sel,
            cmd_offset_i  => vcmd(2).dst_offset,
            chain_input_i => lane_chain_input_i,
            offset_o      => dst_offset
        );

    -- Addressing Units (Stage 0..3) -------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- operand A / src1 --
    address_unit_src1 : address_unit
        generic map(
            ADDR_WIDTH_g        => 10,
            OFFSET_WIDTH_g      => 10,
            OFFSET_REGISTERED_g => true
        )
        port map(
            -- global control --
            ce_i     => address_dsp_ce,
            clk_i    => clk_i,
            -- looping variables --
            x_i      => x_cnt,
            y_i      => y_cnt,
            z_i      => z_cnt,
            -- operands --
            alpha_i  => vcmd(0).src1_alpha,
            beta_i   => vcmd(0).src1_beta,
            gamma_i  => vcmd(0).src1_gamma,
            offset_i => src1_offset,
            -- final address --
            addr_o   => dsp_a_result
        );
    -- operand B / src2 --
    address_unit_src2 : address_unit
        generic map(
            ADDR_WIDTH_g        => 10,
            OFFSET_WIDTH_g      => 10,
            OFFSET_REGISTERED_g => true
        )
        port map(
            -- global control --
            ce_i     => address_dsp_ce,
            clk_i    => clk_i,
            -- looping variables --
            x_i      => x_cnt,
            y_i      => y_cnt,
            z_i      => z_cnt,
            -- operands --
            alpha_i  => vcmd(0).src2_alpha,
            beta_i   => vcmd(0).src2_beta,
            gamma_i  => vcmd(0).src2_gamma,
            offset_i => src2_offset,
            -- final address --
            addr_o   => dsp_b_result
        );
    -- destination on own dsp --
    address_unit_dst : address_unit
        generic map(
            ADDR_WIDTH_g        => 10,
            OFFSET_WIDTH_g      => 10,
            OFFSET_REGISTERED_g => true
        )
        port map(
            -- global control --
            ce_i     => address_dsp_ce, -- only cares on stall_out, not on stall_in
            clk_i    => clk_i,
            -- looping variables --
            x_i      => x_cnt,
            y_i      => y_cnt,
            z_i      => z_cnt,
            -- operands --
            alpha_i  => vcmd(0).dst_alpha,
            beta_i   => vcmd(0).dst_beta,
            gamma_i  => vcmd(0).dst_gamma,
            offset_i => dst_offset,
            -- final address --
            addr_o   => dsp_c_result    -- ~ dst_addr(3)
        );

    -- Addressing Units Results (Stage 3) --------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    src1_addr_nxt(4)                             <= dsp_a_result;
    src1_addr_nxt(5 to src1_addr_nxt'length - 1) <= src1_addr(4 to src1_addr'length - 1 - 1);
    src2_addr                                    <= dsp_b_result;
    dst_addr_nxt(4)                              <= dsp_c_result;
    dst_addr_nxt(5 to dst_addr'length - 1)       <= dst_addr(4 to dst_addr'length - 1 - 1);

    -- Chain Data Input Decode (stage 2) --------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- chain active for stage 3 chain_rd_o signal
    lane_chain_src_nxt(2) <= '1' when ((vcmd(1).src1_sel = srcsel_chain_neighbor_c) or (vcmd(1).src2_sel = srcsel_chain_neighbor_c)) and (enable(1) = '1') else
                             '0';
    ls_chain_src_nxt(2) <= '1' when ((vcmd(1).src1_sel = srcsel_ls_c) or (vcmd(1).src2_sel = srcsel_ls_c)) and (enable(1) = '1') else '0';

    lane_chain_src_nxt(3 to lane_chain_src'length - 1) <= lane_chain_src(2 to lane_chain_src'length - 1 - 1);
    ls_chain_src_nxt(3 to ls_chain_src'length - 1)     <= ls_chain_src(2 to ls_chain_src'length - 1 - 1);

    -- Chain Input Available (stage 2) & READ (stage 3) -------------------------------------------
    -- --------------------------------------------------------------------------------------------
    input_stall : process(lane_chain_adr(0), ls_chain_adr(0), lane_chain_adr(1), ls_chain_adr(1), stall_pipeline_chain_in_adr_ff, lane_chain_src(3), ls_chain_src(3), lane_chain_src(2), ls_chain_src(2), stall_pipeline_chain_in_ff, stall_pipeline_chain_out_ff, lane_chain_input_i(0), lane_chain_input_i(2)
    )
    begin
--coverage off
        stall_pipeline_chain_in_adr_nxt <= '0';
--coverage on
        stall_pipeline_chain_in_nxt     <= '0';
        lane_chain_input_read_o         <= (others => '0');

        -- address chaining
--coverage off
        -- stall occurs if chaining fifo is empty or previous command requires data chaining (stage 3)
        if (lane_chain_adr(0) = '1') then
            if (lane_chain_input_i(0).data_avai = '0' or lane_chain_src(2) = '1') then
                stall_pipeline_chain_in_adr_nxt <= '1';
            end if;
        end if;
        if (ls_chain_adr(0) = '1') then
            if (lane_chain_input_i(2).data_avai = '0' or ls_chain_src(2) = '1') then
                stall_pipeline_chain_in_adr_nxt <= '1';
            end if;
        end if;

        -- generate read out for address chains
        -- stall_pipeline_chain_in_ff has to be checked for commandos that use both data and address chaining
        -- if a stall in the data chain is present, the readout on the address chain is disabled until the stall is resolved
        if (lane_chain_adr(1) = '1') then
            if (stall_pipeline_chain_in_adr_ff(0) = '0' and stall_pipeline_chain_in_ff = '0') then
                lane_chain_input_read_o(0) <= '1';
            elsif (lane_chain_input_i(0).data_avai = '0') then
                stall_pipeline_chain_in_adr_nxt <= '1';
            end if;
        end if;
        if (ls_chain_adr(1) = '1') then
            if (stall_pipeline_chain_in_adr_ff(0) = '0' and stall_pipeline_chain_in_ff = '0') then
                lane_chain_input_read_o(2) <= '1';
            elsif (lane_chain_input_i(2).data_avai = '0') then
                stall_pipeline_chain_in_adr_nxt <= '1';
            end if;
        end if;
--coverage on

        -- data chaining
        -- left
        if (lane_chain_src(2) = '1') then
            if (lane_chain_input_i(0).data_avai = '0') then
                stall_pipeline_chain_in_nxt <= '1';
            end if;
        end if;
        -- ls
        if (ls_chain_src(2) = '1') then
            if (lane_chain_input_i(2).data_avai = '0') then
                stall_pipeline_chain_in_nxt <= '1';
            end if;
        end if;

        -- generate read out for data chains
        -- enable for stage 3 has to be checked for commandos that use both data and address chaining
        -- if a stall in the address chain is present, the readout on the data chain has to be disabled until stage 3 becomes active again
        if (lane_chain_src(3) = '1') then
            if (stall_pipeline_chain_in_ff = '0') then 
                lane_chain_input_read_o(0) <= '1';
            else                        -- keep stall high if no data available (needed here in stage 3 if short vector not need chain input in stage 2)
                if (lane_chain_input_i(0).data_avai = '0') then
                    stall_pipeline_chain_in_nxt <= '1';
                end if;
            end if;
        end if;
        -- ls
        if (ls_chain_src(3) = '1') then
            if (stall_pipeline_chain_in_ff = '0') then
                lane_chain_input_read_o(2) <= '1';
            else                        -- keep stall high if no data available (needed here in stage 3 if short vector not need chain input in stage 2)
                if (lane_chain_input_i(2).data_avai = '0') then
                    stall_pipeline_chain_in_nxt <= '1';
                end if;
            end if;
        end if;

        if (stall_pipeline_chain_out_ff = '1') then
            -- if chaining from both (e.g. src1 from ls and src2 from lane x): 
            --      stall if any not rdy
            --      do not ack yet
            lane_chain_input_read_o <= (others => '0');
        end if;
    end process input_stall;

    stall_i_registers : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then -- @suppress "Incomplete reset branch: missing asynchronous reset for register 'stall_pipeline_chain_in_ff2'"            
--coverage off
            stall_pipeline_chain_in_adr_ff <= (others => '0');            
--coverage on
            stall_pipeline_chain_in_ff     <= '0';
        elsif rising_edge(clk_i) then
--coverage off
            stall_pipeline_chain_in_adr_ff(0)                                              <= stall_pipeline_chain_in_adr_nxt;
            stall_pipeline_chain_in_adr_ff(1 to stall_pipeline_chain_in_adr_ff'length - 1) <= stall_pipeline_chain_in_adr_ff(0 to stall_pipeline_chain_in_adr_ff'length - 1 - 1);
--coverage on
            stall_pipeline_chain_in_ff                                                     <= stall_pipeline_chain_in_nxt;
            stall_pipeline_chain_in_ff2                                                    <= stall_pipeline_chain_in_ff;
        end if;
    end process;

    -- chain dirs/src for (nxt) stage 4 data buffer mux
    src1_src_nxt <= CHAIN_LANE when (vcmd(3).src1_sel = srcsel_chain_neighbor_c) else
                    CHAIN_LS when vcmd(3).src1_sel = srcsel_ls_c else
                    IMMEDIATE when vcmd(3).src1_sel = srcsel_imm_c else
                    REG;
    src2_src_nxt <= CHAIN_LANE when (vcmd(3).src2_sel = srcsel_chain_neighbor_c) else
                    CHAIN_LS when vcmd(3).src2_sel = srcsel_ls_c else
                    IMMEDIATE when vcmd(3).src2_sel = srcsel_imm_c else
                    REG;

    -- ALU Input Operands (stage 4) --------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    operand_mux_chain_i : operand_mux_chain -- use mux in this stage [buf <= (chain || imm)] to save some timing in the next stage [op <= (buf || rf)]
        port map(
            vcmd_i             => vcmd(4),
            lane_chain_input_i => lane_chain_input_i,
            src1_src_i         => src1_src,
            src2_src_i         => src2_src,
            src1_buf_o         => alu_opa_buf_nxt,
            src1_addr_sel_o    => alu_opa_sel_nxt,
            src2_buf_o         => alu_opb_buf_nxt,
            src2_addr_sel_o    => alu_opb_sel_nxt
        );

    -- ALU Input Operands (stage 5) --------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    src1_flag_data <= src1_rflag & src1_rdata;
    operand_mux_buf_rf_i : operand_mux_buf_rf -- 2nd stage mux
        port map(
            vcmd_i            => vcmd(5),
            src1_addr_sel_i   => alu_opa_sel,
            src2_addr_sel_i   => alu_opb_sel,
            src1_buf_i        => alu_opa_buf,
            src2_buf_i        => alu_opb_buf,
            src1_rdata_i      => src1_flag_data,
            src2_rdata_i      => src2_rdata,
            mac_init_source_i => mac_init_source,
            alu_opa_o         => alu_opa,
            alu_opb_o         => alu_opb,
            alu_opc_o         => alu_opc,
            old_flags_o       => old_flags_nxt
        );

    -- ALU (stages 5..8) -------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    alu_inst : alu
        generic map(
            minmax_instance_g       => minmax_instance_g,
            bit_reversal_instance_g => bit_reversal_instance_g
        )
        port map(
            -- global control --
            ce_i              => alu_dsp_ce,
            clk_i             => clk_i,
            -- function --
            en_i              => enable(5),
            fusel_i           => vcmd(5).fu_sel, --(cmd_fusel_msb_c downto cmd_fusel_lsb_c), -- function unit select
            func_i            => vcmd(5).func, --(cmd_func_msb_c downto cmd_func_lsb_c), -- function select
            mul_shift_i       => mul_shift,
            mac_shift_i       => mac_shift,
            mac_init_source_i => mac_init_source,
            reset_accu_i      => reset_accu(5),
            first_iteration_i => first_iteration(5),
            conditional_i     => condition(7),
            -- operands --
            opa_i             => alu_opa, -- operand A
            opb_i             => alu_opb, -- operand B
            opc_i             => alu_opc, -- mac init data
            -- results --
            result_o          => alu_result, -- computation result
            flags_o           => new_alu_flags -- new status flags
        );

    -- Data Write-Back Buffer (stage 8) ----------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    dwb_switch_buffer_logic : process(alu_result, new_alu_flags, vcmd(8), src1_addr(8), first_iteration(8), min_max_address)
    begin
        rf_write_data_nxt           <= alu_result;
        rf_write_flag_nxt(z_fbus_c) <= new_alu_flags(z_fbus_c);
        rf_write_flag_nxt(n_fbus_c) <= new_alu_flags(n_fbus_c);

        if minmax_instance_g then
            min_max_address_nxt <= min_max_address;
            if (vcmd(8).fu_sel = fu_special_c) and ((vcmd(8).func = func_min_vector_c) or (vcmd(8).func = func_max_vector_c)) then -- MIN/MAX vector
                -- alu has processed the comparision of the values from A to the content of the register (min/max value)
                -- take result value (alu_result) or index (rf address; src1_addr)
                -- flag which operand to take is given by alu_flag (z) -- TODO: z update for other operations than arithemtic?

                -- alu input is opa + min_max_reg
                if (unsigned(vcmd(8).src2_offset) = 1) then
                    rf_write_data_nxt <= (others => '0');
                    if (new_alu_flags(z_fbus_c) = '0') and first_iteration(8) = '0' then -- use register / b wins (registered inside alu)
                        rf_write_data_nxt(min_max_address'length - 1 downto 0) <= min_max_address;
                    else
                        rf_write_data_nxt(src1_addr(8)'length - 1 downto 0) <= src1_addr(8);
                        min_max_address_nxt                                 <= src1_addr(8); -- update register to store new winning address
                    end if;
                end if;
            end if;
        end if;
    end process dwb_switch_buffer_logic;

    dwb_switch_buffer : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (stall_pipeline_chain_out_ff = '0') then
                if minmax_instance_g then
                    min_max_address <= min_max_address_nxt;
                end if;
                rf_write_data <= rf_write_data_nxt;
                rf_write_flag <= rf_write_flag_nxt;
            end if;
        end if;
    end process dwb_switch_buffer;

    chain_out_buffer_logic : process(enable(8), rf_write_data_nxt, rf_write_flag_nxt, vcmd(8).is_chain, vcmd(8).f_update(0))
    begin
        chain_o_nxt.data      <= rf_write_flag_nxt & rf_write_data_nxt;
        chain_o_nxt.data_avai <= enable(8) and vcmd(8).is_chain(0);
        rf_we_nxt             <= enable(8); -- valid data write back to register file
        rf_flag_we_nxt        <= vcmd(8).f_update(0) and enable(8); -- valid flag write back to register file
    end process chain_out_buffer_logic;

    -- Chaining Output (stage 9) -----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    chain_out_buffer : process(clk_i)
    begin
        if rising_edge(clk_i) then
            stall_pipeline_chain_out_ff <= lane_chain_output_stall_i;
            if (stall_pipeline_chain_out_ff = '0') then
                chain_o_no_stall    <= chain_o_nxt;
                rf_we_no_stall      <= rf_we_nxt;
                rf_flag_we_no_stall <= rf_flag_we_nxt;
            end if;
        end if;
    end process chain_out_buffer;

    chain_out_stall : process(stall_pipeline_chain_out_ff, chain_o_no_stall, rf_flag_we_no_stall, rf_we_no_stall)
    begin
        if (stall_pipeline_chain_out_ff = '0') then
            lane_chain_output_o <= chain_o_no_stall;
            rf_we               <= rf_we_no_stall;
            rf_flag_we          <= rf_flag_we_no_stall;
        else
            lane_chain_output_o.data      <= (others => '-');
            lane_chain_output_o.data_avai <= '0';
            rf_we                         <= '0';
            rf_flag_we                    <= '0';
        end if;
    end process chain_out_stall;

    -- Register File (read: stage 3..5; write: stage 9) ------------------------------------------
    -- -------------------------------------------------------------------------------------------

    reg_file_i : register_file
        generic map(
            FLAG_WIDTH_g  => 2,
            DATA_WIDTH_g  => rf_data_width_c,
            NUM_ENTRIES_g => 1024,
            RF_LABLE_g    => LANE_LABLE_g
        )
        port map(
            -- global control --
            rd_ce_i    => rf_rd_ce,
            wr_ce_i    => rf_wr_ce,
            clk_i      => clk_i,
            -- write port --
            waddr_i    => dst_addr(9),
            wdata_i    => rf_write_data,
            wflag_i    => rf_write_flag,
            wdata_we_i => rf_we,        -- data write enable
            wflag_we_i => rf_flag_we,   -- flags write enable
            -- read port --
            raddr_a_i  => src1_addr_nxt(4),
            rdata_a_o  => src1_rdata,
            rflag_a_o  => src1_rflag,
            -- read port --
            raddr_b_i  => src2_addr,
            rdata_b_o  => src2_rdata,
            rflag_b_o  => open          -- take flag data only from reg file port A
        );

end architecture rtl;
