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

entity ls_lane_top is
    generic(
        load_shift_instance_g : boolean;
        num_lanes_per_unit    : natural
    );
    port(
        -- global control --
        clk_i                   : in  std_ulogic; -- global clock, rising edge
        rst_i                   : in  std_ulogic; -- global reset, async, polarity: see package
        -- instruction interface --
        cmd_i                   : in  vpro_command_t;
        cmd_we_i                : in  std_ulogic;
        cmd_busy_o              : out std_ulogic;
        cmd_req_o               : out std_ulogic;
        cmd_isblocking_o        : out std_ulogic;
        -- chaining (data + flags) --
        ls_chain_input_data_i   : in  ls_chain_data_input_t(0 to num_lanes_per_unit - 1); -- alu lanes
        ls_chain_input_read_o   : out ls_chain_data_input_read_t(0 to num_lanes_per_unit - 1);
        ls_chain_output_data_o  : out ls_chain_data_output_t; -- ls output
        ls_chain_output_stall_i : in  std_ulogic; -- ls output
        -- local memory interface --
        lm_we_o                 : out std_ulogic;
        lm_re_o                 : out std_ulogic;
        lm_addr_o               : out std_ulogic_vector(19 downto 0);
        lm_wdata_o              : out std_ulogic_vector(vpro_data_width_c - 1 downto 0);
        lm_rdata_i              : in  std_ulogic_vector(vpro_data_width_c - 1 downto 0)
    );
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of ls_lane_top : entity is "true";
end ls_lane_top;

architecture rtl of ls_lane_top is
    -- constants
    constant num_lanes_per_unit_log2_c : natural := index_size(num_lanes_per_unit);

    -- looping variables --
    signal stall_vector_increment : std_ulogic;
    signal vector_increment_reset : std_ulogic;
    signal x_cnt                  : std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
    signal y_cnt                  : std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
    signal z_cnt                  : std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
    signal final_iteration        : std_ulogic;

    -- control arbiter --
    type arbiter_t is (S_IDLE, S_START_EXECUTE, S_EXECUTE);
    signal arbiter, arbiter_nxt : arbiter_t      := S_IDLE;
    signal cmd_reg, cmd_reg_nxt : vpro_command_t := vpro_cmd_zero_c; -- instruction register (input register)

    -- command register -- 
    signal vcmd, vcmd_nxt               : pipeCmd_t(0 to num_pstages_c - 1);
    signal enable, enable_nxt           : pipe1_t(0 to num_pstages_c - 1) := (others => '0'); -- enable stage
    --	signal enable_last_valid, enable_last_valid_nxt, enable_stall_exclusive : pipe1_t( 0 to num_pstages_c - 1); -- enable stage without stall
    signal pipline_isblocking           : std_ulogic;

    --attribute keep : string;
    --attribute keep of alu_opa_buf : signal is "true";
    --attribute keep of alu_opb_buf : signal is "true";
    --attribute keep of alu_opa_sel : signal is "true";
    --attribute keep of alu_opb_sel : signal is "true";

    -- memory address --
    signal lm_addr_base, lm_addr_base_nxt : std_ulogic_vector(12 downto 0); -- lm base address registered
    signal lm_addr, lm_addr_nxt           : std_ulogic_vector(19 downto 0); -- lm address 1x registered
    signal is_load, is_load_nxt           : pipe1_t(0 to num_pstages_c - 1); -- is memory load
    signal is_load_se, is_load_se_nxt     : pipe1_t(0 to num_pstages_c - 1); -- is sign-extension when loading
    signal is_load_byte, is_load_byte_nxt : pipe1_t(0 to num_pstages_c - 1); -- is byte transfer when loading
    signal is_store, is_store_nxt         : pipe1_t(0 to num_pstages_c - 1); -- is memory store

    -- registered ce and rd data for LM
    signal lm_last_rd_ce, lm_last_rd_ce_nxt   : std_ulogic;
    signal lm_next_rdata, lm_next_rdata_nxt   : std_ulogic_vector(vpro_data_width_c - 1 downto 0);
    signal lm_rdata                           : std_ulogic_vector(vpro_data_width_c - 1 downto 0);
    signal lm_we, lm_we_nxt, lm_re, lm_re_nxt : std_ulogic;

    -- stall
    signal stall_pipeline_chain_out_ff                                     : std_ulogic                      := '0'; -- stalls pipeline all before out rd stage
    constant pipeline_chain_out_stage_c                                    : natural                         := 9;
    signal stall_pipeline_chain_in_ff, stall_pipeline_chain_in_nxt         : std_ulogic                      := '0'; -- stalls pipeline all before in rd stage
    constant pipeline_chain_in_stage_c                                     : natural                         := 3;            
