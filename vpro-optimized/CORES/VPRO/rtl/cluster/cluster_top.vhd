--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # cluster_top.vhd - Top entity of a vector unit cluster                #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_specializations.all;
use core_v2pro.package_datawidths.all;

entity cluster_top is
    generic(
        CLUSTER_ID         : natural := 0; -- absolute ID of this cluster
        num_vu_per_cluster : natural := 1;
        num_lanes_per_unit : natural := 2 -- processing lanes
    );
    port(
        -- vector system (clock domain 1) --
        vcp_clk_i       : in  std_ulogic; -- global clock signal, rising-edge
        vcp_rst_i       : in  std_ulogic; -- global reset, async, LOW-active
        -- internal command interface (clock domain 4) --
        cmd_clk_i       : in  std_ulogic; -- CMD fifo access clock
        cmd_i           : in  vpro_command_t; -- instruction word
        cmd_we_i        : in  std_ulogic; -- cmd write enable, high-active
        cmd_full_o      : out std_ulogic; -- accessed CMD FIFO is full
        idma_cmd_i      : in  dma_command_t;
        idma_cmd_we_i   : in  std_ulogic;
        idma_cmd_full_o : out std_ulogic;
        -- io interface (clock domain 2), 16-bit address space --
        io_clk_i        : in  std_ulogic; -- global clock signal, rising-edge
        io_rst_i        : in  std_ulogic; -- global reset, async, LOW-active
        io_ren_i        : in  std_ulogic; -- read enable
        io_wen_i        : in  std_ulogic; -- write enable (full word)
        io_adr_i        : in  std_ulogic_vector(15 downto 0); -- data address, word-indexed!
        io_data_i       : in  std_ulogic_vector(31 downto 0); -- data output
        io_data_o       : out std_ulogic_vector(31 downto 0); -- data input
        -- external memory system interface (clock domain 3) --
        mem_clk_i       : in  std_ulogic; -- global clock signal, rising-edge
        mem_rst_i       : in  std_ulogic; -- global reset, async, LOW-active
        mem_o           : out main_memory_single_out_t;
        mem_i           : in  main_memory_single_in_t;
        -- debug (cnt)
        lane_busy_o     : out std_ulogic;
        dma_busy_o      : out std_ulogic
    );
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of cluster_top : entity is "true";
end cluster_top;

