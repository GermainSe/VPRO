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

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_specializations.all;
use core_v2pro.package_datawidths.all;

entity dma_crossbar is
    generic(
        NUM_CLUSTERS              : integer := 8;
        NUM_RAMS                  : integer := 8;
        ASSOCIATIVITY_LOG2        : integer := 3;
        RAM_ADDR_WIDTH            : integer := 16;
        DCMA_ADDR_WIDTH           : integer := 32; -- Address Width
        DCMA_DATA_WIDTH           : integer := 64; -- Data Width
        VPRO_DATA_WIDTH           : integer := 16;
        ADDR_WORD_BITWIDTH        : integer := 3;
        ADDR_WORD_SELECT_BITWIDTH : integer := 9;
        ADDR_SET_BITWIDTH         : integer := 7
    );
    port(
        clk_i              : in  std_ulogic; -- Clock 
        areset_n_i         : in  std_ulogic;
        -- dma interface --
        dma_base_adr_i     : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
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
        -- ram interface --
        ram_busy_i         : in  std_ulogic_vector(NUM_RAMS - 1 downto 0);
        ram_wr_en_o        : out std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto 0); -- Write Enable
        ram_rd_en_o        : out std_ulogic_vector(NUM_RAMS - 1 downto 0); -- Memory Enable
        ram_wdata_o        : out std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0); -- Data Input  
        ram_addr_o         : out std_ulogic_vector(NUM_RAMS * RAM_ADDR_WIDTH - 1 downto 0); -- Address Input
        ram_rdata_i        : in  std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0); -- Data Output
        -- controller interface --
        ctrl_addr_o        : out std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0);
        ctrl_is_read_o     : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        ctrl_valid_o       : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        ctrl_is_hit_i      : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        ctrl_line_offset_i : in  std_ulogic_vector(NUM_CLUSTERS * ASSOCIATIVITY_LOG2 - 1 downto 0)
    );
end dma_crossbar;

