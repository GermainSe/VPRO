--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
--! @file top.vhd
--! @brief Top entity of the VPRO vector processor array
-- #############################################################################

--! Use standard libray
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library eisv;
use eisv.eisV_pkg.all;                  -- multi_cmd_t

--! Use Vectorprocessor libray
library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

--! VPRO top entity

--! Contains the Vectorprocessor hierarchy
entity top is
    generic(
        num_clusters          : natural := 8;
        num_units_per_cluster : natural := 8;
        num_lanes_per_unit    : natural := 2
    );
    port(
        -- vector system (clock domain 1) --
        vpro_clk_i            : in  std_ulogic; -- global clock signal, rising-edge
        vpro_rst_i            : in  std_ulogic_vector(num_clusters - 1 downto 0); -- global reset, async, polarity: see package
        -- host command interface (clock domain 2) --
        cmd_clk_i             : in  std_ulogic; -- CMD fifo access clock
        cmd_i                 : in  vpro_command_t; -- instruction word
        cmd_we_i              : in  std_ulogic; -- cmd write enable, high-active
        cmd_full_o            : out std_ulogic; -- accessed CMD FIFO is full
        idma_dcache_cmd_i     : in  multi_cmd_t;
        idma_dcache_cmd_we_i  : in  std_ulogic;
        idma_cmd_full_o       : out std_ulogic;
        dcache_dma_fsm_busy_i : in  std_ulogic;
        sync_request_i        : in  sync_request_t;
        sync_pending_o        : out std_ulogic;
        -- io interface (clock domain 2), 16-bit address space --
        io_clk_i              : in  std_ulogic; -- global clock signal, rising-edge
        io_rst_i              : in  std_ulogic; -- global reset, async
        io_ren_i              : in  std_ulogic; -- read enable
        io_wen_i              : in  std_ulogic; -- write enable (full word)
        io_adr_i              : in  std_ulogic_vector(15 downto 0); -- data address, byte-indexed!
        io_data_i             : in  std_ulogic_vector(31 downto 0); -- data output
        io_data_o             : out std_ulogic_vector(31 downto 0); -- data input
        -- external memory system interface (clock domain 3) --
        mem_clk_i             : in  std_ulogic; -- global clock signal, rising-edge
        mem_rst_i             : in  std_ulogic_vector(num_clusters downto 0); -- global reset, async, polarity: see package
        mem_bundle_o          : out main_memory_bundle_out_t(0 to num_clusters - 1);
        mem_bundle_i          : in  main_memory_bundle_in_t(0 to num_clusters - 1);
        -- debug (cnt)
        vcp_lane_busy_o       : out std_ulogic;
        vcp_dma_busy_o        : out std_ulogic
    );
end top;

