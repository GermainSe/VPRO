--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # Package Definitions for specialized entities (FPGA, ASIC Optimized)       #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

package package_specializations is
    
    constant IMPLEMENT_RESET_C : boolean := true;

    -- AXI ERROR HANDLING
    constant axi_rd_req_error_handling_icache  : boolean := false;
    constant axi_rd_data_error_handling_icache : boolean := false;
    constant axi_rd_req_error_handling_dcache  : boolean := false;
    constant axi_rd_data_error_handling_dcache : boolean := false;
    constant axi_wr_req_error_handling_dcache  : boolean := false;
    constant axi_wr_data_error_handling_dcache : boolean := false;
    constant axi_rd_req_error_handling_dcma    : boolean := false;
    constant axi_rd_data_error_handling_dcma   : boolean := false;
    constant axi_wr_req_error_handling_dcma    : boolean := false;
    constant axi_wr_data_error_handling_dcma   : boolean := false;

    -- DCMA
    constant dcma_num_pipeline_reg_c                        : integer := 2; -- must be multiple of 2 or 0
    constant dcma_additional_pipeline_reg_in_dma_crossbar_c : boolean := false;
    constant dcma_to_dma_fifo_entries_c                     : integer := 8;
    constant dcma_to_axi_fifo_entries_c                     : integer := 4;

    -- Component: Complex Addressing Unit -----------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component address_unit
        generic(
            ADDR_WIDTH_g        : natural := 10;
            OFFSET_WIDTH_g      : natural := 10;
            OFFSET_REGISTERED_g : boolean := false
        );
        port(
            -- global control --
            ce_i     : in  std_ulogic;
            clk_i    : in  std_ulogic;
            -- looping variables --
            x_i      : in  std_ulogic_vector(5 downto 0);
            y_i      : in  std_ulogic_vector(5 downto 0);
            z_i      : in  std_ulogic_vector(9 downto 0);
            -- operands --
            alpha_i  : in  std_ulogic_vector(5 downto 0);
            beta_i   : in  std_ulogic_vector(5 downto 0);
            gamma_i  : in  std_ulogic_vector(5 downto 0);
            offset_i : in  std_ulogic_vector(OFFSET_WIDTH_g - 1 downto 0);
            -- final address --
            addr_o   : out std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0) -- cut to 10-bit. maximum address is 1025 inside RF, 13-bit for 8192 LM
        );
    end component;

    component vector_incrementer is
        port(
            clk_i             : in  std_ulogic;
            --
            stall_i           : in  std_ulogic; -- stop increment; stall_pipeline_chain_in or stall_pipeline_chain_out
            reset_i           : in  std_ulogic; -- resets counters
            --
            x_end_i           : in  std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
            y_end_i           : in  std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
            z_end_i           : in  std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
            --
            x_o               : out std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
            y_o               : out std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
            z_o               : out std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
            --
            final_iteration_o : out std_ulogic
        );
    end component;

    -- Component: Single Unit Top Entity ---------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component unit_top
        generic(
            ID_UNIT            : natural := 0; -- ABSOLUTE ID of this unit (0..num_vectorunits_c-1)
            UNIT_LABLE_g       : string  := "unknown";
            num_lanes_per_unit : natural := 2 -- processing lanes
        );
        port(
            -- global control (clock domain 1) --
            vcp_clk_i         : in  std_ulogic; -- global clock signal, rising-edge
            vcp_rst_i         : in  std_ulogic; -- global reset, async, polarity: see package
            -- command interface (clock domain 4) --
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
    end component;

    -- Component: Complex iDMA ----------------------------------------------------------------
    -- ----------------------------------------------------------------------------------------
    component idma
        generic(
            CLUSTER_ID         : natural := 0; -- absolute ID of this cluster
            num_vu_per_cluster : natural := 1
        );
        port(
            -- global control --
            clk_i           : in  std_ulogic; -- global clock line, rising-edge
            rst_i           : in  std_ulogic; -- global reset line, polarity: see package
            -- control interface --
            io_clk_i        : in  std_ulogic; -- io configuration clock
            io_rst_i        : in  std_ulogic; -- io reset line, sync, polarity: see package
            io_ren_i        : in  std_ulogic; -- read enable
            io_wen_i        : in  std_ulogic; -- write enable (full word)
            io_adr_i        : in  std_ulogic_vector(15 downto 0); -- data address, word-indexed
            io_data_i       : in  std_ulogic_vector(31 downto 0); -- data output
            io_data_o       : out std_ulogic_vector(31 downto 0); -- data input
            idma_cmd_i      : in  dma_command_t;
            idma_cmd_we_i   : in  std_ulogic;
            idma_cmd_full_o : out std_ulogic;
            -- external memory system interface --
            mem_base_adr_o  : out std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
            mem_size_o      : out std_ulogic_vector(19 downto 0); -- quantity
            mem_dat_i       : in  std_ulogic_vector(mm_data_width_c - 1 downto 0);
            mem_dat_o       : out std_ulogic_vector(mm_data_width_c - 1 downto 0);
            mem_req_o       : out std_ulogic; -- memory request
            mem_busy_i      : in  std_ulogic; -- no request possible right now
            mem_rw_o        : out std_ulogic; -- read/write a block from/to memory
            mem_rden_o      : out std_ulogic; -- FIFO read enable
            mem_wren_o      : out std_ulogic; -- FIFO write enable
            mem_wrdy_i      : in  std_ulogic; -- data can be written
            mem_wr_last_o   : out std_ulogic; -- last word of write-block
            mem_rrdy_i      : in  std_ulogic; -- read data ready
            -- local memory system interface (unique connection for each LM) --
            loc_adr_o       : out std_ulogic_vector(lm_addr_width_c - 1 downto 0); -- data address
            loc_dat_i       : in  lm_dma_word_t; -- data from local memories
            loc_dat_o       : out std_ulogic_vector(mm_data_width_c - 1 downto 0); -- data to local memories
            loc_rden_o      : out lm_1b_t; -- read enable
            loc_wren_o      : out lm_wren_t; -- write enable
            -- debug (cnt)
            dma_busy_o      : out std_ulogic
        );
    end component;

    -- Component: Local Memory 64bit Wrapper -----------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component local_mem_64bit_wrapper
        generic(
            ADDR_WIDTH_g      : natural := 13;
            VPRO_DATA_WIDTH_g : natural := 16;
            DCMA_DATA_WIDTH_g : natural := 64
        );
        port(
            a_clk_i  : in  std_ulogic;
            a_addr_i : in  std_ulogic_vector(19 downto 0);
            a_di_i   : in  std_ulogic_vector(VPRO_DATA_WIDTH_g - 1 downto 0);
            a_we_i   : in  std_ulogic;
            a_re_i   : in  std_ulogic;
            a_do_o   : out std_ulogic_vector(VPRO_DATA_WIDTH_g - 1 downto 0);
            b_clk_i  : in  std_ulogic;
            b_addr_i : in  std_ulogic_vector(19 downto 0);
            b_di_i   : in  std_ulogic_vector(DCMA_DATA_WIDTH_g - 1 downto 0);
            b_we_i   : in  std_ulogic_vector(DCMA_DATA_WIDTH_g / VPRO_DATA_WIDTH_g - 1 downto 0);
            b_re_i   : in  std_ulogic;
            b_do_o   : out std_ulogic_vector(DCMA_DATA_WIDTH_g - 1 downto 0)
        );
    end component local_mem_64bit_wrapper;

    -- Component: Command FIFO (based on BRAM) ---------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component cdc_fifo_bram
        generic(
            NUM_ENTRIES : natural := 32; -- number of FIFO entries, should be a power of 2!
            NUM_SYNC_FF : natural := 2; -- number of synchronization FF stages
            NUM_SFULL   : natural := 1  -- offset between RD and WR for issueing 'special full' signal
        );
        port(
            -- write port (master clock domain) --
            m_clk_i    : in  std_ulogic;
            m_rst_i    : in  std_ulogic; -- polarity: see package
            m_cmd_i    : in  vpro_command_t;
            m_cmd_we_i : in  std_ulogic;
            m_full_o   : out std_ulogic;
            -- read port (slave clock domain) --
            s_clk_i    : in  std_ulogic;
            s_rst_i    : in  std_ulogic; -- polarity: see package -- @suppress "Unused port: s_rst_i is not used in core_v2pro.cmd_fifo(cmd_fifo_rtl)"
            s_cmd_o    : out vpro_command_t;
            s_cmd_re_i : in  std_ulogic;
            s_empty_o  : out std_ulogic
        );
    end component;

end package package_specializations;

package body package_specializations is

end package body package_specializations;
