--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # unit_top.vhd - Single Unit (with several lanes) top entity           #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_specializations.all;
use core_v2pro.package_datawidths.all;

entity unit_top is
    generic(
        ID_UNIT            : natural := 0; -- ABSOLUTE ID of this unit (0..num_vectorunits_c-1)
        num_lanes_per_unit : natural := 2;
        UNIT_LABLE_g       : string  := "unknown"
    );
    port(
        -- global control (clock domain 1) --
        vcp_clk_i         : in  std_ulogic; -- global clock signal, rising-edge
        vcp_rst_i         : in  std_ulogic; -- global reset, async, polarity: see package
        -- command interface (clock domain 2) --
        cmd_clk_i         : in  std_ulogic; -- CMD fifo access clock
        cmd_i             : in  vpro_command_t; -- instruction word
        cmd_we_i          : in  std_ulogic; -- cmd write enable, high-active
        cmd_full_o        : out std_ulogic; -- command fifo is full
        cmd_busy_o        : out std_ulogic; -- unit is still busy
        mul_shift_i       : in  std_ulogic_vector(04 downto 0);
        mac_shift_i       : in  std_ulogic_vector(04 downto 0);
        mac_init_source_i : in  MAC_INIT_SOURCE_t;
        mac_reset_mode_i  : in  MAC_RESET_MODE_t;
        -- local memory (clock domain 3) --
        lm_clk_i          : in  std_ulogic; -- lm access clock
        lm_adr_i          : in  std_ulogic_vector(19 downto 0); -- access address
        lm_di_i           : in  std_ulogic_vector(mm_data_width_c - 1 downto 0); -- data input
        lm_do_o           : out std_ulogic_vector(mm_data_width_c - 1 downto 0); -- data output
        lm_wren_i         : in  std_ulogic_vector(mm_data_width_c / vpro_data_width_c - 1 downto 0); -- write enable
        lm_rden_i         : in  std_ulogic -- read enable
    );
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of unit_top : entity is "true";
end unit_top;

architecture unit_top_rtl of unit_top is

    -- command interface --
    signal global_cmd    : vpro_command_t;
    signal lane_cmd_we   : std_ulogic_vector(num_lanes_per_unit downto 0) := (others => '0');
    signal lane_busy     : std_ulogic_vector(num_lanes_per_unit downto 0) := (others => '0');
    signal lane_blocking : std_ulogic_vector(num_lanes_per_unit downto 0) := (others => '0');
    signal lane_cmd_req  : std_ulogic_vector(num_lanes_per_unit downto 0) := (others => '0');
    signal cmd_ct_idle   : std_ulogic;

    -- to & from alu lanes
    signal lane_chain_data_input      : lane_chain_data_input_array_t(0 to num_lanes_per_unit - 1);
    signal lane_chain_data_output     : lane_chain_data_output_array_t(0 to num_lanes_per_unit - 1);
    signal lane_chain_stall           : std_ulogic_vector(num_lanes_per_unit - 1 downto 0);
    signal lane_chain_data_input_read : lane_chain_data_input_read_array_t(0 to num_lanes_per_unit - 1);

    -- from the fifo's for each lane
    signal chain_fifo_data  : chain_data_array_t(0 to num_lanes_per_unit)  := (others => (others => '0'));
    signal chain_fifo_re    : chain_re_array_t(0 to num_lanes_per_unit)    := (others => '0');
    signal chain_fifo_empty : chain_emtpy_array_t(0 to num_lanes_per_unit) := (others => '0');

    -- to & from ls lane
    signal ls_chain_data_input      : ls_chain_data_input_t(0 to num_lanes_per_unit - 1);
    signal ls_chain_data_output     : ls_chain_data_output_t;
    signal ls_chain_stall           : std_ulogic;
    signal ls_chain_data_input_read : ls_chain_data_input_read_t(0 to num_lanes_per_unit - 1);

    -- local memory interface - lane --
    signal lane_lm_addr : std_ulogic_vector(19 downto 0);
    signal lane_lm_do   : std_ulogic_vector(15 downto 0);
    signal lane_lm_di   : std_ulogic_vector(15 downto 0);
    signal lane_lm_we   : std_ulogic;
    signal lane_lm_re   : std_ulogic;

    -- cmd fifo interface --
    signal cmd_data  : vpro_command_t;
    signal cmd_re    : std_ulogic;
    signal cmd_avail : std_ulogic;
    signal cmd_empty : std_ulogic;

    -- misc --
    signal any_busy    : std_ulogic;
    signal cmd_busy_ff : std_ulogic;
    signal rst_buf_ff  : std_ulogic := active_reset_c;

    attribute keep : string;
    attribute keep of rst_buf_ff : signal is "true";

    signal cmd_fifo_full : std_ulogic;
