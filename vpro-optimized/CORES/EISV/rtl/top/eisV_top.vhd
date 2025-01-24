--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- #                                                                           #
-- # Top entity includes a direct mapped I-cache and data gateway for MEMORY   #
-- # and IO area access.                                                       #
-- #                                                                           #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use STD.textio.all;
use ieee.std_logic_textio.all;

--cadence synthesis off
library utils;
use utils.txt_util.all;
use utils.binaryio.all;
--cadence synthesis on

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;

entity eisV_top is
    generic(
        ic_log2_num_lines_g : natural                        := 4; -- log2 of number of cache lines (i-cache)
        ic_log2_line_size_g : natural                        := 5; -- log2 of size of cache line (size in 32b words) (i-cache)
        dc_log2_num_lines_g : natural                        := 3; -- log2 of number of cache lines (d-cache)
        dc_log2_line_size_g : natural                        := 6; -- log2 of size of cache line (size in 32b words) (d-cache)
        dcache_area_begin_g : std_ulogic_vector(31 downto 0) := x"00000000"; -- where does the dcache area start?
        dma_area_begin_g    : std_ulogic_vector(31 downto 0) := x"80000000"; -- where does the dma area start?
        io_area_begin_g     : std_ulogic_vector(31 downto 0) := x"C0000000" -- where does the IO area start?
    );
    port(
        -- Global control --
        clk_i                  : in  std_ulogic; -- main clock, trigger on rising edge
        rst_ni                 : in  std_ulogic; -- main reset signal, sync, high-active
        irq_i                  : in  std_ulogic_vector(04 downto 0); -- 5 general-purpose hardware interrupts
        nmi_i                  : in  std_ulogic; -- non-maskable interrupt
        -- Data Memory Interface --
        data_req_o             : out std_ulogic; -- data request
        data_busy_i            : in  std_ulogic; -- memory command buffer full
        data_wrdy_i            : in  std_ulogic; -- write fifo is ready
        data_rw_o              : out std_ulogic; -- read/write a block from/to memory
        data_read_length_o     : out std_ulogic_vector(19 downto 0); --length of that block in bytes
        data_rden_o            : out std_ulogic; -- FIFO read enable
        data_wren_o            : out std_ulogic; -- FIFO write enable
        data_wr_last_o         : out std_ulogic; -- last word of write-block
        data_wr_done_i         : in  std_ulogic_vector(1 downto 0);
        data_data_i            : in  std_ulogic_vector(dc_cache_word_width_c - 1 downto 0); -- data input
        data_rrdy_i            : in  std_ulogic; -- read-data ready
        data_base_adr_o        : out std_ulogic_vector(31 downto 0); -- data address, word-indexed
        data_data_o            : out std_ulogic_vector(dc_cache_word_width_c - 1 downto 0); -- data output
        -- IO Interface --
        io_data_i              : in  std_ulogic_vector(31 downto 0); -- data input
        io_ack_i               : in  std_ulogic; -- ack transfer
        io_ren_o               : out std_ulogic; -- read enable
        io_wen_o               : out std_ulogic_vector(03 downto 0); -- 4-bit write enable (for each byte)
        io_adr_o               : out std_ulogic_vector(31 downto 0); -- data address, byte-indexed
        io_data_o              : out std_ulogic_vector(31 downto 0); -- data output
        -- Instruction Memory Interface --
        inst_data_i            : in  std_ulogic_vector(ic_cache_word_width_c - 1 downto 0); -- instruction word input
        inst_base_adr_o        : out std_ulogic_vector(31 downto 0); -- instruction address, word-indexed
        inst_rdy_i             : in  std_ulogic; -- instruction word ready
        inst_ren_o             : out std_ulogic; -- read enable
        inst_req_o             : out std_ulogic; -- instruction request
        inst_wait_i            : in  std_ulogic; -- memory command buffer full
        -- Vector System Interface --
        vpro_ext_vpro_cmd_o    : out vpro_command_t; -- vpro instruction word
        vpro_ext_vpro_cmd_we_o : out std_ulogic; -- cmd write enable
        vpro_cmd_full_i        : in  std_ulogic; -- vpro command fifo is full
        dma_dcache_cmd_o       : out multi_cmd_t;
        dma_dcache_cmd_we_o    : out std_ulogic;
        dma_cmd_full_i         : in  std_ulogic; -- dma command fifo is full
        vpro_dma_fsm_active_o  : out std_ulogic; -- whether the DMA Command generating FSM is active
        -- other
        debug_o                : out eisv_debug_o_t;
        mips_ce_o              : out std_ulogic;
        ic_miss_o              : out std_ulogic;
        ic_hit_o               : out std_ulogic; -- icache access signal
        dc_miss_o              : out std_ulogic;
        dc_hit_o               : out std_ulogic -- dcache access signal
    );
