--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
-- coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dcma_top is
    generic(
        NUM_CLUSTERS          : integer := 8;
        NUM_RAMS              : integer := 8;
        ASSOCIATIVITY_LOG2    : integer := 2;
        RAM_ADDR_WIDTH        : integer := 14;
        DCMA_ADDR_WIDTH       : integer := 32; -- Address Width
        DCMA_DATA_WIDTH       : integer := 64; -- Data Width
        VPRO_DATA_WIDTH       : integer := 16;
        AXI_DATA_WIDTH        : integer := 512;
        CACHE_LINE_SIZE_BYTES : integer := 4096
    );
    port(
        clk_i              : in  std_ulogic; -- Clock 
        areset_n_i         : in  std_ulogic;
        -- dma interface --
        dma_base_adr_i     : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0); -- addressing bytes
        dma_size_i         : in  std_ulogic_vector(NUM_CLUSTERS * 20 - 1 downto 0); -- quantity
        dma_dat_o          : out std_ulogic_vector(NUM_CLUSTERS * DCMA_DATA_WIDTH - 1 downto 0); -- data from main memory
        dma_dat_i          : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_DATA_WIDTH - 1 downto 0); -- data to main memory
        dma_req_i          : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- memory request
        dma_busy_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- no request possible right now
        dma_rw_i           : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- read/write a block from/to memory
        dma_rden_i         : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- FIFO read enable
        dma_wren_i         : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- FIFO write enable
        dma_wrdy_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- data can be written
        dma_wr_last_i      : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- last word of write-block
        dma_rrdy_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- read data ready
        -- axi master interface unit (AIU) interface --
        aiu_req_o          : out std_ulogic; -- data request
        aiu_busy_i         : in  std_ulogic; -- memory command buffer full
        aiu_rw_o           : out std_ulogic; -- read/write a block from/to memory
        aiu_read_length_o  : out std_ulogic_vector(19 downto 0); --length of that block in bytes
        aiu_base_adr_o     : out std_ulogic_vector(31 downto 0); -- byte address
        aiu_fifo_rden_o    : out std_ulogic; -- FIFO read enable
        aiu_fifo_wren_o    : out std_ulogic; -- FIFO write enable
        aiu_fifo_wr_last_o : out std_ulogic; -- last word of write-block
        aiu_fifo_data_i    : in  std_ulogic_vector(AXI_DATA_WIDTH - 1 downto 0); -- data output
        aiu_fifo_wrdy_i    : in  std_ulogic; -- write fifo is ready
        aiu_fifo_rrdy_i    : in  std_ulogic; -- read-data ready
        aiu_fifo_data_o    : out std_ulogic_vector(AXI_DATA_WIDTH - 1 downto 0); -- data input
        aiu_wr_done_i      : in  std_ulogic_vector(1 downto 0); -- '00' not done, '01' done, '10' data error, '11' req error
        -- control signals from io fabric
        dcma_flush         : in  std_ulogic;
        dcma_reset         : in  std_ulogic;
        dcma_busy          : out std_ulogic
    );
end dcma_top;