begin

    -- Reset "Buffer" -----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    reset_ff : process(cmd_clk_i, vcp_rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C) then
            if (vcp_rst_i = active_reset_c) then
                rst_buf_ff <= active_reset_c;
            elsif rising_edge(cmd_clk_i) then
                rst_buf_ff <= not active_reset_c;
            end if;
        end if;
    end process reset_ff;

    -- Access Control -----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    cmd_full_o <= cmd_fifo_full;

    -- CDC (CMD_clk) to VPRO (vcp_clk)
    cmd_fifo_wrapper_i : cmd_fifo_wrapper
        generic map(
            DATA_WIDTH  => vpro_cmd_len_c,
            NUM_ENTRIES => dram_cmd_fifo_num_entries_c,
            NUM_SYNC_FF => dram_cmd_fifo_num_sync_ff_c,
            NUM_SFULL   => dram_cmd_fifo_num_sfull_c
        )
        port map(
            -- write port (master clock domain) --
            m_clk_i    => cmd_clk_i,
            m_rst_i    => rst_buf_ff,
            m_cmd_i    => cmd_i,
            m_cmd_we_i => cmd_we_i,
            m_full_o   => cmd_fifo_full,
            -- read port (slave clock domain) --
            s_clk_i    => vcp_clk_i,
            s_rst_i    => rst_buf_ff,
            s_cmd_o    => cmd_data,
            s_cmd_re_i => cmd_re,
            s_empty_o  => cmd_empty
        );

    -- cmd available? --
    cmd_avail <= not cmd_empty;

    -- Instruction Scheduler ----------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    cmd_ctrl_inst : cmd_ctrl
        generic map(
            num_lanes_per_unit => num_lanes_per_unit + 1 -- number of lanes in this unit + ls lane
        )
        port map(
            -- global control --
            clk_i           => vcp_clk_i,
            rst_i           => rst_buf_ff,
            -- status --
            idle_o          => cmd_ct_idle,
            -- cmd fifo interface --
            cmd_i           => cmd_data,
            cmd_avail_i     => cmd_avail,
            cmd_re_o        => cmd_re,
            -- lane interface --
            lane_cmd_o      => global_cmd,
            lane_cmd_we_o   => lane_cmd_we,
            lane_cmd_req_i  => lane_cmd_req,
            lane_blocking_i => lane_blocking
        );

    -- any lane busy? --
    any_busy <= '0' when (to_integer(unsigned(lane_busy)) = 0) else '1';

    cmd_busy_ff <= (not cmd_empty) or cmd_avail or (not cmd_ct_idle) or any_busy;

    --    sfull_buffer : process(cmd_clk_i)
    --    begin
    --        if rising_edge(cmd_clk_i) then
    --            cmd_we_int_ff  <= cmd_we_i;
    --            cmd_we_int_ff2 <= cmd_we_int_ff;
    --        end if;
    --    end process sfull_buffer;

    busy_reg_cdc : process(cmd_clk_i)
    begin
        if rising_edge(cmd_clk_i) then
            cmd_busy_o <= cmd_busy_ff;  -- or cmd_we_i or cmd_we_int_ff or cmd_we_int_ff2;
        end if;
    end process busy_reg_cdc;

    -- Vector Lanes -------------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    generate_vector_lanes :             -- LANES per UNIT
    for i in 0 to num_lanes_per_unit - 1 generate
        lane_top_inst : lane_top
            generic map(
                minmax_instance_g       => instanciate_instruction_min_max_vector_c,
                bit_reversal_instance_g => instanciate_instruction_bit_reversal_c,
                LANE_LABLE_g            => UNIT_LABLE_g & "L" & integer'image(i)
            )
            port map(
                -- global control --
                clk_i                     => vcp_clk_i,
                rst_i                     => rst_buf_ff,
                -- instruction interface --
                cmd_i                     => global_cmd,
                cmd_we_i                  => lane_cmd_we(i),
                cmd_busy_o                => lane_busy(i),
                cmd_req_o                 => lane_cmd_req(i),
                cmd_isblocking_o          => lane_blocking(i),
                mul_shift_i               => mul_shift_i,
                mac_shift_i               => mac_shift_i,
                mac_init_source_i         => mac_init_source_i,
                mac_reset_mode_i          => mac_reset_mode_i,
                -- chaining (data + flags) --
                lane_chain_input_i        => lane_chain_data_input(i),
                lane_chain_input_read_o   => lane_chain_data_input_read(i),
                lane_chain_output_o       => lane_chain_data_output(i),
                lane_chain_output_stall_i => lane_chain_stall(i)
            );
    end generate;                       -- i

    ls_lane_top_inst : ls_lane_top
        generic map(
            load_shift_instance_g => instanciate_instruction_load_shift_c,
            num_lanes_per_unit    => num_lanes_per_unit
        )
        port map(
            -- global control --
            clk_i                   => vcp_clk_i,
            rst_i                   => rst_buf_ff,
            -- instruction interface --
            cmd_i                   => global_cmd,
            cmd_we_i                => lane_cmd_we(num_lanes_per_unit),
            cmd_busy_o              => lane_busy(num_lanes_per_unit),
            cmd_req_o               => lane_cmd_req(num_lanes_per_unit),
            cmd_isblocking_o        => lane_blocking(num_lanes_per_unit),
            -- chaining (data + flags) --
            ls_chain_input_data_i   => ls_chain_data_input, -- alu lanes
            ls_chain_input_read_o   => ls_chain_data_input_read,
            ls_chain_output_data_o  => ls_chain_data_output, -- ls output
            ls_chain_output_stall_i => ls_chain_stall, -- ls output
            -- local memory interface --
            lm_we_o                 => lane_lm_we,
            lm_re_o                 => lane_lm_re,
            lm_addr_o               => lane_lm_addr,
            lm_wdata_o              => lane_lm_do,
            lm_rdata_i              => lane_lm_di
        );

    generate_chain_fifos : for i in 0 to num_lanes_per_unit - 1 generate
        lane_chain_fifo : sync_fifo_register
            generic map(
                DATA_WIDTH  => rf_data_width_c + 2, -- data width of FIFO entries
                NUM_ENTRIES => 4        -- number of FIFO entries, should be a power of 2!
            )
            port map(
                -- globals --
                clk_i    => vcp_clk_i,
                rst_i    => rst_buf_ff,
                -- write port --
                wdata_i  => lane_chain_data_output(i).data,
                we_i     => lane_chain_data_output(i).data_avai,
                wfull_o  => open,
                wsfull_o => lane_chain_stall(i),
                -- read port --
                rdata_o  => chain_fifo_data(i), -- this lane (0) is left(0) of 1  => and right of  =>  and id 0 of ls
                re_i     => chain_fifo_re(i), -- any read from lane(0)
                rempty_o => chain_fifo_empty(i) -- inverted @ lane 1/1/ls input
            );
    end generate;                       -- i

    ls_chain_fifo : sync_fifo_register
        generic map(
            DATA_WIDTH  => rf_data_width_c + 2, -- data width of FIFO entries
            NUM_ENTRIES => 4            -- number of FIFO entries, should be a power of 2!
        )
        port map(
            -- globals --
            clk_i    => vcp_clk_i,
            rst_i    => rst_buf_ff,
            -- write port --
            wdata_i  => ls_chain_data_output.data,
            we_i     => ls_chain_data_output.data_avai,
            wfull_o  => open,
            wsfull_o => ls_chain_stall,
            -- read port --
            rdata_o  => chain_fifo_data(num_lanes_per_unit), -- this lane (0) is left(0) of 1  => and right of  =>  and id 0 of ls
            re_i     => chain_fifo_re(num_lanes_per_unit), -- any read from lane(0)
            rempty_o => chain_fifo_empty(num_lanes_per_unit) -- inverted @ lane 1/1/ls input
        );

    -- chaining interconnection --
    chain_intercon : process(chain_fifo_data, chain_fifo_empty, lane_chain_data_input_read, ls_chain_data_input_read)
    begin
        -- L0 data
        lane_chain_data_input(1)(1).data      <= chain_fifo_data(0);
        lane_chain_data_input(1)(1).data_avai <= not chain_fifo_empty(0);
        lane_chain_data_input(1)(0).data      <= chain_fifo_data(0);
        lane_chain_data_input(1)(0).data_avai <= not chain_fifo_empty(0);
        ls_chain_data_input(0).data           <= chain_fifo_data(0);
        ls_chain_data_input(0).data_avai      <= not chain_fifo_empty(0);

        chain_fifo_re(0) <= ls_chain_data_input_read(0) or lane_chain_data_input_read(1)(0);

        -- L1 data
        lane_chain_data_input(0)(1).data      <= chain_fifo_data(1);
        lane_chain_data_input(0)(1).data_avai <= not chain_fifo_empty(1);
        lane_chain_data_input(0)(0).data      <= chain_fifo_data(1);
        lane_chain_data_input(0)(0).data_avai <= not chain_fifo_empty(1);
        ls_chain_data_input(1).data           <= chain_fifo_data(1);
        ls_chain_data_input(1).data_avai      <= not chain_fifo_empty(1);

        chain_fifo_re(1) <= ls_chain_data_input_read(1) or lane_chain_data_input_read(0)(0);

        -- LS data
        lane_chain_data_input(1)(2).data      <= chain_fifo_data(2);
        lane_chain_data_input(1)(2).data_avai <= not chain_fifo_empty(2);
        lane_chain_data_input(0)(2).data      <= chain_fifo_data(2);
        lane_chain_data_input(0)(2).data_avai <= not chain_fifo_empty(2);

        chain_fifo_re(2) <= lane_chain_data_input_read(0)(2) or lane_chain_data_input_read(1)(2);
    end process chain_intercon;

    -- Local Memory ----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------        
    local_mem_inst : local_mem_64bit_wrapper
        generic map(
            ADDR_WIDTH_g      => lm_addr_width_c,
            VPRO_DATA_WIDTH_g => vpro_data_width_c,
            DCMA_DATA_WIDTH_g => mm_data_width_c
        )
        port map(
            a_clk_i  => vcp_clk_i,
            a_addr_i => lane_lm_addr,
            a_di_i   => lane_lm_do,
            a_we_i   => lane_lm_we,
            a_re_i   => lane_lm_re,
            a_do_o   => lane_lm_di,
            b_clk_i  => lm_clk_i,
            b_addr_i => lm_adr_i,
            b_di_i   => lm_di_i,
            b_we_i   => lm_wren_i,
            b_re_i   => lm_rden_i,
            b_do_o   => lm_do_o
        );

end unit_top_rtl;