--! @brief Architecture definition of the Vectorprocessor
--! @details it contains the hierarchy with all clusters, dma, units, etc.
--!          global registers are defined in this top 
architecture top_rtl of top is
    -- constants
    constant num_clusters_log2 : natural := integer(ceil(log2(real(num_clusters))));

    -- command interface --
    signal cmd_we       : std_ulogic_vector(num_clusters - 1 downto 0);
    signal cmd_full     : std_ulogic_vector(num_clusters - 1 downto 0);
    signal cmd_full_int : std_ulogic;

    -- io access
    type io_rdata_t is array (0 to num_clusters - 1) of std_ulogic_vector(31 downto 0);
    signal io_rdata      : io_rdata_t;
    signal io_data_o_top : std_ulogic_vector(31 downto 0);

    -- Cluster mask register --
    signal cluster_mask_reg, cluster_mask_reg_cdc, cluster_mask : std_ulogic_vector(31 downto 0); -- register for IO write-only access
    -- sync mask register --
    signal cluster_sync_mask_reg, cluster_sync_mask_nxt         : std_ulogic_vector(31 downto 0); -- register for IO access

    -- dma access counter pointer
    signal dma_counters_cluster_pointer_ff : std_ulogic_vector(num_clusters_log2 - 1 downto 0);

    signal cluster_lane_busy, cluster_dma_busy : std_ulogic_vector(num_clusters - 1 downto 0);
    signal vcp_lane_busy_int, vcp_dma_busy_int : std_ulogic;

    signal idma_cmd_full     : std_ulogic_vector(num_clusters - 1 downto 0);
    signal idma_cmd_full_int : std_ulogic;
    signal cmd_fifo_full     : std_ulogic;
    signal cmd_fifo_empty    : std_ulogic;
    signal cmd_fifo_data_i   : std_ulogic_vector(vpro_cmd_len_c + num_clusters - 1 downto 0);
    signal cmd_fifo_data     : std_ulogic_vector(vpro_cmd_len_c + num_clusters - 1 downto 0);
    signal cmd_fifo_rd       : std_ulogic;
    signal slave_cmd_wr      : std_ulogic;
    signal cmd_mask          : std_ulogic_vector(num_clusters - 1 downto 0);
    signal cmd_data          : vpro_command_t;
    signal tmp_signal        : std_ulogic_vector(vpro_cmd_len_c - 1 downto 0);

    -- the passed dma commands to the cluster dma's are mux'd (io registers or direct write from external bus)
    signal idma_cluster_cmd_i    : dma_command_t;
    signal idma_cluster_cmd_we_i : std_ulogic;

    signal dma_cmd_gen_we_int              : std_ulogic;
    signal dma_cmd_gen_cmd_int             : dma_command_t;
    signal dma_cmd_gen_busy_int            : std_ulogic;
    signal dma_cmd_gen_waiting_for_dma_int : std_ulogic;

    signal mem_bundle_o_int : main_memory_bundle_out_t(0 to num_clusters - 1);

    -- dma access counter sigals
    signal dma_counters_read_hit_cycles   : dma_access_counter_t(0 to num_clusters - 1);
    signal dma_counters_read_miss_cycles  : dma_access_counter_t(0 to num_clusters - 1);
    signal dma_counters_write_hit_cycles  : dma_access_counter_t(0 to num_clusters - 1);
    signal dma_counters_write_miss_cycles : dma_access_counter_t(0 to num_clusters - 1);
    signal dma_counters_reset_counters    : std_ulogic;

    -- sync fsm
    signal sync_vpro_cmd_fifo_full                                                       : std_ulogic;
    signal sync_dma_cmd_fifo_full                                                        : std_ulogic;
    type sync_fsm_t is (IDLE, SYNC_BOTH, SYNC_DMA, SYNC_VPRO);
    signal sync_fsm_ff, sync_fsm_nxt                                                     : sync_fsm_t;
    signal sync_check_external_dcache_dma_fsm_ff, sync_check_external_dcache_dma_fsm_nxt : std_ulogic;

    -- counter to indicate lane busy after vpro cmd write
    signal cmd_we_delay_busy                               : std_ulogic;
    signal cmd_we_busy_counter_nxt, cmd_we_busy_counter_ff : signed(3 downto 0);