architecture RTL of dcma_top is
    -- constants
    constant cache_mem_size_bytes_c : integer := NUM_RAMS * (2 ** RAM_ADDR_WIDTH) * DCMA_DATA_WIDTH / 8;
    constant num_cache_lines_c      : integer := cache_mem_size_bytes_c / CACHE_LINE_SIZE_BYTES;
    --    constant num_cache_lines_log2_c : integer := integer(ceil(log2(real(num_cache_lines_c))));
    constant num_sets_c             : integer := num_cache_lines_c / (2 ** ASSOCIATIVITY_LOG2);

    -- ADDR: |TAG|SET|WORD_SEL|WORD|
    constant addr_set_width_c         : integer := integer(ceil(log2(real(num_sets_c))));
    constant addr_word_offset_width_c : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH / 8))));
    constant addr_word_sel_width_c    : integer := integer(ceil(log2(real(CACHE_LINE_SIZE_BYTES / (DCMA_DATA_WIDTH / 8)))));
    --    constant addr_tag_width_c         : integer := DCMA_ADDR_WIDTH - addr_set_width_c - addr_word_sel_width_c - addr_word_offset_width_c;

    -- components
    component dcma_controller
        generic(
            NUM_CLUSTERS          : integer := 8;
            NUM_RAMS              : integer := 32;
            ASSOCIATIVITY_LOG2    : integer := 2;
            RAM_ADDR_WIDTH        : integer := 12;
            DCMA_ADDR_WIDTH       : integer := 32;
            DCMA_DATA_WIDTH       : integer := 64;
            CACHE_LINE_SIZE_BYTES : integer := 1024
        );
        port(
            clk_i                : in  std_ulogic;
            areset_n_i           : in  std_ulogic;
            dma_addr_i           : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0);
            dma_is_read_i        : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_valid_i          : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_is_hit_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_line_offset_o    : out std_ulogic_vector(NUM_CLUSTERS * ASSOCIATIVITY_LOG2 - 1 downto 0);
            ram_axi_cache_addr_o : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
            ram_axi_mem_addr_o   : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
            ram_axi_is_read_o    : out std_ulogic;
            ram_axi_valid_o      : out std_ulogic;
            ram_axi_is_busy_i    : in  std_ulogic;
            dcma_flush           : in  std_ulogic;
            dcma_reset           : in  std_ulogic;
            dcma_busy            : out std_ulogic
        );
    end component dcma_controller;

    component dma_crossbar
        generic(
            NUM_CLUSTERS              : integer := 12;
            NUM_RAMS                  : integer := 32;
            ASSOCIATIVITY_LOG2        : integer := 2;
            RAM_ADDR_WIDTH            : integer := 12;
            DCMA_ADDR_WIDTH           : integer := 32;
            DCMA_DATA_WIDTH           : integer := 64;
            VPRO_DATA_WIDTH           : integer := 16;
            ADDR_WORD_BITWIDTH        : integer;
            ADDR_WORD_SELECT_BITWIDTH : integer;
            ADDR_SET_BITWIDTH         : integer
        );
        port(
            clk_i              : in  std_ulogic;
            areset_n_i         : in  std_ulogic;
            dma_base_adr_i     : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0);
            dma_size_i         : in  std_ulogic_vector(NUM_CLUSTERS * 20 - 1 downto 0);
            dma_dat_o          : out std_ulogic_vector(NUM_CLUSTERS * DCMA_DATA_WIDTH - 1 downto 0);
            dma_dat_i          : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_DATA_WIDTH - 1 downto 0);
            dma_req_i          : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_busy_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_rw_i           : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_rden_i         : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_wren_i         : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_wrdy_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_wr_last_i      : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_rrdy_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            ram_busy_i         : in  std_ulogic_vector(NUM_RAMS - 1 downto 0);
            ram_wr_en_o        : out std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto 0);
            ram_rd_en_o        : out std_ulogic_vector(NUM_RAMS - 1 downto 0);
            ram_wdata_o        : out std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);
            ram_addr_o         : out std_ulogic_vector(NUM_RAMS * RAM_ADDR_WIDTH - 1 downto 0);
            ram_rdata_i        : in  std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);
            ctrl_addr_o        : out std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0);
            ctrl_is_read_o     : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            ctrl_valid_o       : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            ctrl_is_hit_i      : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            ctrl_line_offset_i : in  std_ulogic_vector(NUM_CLUSTERS * ASSOCIATIVITY_LOG2 - 1 downto 0)
        );
    end component dma_crossbar;

    component dcma_ram_wrapper
        generic(
            ADDR_WIDTH      : integer := 12;
            DATA_WIDTH      : integer := 64;
            VPRO_WORD_WIDTH : integer := 16
        );
        port(
            clk     : in  std_ulogic;
            wr_en_a : in  std_ulogic_vector(DATA_WIDTH / VPRO_WORD_WIDTH - 1 downto 0);
            rd_en_a : in  std_ulogic;
            busy_a  : out std_ulogic;
            wdata_a : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            addr_a  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            rdata_a : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            wr_en_b : in  std_ulogic_vector(DATA_WIDTH / VPRO_WORD_WIDTH - 1 downto 0);
            rd_en_b : in  std_ulogic;
            busy_b  : out std_ulogic;
            wdata_b : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            addr_b  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            rdata_b : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component dcma_ram_wrapper;

    component ram_axi_crossbar
        generic(
            NUM_RAMS              : integer := 32;
            RAM_ADDR_WIDTH        : integer := 12;
            DCMA_ADDR_WIDTH       : integer := 32;
            DCMA_DATA_WIDTH       : integer := 64;
            AXI_DATA_WIDTH        : integer := 512;
            CACHE_LINE_SIZE_BYTES : integer
        );
        port(
            clk_i              : in  std_ulogic;
            areset_n_i         : in  std_ulogic;
            cmd_req_o          : out std_ulogic;
            cmd_busy_i         : in  std_ulogic;
            cmd_rw_o           : out std_ulogic;
            cmd_read_length_o  : out std_ulogic_vector(19 downto 0);
            cmd_base_adr_o     : out std_ulogic_vector(31 downto 0);
            cmd_fifo_rden_o    : out std_ulogic;
            cmd_fifo_wren_o    : out std_ulogic;
            cmd_fifo_wr_last_o : out std_ulogic;
            cmd_fifo_data_i    : in  std_ulogic_vector(AXI_DATA_WIDTH - 1 downto 0);
            cmd_fifo_wrdy_i    : in  std_ulogic;
            cmd_fifo_rrdy_i    : in  std_ulogic;
            cmd_fifo_data_o    : out std_ulogic_vector(AXI_DATA_WIDTH - 1 downto 0);
            cmd_wr_done_i      : in  std_ulogic_vector(1 downto 0); -- '00' not done, '01' done, '10' data error, '11' req error
            ram_wr_en_o        : out std_ulogic_vector(NUM_RAMS - 1 downto 0);
            ram_rd_en_o        : out std_ulogic_vector(NUM_RAMS - 1 downto 0);
            ram_wdata_o        : out std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);
            ram_addr_o         : out std_ulogic_vector(NUM_RAMS * RAM_ADDR_WIDTH - 1 downto 0);
            ram_rdata_i        : in  std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);
            ctrl_cache_addr_i  : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
            ctrl_mem_addr_i    : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
            ctrl_is_read_i     : in  std_ulogic;
            ctrl_valid_i       : in  std_ulogic;
            ctrl_is_busy_o     : out std_ulogic
        );
    end component ram_axi_crossbar;

    -- signals
    signal dma_addr        : std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0);
    signal dma_is_read     : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal dma_valid       : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal dma_is_hit      : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal dma_line_offset : std_ulogic_vector(NUM_CLUSTERS * ASSOCIATIVITY_LOG2 - 1 downto 0);

    signal ram_axi_cache_addr : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal ram_axi_mem_addr   : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal ram_axi_is_read    : std_ulogic;
    signal ram_axi_valid      : std_ulogic;
    signal ram_axi_is_busy    : std_ulogic;

    signal dma_ram_busy  : std_ulogic_vector(NUM_RAMS - 1 downto 0);
    signal dma_ram_wr_en : std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto 0);
    signal dma_ram_rd_en : std_ulogic_vector(NUM_RAMS - 1 downto 0);
    signal dma_ram_wdata : std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);
    signal dma_ram_addr  : std_ulogic_vector(NUM_RAMS * RAM_ADDR_WIDTH - 1 downto 0);
    signal dma_ram_rdata : std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);

    signal ram_axi_wr_en     : std_ulogic_vector(NUM_RAMS - 1 downto 0);
    signal ram_axi_wr_en_int : std_ulogic_vector(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH * NUM_RAMS - 1 downto 0);
    signal ram_axi_rd_en     : std_ulogic_vector(NUM_RAMS - 1 downto 0);
    signal ram_axi_wdata     : std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);
    signal ram_axi_addr      : std_ulogic_vector(NUM_RAMS * RAM_ADDR_WIDTH - 1 downto 0);
    signal ram_axi_rdata     : std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0);