architecture rtl of dma_crossbar is
    -- constants
    constant ram_log2_c : integer := integer(ceil(log2(real(NUM_RAMS))));

    -- types
    type cluster_dcma_data_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    type cluster_dma_size_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(dma_size_i'length / NUM_CLUSTERS - 1 downto 0);
    type cluster_associativity_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);
    type cluster_ram_addr_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);
    type cluster_ram_idx_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(ram_log2_c - 1 downto 0);
    type cluster_ram_idx_array_pipe_t is array (dcma_num_pipeline_reg_c + 1 downto 0) of cluster_ram_idx_array_t;
    type cluster_data_wren_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto 0);

    type ram_data_array_t is array (NUM_RAMS - 1 downto 0) of std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    type ram_addr_array_t is array (NUM_RAMS - 1 downto 0) of std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);

    type dcma_ram_pipeline_t is array (dcma_num_pipeline_reg_c + 1 downto 0) of std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);

    -- registers
    signal rd_access_ram_idx_nxt : cluster_ram_idx_array_t;
    signal rd_access_ram_idx_ff  : cluster_ram_idx_array_pipe_t;

    signal dma_rd_last_cycle_nxt : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal dma_rd_last_cycle_ff  : dcma_ram_pipeline_t;

    -- signals
    --    signal dma_base_adr_int : cluster_dcma_addr_array_t;
    signal dma_size_int  : cluster_dma_size_array_t;
    signal dma_dat_o_int : cluster_dcma_data_array_t;
    signal dma_dat_i_int : cluster_dcma_data_array_t;

    signal ram_wr_en_int : std_ulogic_vector(ram_wr_en_o'range);
    signal ram_rd_en_int : std_ulogic_vector(ram_rd_en_o'range);
    signal ram_wdata_int : ram_data_array_t;
    signal ram_addr_int  : ram_addr_array_t;
    signal ram_rdata_int : ram_data_array_t;

    signal ctrl_line_offset_int : cluster_associativity_array_t;

    signal access_ram_addr : cluster_ram_addr_array_t;
    signal access_ram_idx  : cluster_ram_idx_array_t;

    signal is_dma_access_allowed  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal access_ram_is_read     : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal access_ram_rrdy        : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal access_ram_wdata_valid : cluster_data_wren_t;
    signal access_ram_rdata_valid : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal access_ram_wdata       : cluster_dcma_data_array_t;
    signal access_ram_rdata       : cluster_dcma_data_array_t;

    signal is_dma_access_allowed_ff : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal access_ram_idx_ff        : cluster_ram_idx_array_t;
begin
    dma_crossbar_dma_module_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        dma_module_inst : dma_crossbar_dma_module
            generic map(
                NUM_RAMS                  => NUM_RAMS,
                ASSOCIATIVITY_LOG2        => ASSOCIATIVITY_LOG2,
                RAM_ADDR_WIDTH            => RAM_ADDR_WIDTH,
                DCMA_ADDR_WIDTH           => DCMA_ADDR_WIDTH,
                DCMA_DATA_WIDTH           => DCMA_DATA_WIDTH,
                VPRO_DATA_WIDTH           => VPRO_DATA_WIDTH,
                ADDR_WORD_BITWIDTH        => ADDR_WORD_BITWIDTH,
                ADDR_WORD_SELECT_BITWIDTH => ADDR_WORD_SELECT_BITWIDTH,
                ADDR_SET_BITWIDTH         => ADDR_SET_BITWIDTH,
                RAM_LOG2                  => ram_log2_c
            )
            port map(
                clk_i                    => clk_i,
                areset_n_i               => areset_n_i,
                dma_base_adr_i           => dma_base_adr_i(DCMA_ADDR_WIDTH * (I + 1) - 1 downto DCMA_ADDR_WIDTH * I),
                dma_size_i               => dma_size_int(I),
                dma_dat_o                => dma_dat_o_int(I),
                dma_dat_i                => dma_dat_i_int(I),
                dma_req_i                => dma_req_i(I),
                dma_busy_o               => dma_busy_o(I),
                dma_rw_i                 => dma_rw_i(I),
                dma_rden_i               => dma_rden_i(I),
                dma_wren_i               => dma_wren_i(I),
                dma_wrdy_o               => dma_wrdy_o(I),
                dma_wr_last_i            => dma_wr_last_i(I),
                dma_rrdy_o               => dma_rrdy_o(I),
                is_dma_access_allowed_i  => is_dma_access_allowed(I),
                access_ram_idx_o         => access_ram_idx(I),
                access_ram_addr_o        => access_ram_addr(I),
                access_ram_is_read_o     => access_ram_is_read(I),
                access_ram_wdata_valid_o => access_ram_wdata_valid(I),
                access_ram_rdata_valid_i => access_ram_rdata_valid(I),
                access_ram_rrdy_o        => access_ram_rrdy(I),
                access_ram_wdata_o       => access_ram_wdata(I),
                access_ram_rdata_i       => access_ram_rdata(I),
                ctrl_addr_o              => ctrl_addr_o(DCMA_ADDR_WIDTH * (I + 1) - 1 downto DCMA_ADDR_WIDTH * I),
                ctrl_is_read_o           => ctrl_is_read_o(I),
                ctrl_valid_o             => ctrl_valid_o(I),
                ctrl_is_hit_i            => ctrl_is_hit_i(I),
                ctrl_line_offset_i       => ctrl_line_offset_int(I)
            );
    end generate;

    ram_pipe_seq : process(clk_i, areset_n_i)
    begin
        if areset_n_i = '0' then
            dma_rd_last_cycle_ff <= (others => (others => '0'));
            rd_access_ram_idx_ff <= (others => (others => (others => '0')));
        elsif rising_edge(clk_i) then
            dma_rd_last_cycle_ff(0) <= dma_rd_last_cycle_nxt;
            rd_access_ram_idx_ff(0) <= rd_access_ram_idx_nxt;
            if dcma_num_pipeline_reg_c > 0 then
                dma_rd_last_cycle_ff(dma_rd_last_cycle_ff'left downto 1) <= dma_rd_last_cycle_ff(dma_rd_last_cycle_ff'left - 1 downto 0);
                rd_access_ram_idx_ff(rd_access_ram_idx_ff'left downto 1) <= rd_access_ram_idx_ff(rd_access_ram_idx_ff'left - 1 downto 0);
            end if;
        end if;
    end process;

    additional_pipe_gen : if dcma_additional_pipeline_reg_in_dma_crossbar_c generate
        ram_ctrl_seq : process(clk_i)
        begin
            if rising_edge(clk_i) then
                is_dma_access_allowed_ff <= is_dma_access_allowed;
                access_ram_idx_ff        <= access_ram_idx;
            end if;
        end process;
    end generate;

    no_additional_pipe_gen : if not dcma_additional_pipeline_reg_in_dma_crossbar_c generate
        is_dma_access_allowed_ff <= is_dma_access_allowed;
        access_ram_idx_ff        <= access_ram_idx;
    end generate;

    ram_wr_en_o <= ram_wr_en_int;
    ram_rd_en_o <= ram_rd_en_int;
    connect_ram_ports_with_internal_signal_gen : for I in 0 to NUM_RAMS - 1 generate
        -- RAM signals
        ram_wdata_o(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I) <= ram_wdata_int(I);
        ram_addr_o(RAM_ADDR_WIDTH * (I + 1) - 1 downto RAM_ADDR_WIDTH * I)    <= ram_addr_int(I);
    end generate;

    ram_comb : process(is_dma_access_allowed_ff, access_ram_idx_ff, access_ram_addr, access_ram_is_read, access_ram_rrdy, access_ram_wdata, access_ram_wdata_valid)
        variable cur_ram_idx_v : integer;
    begin
        -- default
        ram_wr_en_int         <= (others => '0');
        ram_rd_en_int         <= (others => '0');
        ram_wdata_int         <= (others => (others => '-'));
        ram_addr_int          <= (others => (others => '-'));
        dma_rd_last_cycle_nxt <= (others => '0');

        for I in NUM_CLUSTERS - 1 downto 0 loop
            cur_ram_idx_v            := to_integer(unsigned(access_ram_idx_ff(I)));
            rd_access_ram_idx_nxt(I) <= access_ram_idx_ff(I);

            if is_dma_access_allowed_ff(I) = '1' then
                ram_addr_int(cur_ram_idx_v) <= access_ram_addr(I);
                if access_ram_is_read(I) = '1' then
                    if access_ram_rrdy(I) = '1' then
                        ram_rd_en_int(cur_ram_idx_v) <= '1';
                        dma_rd_last_cycle_nxt(I)     <= '1';
                    end if;
                else
                    ram_wr_en_int(cur_ram_idx_v * DCMA_DATA_WIDTH / VPRO_DATA_WIDTH + DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto cur_ram_idx_v * DCMA_DATA_WIDTH / VPRO_DATA_WIDTH) <= access_ram_wdata_valid(I);
                    ram_wdata_int(cur_ram_idx_v)                                                                                                                                      <= access_ram_wdata(I);
                end if;
            end if;
        end loop;
    end process;

    dma_readdata_comb : process(dma_rd_last_cycle_ff, ram_rdata_int, rd_access_ram_idx_ff)
        variable cur_ram_idx_v : integer;
    begin
        --default
        access_ram_rdata_valid <= (others => '0');
        access_ram_rdata       <= (others => (others => '-'));

        for I in 0 to NUM_CLUSTERS - 1 loop
            cur_ram_idx_v := to_integer(unsigned(rd_access_ram_idx_ff(dcma_num_pipeline_reg_c)(I)));
            if dma_rd_last_cycle_ff(dcma_num_pipeline_reg_c)(I) = '1' then
                access_ram_rdata(I)       <= ram_rdata_int(cur_ram_idx_v);
                access_ram_rdata_valid(I) <= '1';
            end if;
        end loop;
    end process;

    is_ram_busy_comb : process(access_ram_idx, ctrl_is_hit_i, ram_busy_i)
        variable is_ram_accessed_v : std_ulogic_vector(NUM_RAMS - 1 downto 0);
        variable cur_ram_idx_v     : integer;
    begin
        -- default
        is_dma_access_allowed <= (others => '0');
        is_ram_accessed_v     := (others => '0');

        for I in 0 to NUM_CLUSTERS - 1 loop
            -- give higher priority to DMAs with smaller index
            cur_ram_idx_v := to_integer(unsigned(access_ram_idx(I)));
            if ctrl_is_hit_i(I) = '1' and is_ram_accessed_v(cur_ram_idx_v) = '0' and ram_busy_i(cur_ram_idx_v) = '0' then
                is_dma_access_allowed(I)         <= '1';
                is_ram_accessed_v(cur_ram_idx_v) := '1';
            end if;
        end loop;
    end process;

    connect_dma_ports_with_internal_signals_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        -- DMA signals
        dma_dat_o(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I) <= dma_dat_o_int(I);

        dma_dat_i_int(I) <= dma_dat_i(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I);
        dma_size_int(I)  <= dma_size_i(dma_size_i'length / NUM_CLUSTERS * (I + 1) - 1 downto dma_size_i'length / NUM_CLUSTERS * I);
        --        dma_base_adr_int(I) <= std_ulogic_vector(shift_right(unsigned(dma_base_adr_i(DCMA_ADDR_WIDTH * (I + 1) - 1 downto DCMA_ADDR_WIDTH * I)), ADDR_WORD_BITWIDTH));
    end generate;

    connect_ram_ports_with_internal_signals_gen : for I in 0 to NUM_RAMS - 1 generate
        -- RAM signals
        --        ram_wdata_o(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I) <= ram_wdata_int(I);
        --        ram_addr_o(RAM_ADDR_WIDTH * (I + 1) - 1 downto RAM_ADDR_WIDTH * I)    <= ram_addr_int(I);

        ram_rdata_int(I) <= ram_rdata_i(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I);
    end generate;

    connect_ctrl_ports_with_internal_signals_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        -- DMA signals
        ctrl_line_offset_int(I) <= ctrl_line_offset_i(ASSOCIATIVITY_LOG2 * (I + 1) - 1 downto ASSOCIATIVITY_LOG2 * I);
    end generate;
end architecture rtl;