end eisV_top;

architecture behavioral of eisV_top is
    -- constants
    constant addr_width_c : integer := 32;
    constant word_width_c : integer := 32;

    signal core_instr_req_o     : std_ulogic;
    signal core_instr_rvalid_i  : std_ulogic;
    signal core_instr_addr_o    : std_ulogic_vector(31 downto 0);
    signal core_instr_rdata_i   : std_ulogic_vector(31 downto 0);
    signal core_instr_rdata_int : std_ulogic_vector(31 downto 0);
    signal core_data_req_o      : std_ulogic;
    signal core_data_gnt_i      : std_ulogic;
    signal core_data_rvalid_i   : std_ulogic;
    signal core_data_we_o       : std_ulogic;
    signal core_data_be_o       : std_ulogic_vector(3 downto 0);
    signal core_data_addr_o     : std_ulogic_vector(31 downto 0);
    signal core_data_wdata_o    : std_ulogic_vector(31 downto 0);
    signal core_data_rdata_i    : std_ulogic_vector(31 downto 0);
    signal core_irq_i           : std_ulogic_vector(31 downto 0);
    signal core_irq_ack_o       : std_ulogic;
    signal core_irq_id_o        : std_ulogic_vector(4 downto 0);
    signal core_fetch_enable_i  : std_ulogic;

    signal rst_i             : std_ulogic;
    signal core_instr_gnt    : std_ulogic;
    signal core_instr_req_ff : std_ulogic;

    signal core_instr_stall : std_ulogic;

    signal mux_sel_dma_o : std_ulogic;

    signal dma_req_o      : std_ulogic;
    signal dma_adr_o      : std_ulogic_vector(addr_width_c - 1 downto 0);
    signal dma_rden_o     : std_ulogic;
    signal dma_wren_o     : std_ulogic_vector(word_width_c / 8 - 1 downto 0);
    signal dma_rdata_i    : std_ulogic_vector(word_width_c - 1 downto 0);
    signal dma_wdata_o    : std_ulogic_vector(word_width_c - 1 downto 0);
    signal dma_stall_i    : std_ulogic;
    signal dcache_oe_o    : std_ulogic;
    signal dcache_req_o   : std_ulogic;
    signal dcache_adr_o   : std_ulogic_vector(addr_width_c - 1 downto 0);
    signal dcache_rden_o  : std_ulogic;
    signal dcache_wren_o  : std_ulogic_vector(word_width_c / 8 - 1 downto 0);
    signal dcache_stall_i : std_ulogic;
    signal dcache_wdata_o : std_ulogic_vector(word_width_c - 1 downto 0);
    signal dcache_rdata_i : std_ulogic_vector(word_width_c - 1 downto 0);
    --    signal dcache_instr_i : std_ulogic_vector(word_width_c - 1 downto 0);
    signal dcache_instr_o : multi_cmd_t;

    -- dcache to axi mem signals
    signal mem_dcache_req_o         : std_ulogic; -- data request
    signal mem_dcache_busy_i        : std_ulogic; -- memory command buffer full
    signal mem_dcache_wrdy_i        : std_ulogic; -- write fifo is ready
    signal mem_dcache_rw_o          : std_ulogic; -- read/write a block from/to memory
    signal mem_dcache_read_length_o : std_ulogic_vector(19 downto 0); --length of that block in bytes
    signal mem_dcache_rden_o        : std_ulogic; -- FIFO read enable
    signal mem_dcache_wren_o        : std_ulogic; -- FIFO write enable
    signal mem_dcache_wr_last_o     : std_ulogic; -- last word of write-block
    signal mem_dcache_wr_done_i     : std_ulogic_vector(1 downto 0);
    signal mem_dcache_rdata_i       : std_ulogic_vector(data_data_i'range); -- data input
    signal mem_dcache_rrdy_i        : std_ulogic; -- read-data ready
    signal mem_dcache_base_adr_o    : std_ulogic_vector(addr_width_c - 1 downto 0); -- data address, word-indexed
    signal mem_dcache_wdata_o       : std_ulogic_vector(data_data_i'range); -- data output
    signal mem_dcache_busy_o        : std_ulogic;

    -- dma to axi mem signals
    signal mem_dma_req_o         : std_ulogic; -- data request
    signal mem_dma_busy_i        : std_ulogic; -- memory command buffer full
    signal mem_dma_wrdy_i        : std_ulogic; -- write fifo is ready
    signal mem_dma_rw_o          : std_ulogic; -- read/write a block from/to memory
    signal mem_dma_read_length_o : std_ulogic_vector(19 downto 0); --length of that block in bytes
    signal mem_dma_rden_o        : std_ulogic; -- FIFO read enable
    signal mem_dma_wren_o        : std_ulogic; -- FIFO write enable
    signal mem_dma_wr_last_o     : std_ulogic; -- last word of write-block
    signal mem_dma_wr_done_i     : std_ulogic_vector(1 downto 0);
    signal mem_dma_rdata_i       : std_ulogic_vector(data_data_i'range); -- data input
    signal mem_dma_rrdy_i        : std_ulogic; -- read-data ready
    signal mem_dma_base_adr_o    : std_ulogic_vector(addr_width_c - 1 downto 0); -- data address, word-indexed
    signal mem_dma_wdata_o       : std_ulogic_vector(data_data_i'range); -- data output

    -- VPRO custom extension
    signal vpro_custom_extension_bundle : vpro_bundle_t;
    signal vpro_custom_extension_ready  : std_ulogic;

    signal vpro_fsm_dcache_addr : std_ulogic_vector(31 downto 0);
    signal vpro_fsm_dcache_req  : std_ulogic;
    signal vpro_fsm_active      : std_ulogic;
    signal vpro_cmd_full_ff     : std_ulogic;

    signal dcache_clear, dcache_flush : std_ulogic;
    signal icache_clear, icache_flush : std_ulogic; -- @suppress "signal icache_flush is never read"
    signal dcache_req_int             : std_ulogic;

    signal dma_cmd_full_ff : std_ulogic;
    signal vpro_fsm_stall  : std_ulogic;

    constant FSM_SIZE                  : std_ulogic_vector(31 downto 0) := x"FFFFFE40";
    constant FSM_START_ADDRESS_TRIGGER : std_ulogic_vector(31 downto 0) := x"FFFFFE44";
    constant SINGLE_DMA_TRIGGER        : std_ulogic_vector(31 downto 0) := x"FFFFFE48";
    constant DMA_FSM_BUSY              : std_ulogic_vector(31 downto 0) := x"FFFFFE4C";
    signal vpro_dma_fsm_dcache_rvalid  : std_ulogic;

    -- IO Addresses captcured here 
    constant DCACHE_FLUSH_ADDR           : std_ulogic_vector(31 downto 0) := x"FFFFFF04";
    constant DCACHE_CLEAR_ADDR           : std_ulogic_vector(31 downto 0) := x"FFFFFF08";
    constant ICACHE_FLUSH_ADDR           : std_ulogic_vector(31 downto 0) := x"FFFFFF0C";
    constant ICACHE_CLEAR_ADDR           : std_ulogic_vector(31 downto 0) := x"FFFFFF10";
    constant DCACHE_PREFETCH_TRIGER_ADDR : std_ulogic_vector(31 downto 0) := x"FFFFFF24";

    signal dcache_prefetch      : std_ulogic;
    signal dcache_prefetch_addr : std_ulogic_vector(31 downto 0);

    signal io_datao : std_ulogic_vector(32 - 1 downto 0);
    signal io_ack   : std_ulogic;
    signal io_ren   : std_ulogic;
    signal io_wen   : std_ulogic_vector(32 / 8 - 1 downto 0);
    signal io_adr   : std_ulogic_vector(32 - 1 downto 0);
    signal io_datai : std_ulogic_vector(32 - 1 downto 0);

    signal fsm_ack                          : std_ulogic;
    signal fsm_data                         : std_ulogic_vector(32 - 1 downto 0);
    signal dma_dcache_cmd_int               : multi_cmd_t;
    signal dma_fsm_stall_by_dma_cmd_gen_nxt : std_ulogic;
    signal dma_dcache_cmd_we_int            : std_ulogic;

begin

    rst_i <= not rst_ni;

    -- -------------------------------------------------------------------------------------------------
    -- EIS-V Core 
    -- -------------------------------------------------------------------------------------------------
    core_irq_i <= (others => '0');
    --
    -- IRQ: Todo - Hardware + Software (Test)
    --
    -- From external:
    --     irq_i
    --     nmi_i
    --
    -- To Core:
    --     core_irq_i
    --
    -- From Core:  
    --     core_irq_ack_o
    --     core_irq_id_o

    core_fetch_enable_i <= '1';

    eisV_core_inst : eisV_core
        generic map(
            NUM_MHPMCOUNTERS => 16
        )
        port map(
            clk_i             => clk_i,
            rst_ni            => rst_ni, -- EISV_rst_n,
            -- Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
            if_boot_addr_i    => x"00000080", -- core_boot_addr_i,
            mtvec_addr_i      => x"00000000", -- core_mtvec_addr_i,
            hart_id_i         => x"00000000", --core_hart_id_i,
            -- Instruction memory interface
            if_instr_req_o    => core_instr_req_o,
            if_instr_gnt_i    => core_instr_gnt,
            id_instr_rvalid_i => core_instr_rvalid_i,
            if_instr_addr_o   => core_instr_addr_o,
            id_instr_rdata_i  => core_instr_rdata_i,
            -- Data memory interface
            mem_data_req_o    => core_data_req_o,
            mem_data_gnt_i    => core_data_gnt_i,
            wb_data_rvalid_i  => core_data_rvalid_i,
            mem_data_we_o     => core_data_we_o,
            mem_data_be_o     => core_data_be_o,
            mem_data_addr_o   => core_data_addr_o,
            mem_data_wdata_o  => core_data_wdata_o,
            wb_data_rdata_i   => core_data_rdata_i,
            -- Interrupt s
            irq_i             => core_irq_i, -- core_irq_i,
            irq_ack_o         => core_irq_ack_o, -- core_irq_ack_o,
            irq_id_o          => core_irq_id_o, -- core_irq_id_o,
            -- CPU Control Signals
            fetch_enable_i    => core_fetch_enable_i, -- core_fetch_enable_i,
            ex_vpro_bundle_o  => vpro_custom_extension_bundle,
            ex_vpro_rdy_i     => vpro_custom_extension_ready
        );

    -- trace generation
    --cadence synthesis off
    --pragma translate_off
    dcache_trace_gen : if generate_dcache_access_trace generate
        file_output : process
            file trace_file   : text;
            variable line_out : line;
            variable start    : boolean := true;
            variable nr       : integer := 0;
            variable string_v : string(1 to 1);
        begin
            if start then
                file_open(trace_file, "eisv_dcache.trace", write_mode);
                string_v := "W";
                write(line_out, '#');
                write(line_out, ',');
                write(line_out, 'P');
                write(line_out, 'C');
                write(line_out, ',');
                write(line_out, 'R');
                write(line_out, string_v);
                writeline(trace_file, line_out);
                start    := false;
                nr       := 0;
            end if;
            wait on clk_i until clk_i = '1' and clk_i'last_value = '0';

            if (dcache_req_o = '1' and dcache_stall_i = '0') then
                -- core_data_we_o
                -- core_data_be_o
                -- core_data_wdata_o
                -- core_data_rdata_i

                write(line_out, str(nr));
                write(line_out, ',');
                write(line_out, hstr(std_logic_vector(dcache_adr_o)));
                write(line_out, ',');
                if dcache_wren_o /= "0000" then
                    string_v := "W";
                    write(line_out, string_v);
                elsif dcache_rden_o = '1' then
                    write(line_out, 'R');
                end if;
                --                write(line_out, str(to_integer(unsigned(core_data_addr_o))));
                nr := nr + 1;
                writeline(trace_file, line_out);
            end if;
        end process file_output;
    end generate;
    --pragma translate_on
    --cadence synthesis on

    -- -------------------------------------------------------------------------------------------------
    --  FSM to split RISC's Data Port to DMA, DCache and IO 
    -- -------------------------------------------------------------------------------------------------
    eisV_data_distributor_inst : eisV_data_distributor
        generic map(
            addr_width_g              => addr_width_c,
            word_width_g              => word_width_c,
            dcache_area_begin_g       => dcache_area_begin_g,
            dma_area_begin_g          => dma_area_begin_g,
            io_area_begin_g           => io_area_begin_g,
            FSM_SIZE                  => FSM_SIZE,
            FSM_START_ADDRESS_TRIGGER => FSM_START_ADDRESS_TRIGGER,
            SINGLE_DMA_TRIGGER        => SINGLE_DMA_TRIGGER
        )
        port map(
            clk_i                        => clk_i,
            rst_i                        => rst_i,
            eisV_req_i                   => core_data_req_o,
            eisV_gnt_o                   => core_data_gnt_i,
            eisV_rvalid_o                => core_data_rvalid_i,
            eisV_we_i                    => core_data_we_o,
            eisV_be_i                    => core_data_be_o,
            eisV_addr_i                  => core_data_addr_o,
            eisV_wdata_i                 => core_data_wdata_o,
            eisV_rdata_o                 => core_data_rdata_i,
            dma_req_o                    => dma_req_o,
            dma_adr_o                    => dma_adr_o,
            dma_rden_o                   => dma_rden_o,
            dma_wren_o                   => dma_wren_o,
            dma_rdata_i                  => dma_rdata_i,
            dma_wdata_o                  => dma_wdata_o,
            dma_stall_i                  => dma_stall_i,
            vpro_dma_fsm_busy_i          => vpro_fsm_active,
            vpro_dma_fsm_stall_o         => vpro_fsm_stall,
            vpro_dma_fsm_dcache_addr_i   => vpro_fsm_dcache_addr,
            vpro_dma_fsm_dcache_req_i    => vpro_fsm_dcache_req,
            vpro_dma_fsm_dcache_rvalid_o => vpro_dma_fsm_dcache_rvalid,
            vpro_dma_fifo_full_i         => dma_cmd_full_ff,
            dcache_oe_o                  => dcache_oe_o,
            dcache_req_o                 => dcache_req_o,
            dcache_adr_o                 => dcache_adr_o,
            dcache_rden_o                => dcache_rden_o,
            dcache_wren_o                => dcache_wren_o,
            dcache_stall_i               => dcache_stall_i,
            dcache_wdata_o               => dcache_wdata_o,
            dcache_rdata_i               => dcache_rdata_i,
            io_rdata_i                   => io_datai,
            io_ack_i                     => io_ack,
            io_ren_o                     => io_ren,
            io_wen_o                     => io_wen,
            io_adr_o                     => io_adr,
            io_wdata_o                   => io_datao,
            mux_sel_dma_o                => mux_sel_dma_o
        );

    io_data_o <= io_datao;
    io_adr_o  <= io_adr;
    io_wen_o  <= io_wen;
    io_ren_o  <= io_ren;
    io_ack    <= io_ack_i or fsm_ack;
    io_datai  <= io_data_i or fsm_data;

    fsm_busy_p : process(clk_i)
    begin
        if rising_edge(clk_i) then
            fsm_ack  <= '0';
            fsm_data <= (others => '0');
            if (io_adr = DMA_FSM_BUSY) and (io_ren = '1') then
                fsm_ack     <= '1';
                fsm_data(0) <= vpro_fsm_active;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------------------------------
    --  Instruction Cache 
    -- -------------------------------------------------------------------------------------------------
    instruction_streamer_inst : instruction_streamer
        generic map(
            LOG2_NUM_LINES => ic_log2_num_lines_g, -- log2 of number of cache lines
            LOG2_LINE_SIZE => ic_log2_line_size_g -- log2 of size of cache line (size in 32b words)
        )
        port map(
            -- global control --
            clk_i           => clk_i,   -- global clock line, rising-edge
            rst_i           => rst_i,   -- global reset line, high-active, sync
            ce_i            => '1',     -- global clock enable, high-active
            stall_i         => '0',     -- freeze output if any stall
            clear_i         => icache_clear, -- FIXME force reload of cache
            -- CPU instruction interface --
            cpu_oe_i        => '1',     -- FIXME instr_en, -- "IR" update enable
            cpu_instr_adr_i => core_instr_addr_o, -- addressing words (only on boundaries!)
            cpu_instr_req_i => core_instr_req_o, -- this is a valid read request
            cpu_instr_dat_o => core_instr_rdata_int, -- the instruction word
            cpu_stall_o     => core_instr_stall, --FIXME (miss)
            -- Vector CP instruction interface --
            vcp_instr_array => open,    -- vcp_instr_array, -- the instruction word
            -- memory system interface --
            mem_base_adr_o  => inst_base_adr_o, -- addressing words (only on boundaries!)
            mem_dat_i       => inst_data_i,
            mem_req_o       => inst_req_o, -- request data from memory
            mem_wait_i      => inst_wait_i, -- memory command buffer full
            mem_ren_o       => inst_ren_o, -- read enable
            mem_rdy_i       => inst_rdy_i, -- applied data is valid
            hit_o           => ic_hit_o,
            miss_o          => ic_miss_o
        );
    core_instr_gnt      <= not core_instr_stall;
    core_instr_rvalid_i <= (not core_instr_stall) and core_instr_req_ff;
    core_instr_rdata_i  <= core_instr_rdata_int when core_instr_rvalid_i = '1' else (others => '0');
    process(clk_i)
    begin
        if (rising_edge(clk_i)) then
            core_instr_req_ff <= core_instr_req_o;
        end if;
    end process;

    dcache_flush <= '1' when core_data_addr_o = DCACHE_FLUSH_ADDR and (core_data_we_o = '1') and (core_data_be_o = "1111") and (core_data_req_o = '1') else '0';
    dcache_clear <= '1' when core_data_addr_o = DCACHE_CLEAR_ADDR and (core_data_we_o = '1') and (core_data_be_o = "1111") and (core_data_req_o = '1') else '0';
    icache_flush <= '1' when core_data_addr_o = ICACHE_FLUSH_ADDR and (core_data_we_o = '1') and (core_data_be_o = "1111") and (core_data_req_o = '1') else '0';
    icache_clear <= '1' when core_data_addr_o = ICACHE_CLEAR_ADDR and (core_data_we_o = '1') and (core_data_be_o = "1111") and (core_data_req_o = '1') else '0';

    dcache_prefetch      <= '1' when core_data_addr_o = DCACHE_PREFETCH_TRIGER_ADDR and (core_data_we_o = '1') and (core_data_be_o = "1111") and (core_data_req_o = '1') else '0';
    dcache_prefetch_addr <= core_data_wdata_o when dcache_prefetch = '1' else (others => '0');

    dcache_req_int <= dcache_req_o or dcache_flush or dcache_clear;
    -- -------------------------------------------------------------------------------------------------
    -- Data Cache 
    -- -------------------------------------------------------------------------------------------------
    d_cache_inst : d_cache_multiword
        generic map(
            LOG2_NUM_LINES       => dc_log2_num_lines_g, -- log2 of number of cache lines
            LOG2_LINE_SIZE       => dc_log2_line_size_g, -- log2 of size of cache line (size in 32b words)
            log2_associativity_g => 2,
            INSTR_WORD_COUNT     => dc_cache_word_width_c / 32,  -- number of output instruction words
            WORD_WIDTH           => 32, --width of one instruction word
            MEMORY_WORD_WIDTH    => data_data_i'length, -- width of one instruction word
            ADDR_WIDTH           => 32  -- width of address
        )
        port map(
            -- global control --
            clk_i                  => clk_i, -- global clock line, rising-edge
            rst_i                  => rst_i, -- global reset line, high-active, sync
            ce_i                   => '1', -- mem_acc_dcache global clock enable, high-active
            stall_i                => '0', -- FIXME (generated from risc-core) dc_stall freeze output if any stall
            clear_i                => dcache_clear, -- FIXME (generated from risc-core) dc_clear force reload of cache
            flush_i                => dcache_flush, -- FIXME (generated from risc-core) dc_flush force flush of cache
            -- CPU data interface --
            cpu_oe_i               => dcache_oe_o, -- output reg enable
            cpu_req_i              => dcache_req_int, -- mem_req,  -- access to cached memory space
            cpu_adr_i              => dcache_adr_o, -- mem_data.addr, -- addressing words (only on boundaries!)
            cpu_rden_i             => dcache_rden_o, -- core_data_mem_data.rd_en, -- read enable
            cpu_wren_i             => dcache_wren_o, -- FIXME core_data_we_o, -- mem_data.wr_en, -- write enable
            cpu_stall_o            => dcache_stall_i, -- FIXME (miss)
            cpu_data_i             => dcache_wdata_o, --  mem_data.input, -- write-data word
            data_o                 => dcache_instr_o, --     : out multi_cmd_t; -- multiple cmds starting at addr!
            --
            dcache_prefetch_i      => dcache_prefetch,
            dcache_prefetch_addr_i => dcache_prefetch_addr,
            -- memory system interface --
            mem_base_adr_o         => mem_dcache_base_adr_o, -- addressing words (only on boundaries!)
            mem_dat_i              => mem_dcache_rdata_i,
            mem_req_o              => mem_dcache_req_o, -- memory request
            mem_wait_i             => mem_dcache_busy_i, -- memory command buffer full
            mem_ren_o              => mem_dcache_rden_o, -- FIFO read enable
            mem_rdy_i              => mem_dcache_rrdy_i, -- read data ready
            mem_dat_o              => mem_dcache_wdata_o,
            mem_wrdy_i             => mem_dcache_wrdy_i, -- write fifo is ready
            mem_rw_o               => mem_dcache_rw_o, -- read/write a block from/to memory
            mem_wren_o             => mem_dcache_wren_o, -- FIFO write enable
            mem_wr_last_o          => mem_dcache_wr_last_o, -- last word of write-block
            mem_wr_done_i          => mem_dcache_wr_done_i,
            mem_busy_o             => mem_dcache_busy_o,
            -- access statistics --
            hit_o                  => dc_hit_o, -- valid hit access
            miss_o                 => dc_miss_o -- valid miss access
        );
    mem_dcache_read_length_o <= std_ulogic_vector(to_unsigned(data_data_i'length/8 * (2 ** dc_log2_line_size_g), 20)); -- 4-byte for 32-bit word, *4 to get 128-bit mem word
    dcache_rdata_i           <= dcache_instr_o(0);

    -- -------------------------------------------------------------------------------------------------
    --  RISC Core DMA 
    -- -------------------------------------------------------------------------------------------------
    eisV_dma_inst : eisV_dma
        port map(
            clk_i             => clk_i,
            rst_i             => rst_i,
            ce_i              => '1',
            stall_i           => '0',
            stall_o           => dma_stall_i,
            cpu_req_i         => dma_req_o,
            cpu_adr_i         => dma_adr_o,
            cpu_rden_i        => dma_rden_o,
            cpu_wren_i        => dma_wren_o,
            cpu_data_o        => dma_rdata_i,
            cpu_data_i        => dma_wdata_o,
            mem_read_length_o => mem_dma_read_length_o,
            mem_base_adr_o    => mem_dma_base_adr_o,
            mem_dat_i         => mem_dma_rdata_i, -- read data
            mem_dat_o         => mem_dma_wdata_o, -- write data
            mem_req_o         => mem_dma_req_o,
            mem_busy_i        => mem_dma_busy_i,
            mem_wrdy_i        => mem_dma_wrdy_i,
            mem_rw_o          => mem_dma_rw_o,
            mem_rden_o        => mem_dma_rden_o,
            mem_wren_o        => mem_dma_wren_o,
            mem_wr_last_o     => mem_dma_wr_last_o,
            mem_wr_done_i     => mem_dma_wr_done_i,
            mem_rrdy_i        => mem_dma_rrdy_i
        );

    dcache_dma_mux : process(data_busy_i, data_data_i, data_rrdy_i, data_wrdy_i, mem_dcache_base_adr_o, mem_dcache_rden_o, mem_dcache_read_length_o, mem_dcache_req_o, mem_dcache_rw_o, mem_dcache_wdata_o, mem_dcache_wr_last_o, mem_dcache_wren_o, mem_dma_base_adr_o, mem_dma_rden_o, mem_dma_read_length_o, mem_dma_req_o, mem_dma_rw_o, mem_dma_wdata_o, mem_dma_wr_last_o, mem_dma_wren_o, data_wr_done_i, mem_dcache_busy_o)
    begin
        -- default        
        data_req_o           <= mem_dcache_req_o;
        mem_dcache_busy_i    <= data_busy_i;
        mem_dcache_wrdy_i    <= data_wrdy_i;
        data_rw_o            <= mem_dcache_rw_o;
        data_read_length_o   <= mem_dcache_read_length_o;
        data_rden_o          <= mem_dcache_rden_o;
        data_wren_o          <= mem_dcache_wren_o;
        data_wr_last_o       <= mem_dcache_wr_last_o;
        mem_dcache_wr_done_i <= data_wr_done_i;
        mem_dcache_rdata_i   <= data_data_i;
        mem_dcache_rrdy_i    <= data_rrdy_i;
        data_base_adr_o      <= mem_dcache_base_adr_o;
        data_data_o          <= mem_dcache_wdata_o;
        mem_dma_busy_i       <= '1';
        mem_dma_wrdy_i       <= '0';
        mem_dma_rdata_i      <= data_data_i;
        mem_dma_rrdy_i       <= '0';
        mem_dma_wr_done_i    <= data_wr_done_i;

        if mem_dcache_busy_o = '0' then
            data_req_o         <= mem_dma_req_o;
            mem_dma_busy_i     <= data_busy_i;
            mem_dma_wrdy_i     <= data_wrdy_i;
            data_rw_o          <= mem_dma_rw_o;
            data_read_length_o <= mem_dma_read_length_o;
            data_rden_o        <= mem_dma_rden_o;
            data_wren_o        <= mem_dma_wren_o;
            data_wr_last_o     <= mem_dma_wr_last_o;
            mem_dma_rrdy_i     <= data_rrdy_i;
            data_base_adr_o    <= mem_dma_base_adr_o;
            data_data_o        <= mem_dma_wdata_o;
            mem_dcache_busy_i  <= '0';
            mem_dcache_wrdy_i  <= '0';
            mem_dcache_rrdy_i  <= '0';
        end if;
    end process;

    -- -------------------------------------------------------------------------------------------------
    -- RISC Debug output (Axi slave can read this)
    -- -------------------------------------------------------------------------------------------------
    process(core_instr_addr_o, core_instr_rdata_i, core_instr_req_o)
    begin
        debug_o.instr_addr <= core_instr_addr_o;
        debug_o.instr_dat  <= core_instr_rdata_i;
        debug_o.instr_req  <= core_instr_req_o;
    end process;
    mips_ce_o <= core_instr_gnt;

    process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            dma_fsm_stall_by_dma_cmd_gen_nxt <= '0';
        elsif (rising_edge(clk_i)) then
            dma_cmd_full_ff <= dma_cmd_full_i;

            dma_fsm_stall_by_dma_cmd_gen_nxt <= '0';
            if dma_dcache_cmd_int(0)(2) = '1' and dma_dcache_cmd_we_int = '1' then -- start command for dma_cmd_gen
                dma_fsm_stall_by_dma_cmd_gen_nxt <= '1'; -- stall once after the next we
            end if;

            if dma_fsm_stall_by_dma_cmd_gen_nxt = '1' then
                if dma_dcache_cmd_we_int = '1' then -- the next we / base command to dma_cmd_gen
                    dma_cmd_full_ff <= '1';
                else
                    dma_fsm_stall_by_dma_cmd_gen_nxt <= '1';
                end if;
            end if;
        end if;
    end process;

    -- -------------------------------------------------------------------------------------------------
    -- VPRO-DMA Command issue
    -- -------------------------------------------------------------------------------------------------
    eisV_vpro_dma_fsm_i : eisV_vpro_dma_fsm
        generic map(
            FSM_SIZE                  => FSM_SIZE,
            FSM_START_ADDRESS_TRIGGER => FSM_START_ADDRESS_TRIGGER,
            SINGLE_DMA_TRIGGER        => SINGLE_DMA_TRIGGER
        )
        port map(
            clk_i             => clk_i,
            rst_i             => rst_i,
            core_data_addr_i  => core_data_addr_o,
            core_data_req_i   => core_data_req_o,
            core_data_we_i    => core_data_we_o,
            core_data_be_i    => core_data_be_o,
            core_data_wdata_i => core_data_wdata_o,
            dcache_addr_o     => vpro_fsm_dcache_addr,
            dcache_req_o      => vpro_fsm_dcache_req,
            dcache_instr_i    => dcache_instr_o,
            dcache_rvalid_i   => vpro_dma_fsm_dcache_rvalid,
            dcache_stall_i    => dcache_stall_i,
            active_o          => vpro_fsm_active,
            vpro_fsm_stall_i  => vpro_fsm_stall,
            dma_cmd_full_i    => dma_cmd_full_ff,
            dma_cmd_we_o      => dma_dcache_cmd_we_int,
            dma_cmd_o         => dma_dcache_cmd_int
        );

    dma_dcache_cmd_we_o   <= dma_dcache_cmd_we_int;
    dma_dcache_cmd_o      <= dma_dcache_cmd_int;
    vpro_dma_fsm_active_o <= vpro_fsm_active;

    -- -------------------------------------------------------------------------------------------------
    -- VPRO Command issue
    -- -------------------------------------------------------------------------------------------------

    process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            vpro_cmd_full_ff <= '0';
        elsif (rising_edge(clk_i)) then
            vpro_cmd_full_ff <= vpro_cmd_full_i; -- cut critical path
        end if;
    end process;

    -- coverage off
    generate_vpro_custom_ext_register : if (VPRO_CUSTOM_EXTENSION) generate
        eisV_VPRO_ext_register_file_i : eisV_VPRO_ext_register_file
            port map(
                clk                   => clk_i,
                rst_n                 => rst_ni,
                ex_vpro_bundle_i      => vpro_custom_extension_bundle,
                ex_ready_o            => vpro_custom_extension_ready,
                vpro_vpro_fifo_full_i => vpro_cmd_full_ff,
                mem_vpro_cmd_o        => vpro_ext_vpro_cmd_o,
                mem_vpro_we_o         => vpro_ext_vpro_cmd_we_o
            );
    end generate;

    no_generate_vpro_custom_ext_register : if (not VPRO_CUSTOM_EXTENSION) generate
        vpro_ext_vpro_cmd_we_o <= '0';
    end generate;
    -- coverage on
end behavioral;