--coverage off
    signal stall_pipeline_chain_in_adr_ff, stall_pipeline_chain_in_adr_nxt : pipe1_t(0 to num_pstages_c - 1) := (others => '0'); -- registers for input stall caused by indirect addressing    
    constant pipeline_chain_in_adr_stage_c                                 : natural                         := 1;

    signal lane0_chain_adr_ff, lane0_chain_adr_nxt   : pipe1_t(0 to num_pstages_c - 1);
    signal lane1_chain_adr_ff, lane1_chain_adr_nxt : pipe1_t(0 to num_pstages_c - 1);        
--coverage on

    signal src1_offset : std_ulogic_vector(13 - 1 downto 0);

    signal lm_loaded_data : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal lm_loaded_flag : std_ulogic_vector(01 downto 0);

    signal address_dsp_ce : std_ulogic;
    signal addr_dsp_alpha : std_ulogic_vector(05 downto 0);
    signal addr_dsp_beta  : std_ulogic_vector(05 downto 0);
    --    signal addr_dsp_offset : std_ulogic_vector(09 downto 0);
    signal addr_dsp_gamma : std_ulogic_vector(vpro_cmd_dst_gamma_len_c - 1 downto 0);

    signal lm_store_data_nxt : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal lm_store_data     : std_ulogic_vector(rf_data_width_c - 1 downto 0);

    signal chain_lane_id, chain_lane_id_nxt, chain_lane_id_ff1, chain_lane_id_ff2 : integer range 0 to 2 ** (1 + num_lanes_per_unit_log2_c) - 1; --std_ulogic_vector(18 downto 0);
    signal chain_data_o_nxt, chain_data_o_no_stall                                : ls_chain_data_output_t;
    signal lm_shifted_result                                                      : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal lm_loaded_flag_ff1, lm_loaded_flag_ff2                                 : std_ulogic_vector(01 downto 0);

    -- Barrel Shifter for combined instructions
    signal bs_ce                                : std_ulogic;
    signal bs_shift                             : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal vector_incr_xend                     : std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
    signal vector_incr_yend                     : std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
    signal vector_incr_zend                     : std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
    signal chain_in_active, chain_in_active_nxt : pipe1_t(0 to num_pstages_c - 1);

    signal block_pipeline : std_ulogic_vector(5 downto 0);
begin

    address_dsp_ce <= '1' when ((stall_pipeline_chain_in_ff or stall_pipeline_chain_out_ff) = '0') --            
--coverage off
 and (stall_pipeline_chain_in_adr_ff(1) = '0') --            
--coverage on
 else '0';

    -- Blocking Logic depends on cmd up to stage 4
    --   if stage 5 is blocking, next cmd can start next cycle
    -- 	 next cmd reads from RF when current stage 5 has completed the whole pipeline (stage 9 - wb)
    
    block_pipeline(0) <= vcmd_nxt(0).blocking(0) and enable_nxt(0);
    block_pipeline(1) <= vcmd(0).blocking(0) and enable(0);
    block_pipeline(2) <= vcmd(1).blocking(0) and enable(1);
    block_pipeline(3) <= vcmd(2).blocking(0) and enable(2);
    block_pipeline(4) <= vcmd(3).blocking(0) and enable(3);
    block_pipeline(5) <= vcmd(4).blocking(0) and enable(4);
    
    pipline_isblocking <= or_reduce(block_pipeline);
