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

entity dcma_passthrough_mux is
    generic(
        NUM_CLUSTERS    : integer := 8;
        DCMA_ADDR_WIDTH : integer := 32; -- Address Width
        DCMA_DATA_WIDTH : integer := 64; -- Data Width
        VPRO_DATA_WIDTH : integer := 16
    );
    port(
        clk_i              : in  std_ulogic; -- DCMA/DMA Clock 
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
        aiu_fifo_data_i    : in  std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- data output
        aiu_fifo_wrdy_i    : in  std_ulogic; -- write fifo is ready
        aiu_fifo_rrdy_i    : in  std_ulogic; -- read-data ready
        aiu_fifo_data_o    : out std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0) -- data input
    );
end dcma_passthrough_mux;

architecture RTL of dcma_passthrough_mux is
    -- constants
    constant num_cluster_log2_c           : integer := integer(ceil(log2(real(NUM_CLUSTERS))));
    constant dcma_data_width_bytes_log2_c : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH / 8))));
    constant align_width_log2_c           : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH))));

    -- components

    -- types
    type cluster_dcma_addr_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    type cluster_dcma_data_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    type cluster_dma_size_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(dma_size_i'length / NUM_CLUSTERS - 1 downto 0);

    -- register
    signal idle_ff, idle_nxt                                   : std_ulogic;
    signal active_dma_ff, active_dma_nxt                       : std_ulogic_vector(num_cluster_log2_c - 1 downto 0);
    signal is_read_ff, is_read_nxt                             : std_ulogic;
    signal remain_read_transfers_ff, remain_read_transfers_nxt : std_ulogic_vector(dma_size_i'length / NUM_CLUSTERS - dcma_data_width_bytes_log2_c - 1 downto 0);

    -- signals
    signal dma_base_adr_int : cluster_dcma_addr_array_t;
    signal dma_size_int     : cluster_dma_size_array_t;
    signal dma_dat_o_int    : cluster_dcma_data_array_t;
    signal dma_dat_i_int    : cluster_dcma_data_array_t;
begin
    -- register to output

    seq : process(clk_i, areset_n_i)
    begin
        if areset_n_i = '0' then
            idle_ff                  <= '1';
            active_dma_ff            <= (others => '0');
            remain_read_transfers_ff <= (others => '0');
            is_read_ff               <= '0';
        elsif rising_edge(clk_i) then
            idle_ff                  <= idle_nxt;
            active_dma_ff            <= active_dma_nxt;
            remain_read_transfers_ff <= remain_read_transfers_nxt;
            is_read_ff               <= is_read_nxt;
        end if;
    end process;

    comb : process(idle_ff, active_dma_ff, remain_read_transfers_ff, aiu_busy_i, aiu_fifo_data_i, aiu_fifo_rrdy_i, aiu_fifo_wrdy_i, dma_base_adr_int, dma_dat_i_int, dma_rden_i, dma_req_i, dma_rw_i, dma_size_int, dma_wr_last_i, dma_wren_i, is_read_ff)
        variable nr_transfers_v        : unsigned(dma_base_adr_int(0)'range);
        variable active_dma_ff_integer : integer;
    begin
        -- default 
        idle_nxt                  <= idle_ff;
        active_dma_nxt            <= active_dma_ff;
        remain_read_transfers_nxt <= remain_read_transfers_ff;
        is_read_nxt               <= is_read_ff;

        dma_dat_o_int <= (others => (others => '-'));
        dma_wrdy_o    <= (others => '0');
        dma_rrdy_o    <= (others => '0');
        dma_busy_o    <= (others => '1');

        -- placeholders
        active_dma_ff_integer := to_integer(unsigned(active_dma_ff));
        nr_transfers_v        := resize(shift_right(unsigned(std_ulogic_vector(dma_base_adr_int(active_dma_ff_integer)(dcma_data_width_bytes_log2_c - 1 downto 0))) + unsigned(dma_size_int(active_dma_ff_integer)) - 1, dcma_data_width_bytes_log2_c), nr_transfers_v'length);

        -- default mux to dma 0
        aiu_req_o                            <= dma_req_i(active_dma_ff_integer);
        aiu_rw_o                             <= dma_rw_i(active_dma_ff_integer);
        aiu_read_length_o                    <= dma_size_int(active_dma_ff_integer);
        aiu_base_adr_o                       <= dma_base_adr_int(active_dma_ff_integer);
        aiu_fifo_rden_o                      <= dma_rden_i(active_dma_ff_integer);
        aiu_fifo_wren_o                      <= dma_wren_i(active_dma_ff_integer);
        aiu_fifo_wr_last_o                   <= dma_wr_last_i(active_dma_ff_integer);
        aiu_fifo_data_o                      <= dma_dat_i_int(active_dma_ff_integer);
        dma_dat_o_int(active_dma_ff_integer) <= aiu_fifo_data_i;
        dma_wrdy_o(active_dma_ff_integer)    <= aiu_fifo_wrdy_i;
        dma_rrdy_o(active_dma_ff_integer)    <= aiu_fifo_rrdy_i;

        if idle_ff = '1' then
            if dma_req_i(active_dma_ff_integer) = '1' then
                if aiu_busy_i = '0' then
                    dma_busy_o(active_dma_ff_integer)   <= '0';
                    is_read_nxt                         <= not dma_rw_i(active_dma_ff_integer);
                    remain_read_transfers_nxt           <= std_ulogic_vector(resize(nr_transfers_v, remain_read_transfers_nxt'length));

                    idle_nxt <= '0';
                end if;
            else
                active_dma_nxt <= std_ulogic_vector(unsigned(active_dma_ff) + 1);
                if unsigned(active_dma_ff) = NUM_CLUSTERS - 1 then
                    active_dma_nxt <= (others => '0');
                end if;
            end if;
        else
            if is_read_ff = '1' then
                if dma_rden_i(active_dma_ff_integer) = '1' then
                    remain_read_transfers_nxt <= std_ulogic_vector(unsigned(remain_read_transfers_ff) - 1);

                    if unsigned(remain_read_transfers_ff) = 0 then
                        active_dma_nxt <= std_ulogic_vector(unsigned(active_dma_ff) + 1);
                        if unsigned(active_dma_ff) = NUM_CLUSTERS - 1 then
                            active_dma_nxt <= (others => '0');
                        end if;

                        idle_nxt <= '1';
                    end if;
                end if;
            else
                if dma_wren_i(active_dma_ff_integer) = '1' and dma_wr_last_i(active_dma_ff_integer) = '1' then
                    active_dma_nxt <= std_ulogic_vector(unsigned(active_dma_ff) + 1);
                    if unsigned(active_dma_ff) = NUM_CLUSTERS - 1 then
                        active_dma_nxt <= (others => '0');
                    end if;

                    idle_nxt <= '1';
                end if;
            end if;
            -- when is transfer finished?
        end if;
    end process;

    connect_dma_ports_with_internal_signals_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        -- DMA signals
        dma_dat_o(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I) <= dma_dat_o_int(I);

        dma_dat_i_int(I)    <= dma_dat_i(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I);
        dma_size_int(I)     <= dma_size_i(dma_size_i'length / NUM_CLUSTERS * (I + 1) - 1 downto dma_size_i'length / NUM_CLUSTERS * I);
        dma_base_adr_int(I) <= std_ulogic_vector(dma_base_adr_i(DCMA_ADDR_WIDTH * (I + 1) - 1 downto DCMA_ADDR_WIDTH * I));
    end generate;
end architecture RTL;