begin

    -- IO Bus Switching Fabric -------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    -- read-back data from all clusters --
    io_interface_feedback : process(io_rdata, io_data_o_top)
        variable tmp32_v : std_ulogic_vector(31 downto 0);
    begin
        tmp32_v   := io_rdata(0);
        for i in 1 to num_clusters - 1 loop
            tmp32_v := tmp32_v or io_rdata(i);
        end loop;                       -- i
        io_data_o <= tmp32_v or io_data_o_top;
    end process io_interface_feedback;

    -- Global Cluster ID Mask Register ------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    vcp_write_cluster_mask : process(io_clk_i, io_rst_i)
    begin
        if (io_rst_i = active_reset_c) then
            cluster_mask_reg                <= (others => '1');
            dma_counters_cluster_pointer_ff <= (others => '0');
        elsif rising_edge(io_clk_i) then
            io_data_o_top <= (others => '0');
            if (io_wen_i = '1') then    -- valid write access
                case (io_adr_i(io_addr_cluster_mask_c'range)) is
                    when io_addr_cluster_mask_c =>
                        cluster_mask_reg <= io_data_i;
                    when io_addr_sync_cl_mask_c =>
                        cluster_sync_mask_nxt <= io_data_i;
                    when others =>
                end case;
            elsif (io_ren_i = '1') then
                case (io_adr_i(io_addr_cluster_mask_c'range)) is
                    when io_addr_cluster_mask_c =>
                        io_data_o_top <= cluster_mask_reg;
                    when io_addr_sync_cl_mask_c =>
                        io_data_o_top <= cluster_sync_mask_reg;
                    when io_addr_sync_dma_c | io_addr_sync_dma_block_c =>
                        -- dma busy?
                        io_data_o_top <= std_ulogic_vector(resize(unsigned(cluster_dma_busy and cluster_mask_reg(num_clusters - 1 downto 0)), io_data_o_top'length));
                    when io_addr_sync_vpro_c | io_addr_sync_vpro_block_c =>
                        -- lane/unit busy?
                        io_data_o_top <= std_ulogic_vector(resize(unsigned(cluster_lane_busy and cluster_mask_reg(num_clusters - 1 downto 0)), io_data_o_top'length));
                    when io_addr_sync_block_c =>
                        -- dma or lane busy?
                        io_data_o_top <= std_ulogic_vector(resize(unsigned((cluster_lane_busy or cluster_dma_busy) and cluster_mask_reg(num_clusters - 1 downto 0)), io_data_o_top'length));
                    when io_addr_dma_read_hit_cycles_c =>
                        io_data_o_top <= dma_counters_read_hit_cycles(to_integer(unsigned(dma_counters_cluster_pointer_ff)));
                    when io_addr_dma_read_miss_cycles_c =>
                        io_data_o_top <= dma_counters_read_miss_cycles(to_integer(unsigned(dma_counters_cluster_pointer_ff)));
                    when io_addr_dma_write_hit_cycles_c =>
                        io_data_o_top <= dma_counters_write_hit_cycles(to_integer(unsigned(dma_counters_cluster_pointer_ff)));
                    when io_addr_dma_write_miss_cycles_c =>
                        io_data_o_top                   <= dma_counters_write_miss_cycles(to_integer(unsigned(dma_counters_cluster_pointer_ff)));
                        dma_counters_cluster_pointer_ff <= std_ulogic_vector(unsigned(dma_counters_cluster_pointer_ff) + 1);
                    when others =>
                end case;
            end if;
        end if;
    end process vcp_write_cluster_mask;

    -- clock domain crossing: host command interface => internal command bus --
    cluster_mask_cdc : process(cmd_clk_i)
    begin
        if rising_edge(cmd_clk_i) then
            cluster_mask_reg_cdc  <= cluster_mask_reg;
            cluster_mask          <= cluster_mask_reg_cdc;
            -- no cdc, comes in cmdclk/ioclk from cluster
            cluster_sync_mask_reg <= cluster_sync_mask_nxt;
        end if;
    end process cluster_mask_cdc;

    -- VPRO Command FIFO---------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    -- command fifo on top (large fifo to buffer all commands for all units)
    -- 512 entries
    cmd_fifo_inst : sync_fifo
        generic map(
            DATA_WIDTH     => vpro_cmd_len_c + num_clusters,
            NUM_ENTRIES    => dram_cmd_fifo_num_entries_top_c,
            NUM_SFULL      => dram_cmd_fifo_num_sfull_c,
            DIRECT_OUT     => false,
            DIRECT_OUT_REG => true
        )
        port map(
            clk_i    => cmd_clk_i,
            rst_i    => vpro_rst_i(0),
            wdata_i  => cmd_fifo_data_i,
            we_i     => cmd_we_i,
            wfull_o  => open,
            wsfull_o => cmd_fifo_full,
            rdata_o  => cmd_fifo_data,
            re_i     => cmd_fifo_rd,
            rempty_o => cmd_fifo_empty
        );

    -- pass fifo cmd data to unit fifos until any of those is full (TODO: only selected?)
    -- if not cmd_full_int -> read + set write to all cluster->unit fifo
    cmd_fifo_data_i <= vpro_cmd2vec(cmd_i) & cluster_mask(num_clusters - 1 downto 0);
    cmd_fifo_rd     <= not cmd_fifo_empty and not cmd_full_int;
    cmd_mask        <= cmd_fifo_data(num_clusters - 1 downto 0);
    tmp_signal      <= cmd_fifo_data(vpro_cmd_len_c + num_clusters - 1 downto num_clusters);
    cmd_data        <= vpro_vec2cmd(tmp_signal);
    slave_cmd_wr    <= not cmd_fifo_empty and not cmd_full_int;


--coverage off
    -- DMA IO Command Registers -------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    dma_io_write : process(io_clk_i)
    begin
        if rising_edge(io_clk_i) then
            dma_counters_reset_counters <= '0';
            if (io_wen_i = '1') then
                case (io_adr_i(io_addr_dma_unit_mask_c'range)) is
                    when io_addr_dma_unit_mask_c | io_addr_dma_cluster_mask_c | io_addr_dma_ext_base_l2e_c | io_addr_dma_ext_base_e2l_c |
                         io_addr_dma_loc_base_c | io_addr_dma_x_size_c | io_addr_dma_y_size_c | io_addr_dma_x_stride_c | io_addr_dma_pad_active_c =>
                        report "[IO DMA Generate Error] Outdated way of creating DMA instructions! update your software!" severity failure;
                    --                    when io_addr_dma_unit_mask_c =>
                    --                        io_dma_cmd_ff.unit_mask <= io_data_i(dma_cmd_unit_mask_len_c - 1 downto 0);
                    --                    when io_addr_dma_cluster_mask_c => -- always the first (set default values)
                    --                        io_dma_cmd_ff.cluster     <= io_data_i(dma_cmd_cluster_len_c - 1 downto 0);
                    --                        io_dma_cmd_ff.y_size      <= (others => '0');
                    --                        io_dma_cmd_ff.y_size(0)   <= '1';
                    --                        io_dma_cmd_ff.x_stride    <= (others => '0');
                    --                        io_dma_cmd_ff.x_stride(0) <= '1';
                    --                        io_dma_cmd_ff.pad         <= (others => '0');
                    --                    when io_addr_dma_ext_base_l2e_c => -- trigger
                    --                        io_dma_cmd_ff.ext_base <= io_data_i;
                    --                        io_dma_cmd_ff.dir      <= "1";
                    --                        io_dma_we_ff           <= '1';
                    --                    when io_addr_dma_ext_base_e2l_c => -- trigger
                    --                        io_dma_cmd_ff.ext_base <= io_data_i;
                    --                        io_dma_cmd_ff.dir      <= "0";
                    --                        io_dma_we_ff           <= '1';
                    --                    when io_addr_dma_loc_base_c =>
                    --                        io_dma_cmd_ff.loc_base <= io_data_i(dma_cmd_loc_base_len_c - 1 downto 0);
                    --                    when io_addr_dma_x_size_c =>
                    --                        io_dma_cmd_ff.x_size <= io_data_i(dma_cmd_x_size_len_c - 1 downto 0);
                    --                    when io_addr_dma_y_size_c =>
                    --                        io_dma_cmd_ff.y_size <= io_data_i(dma_cmd_y_size_len_c - 1 downto 0);
                    --                    when io_addr_dma_x_stride_c =>
                    --                        io_dma_cmd_ff.x_stride <= io_data_i(dma_cmd_x_stride_len_c - 1 downto 0);
                    --                    when io_addr_dma_pad_active_c =>
                    --                        io_dma_cmd_ff.pad <= io_data_i(dma_cmd_pad_len_c - 1 downto 0);
                    when io_addr_dma_read_hit_cycles_c =>
                        dma_counters_reset_counters <= '1';
                    when io_addr_dma_read_miss_cycles_c =>
                        dma_counters_reset_counters <= '1';
                    when io_addr_dma_write_hit_cycles_c =>
                        dma_counters_reset_counters <= '1';
                    when io_addr_dma_write_miss_cycles_c =>
                        dma_counters_reset_counters <= '1';
                    when others =>
                end case;
            end if;
        end if;
    end process dma_io_write;

    -- DMA Command Forward / Generation Processor -------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------

    -- MUX for write of dma commands to clusters (IO registered command or from external bus)
    idma_cluster_cmd_i <= dma_cmd_gen_cmd_int;

    check_assert : process(cmd_clk_i)
    begin
        if falling_edge(cmd_clk_i) then
            if (idma_cluster_cmd_we_i = '1') then

                if unsigned(idma_cluster_cmd_i.unit_mask) = 0 and idma_cluster_cmd_we_i = '1' then
                    report "[ERROR] VPRO Top. Dma command: unit mask is empty! (invalid)" severity failure;
                end if;
                if unsigned(idma_cluster_cmd_i.cluster) = 0 and idma_cluster_cmd_we_i = '1' then
                    report "[ERROR] VPRO Top. Dma command: cluster mask is empty! (invalid)" severity failure;
                end if;
            end if;
        end if;
    end process;

    idma_cluster_cmd_we_i <= '0' when dma_cmd_gen_waiting_for_dma_int = '1' else -- DMA CMD LOOP command (Parameter or Base)
                             dma_cmd_gen_we_int;

    dma_command_generator_processor_i : dma_command_gen
        port map(
            vpro_clk_i           => cmd_clk_i,
            vpro_rst_i           => mem_rst_i(0),
            idma_cmd_full_i      => idma_cmd_full_int,
            idma_dcache_cmd_i    => idma_dcache_cmd_i,
            idma_dcache_cmd_we_i => idma_dcache_cmd_we_i,
            dma_cmd_gen_cmd_o    => dma_cmd_gen_cmd_int,
            dma_cmd_we_o         => dma_cmd_gen_we_int,
            waiting_for_dma_o    => dma_cmd_gen_waiting_for_dma_int,
            busy_o               => dma_cmd_gen_busy_int
        );
    --coverage on

    -- Sync FSM -----------------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    process(sync_fsm_ff, sync_request_i, vcp_lane_busy_int, vcp_dma_busy_int, dma_cmd_gen_busy_int, dcache_dma_fsm_busy_i, sync_check_external_dcache_dma_fsm_ff, cmd_we_delay_busy)
    begin
        sync_vpro_cmd_fifo_full <= '0';
        sync_dma_cmd_fifo_full  <= '0';
        sync_fsm_nxt            <= sync_fsm_ff;
        sync_pending_o          <= '0';

        -- only check dcache fsm busy if it was busy when sync started.
        -- required due: 
        --  dcache fsm can become busy by risc-v trigger during fifo full (e.g. from this sync) -> sync would never end as fsm cannot push cmds to full fifo
        sync_check_external_dcache_dma_fsm_nxt <= sync_check_external_dcache_dma_fsm_ff;

        case (sync_fsm_ff) is
            when IDLE =>
                case (sync_request_i) is
                    when SYNC_REQUEST_DMA =>
                        sync_fsm_nxt                           <= SYNC_DMA;
                        sync_check_external_dcache_dma_fsm_nxt <= dcache_dma_fsm_busy_i;
                    when SYNC_REQUEST_VPRO =>
                        sync_fsm_nxt <= SYNC_VPRO;
                    when SYNC_REQUEST_BOTH =>
                        sync_fsm_nxt                           <= SYNC_BOTH;
                        sync_check_external_dcache_dma_fsm_nxt <= dcache_dma_fsm_busy_i;
                    when others =>
                end case;

            when SYNC_BOTH =>
                --coverage off
                sync_pending_o          <= '1';
                sync_vpro_cmd_fifo_full <= '1';
                sync_dma_cmd_fifo_full  <= '1';
                if sync_check_external_dcache_dma_fsm_ff = '1' then -- enable dcache dma fsm to issue dma cmds
                    sync_dma_cmd_fifo_full <= '0';
                end if;
                if (dcache_dma_fsm_busy_i and sync_check_external_dcache_dma_fsm_ff) = '0' then -- the dcache finished work, dont check it anymore (it could become active again)
                    sync_check_external_dcache_dma_fsm_nxt <= '0';
                end if;
                if ((vcp_lane_busy_int or cmd_we_delay_busy) = '0') and ((vcp_dma_busy_int or dma_cmd_gen_busy_int or (dcache_dma_fsm_busy_i and sync_check_external_dcache_dma_fsm_ff)) = '0') then -- both done
                    sync_fsm_nxt <= IDLE;
                end if;
                --coverage on

            when SYNC_DMA =>
                --coverage off
                sync_pending_o          <= '1';
                sync_vpro_cmd_fifo_full <= '1';
                sync_dma_cmd_fifo_full  <= '1';
                if sync_check_external_dcache_dma_fsm_ff = '1' then
                    sync_dma_cmd_fifo_full <= '0';
                end if;
                if (dcache_dma_fsm_busy_i and sync_check_external_dcache_dma_fsm_ff) = '0' then
                    sync_check_external_dcache_dma_fsm_nxt <= '0';
                end if;
                if (vcp_dma_busy_int or dma_cmd_gen_busy_int or (dcache_dma_fsm_busy_i and sync_check_external_dcache_dma_fsm_ff)) = '0' then -- dma done
                    sync_fsm_nxt <= IDLE;
                end if;
                --coverage on

            when SYNC_VPRO =>
                sync_pending_o          <= '1';
                sync_vpro_cmd_fifo_full <= '1';
                sync_dma_cmd_fifo_full  <= '1';
                if (vcp_lane_busy_int or cmd_we_delay_busy) = '0' then -- vpro done
                    sync_fsm_nxt <= IDLE;
                end if;

        end case;
    end process;

    process(cmd_clk_i, io_rst_i)
    begin
        if (io_rst_i = active_reset_c) then
            sync_fsm_ff <= IDLE;
        else
            if rising_edge(cmd_clk_i) then
                sync_fsm_ff                           <= sync_fsm_nxt;
                sync_check_external_dcache_dma_fsm_ff <= sync_check_external_dcache_dma_fsm_nxt;
            end if;
        end if;
    end process;

    -- Busy Signal Checks -------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    cmd_full_o      <= cmd_fifo_full or sync_vpro_cmd_fifo_full;
    vcp_lane_busy_o <= vcp_lane_busy_int; -- or cmd_we_delay_busy;
    --coverage off
    vcp_dma_busy_o  <= vcp_dma_busy_int or dma_cmd_gen_busy_int;
    idma_cmd_full_o <= idma_cmd_full_int or dma_cmd_gen_busy_int or sync_dma_cmd_fifo_full;
    --coverage on

    -- busy of lane the next 5 cycles after cmd_we_i (to enable cmd to get passed through fifos into executing lane -> busy signal propagates back)
    -- inside vector unit: fifo we -> lane busy: 2 cycles
    process(cmd_we_busy_counter_ff, cmd_we_i)
    begin
        cmd_we_busy_counter_nxt <= cmd_we_busy_counter_ff;
        if cmd_we_busy_counter_ff(cmd_we_busy_counter_ff'left) = '0' then -- positive number
            cmd_we_busy_counter_nxt <= cmd_we_busy_counter_ff - 1;
            cmd_we_delay_busy       <= '1';
        else
            cmd_we_delay_busy <= '0';
        end if;

        if cmd_we_i = '1' then
            cmd_we_busy_counter_nxt <= to_signed(6, cmd_we_busy_counter_ff'length);
        end if;
    end process;

    process(cmd_clk_i, io_rst_i)
    begin
        if (io_rst_i = active_reset_c) then
            cmd_we_busy_counter_ff <= (others => '0');
        else
            if rising_edge(cmd_clk_i) then
                cmd_we_busy_counter_ff <= cmd_we_busy_counter_nxt;
            end if;
        end if;
    end process;

    -- any cmd fifo full? --
    vcmd_fifo_full_check : process(cmd_full, cluster_lane_busy, cluster_dma_busy, idma_cmd_full)
        variable full_any_v         : std_ulogic;
        variable lane_busy_any_v    : std_ulogic;
        variable dma_busy_any_v     : std_ulogic;
        variable dma_cmd_full_any_v : std_ulogic;
    begin
        full_any_v   := cmd_full(0);
        for i in 1 to num_clusters - 1 loop
            full_any_v := full_any_v or cmd_full(i);
        end loop;                       -- i
        cmd_full_int <= full_any_v;

        lane_busy_any_v   := cluster_lane_busy(0);
        for i in 1 to num_clusters - 1 loop
            lane_busy_any_v := lane_busy_any_v or cluster_lane_busy(i);
        end loop;                       -- i
        vcp_lane_busy_int <= lane_busy_any_v;

        dma_busy_any_v   := cluster_dma_busy(0);
        for i in 1 to num_clusters - 1 loop
            dma_busy_any_v := dma_busy_any_v or cluster_dma_busy(i);
        end loop;                       -- i
        vcp_dma_busy_int <= dma_busy_any_v;

        dma_cmd_full_any_v := idma_cmd_full(0);
        for i in 1 to num_clusters - 1 loop
            dma_cmd_full_any_v := dma_cmd_full_any_v or idma_cmd_full(i);
        end loop;
        idma_cmd_full_int  <= dma_cmd_full_any_v;
    end process vcmd_fifo_full_check;

    vcmd_fifo_we_reg : process(cmd_mask, slave_cmd_wr)
    begin
        for i in 0 to num_clusters - 1 loop
            cmd_we(i) <= slave_cmd_wr and cmd_mask(i);
        end loop;
    end process vcmd_fifo_we_reg;

    -- Vector Clusters ----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    generate_vector_cluster : for i in 0 to num_clusters - 1 generate

        -- synopsys dc_tcl_script_begin
        -- set_db [vfind /des*/* -hinst generate_vector_cluster.vector_cluster_inst] .ungroup_ok false
        -- synopsys dc_tcl_script_end

        vector_cluster_inst : cluster_top
            generic map(
                CLUSTER_ID         => i, -- absolute ID of this cluster
                num_vu_per_cluster => num_units_per_cluster,
                num_lanes_per_unit => num_lanes_per_unit
            )
            port map(
                -- vector system (clock domain 1) --
                vcp_clk_i       => vpro_clk_i, -- global clock signal, rising-edge
                vcp_rst_i       => vpro_rst_i(i), -- global reset, async, polarity: see package
                -- internal command interface (clock domain 4) --
                cmd_clk_i       => cmd_clk_i, -- CMD fifo access clock
                cmd_i           => cmd_data, -- instruction word -- cmd_data
                cmd_we_i        => cmd_we(i), -- cmd write enable, high-active
                cmd_full_o      => cmd_full(i), -- accessed CMD FIFO is full
                idma_cmd_i      => idma_cluster_cmd_i,
                idma_cmd_we_i   => idma_cluster_cmd_we_i,
                idma_cmd_full_o => idma_cmd_full(i),
                -- io interface (clock domain 2), 16-bit address space --
                io_clk_i        => io_clk_i, -- global clock signal, rising-edge
                io_rst_i        => io_rst_i, -- global reset, async
                io_ren_i        => io_ren_i, -- read enable
                io_wen_i        => io_wen_i, -- write enable (full word)
                io_adr_i        => io_adr_i, -- data address, byte-indexed!
                io_data_i       => io_data_i, -- data output
                io_data_o       => io_rdata(i), -- data input
                -- external memory system interface (clock domain 3) --
                mem_clk_i       => mem_clk_i, -- global clock signal, rising-edge
                mem_rst_i       => mem_rst_i(i + 1), -- global reset, async
                mem_o           => mem_bundle_o_int(i),
                mem_i           => mem_bundle_i(i),
                -- debug (cnt)
                lane_busy_o     => cluster_lane_busy(i),
                dma_busy_o      => cluster_dma_busy(i)
            );
    end generate;

    --coverage off
    mem_bundle_o <= mem_bundle_o_int;

    idma_access_counter_inst : idma_access_counter
        generic map(
            num_clusters => num_clusters
        )
        port map(
            dma_clk_i            => mem_clk_i,
            dma_rst_i            => mem_rst_i(0),
            mem_bundle_dma2mem_i => mem_bundle_o_int,
            mem_bundle_mem2dma_i => mem_bundle_i,
            read_hit_cycles_o    => dma_counters_read_hit_cycles,
            read_miss_cycles_o   => dma_counters_read_miss_cycles,
            write_hit_cycles_o   => dma_counters_write_hit_cycles,
            write_miss_cycles_o  => dma_counters_write_miss_cycles,
            reset_counters_i     => dma_counters_reset_counters
        );
    --coverage on
    
end top_rtl;