--                          (vcmd_nxt(0).blocking(0) and enable_nxt(0)) or --
--                          (vcmd(0).blocking(0) and enable(0)) or --
--                          (vcmd(1).blocking(0) and enable(1)) or --
--                          (vcmd(2).blocking(0) and enable(2)) or --
--                          (vcmd(3).blocking(0) and enable(3)) or --
--                          (vcmd(4).blocking(0) and enable(4)); -- or --
    --((5) and enable(5));   -- no longer needed, as the blocking signal is buffered in unit's cmd ctrl unit one cycle

    cmd_isblocking_o <= pipline_isblocking;

    -- Control FSM (basically Stage 0 to start new commands) -------------------------------------
    -- -------------------------------------------------------------------------------------------
    control_arbiter_comb : process(arbiter, cmd_i, cmd_we_i, final_iteration, cmd_reg, 
        stall_pipeline_chain_in_ff, stall_pipeline_chain_out_ff, stall_pipeline_chain_in_adr_ff(0)
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
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then -- @suppress "Incomplete reset branch: missing asynchronous reset for register 'cmd_buffer_ff'"
            arbiter <= S_IDLE;
        elsif rising_edge(clk_i) then
            arbiter       <= arbiter_nxt;
        end if;
    end process control_arbiter_sync;

    -- Index Counters -------------------------------------------------------------------------
    -- ----------------------------------------------------------------------------------------
    stall_vector_increment <= stall_pipeline_chain_in_ff or stall_pipeline_chain_out_ff
--coverage off
or stall_pipeline_chain_in_adr_ff(0)--             
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

    -- Pipeline Register ----------------------------------------------------------------------
    -- ----------------------------------------------------------------------------------------

    -- Instruction Decoding --
    vcmd_nxt(0) <= cmd_reg;
    vcmd_nxt(1 to vcmd'length - 1) <= vcmd(0 to vcmd'length - 1 - 1);

    -- is memory transfer? --
    is_load_nxt(0)                         <= '1' when (vcmd_nxt(0).fu_sel = fu_memory_c) and (vcmd_nxt(0).func(3) = '0') else '0'; -- is load (lm->reg)?
    is_load_nxt(1 to is_load'length - 1)   <= is_load(0 to is_load'length - 1 - 1);
    is_store_nxt(0)                        <= '1' when (vcmd_nxt(0).fu_sel = fu_memory_c) and (vcmd_nxt(0).func(3) = '1') else '0'; -- is store (reg->lm)?
    is_store_nxt(1 to is_store'length - 1) <= is_store(0 to is_store'length - 1 - 1);

    is_load_se_nxt(0)                              <= '1' when (vcmd_nxt(0).fu_sel = fu_memory_c) and not (vcmd_nxt(0).func = func_load_c or vcmd_nxt(0).func = func_loadb_c) else '0'; -- sign-extension? mostly
    is_load_se_nxt(1 to is_load_se'length - 1)     <= is_load_se(0 to is_load_se'length - 1 - 1);
    is_load_byte_nxt(0)                            <= '1' when (vcmd_nxt(0).fu_sel = fu_memory_c) and (vcmd_nxt(0).func = func_loadb_c or vcmd_nxt(0).func = func_loadbs_c) else '0'; -- byte transfer? rarely
    is_load_byte_nxt(1 to is_load_byte'length - 1) <= is_load_byte(0 to is_load_byte'length - 1 - 1);

    assert enable(0) = '0' or (enable(0) = '1' and vcmd(0).fu_sel = fu_memory_c) report "LS Lane got a ALU command!" severity error;

    enable_nxt_process : process(enable, arbiter, stall_pipeline_chain_in_ff, final_iteration, stall_pipeline_chain_in_adr_ff(0))
    begin
        enable_nxt(0)                      <= '1';
        enable_nxt(1 to enable'length - 1) <= enable(0 to enable'length - 1 - 1);

        -- Enable (stage 0) --------------------------------------------------------
        -- -------------------------------------------------------------------------
        if (arbiter = S_IDLE) or (arbiter = S_EXECUTE and final_iteration = '1') then -- execute command
            enable_nxt(0) <= '0';
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

    -- Chain Input Decode for Indirect Adressing (stage 0) --------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- chain active for stage 1 chain_rd_o signal             
--coverage off
    lane0_chain_adr_nxt(0)  <= '1' when ((vcmd_nxt(0).src1_sel = srcsel_indirect_chain_l0_c)) and (enable_nxt(0) = '1') else
                              '0';
    lane1_chain_adr_nxt(0) <= '1' when ((vcmd_nxt(0).src1_sel = srcsel_indirect_chain_l1_c)) and (enable_nxt(0) = '1') else
                              '0';

    lane0_chain_adr_nxt(1 to lane0_chain_adr_ff'length - 1) <= lane0_chain_adr_ff(0 to lane0_chain_adr_ff'length - 1 - 1);
    lane1_chain_adr_nxt(1 to lane1_chain_adr_ff'length - 1) <= lane1_chain_adr_ff(0 to lane1_chain_adr_ff'length - 1 - 1);             
--coverage on

    -- with reset --
    pipeline_regs_rst : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then
            enable  <= (others => '0');
            cmd_reg <= vpro_cmd_zero_c;
        elsif rising_edge(clk_i) then
            enable <= enable_nxt;

            -- Stall?
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
--coverage off
            if (stall_pipeline_chain_in_adr_ff(0) = '1') then
                for i in 0 to pipeline_chain_in_adr_stage_c loop
                    enable(i) <= enable(i);
                end loop;
            end if;             
--coverage on

            cmd_reg <= cmd_reg_nxt;     -- no stall, due to FSM storing incoming cmd
        end if;
    end process pipeline_regs_rst;

    -- without reset --
    pipeline_regs : process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- no stall 
            vcmd          <= vcmd_nxt;
            is_load       <= is_load_nxt;
            is_load_se    <= is_load_se_nxt;
            is_load_byte  <= is_load_byte_nxt;
            is_store      <= is_store_nxt;
            lm_addr_base  <= lm_addr_base_nxt;
            lm_addr       <= lm_addr_nxt;
            lm_store_data <= lm_store_data_nxt;

            -- data & address chaining             
--coverage off
            lane0_chain_adr_ff  <= lane0_chain_adr_nxt;
            lane1_chain_adr_ff <= lane1_chain_adr_nxt;             
--coverage on

            chain_lane_id     <= chain_lane_id_nxt;
            chain_lane_id_ff1 <= chain_lane_id;
            chain_lane_id_ff2 <= chain_lane_id_ff1;
            chain_in_active   <= chain_in_active_nxt;

            if (stall_pipeline_chain_in_ff = '1') or (stall_pipeline_chain_out_ff = '1') --             
--coverage off
or (stall_pipeline_chain_in_adr_ff(2) = '1') --             
--coverage on
then -- TODO addr(0) or addr(2) ?!
                vcmd              <= vcmd;
                chain_lane_id     <= chain_lane_id;
                chain_lane_id_ff1 <= chain_lane_id_ff1;
                chain_lane_id_ff2 <= chain_lane_id_ff2;
                lm_addr_base      <= lm_addr_base;
             
--coverage off
                lane0_chain_adr_ff  <= lane0_chain_adr_ff;
                lane1_chain_adr_ff <= lane1_chain_adr_ff;             
--coverage on
            end if;

            if (stall_pipeline_chain_in_ff = '1') then
                for i in 0 to pipeline_chain_in_stage_c loop
                    is_load(i)         <= is_load(i);
                    is_load_se(i)      <= is_load_se(i);
                    is_load_byte(i)    <= is_load_byte(i);
                    is_store(i)        <= is_store(i);
                    chain_in_active(i) <= chain_in_active(i);
                end loop;
            end if;

            if (stall_pipeline_chain_out_ff = '1') then
                lm_addr <= lm_addr;     -- only if out stall!
                for i in 0 to pipeline_chain_out_stage_c loop
                    is_load(i)         <= is_load(i);
                    is_load_se(i)      <= is_load_se(i);
                    is_load_byte(i)    <= is_load_byte(i);
                    is_store(i)        <= is_store(i);
                    chain_in_active(i) <= chain_in_active(i);
                end loop;
            end if;
             
--coverage off
            if (stall_pipeline_chain_in_adr_ff(0) = '1') then
                for i in 0 to pipeline_chain_in_adr_stage_c loop
                    is_load(i)         <= is_load(i);
                    is_load_se(i)      <= is_load_se(i);
                    is_load_byte(i)    <= is_load_byte(i);
                    is_store(i)        <= is_store(i);
                    chain_in_active(i) <= chain_in_active(i);
                end loop;
            end if;             
--coverage on

            if (arbiter = S_IDLE) then  -- no matter if stall, due to new cmd start even if stall (if idle)
                vcmd <= vcmd_nxt;
            end if;
            --			stall_pipeline_chain_out_last <= stall_pipeline_chain_out;
            --			stall_pipeline_chain_in_last  <= stall_pipeline_chain_in;
        end if;
    end process pipeline_regs;

    -- Addressing Units (Stage 0..3) -------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    dsp_complex_addr_parameter_process : process(vcmd(0))
    begin
        -- if this is a store command => lm_addr = SRC1 + SRC2IMM
        -- if this is a load command => lm_addr = SRC1 + SRC2IMM
        addr_dsp_alpha <= vcmd(0).src1_alpha;
        addr_dsp_beta  <= vcmd(0).src1_beta;
        addr_dsp_gamma <= vcmd(0).src1_gamma;
    end process dsp_complex_addr_parameter_process;

    -- select source of offsets (stage 2)
    src1_offset <= --
--coverage off
                   ls_chain_input_data_i(0).data(13 - 1 downto 0) when (vcmd(2).src1_sel = srcsel_indirect_chain_l0_c) else -- TODO: compare not all bits?
                   ls_chain_input_data_i(1).data(13 - 1 downto 0) when (vcmd(2).src1_sel = srcsel_indirect_chain_l1_c) else
--coverage on
                   "000" & vcmd(2).src1_offset;
                   
    -- operand A / src1 --
    address_unit_src1 : address_unit
        generic map(
            ADDR_WIDTH_g        => 13,
            OFFSET_WIDTH_g      => 13,
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
            alpha_i  => addr_dsp_alpha,
            beta_i   => addr_dsp_beta,
            gamma_i  => addr_dsp_gamma,
            offset_i => src1_offset,
            -- final address --
            addr_o   => lm_addr_base_nxt -- base address (stage 3)
        );

    -- Chain Input chain id decode (stage 1) ------------------------------------------------------
    -- --------------------------------------------------------------------------------------------
    assert (vpro_cmd_dst_gamma_len_c - 1 >= num_lanes_per_unit_log2_c) report "LS encoded id of chain source out of encode range (GAMMA)! TODO: use whole immediate in decode ls_lane_top.vhd" severity failure;

    -- 
    -- LM Addr: SRC1 (ADDR) + SRC2 (IMM)        always, SRC1 select required for (possible) indirect addressing
    --    Store Data: DST (Chain -> gamma)
    --    Load Data:  DST (unused)
    --
    chain_lane_id_nxt <= to_integer(unsigned(vcmd(1).dst_gamma(num_lanes_per_unit_log2_c downto 0)));

    chain_in_active_nxt(2) <= '1' when enable(1) = '1' and is_load(1) = '0' else '0';
    chain_in_active_nxt(3) <= chain_in_active(2);

    -- Chain Input Available (stage 2) & READ (stage 3) -------------------------------------------
    -- --------------------------------------------------------------------------------------------
    input_stall : process(chain_lane_id, ls_chain_input_data_i, stall_pipeline_chain_in_ff, chain_in_active(2), chain_in_active(3), chain_lane_id_ff1, stall_pipeline_chain_out_ff, lane0_chain_adr_ff(0), lane0_chain_adr_ff(1), lane1_chain_adr_ff(0), lane1_chain_adr_ff(1), stall_pipeline_chain_in_adr_ff(0))
    begin
        stall_pipeline_chain_in_nxt        <= '0';            
--coverage off
        stall_pipeline_chain_in_adr_nxt(0) <= '0';            
--coverage on
        ls_chain_input_read_o              <= (others => '0');
            
--coverage off
        -- stall occurs if chaining fifo is empty or previous command requires data chaining (stage 3)
        if (lane0_chain_adr_ff(0) = '1') then
            if (ls_chain_input_data_i(0).data_avai = '0' or chain_in_active(2) = '1') then
                stall_pipeline_chain_in_adr_nxt(0) <= '1';
            end if;
        end if;
        if (lane1_chain_adr_ff(0) = '1') then
            if (ls_chain_input_data_i(1).data_avai = '0' or chain_in_active(2) = '1') then
                stall_pipeline_chain_in_adr_nxt(0) <= '1';
            end if;
        end if;     

        -- generate read out for address chains
        -- stall_pipeline_chain_in_ff has to be checked for commandos that use both data and address chaining
        -- if a stall in the data chain is present, the readout on the address chain is disabled until the stall is resolved
        if (lane0_chain_adr_ff(1) = '1') then
            if (stall_pipeline_chain_in_adr_ff(0) = '0' and stall_pipeline_chain_in_ff = '0') then
                ls_chain_input_read_o(0) <= '1';
            elsif (ls_chain_input_data_i(0).data_avai = '0') then
                stall_pipeline_chain_in_adr_nxt(0) <= '1';
            end if;
        end if;
        if (lane1_chain_adr_ff(1) = '1') then
            if (stall_pipeline_chain_in_adr_ff(0) = '0' and stall_pipeline_chain_in_ff = '0') then
                ls_chain_input_read_o(1) <= '1';
            elsif (ls_chain_input_data_i(1).data_avai = '0') then
                stall_pipeline_chain_in_adr_nxt(0) <= '1';
            end if;
        end if;
--coverage on

        -- data chaining
        if (chain_in_active(2) = '1') then
            if ls_chain_input_data_i(chain_lane_id).data_avai = '0' then
                stall_pipeline_chain_in_nxt <= '1';
            end if;
        end if;

        if (chain_in_active(3) = '1') then
            if stall_pipeline_chain_in_ff = '0' then
                ls_chain_input_read_o(chain_lane_id_ff1) <= '1';
            else                        -- keep stall high if no data available (needed here in stage 3 if short vector not need chain input in stage 2)
                if (ls_chain_input_data_i(chain_lane_id_ff1).data_avai = '0') then
                    stall_pipeline_chain_in_nxt <= '1';
                end if;
            end if;
        end if;

        if (stall_pipeline_chain_out_ff = '1') then
            ls_chain_input_read_o <= (others => '0');
        end if;

        -- TODO: if following cmd after load_shift is load, last shift load overwrites first load (pipeline depth differs)
        -- stall input stage for pipeline depth diffences (- cmd fsm cycle delays ~ 1)
        -- applies if long instr in last cmd / later stage
        --         if newer stage is not one of those
        --      if (vcmd(3).func = func_load_shift_left_c) or (vcmd(3).func = func_load_shift_right_c) then
        --          if not (vcmd(1).func = func_load_shift_left_c) or (vcmd(1).func = func_load_shift_right_c) then
        --              stall_pipeline_chain_in <= '1';
        --          would create deadlock!
        --              if cmd is done, vcmd should fill nop or similar
        --          end if;
        --      end if;
    end process input_stall;

    stall_i_registers : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then            
--coverage off
            stall_pipeline_chain_in_adr_ff <= (others => '0');            
--coverage on
            stall_pipeline_chain_in_ff     <= '0';
        elsif rising_edge(clk_i) then            
--coverage off
            stall_pipeline_chain_in_adr_ff <= stall_pipeline_chain_in_adr_nxt;            
--coverage on
            stall_pipeline_chain_in_ff     <= stall_pipeline_chain_in_nxt;
        end if;
    end process;
            
--coverage off
    stall_pipeline_chain_in_adr_nxt(1 to stall_pipeline_chain_in_adr_nxt'length - 1) <= stall_pipeline_chain_in_adr_ff(0 to stall_pipeline_chain_in_adr_nxt'length - 2);            
--coverage on

    -- Local Memory Address Computation (stage 4 )-------------------------------------------------
    -- --------------------------------------------------------------------------------------------
    -- immediate offset (stage 4) --
    lm_addr_adder : process(lm_addr_base, vcmd)
        variable base_v     : std_ulogic_vector(19 downto 0);
        variable imm_offset : std_ulogic_vector(lm_addr_nxt'range);
        variable imm_cmd    : std_ulogic_vector(vpro_cmd_src2_imm_len_c - 1 downto 0);
    begin
        imm_cmd := vpro_cmd2src2_imm(vcmd(4));
        -- source 2 as immediate --
        if vpro_cmd_src2_imm_len_c < lm_addr_nxt'length then
            imm_offset                := (others => imm_cmd(imm_cmd'left)); -- @suppress "Dead code"
            imm_offset(imm_cmd'range) := imm_cmd;
        else                            -- @suppress "Dead code"
            imm_offset := imm_cmd(lm_addr_nxt'range);
        end if;

        base_v              := (others => '0'); -- NO sign extension
        base_v(12 downto 0) := lm_addr_base;
        -- use 20 bit instead 22
        lm_addr_nxt         <= std_ulogic_vector(unsigned(base_v) + unsigned(imm_offset));
    end process lm_addr_adder;

    -- Store Data Operands selection (stage 4) -----------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    lm_store_data_nxt <= ls_chain_input_data_i(chain_lane_id_ff2).data(rf_data_width_c - 1 downto 0);

    -- Local Memory Interface (stage 5) ----------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    lm_we_nxt <= enable(5) and is_store(5);
    lm_re_nxt <= enable(5) and is_load(5);

    lm_output_reg : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (stall_pipeline_chain_out_ff = '0') then
                lm_we      <= lm_we_nxt;
                lm_re      <= lm_re_nxt;
                lm_addr_o  <= lm_addr;
                lm_wdata_o <= lm_store_data(15 downto 0);
            end if;
        end if;
    end process lm_output_reg;

    lm_we_o <= '0' when (stall_pipeline_chain_out_ff = '1') else lm_we; -- as rd "enable"
    lm_re_o <= '0' when (stall_pipeline_chain_out_ff = '1') else lm_re; -- as wr "enable"

    -- Data Load Write-Back Buffer (stage 8) -------------------------------------------------------
    -- ---------------------------------------------------------------------------------------------
    -- stall buffer ( if out stage is stalled )
    lm_last_rd_ce_nxt <= not stall_pipeline_chain_out_ff;
    lm_next_rdata_nxt <= lm_rdata_i;

    lm_register_clk : process(clk_i)
    begin
        if rising_edge(clk_i) then
            lm_last_rd_ce <= lm_last_rd_ce_nxt;
            if (stall_pipeline_chain_out_ff = '1' and lm_last_rd_ce = '1') then -- valid lm data in @ stall start
                lm_next_rdata <= lm_next_rdata_nxt;
            end if;
        end if;
    end process;

    lm_data_i_process : process(lm_rdata_i, lm_next_rdata, lm_last_rd_ce)
    begin
        if (lm_last_rd_ce = '1') then
            lm_rdata <= lm_rdata_i;
        else
            lm_rdata <= lm_next_rdata;
        end if;
    end process;

    dwb_switch_buffer_logic : process(is_load(8), lm_rdata, is_load_byte(8), is_load_se(8))
        variable data_loaded_v : std_ulogic_vector(rf_data_width_c - 1 downto 0);
        variable load_type     : std_ulogic_vector(01 downto 0);
    begin
        if (is_load(8) = '1') then
            -- which kind of load operation? --
            load_type := is_load_se(8) & is_load_byte(8);
            case load_type is
                when "00" =>            -- load unsigned word
                    data_loaded_v              := (others => '0');
                    data_loaded_v(15 downto 0) := lm_rdata(15 downto 0);
                when "01" =>            -- load unsigned byte
                    data_loaded_v              := (others => '0');
                    data_loaded_v(07 downto 0) := lm_rdata(07 downto 0);
                when "10" =>            -- load signed word (sign-extension!)
                    data_loaded_v              := (others => lm_rdata(15));
                    data_loaded_v(15 downto 0) := lm_rdata(15 downto 0);
                when "11" =>            -- load signed byte (sign-extension!)
                    data_loaded_v              := (others => lm_rdata(07));
                    data_loaded_v(07 downto 0) := lm_rdata(07 downto 0);
                --coverage off
                when others =>          -- undefined
                    data_loaded_v := (others => '0');
                --coverage on
            end case;
            lm_loaded_data <= data_loaded_v;

            if (unsigned(data_loaded_v) = 0) then
                lm_loaded_flag(z_fbus_c) <= '1';
            else
                lm_loaded_flag(z_fbus_c) <= '0';
            end if;
            lm_loaded_flag(n_fbus_c) <= data_loaded_v(data_loaded_v'left);
        else
            lm_loaded_data           <= (others => '0');
            lm_loaded_flag(z_fbus_c) <= '0';
            lm_loaded_flag(n_fbus_c) <= '0';
        end if;
    end process dwb_switch_buffer_logic;

    load_shift_flag_buffer : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (stall_pipeline_chain_out_ff = '0') then
                lm_loaded_flag_ff1 <= lm_loaded_flag;
                lm_loaded_flag_ff2 <= lm_loaded_flag_ff1;
            end if;
        end if;
    end process load_shift_flag_buffer;

    -- Barrelshifter (stage 8) -------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    --coverage off
    create_load_shift_bs : if (load_shift_instance_g) generate
        bs_unit_inst : bs_unit
            generic map(
                only_right_shift => false
            )
            port map(
                -- global control --
                ce_i       => bs_ce,
                clk_i      => clk_i,
                function_i => vcmd(8).func,
                -- operands --
                opa_i      => lm_loaded_data,
                opb_i      => bs_shift,
                -- result --
                data_o     => lm_shifted_result
            );

        bs_shift(rf_data_width_c - 1 downto 10) <= (others => '0');
        bs_shift(09 downto 00)                  <= vcmd(8).dst_offset;
        bs_ce                                   <= not stall_pipeline_chain_out_ff;
    end generate;
    --coverage on

    -- Chaining Output (stage 8 load/10 load + shift) --------------------------------------------
    -- -------------------------------------------------------------------------------------------
    chain_out_buffer_logic : process(enable(8), is_load(8), lm_loaded_data, lm_loaded_flag, enable(10), is_load(10), vcmd(10), lm_shifted_result, lm_loaded_flag_ff2)
    begin
        chain_data_o_nxt.data      <= lm_loaded_flag & lm_loaded_data;
        chain_data_o_nxt.data_avai <= is_load(8) and enable(8); -- and vcmd(8).is_chain(0);

        --coverage off
        if (load_shift_instance_g) then
            if (vcmd(10).func = func_load_shift_left_c) or (vcmd(10).func = func_load_shift_right_c) then
                chain_data_o_nxt.data      <= lm_loaded_flag_ff2 & lm_shifted_result;
                chain_data_o_nxt.data_avai <= is_load(10) and enable(10); -- and vcmd(10).is_chain(0);
            end if;
            -- TODO: if following cmd after load_shift is load, last shift load overwrites first load (pipeline depth differs) -> fix in stall_in process
        end if;
        --coverage on
    end process chain_out_buffer_logic;

    -- Chaining Output (stage 9 load/11 load + shift) --------------------------------------------
    -- -------------------------------------------------------------------------------------------
    chain_out_buffer : process(clk_i)
    begin
        if rising_edge(clk_i) then
            stall_pipeline_chain_out_ff <= ls_chain_output_stall_i;
            if (stall_pipeline_chain_out_ff = '0') then
                chain_data_o_no_stall <= chain_data_o_nxt;
            end if;
        end if;
    end process chain_out_buffer;

    chain_out_stall : process(stall_pipeline_chain_out_ff, chain_data_o_no_stall)
    begin
        if (stall_pipeline_chain_out_ff = '0') then
            ls_chain_output_data_o <= chain_data_o_no_stall;
        else
            ls_chain_output_data_o.data      <= (others => '-');
            ls_chain_output_data_o.data_avai <= '0';
        end if;
    end process chain_out_stall;

end architecture rtl;