begin
    dcma_controller_inst : dcma_controller
        generic map(
            NUM_CLUSTERS          => NUM_CLUSTERS,
            NUM_RAMS              => NUM_RAMS,
            ASSOCIATIVITY_LOG2    => ASSOCIATIVITY_LOG2,
            RAM_ADDR_WIDTH        => RAM_ADDR_WIDTH,
            DCMA_ADDR_WIDTH       => DCMA_ADDR_WIDTH,
            DCMA_DATA_WIDTH       => DCMA_DATA_WIDTH,
            CACHE_LINE_SIZE_BYTES => CACHE_LINE_SIZE_BYTES
        )
        port map(
            clk_i                => clk_i,
            areset_n_i           => areset_n_i,
            dma_addr_i           => dma_addr,
            dma_is_read_i        => dma_is_read,
            dma_valid_i          => dma_valid,
            dma_is_hit_o         => dma_is_hit,
            dma_line_offset_o    => dma_line_offset,
            ram_axi_cache_addr_o => ram_axi_cache_addr,
            ram_axi_mem_addr_o   => ram_axi_mem_addr,
            ram_axi_is_read_o    => ram_axi_is_read,
            ram_axi_valid_o      => ram_axi_valid,
            ram_axi_is_busy_i    => ram_axi_is_busy,
            dcma_flush           => dcma_flush,
            dcma_reset           => dcma_reset,
            dcma_busy            => dcma_busy
        );

    dma_crossbar_inst : dma_crossbar
        generic map(
            NUM_CLUSTERS              => NUM_CLUSTERS,
            NUM_RAMS                  => NUM_RAMS,
            ASSOCIATIVITY_LOG2        => ASSOCIATIVITY_LOG2,
            RAM_ADDR_WIDTH            => RAM_ADDR_WIDTH,
            DCMA_ADDR_WIDTH           => DCMA_ADDR_WIDTH,
            DCMA_DATA_WIDTH           => DCMA_DATA_WIDTH,
            VPRO_DATA_WIDTH           => VPRO_DATA_WIDTH,
            ADDR_WORD_BITWIDTH        => addr_word_offset_width_c,
            ADDR_WORD_SELECT_BITWIDTH => addr_word_sel_width_c,
            ADDR_SET_BITWIDTH         => addr_set_width_c
        )
        port map(
            clk_i              => clk_i,
            areset_n_i         => areset_n_i,
            dma_base_adr_i     => dma_base_adr_i,
            dma_size_i         => dma_size_i,
            dma_dat_o          => dma_dat_o,
            dma_dat_i          => dma_dat_i,
            dma_req_i          => dma_req_i,
            dma_busy_o         => dma_busy_o,
            dma_rw_i           => dma_rw_i,
            dma_rden_i         => dma_rden_i,
            dma_wren_i         => dma_wren_i,
            dma_wrdy_o         => dma_wrdy_o,
            dma_wr_last_i      => dma_wr_last_i,
            dma_rrdy_o         => dma_rrdy_o,
            ram_busy_i         => dma_ram_busy,
            ram_wr_en_o        => dma_ram_wr_en,
            ram_rd_en_o        => dma_ram_rd_en,
            ram_wdata_o        => dma_ram_wdata,
            ram_addr_o         => dma_ram_addr,
            ram_rdata_i        => dma_ram_rdata,
            ctrl_addr_o        => dma_addr,
            ctrl_is_read_o     => dma_is_read,
            ctrl_valid_o       => dma_valid,
            ctrl_is_hit_i      => dma_is_hit,
            ctrl_line_offset_i => dma_line_offset
        );

    ram_axi_crossbar_inst : ram_axi_crossbar
        generic map(
            NUM_RAMS              => NUM_RAMS,
            RAM_ADDR_WIDTH        => RAM_ADDR_WIDTH,
            DCMA_ADDR_WIDTH       => DCMA_ADDR_WIDTH,
            DCMA_DATA_WIDTH       => DCMA_DATA_WIDTH,
            AXI_DATA_WIDTH        => AXI_DATA_WIDTH,
            CACHE_LINE_SIZE_BYTES => CACHE_LINE_SIZE_BYTES
        )
        port map(
            clk_i              => clk_i,
            areset_n_i         => areset_n_i,
            cmd_req_o          => aiu_req_o,
            cmd_busy_i         => aiu_busy_i,
            cmd_rw_o           => aiu_rw_o,
            cmd_read_length_o  => aiu_read_length_o,
            cmd_base_adr_o     => aiu_base_adr_o,
            cmd_fifo_rden_o    => aiu_fifo_rden_o,
            cmd_fifo_wren_o    => aiu_fifo_wren_o,
            cmd_fifo_wr_last_o => aiu_fifo_wr_last_o,
            cmd_fifo_data_i    => aiu_fifo_data_i,
            cmd_fifo_wrdy_i    => aiu_fifo_wrdy_i,
            cmd_fifo_rrdy_i    => aiu_fifo_rrdy_i,
            cmd_fifo_data_o    => aiu_fifo_data_o,
            cmd_wr_done_i      => aiu_wr_done_i,
            ram_wr_en_o        => ram_axi_wr_en,
            ram_rd_en_o        => ram_axi_rd_en,
            ram_wdata_o        => ram_axi_wdata,
            ram_addr_o         => ram_axi_addr,
            ram_rdata_i        => ram_axi_rdata,
            ctrl_cache_addr_i  => ram_axi_cache_addr,
            ctrl_mem_addr_i    => ram_axi_mem_addr,
            ctrl_is_read_i     => ram_axi_is_read,
            ctrl_valid_i       => ram_axi_valid,
            ctrl_is_busy_o     => ram_axi_is_busy
        );

    ram_gen : for I in 0 to NUM_RAMS - 1 generate
        ram_inst : dcma_ram_wrapper
            generic map(
                ADDR_WIDTH      => RAM_ADDR_WIDTH,
                DATA_WIDTH      => DCMA_DATA_WIDTH,
                VPRO_WORD_WIDTH => VPRO_DATA_WIDTH
            )
            port map(
                clk     => clk_i,
                wr_en_a => dma_ram_wr_en(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH / VPRO_DATA_WIDTH * I),
                rd_en_a => dma_ram_rd_en(I),
                busy_a  => dma_ram_busy(I),
                wdata_a => dma_ram_wdata(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I),
                addr_a  => dma_ram_addr(RAM_ADDR_WIDTH * (I + 1) - 1 downto RAM_ADDR_WIDTH * I),
                rdata_a => dma_ram_rdata(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I),
                wr_en_b => ram_axi_wr_en_int(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH / VPRO_DATA_WIDTH * I),
                rd_en_b => ram_axi_rd_en(I),
                busy_b  => open,
                wdata_b => ram_axi_wdata(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I),
                addr_b  => ram_axi_addr(RAM_ADDR_WIDTH * (I + 1) - 1 downto RAM_ADDR_WIDTH * I),
                rdata_b => ram_axi_rdata(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I)
            );
    end generate;

    process(ram_axi_wr_en)
    begin
        for I in 0 to NUM_RAMS - 1 loop
            for J in 0 to DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 loop
                ram_axi_wr_en_int(I * DCMA_DATA_WIDTH / VPRO_DATA_WIDTH + J) <= ram_axi_wr_en(I);
                --                dma_ram_wr_en_int(I * DCMA_DATA_WIDTH / VPRO_DATA_WIDTH + J) <= dma_ram_wr_en(I);
            end loop;
        end loop;
    end process;
end architecture RTL;