architecture cluster_top_rtl of cluster_top is

    -- io interface --
    type io_interface_t is record
        clk : std_ulogic;               -- clock, rising edge
        rst : std_ulogic;               -- reset, async, LOW-active
        adr : std_ulogic_vector(15 downto 0); -- data address, word-indexing
        re  : std_ulogic;               -- read enable
        we  : std_ulogic;               -- write enable (full word!)
        di  : std_ulogic_vector(31 downto 0); -- data input
        do  : std_ulogic_vector(31 downto 0); -- data output
    end record;
    signal dma_io, sreg_io : io_interface_t;

    -- status register cdc sync --
    --	signal cmd_busy_ff0, cmd_busy_ff1 : std_ulogic_vector(num_vu_per_cluster - 1 downto 0);

    -- switching fabric --
    signal vcp_sreg_io_access, vcp_sreg_io_access_ff : std_ulogic;
    signal vcp_dma_io_access, vcp_dma_io_access_ff   : std_ulogic;

    -- DMA local memory interfaces --
    type lm_dma_interface_t is record
        adr : std_ulogic_vector(lm_addr_width_c - 1 downto 0);
        re  : lm_1b_t(0 to num_vu_per_cluster - 1);
        we  : lm_wren_t(0 to num_vu_per_cluster - 1);
        di  : lm_dma_word_t(0 to num_vu_per_cluster - 1);
        do  : std_ulogic_vector(mm_data_width_c - 1 downto 0);
    end record;
    signal lm_dma : lm_dma_interface_t;

    type lm_interface_t is record
        adr : lm_20b_t(0 to num_vu_per_cluster - 1);
        re  : lm_1b_t(0 to num_vu_per_cluster - 1);
        we  : lm_wren_t(0 to num_vu_per_cluster - 1);
        di  : lm_dma_word_t(0 to num_vu_per_cluster - 1);
        do  : lm_dma_word_t(0 to num_vu_per_cluster - 1);
    end record;
    signal lm_clk : std_ulogic;
    signal lm_if  : lm_interface_t;

    -- CMD interface buffer --
    signal cmd_unit      : vpro_command_t;
    signal cmd_we_unit   : std_ulogic_vector(num_vu_per_cluster - 1 downto 0);
    signal cmd_full_unit : std_ulogic_vector(num_vu_per_cluster - 1 downto 0);
    signal cmd_full_int  : std_ulogic;
    signal cmd_busy_unit : std_ulogic_vector(num_vu_per_cluster - 1 downto 0);
    --	signal stall_request : std_ulogic_vector(num_vu_per_cluster - 1 downto 0);

    -- Unit mask register --
    signal unit_mask_reg     : std_ulogic_vector(31 downto 0); -- register for IO write-only access
    signal unit_mask_reg_cdc : std_ulogic_vector(31 downto 0); -- cdc buffer
    signal unit_mask         : std_ulogic_vector(31 downto 0); -- actual global ID mask (in ibus clock domain)

    -- MUL Shift register --
    signal mul_shift_reg     : std_ulogic_vector(04 downto 0); -- register for IO write-only access
    signal mul_shift_reg_cdc : std_ulogic_vector(04 downto 0); -- cdc buffer
    signal mul_shift         : std_ulogic_vector(04 downto 0); -- actual global ID mask (in ibus clock domain)

    -- MAC Shift register --
    signal mac_shift_reg     : std_ulogic_vector(04 downto 0); -- register for IO write-only access
    signal mac_shift_reg_cdc : std_ulogic_vector(04 downto 0); -- cdc buffer
    signal mac_shift         : std_ulogic_vector(04 downto 0); -- actual global ID mask (in ibus clock domain)

    attribute keep : string;
    attribute keep of lm_dma : signal is "true";
    attribute keep of lm_if : signal is "true";

    signal lane_busy_int : std_ulogic;

    signal mac_init_source_reg, mac_init_source_reg_cdc, mac_init_source : MAC_INIT_SOURCE_t;
    signal mac_reset_mode_reg, mac_reset_mode_reg_cdc, mac_reset_mode    : MAC_RESET_MODE_t;

begin

    -- IO Bus Switching Fabric -----------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
--coverage off
    vcp_dma_io_access  <= '1' when io_adr_i(io_addr_dma_access_c'range) = io_addr_dma_access_c else '0'; -- DMA
--coverage on
    vcp_sreg_io_access <= '1' when (not (io_adr_i(io_addr_dma_access_c'range) = io_addr_dma_access_c)) else '0'; -- VCP status register if no dma

    io_switch_reg : process(io_clk_i, io_rst_i)
    begin
        if (io_rst_i = active_reset_c) then
            vcp_sreg_io_access_ff <= '0';
--coverage off            
vcp_dma_io_access_ff  <= '0';
--coverage on
        elsif rising_edge(io_clk_i) then
            vcp_sreg_io_access_ff <= vcp_sreg_io_access and (io_ren_i or io_wen_i);
--coverage off
vcp_dma_io_access_ff  <= vcp_dma_io_access and (io_ren_i or io_wen_i);
--coverage on
        end if;
    end process io_switch_reg;

    -- clock / reset --
    sreg_io.clk <= io_clk_i;
    sreg_io.rst <= io_rst_i;
    dma_io.clk  <= io_clk_i;
    dma_io.rst  <= io_rst_i;

    -- address --
    sreg_io.adr <= io_adr_i;
    dma_io.adr  <= io_adr_i;

    -- write data --
    sreg_io.di <= io_data_i;
    dma_io.di  <= io_data_i;

    -- write enable (full word) --
    sreg_io.we <= io_wen_i when (vcp_sreg_io_access = '1') else '0';
    dma_io.we  <= io_wen_i when (vcp_dma_io_access = '1') else '0';

    -- read enable (full word) --
    sreg_io.re <= io_ren_i when (vcp_sreg_io_access = '1') else '0';
    dma_io.re  <= io_ren_i when (vcp_dma_io_access = '1') else '0';

    -- read data --
    io_data_o <= sreg_io.do when (vcp_sreg_io_access_ff = '1') else
                 dma_io.do when (vcp_dma_io_access_ff = '1') else
                 (others => '0');

    -- Vector Cluster Status/Control Register --------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    vcp_read_acc : process(sreg_io)
    begin
        if rising_edge(sreg_io.clk) then
            if (sreg_io.rst = active_reset_c) then
                unit_mask_reg       <= (others => '1');
                mul_shift_reg       <= std_ulogic_vector(to_unsigned(rf_data_width_c, mul_shift_reg'length));
                mac_shift_reg       <= std_ulogic_vector(to_unsigned(rf_data_width_c, mac_shift_reg'length));
                mac_init_source_reg <= NONE;
                mac_reset_mode_reg  <= NEVER;
            else
                -- sync for clock domain crossing --
                --				cmd_busy_ff0 <= cmd_busy_unit;
                --				cmd_busy_ff1 <= cmd_busy_ff0;
                -- read data --
                sreg_io.do <= (others => '0');
                if (sreg_io.re = '1') then -- valid read access
                    if (io_adr_i(15 downto 8) = std_ulogic_vector(to_unsigned(CLUSTER_ID, 8))) then -- this cluster is accessed
                        if (sreg_io.adr(io_addr_cluster_busy_c'range) = io_addr_cluster_busy_c) then -- access BUSY REG
                            for i in 0 to num_vu_per_cluster - 1 loop
                                sreg_io.do(i) <= cmd_busy_unit(i);
                            end loop;   -- i
                        end if;
                    end if;
                end if;
                if (sreg_io.we = '1') then -- valid write access
                    case (sreg_io.adr(io_addr_unit_mask_c'range)) is
                        when io_addr_unit_mask_c => -- access UNIT MASK
                            unit_mask_reg <= io_data_i;
                        when io_addr_global_MUL_shift_c => -- access SHIFT Register for MUL
                            mul_shift_reg <= io_data_i(04 downto 00);
                        when io_addr_global_MAC_shift_c => -- access SHIFT Register for MAC
                            mac_shift_reg <= io_data_i(04 downto 00);
                        when io_addr_global_MAC_init_source_c => -- access INIT SOURCE Register for MAC
                            case (io_data_i(02 downto 00)) is
                                when "000" =>
                                    mac_init_source_reg <= NONE;
                                when "001" =>
                                    mac_init_source_reg <= IMM;
                                when "011" =>
                                    mac_init_source_reg <= ADDR;
                                when "101" =>
                                    mac_init_source_reg <= ZERO;
                                when others =>
                                    mac_init_source_reg <= mac_init_source_reg;
                            end case;
                        when io_addr_global_MAC_reset_mode_c => -- TODO:
                            case (io_data_i(02 downto 00)) is
                                when "000" =>
                                    mac_reset_mode_reg <= NEVER;
                                when "001" =>
                                    mac_reset_mode_reg <= ONCE;
                                when "011" =>
                                    mac_reset_mode_reg <= Z_INCREMENT;
                                when "101" =>
                                    mac_reset_mode_reg <= Y_INCREMENT;
                                when "110" =>
                                    mac_reset_mode_reg <= X_INCREMENT;
                                when others =>
                                    mac_reset_mode_reg <= mac_reset_mode_reg;
                            end case;
                        when others =>
                    end case;
                end if;
            end if;
        end if;
    end process vcp_read_acc;

    assert (to_integer(unsigned(mac_shift_reg)) <= rf_data_width_c) report "Error: [MACH] Shift value needs to be smaller than rf data width! Got: " & integer'image(to_integer(unsigned(mac_shift_reg))) & ", Cut to: " & integer'image(rf_data_width_c) severity warning;
    assert (to_integer(unsigned(mul_shift_reg)) <= rf_data_width_c) report "Error: [MULH] Shift value needs to be smaller than rf data width! Got: " & integer'image(to_integer(unsigned(mul_shift_reg))) & ", Cut to: " & integer'image(rf_data_width_c) severity warning;

    -- Global Unit ID Mask Register -----------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    -- clock domain crossing: host command interface => internal command bus --
    cluster_mask_cdc : process(cmd_clk_i)
    begin
        if rising_edge(cmd_clk_i) then
            unit_mask_reg_cdc <= unit_mask_reg;
            unit_mask         <= unit_mask_reg_cdc;

            if to_integer(unsigned(mul_shift_reg)) > rf_data_width_c then
                mul_shift_reg_cdc <= std_ulogic_vector(to_unsigned(rf_data_width_c, mul_shift_reg_cdc'length));
            else
                mul_shift_reg_cdc <= mul_shift_reg;
            end if;
            mul_shift <= mul_shift_reg_cdc;

            if to_integer(unsigned(mac_shift_reg)) > rf_data_width_c then
                mac_shift_reg_cdc <= std_ulogic_vector(to_unsigned(rf_data_width_c, mac_shift_reg_cdc'length));
            else
                mac_shift_reg_cdc <= mac_shift_reg;
            end if;
            mac_shift <= mac_shift_reg_cdc;

            mac_init_source_reg_cdc <= mac_init_source_reg;
            mac_init_source         <= mac_init_source_reg_cdc;

            mac_reset_mode_reg_cdc <= mac_reset_mode_reg;
            mac_reset_mode         <= mac_reset_mode_reg_cdc;
        end if;
    end process cluster_mask_cdc;

    -- Instruction Bus -------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    cmd_interface_buffer : process(cmd_clk_i)
    begin
        if rising_edge(cmd_clk_i) then
            -- buffer incoming & outgoing CMD interface lines once in each cluster --
            cmd_unit <= cmd_i;
            for i in 0 to num_vu_per_cluster - 1 loop
                cmd_we_unit(i) <= cmd_we_i and unit_mask(i);
            end loop;
        end if;
    end process cmd_interface_buffer;

    -- Vector Units CMD FIFO Full Arbitration --------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    cmd_full_o <= cmd_full_int;

    status_select : process(cmd_clk_i)
        variable full_any_v : std_ulogic;
    begin
        if rising_edge(cmd_clk_i) then
            full_any_v   := cmd_full_unit(0);
            for i in 1 to num_vu_per_cluster - 1 loop
                full_any_v := full_any_v or cmd_full_unit(i);
            end loop;                   -- i
            cmd_full_int <= full_any_v;
        end if;
    end process status_select;

    -- accessed cmd fifo full? --
    --	cmd_full_int <= '0' when (unsigned(stall_request) = 0) else '1';

    unit_busy_check : process(cmd_busy_unit)
        variable lane_busy_any_v : std_ulogic;
    begin
        lane_busy_any_v := cmd_busy_unit(0);
        for i in 1 to num_vu_per_cluster - 1 loop
            lane_busy_any_v := lane_busy_any_v or cmd_busy_unit(i);
        end loop;                       -- i
        lane_busy_int   <= lane_busy_any_v;
    end process;

    process(cmd_clk_i)
    begin
        if rising_edge(cmd_clk_i) then
            lane_busy_o <= lane_busy_int;
        end if;
    end process;

    -- Vector Units ----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    generate_vector_units : for i in 0 to num_vu_per_cluster - 1 generate
        unit_top_inst : unit_top
            generic map(
                ID_UNIT            => CLUSTER_ID * num_vu_per_cluster + i, -- absolute ID of this unit
                UNIT_LABLE_g       => "C" & integer'image(CLUSTER_ID) & "U" & integer'image(i),
                num_lanes_per_unit => num_lanes_per_unit
            )
            port map(
                -- global control (clock domain 1) --
                vcp_clk_i         => vcp_clk_i, -- global clock signal, rising-edge
                vcp_rst_i         => vcp_rst_i, -- global reset, async
                -- command interface (clock domain 4) --
                cmd_clk_i         => cmd_clk_i, -- CMD fifo access clock
                cmd_i             => cmd_unit, -- instruction word
                cmd_we_i          => cmd_we_unit(i), -- cmd write enable, high-active
                cmd_full_o        => cmd_full_unit(i), -- command fifo is full
                cmd_busy_o        => cmd_busy_unit(i), -- unit is still busy
                mul_shift_i       => mul_shift,
                mac_shift_i       => mac_shift,
                mac_init_source_i => mac_init_source,
                mac_reset_mode_i  => mac_reset_mode,
                -- local memory (clock domain 3) --
                lm_clk_i          => lm_clk, -- lm access clock
                lm_adr_i          => lm_if.adr(i), -- access address
                lm_di_i           => lm_if.di(i), -- data input
                lm_do_o           => lm_if.do(i), -- data output
                lm_wren_i         => lm_if.we(i), -- write enable
                lm_rden_i         => lm_if.re(i) -- read enable
            );
    end generate;

--coverage off
    -- DMA<->LM Interface-----------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    lm_buffer : process(lm_clk)
    begin
        if rising_edge(lm_clk) then
            -- buffer incoming & outgoing signals --
            for i in 0 to num_vu_per_cluster - 1 loop
                lm_if.adr(i)                   <= (others => '0');
                lm_if.adr(i)(lm_dma.adr'range) <= lm_dma.adr; -- 19 downto 0
                lm_if.di(i)                    <= lm_dma.do;
                lm_if.re(i)                    <= lm_dma.re(i);
                lm_if.we(i)                    <= lm_dma.we(i);
                lm_dma.di(i)                   <= lm_if.do(i);
            end loop;                   -- i
        end if;
    end process lm_buffer;

    -- Complex iDMA Controller -------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------------------
    idma_inst : idma
        generic map(
            CLUSTER_ID         => CLUSTER_ID,
            num_vu_per_cluster => num_vu_per_cluster
        )
        port map(
            -- global control --
            clk_i           => mem_clk_i,
            rst_i           => mem_rst_i,
            -- control interface --
            io_clk_i        => dma_io.clk,
            io_rst_i        => dma_io.rst,
            io_ren_i        => dma_io.re,
            io_wen_i        => dma_io.we,
            io_adr_i        => dma_io.adr, -- make it word-indexing address
            io_data_i       => dma_io.di,
            io_data_o       => dma_io.do,
            idma_cmd_i      => idma_cmd_i,
            idma_cmd_we_i   => idma_cmd_we_i,
            idma_cmd_full_o => idma_cmd_full_o,
            -- external memory system interface --
            mem_base_adr_o  => mem_o.base_adr,
            mem_size_o      => mem_o.size,
            mem_dat_i       => mem_i.rdat,
            mem_dat_o       => mem_o.wdat,
            mem_req_o       => mem_o.req,
            mem_busy_i      => mem_i.busy,
            mem_rw_o        => mem_o.rw,
            mem_rden_o      => mem_o.rden,
            mem_wren_o      => mem_o.wren,
            mem_wrdy_i      => mem_i.wrdy,
            mem_wr_last_o   => mem_o.wr_last,
            mem_rrdy_i      => mem_i.rrdy,
            -- local memory system interface (unique connection for each LM) --
            loc_adr_o       => lm_dma.adr,
            loc_dat_i       => lm_dma.di,
            loc_dat_o       => lm_dma.do,
            loc_rden_o      => lm_dma.re,
            loc_wren_o      => lm_dma.we,
            -- debug (cnt)
            dma_busy_o      => dma_busy_o
        );

    -- dma lm access port clock --
    lm_clk <= mem_clk_i;

-- coverage on
end cluster_top_rtl;
