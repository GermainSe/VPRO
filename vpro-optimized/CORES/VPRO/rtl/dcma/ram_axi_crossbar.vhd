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

entity ram_axi_crossbar is
    generic(
        NUM_RAMS              : integer := 32; -- required: AXI_DATA_WIDTH/DCMA_DATA_WIDTH < NUM_RAMS
        RAM_ADDR_WIDTH        : integer := 12;
        DCMA_ADDR_WIDTH       : integer := 32; -- Address Width
        DCMA_DATA_WIDTH       : integer := 64; -- Data Width
        AXI_DATA_WIDTH        : integer := 512;
        CACHE_LINE_SIZE_BYTES : integer
    );
    port(
        clk_i              : in  std_ulogic; -- Clock 
        areset_n_i         : in  std_ulogic;
        -- axi interface unit master interface --
        cmd_req_o          : out std_ulogic; -- data request
        cmd_busy_i         : in  std_ulogic; -- memory command buffer full
        cmd_rw_o           : out std_ulogic; -- read/write a block from/to memory
        cmd_read_length_o  : out std_ulogic_vector(19 downto 0); --length of that block in bytes
        cmd_base_adr_o     : out std_ulogic_vector(31 downto 0); -- data address, word-indexed
        cmd_fifo_rden_o    : out std_ulogic; -- FIFO read enable
        cmd_fifo_wren_o    : out std_ulogic; -- FIFO write enable
        cmd_fifo_wr_last_o : out std_ulogic; -- last word of write-block
        cmd_fifo_data_i    : in  std_ulogic_vector(AXI_DATA_WIDTH - 1 downto 0); -- data output
        cmd_fifo_wrdy_i    : in  std_ulogic; -- write fifo is ready
        cmd_fifo_rrdy_i    : in  std_ulogic; -- read-data ready
        cmd_fifo_data_o    : out std_ulogic_vector(AXI_DATA_WIDTH - 1 downto 0); -- data input
        cmd_wr_done_i      : in  std_ulogic_vector(1 downto 0); -- '00' not done, '01' done, '10' data error, '11' req error
        -- ram interface --
        ram_wr_en_o        : out std_ulogic_vector(NUM_RAMS - 1 downto 0); -- Write Enable
        ram_rd_en_o        : out std_ulogic_vector(NUM_RAMS - 1 downto 0); -- Memory Enable
        ram_wdata_o        : out std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0); -- Data Input  
        ram_addr_o         : out std_ulogic_vector(NUM_RAMS * RAM_ADDR_WIDTH - 1 downto 0); -- Address Input
        ram_rdata_i        : in  std_ulogic_vector(NUM_RAMS * DCMA_DATA_WIDTH - 1 downto 0); -- Data Output
        -- controller interface --
        ctrl_cache_addr_i  : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- cache line aligned byte addr
        ctrl_mem_addr_i    : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- memory byte addr
        ctrl_is_read_i     : in  std_ulogic;
        ctrl_valid_i       : in  std_ulogic;
        ctrl_is_busy_o     : out std_ulogic
    );
end ram_axi_crossbar;

architecture rtl of ram_axi_crossbar is
    -- constants
    constant data_width_log2_c                 : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH / 8))));
    constant ram_log2_c                        : integer := integer(ceil(log2(real(NUM_RAMS))));
    constant parallel_ram_accesses_c           : integer := AXI_DATA_WIDTH / DCMA_DATA_WIDTH;
    constant nr_ram_accesses_per_transfer_log2 : integer := integer(ceil(log2(real(CACHE_LINE_SIZE_BYTES * 8 / AXI_DATA_WIDTH))));

    -- types
    type fsm_state_t is (IDLE, WR_GET_DATA, WR_SEND_LAST_DATA, WR_WAIT_DONE, WR_RESEND_REQ, RD_GET_DATA);

    type ram_data_array_t is array (NUM_RAMS - 1 downto 0) of std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    type ram_addr_array_t is array (NUM_RAMS - 1 downto 0) of std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);

    type access_ram_addr_array_t is array (parallel_ram_accesses_c - 1 downto 0) of std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);
    type access_ram_idx_array_t is array (parallel_ram_accesses_c - 1 downto 0) of std_ulogic_vector(ram_log2_c - 1 downto 0);
    type access_ram_idx_pipe_array_t is array (dcma_num_pipeline_reg_c downto 0) of access_ram_idx_array_t;

    -- registers
    signal state_ff, state_nxt                           : fsm_state_t;
    signal cur_addr_ff, cur_addr_nxt                     : std_ulogic_vector(ctrl_cache_addr_i'range);
    signal ctrl_is_read_ff, ctrl_is_read_nxt             : std_ulogic;
    signal cmd_base_adr_ff, cmd_base_adr_nxt             : std_ulogic_vector(cmd_base_adr_o'range);
    --    signal end_addr_ff, end_addr_nxt                         : std_ulogic_vector(ctrl_addr_i'range);
    signal ram_access_counter_ff, ram_access_counter_nxt : std_ulogic_vector(nr_ram_accesses_per_transfer_log2 downto 0);
    signal last_access_ram_idx_nxt                       : access_ram_idx_array_t;
    signal last_access_ram_idx_ff                        : access_ram_idx_pipe_array_t;
    signal wdata_fifo_wren_nxt                           : std_ulogic;
    signal wdata_fifo_wren_ff                            : std_ulogic_vector(dcma_num_pipeline_reg_c downto 0);
    signal wdata_fifo_wlast_nxt                          : std_ulogic;
    signal wdata_fifo_wlast_ff                           : std_ulogic_vector(dcma_num_pipeline_reg_c downto 0);

    -- signals
    signal ram_wdata_int : ram_data_array_t;
    signal ram_addr_int  : ram_addr_array_t;
    signal ram_rdata_int : ram_data_array_t;

    signal access_ram_addr : access_ram_addr_array_t;
    signal access_ram_idx  : access_ram_idx_array_t;

    signal wdata_fifo_wdata : std_ulogic_vector(AXI_DATA_WIDTH + 1 - 1 downto 0); -- + 1 for wlast
    signal wdata_fifo_wren  : std_ulogic;
    signal wdata_fifo_full  : std_ulogic;
    signal wdata_fifo_rdata : std_ulogic_vector(AXI_DATA_WIDTH + 1 - 1 downto 0);
    signal wdata_fifo_rden  : std_ulogic;
    signal wdata_fifo_empty : std_ulogic;
begin
    seq : process(clk_i, areset_n_i)
    begin
        if areset_n_i = '0' then
            state_ff              <= IDLE;
            cur_addr_ff           <= (others => '0');
            ram_access_counter_ff <= (others => '0');
            ctrl_is_read_ff       <= '0';
            cmd_base_adr_ff       <= (others => '0');
        elsif rising_edge(clk_i) then
            state_ff              <= state_nxt;
            cur_addr_ff           <= cur_addr_nxt;
            ram_access_counter_ff <= ram_access_counter_nxt;
            ctrl_is_read_ff       <= ctrl_is_read_nxt;
            cmd_base_adr_ff       <= cmd_base_adr_nxt;
        end if;
    end process;

    pipe_seq : process(clk_i, areset_n_i)
    begin
        if areset_n_i = '0' then
            last_access_ram_idx_ff <= (others => (others => (others => '0')));
            wdata_fifo_wren_ff     <= (others => '0');
            wdata_fifo_wlast_ff    <= (others => '0');
        elsif rising_edge(clk_i) then
            last_access_ram_idx_ff(0) <= last_access_ram_idx_nxt;
            wdata_fifo_wren_ff(0)     <= wdata_fifo_wren_nxt;
            wdata_fifo_wlast_ff(0)    <= wdata_fifo_wlast_nxt;
            if dcma_num_pipeline_reg_c > 0 then
                last_access_ram_idx_ff(last_access_ram_idx_ff'left downto 1) <= last_access_ram_idx_ff(last_access_ram_idx_ff'left - 1 downto 0);
                wdata_fifo_wren_ff(wdata_fifo_wren_ff'left downto 1)         <= wdata_fifo_wren_ff(wdata_fifo_wren_ff'left - 1 downto 0);
                wdata_fifo_wlast_ff(wdata_fifo_wlast_ff'left downto 1)       <= wdata_fifo_wlast_ff(wdata_fifo_wlast_ff'left - 1 downto 0);
            end if;
        end if;
    end process;

    fsm : process(state_ff, cur_addr_ff, cmd_busy_i, ctrl_cache_addr_i, ctrl_is_read_i, ctrl_valid_i, access_ram_addr, access_ram_idx, ram_access_counter_ff, cmd_fifo_data_i, cmd_fifo_rrdy_i, ctrl_mem_addr_i, wdata_fifo_full, wdata_fifo_empty, cmd_wr_done_i, cmd_base_adr_ff, ctrl_is_read_ff)
        variable cur_ram_idx_v : integer;
    begin
        --default 
        state_nxt               <= state_ff;
        ctrl_is_busy_o          <= cmd_busy_i;
        cur_addr_nxt            <= cur_addr_ff;
        cmd_base_adr_nxt        <= cmd_base_adr_ff;
        ctrl_is_read_nxt        <= ctrl_is_read_ff;
        cmd_req_o               <= '0';
        cmd_rw_o                <= '-';
        cmd_read_length_o       <= std_ulogic_vector(to_unsigned(CACHE_LINE_SIZE_BYTES, cmd_read_length_o'length));
        cmd_base_adr_o          <= (others => '-');
        cmd_fifo_rden_o         <= '0';
        wdata_fifo_wren_nxt     <= '0';
        wdata_fifo_wlast_nxt    <= '0';
        ram_wr_en_o             <= (others => '0');
        ram_rd_en_o             <= (others => '0');
        ram_wdata_int           <= (others => (others => '-'));
        ram_addr_int            <= (others => (others => '-'));
        ram_access_counter_nxt  <= ram_access_counter_ff;
        last_access_ram_idx_nxt <= access_ram_idx;

        case state_ff is
            when IDLE =>
                ram_access_counter_nxt <= (others => '0');
                if ctrl_valid_i = '1' and cmd_busy_i = '0' then
                    cur_addr_nxt   <= ctrl_cache_addr_i;
                    cmd_req_o      <= '1';
                    cmd_rw_o       <= not ctrl_is_read_i;
                    cmd_base_adr_o <= std_ulogic_vector(resize(unsigned(ctrl_mem_addr_i), cmd_base_adr_o'length));

                    cmd_base_adr_nxt <= std_ulogic_vector(resize(unsigned(ctrl_mem_addr_i), cmd_base_adr_o'length));
                    ctrl_is_read_nxt <= ctrl_is_read_i;

                    if ctrl_is_read_i = '1' then
                        state_nxt <= RD_GET_DATA;
                    else
                        state_nxt <= WR_GET_DATA;
                    end if;
                end if;

            when WR_GET_DATA =>
                ctrl_is_busy_o <= '1';

                if wdata_fifo_full = '0' then
                    -- start new ram read access
                    for I in 0 to parallel_ram_accesses_c - 1 loop
                        cur_ram_idx_v               := to_integer(unsigned(access_ram_idx(I)));
                        ram_rd_en_o(cur_ram_idx_v)  <= '1';
                        ram_addr_int(cur_ram_idx_v) <= access_ram_addr(I);
                    end loop;
                    ram_access_counter_nxt <= std_ulogic_vector(unsigned(ram_access_counter_ff) + 1);

                    wdata_fifo_wren_nxt <= '1';
                    if unsigned(ram_access_counter_ff) + 1 = 2 ** nr_ram_accesses_per_transfer_log2 then
                        -- transfer finished
                        wdata_fifo_wlast_nxt   <= '1';
                        ram_access_counter_nxt <= (others => '0');
                        state_nxt              <= WR_SEND_LAST_DATA;
                    end if;
                end if;

            when WR_SEND_LAST_DATA =>
                ctrl_is_busy_o <= '1';

                -- wait until all wdata were sent
                if wdata_fifo_empty = '1' then
                    if not axi_wr_data_error_handling_dcma and not axi_wr_req_error_handling_dcma then
                        state_nxt <= IDLE;
                    else
                        state_nxt <= WR_WAIT_DONE;
                    end if;
                end if;

            when WR_WAIT_DONE =>
                ctrl_is_busy_o <= '1';
                case cmd_wr_done_i is
                    when "01" =>
                        state_nxt <= IDLE;
                    when "10" =>
                        if axi_wr_data_error_handling_dcma then
                            state_nxt <= WR_RESEND_REQ;
                        else
                            state_nxt <= IDLE;
                        end if;
                    when "11" =>
                        if axi_wr_req_error_handling_dcma then
                            state_nxt <= WR_RESEND_REQ;
                        else
                            state_nxt <= IDLE;
                        end if;
                    when others =>
                end case;

            when WR_RESEND_REQ =>
                ctrl_is_busy_o         <= '1';
                ram_access_counter_nxt <= (others => '0');
                if cmd_busy_i = '0' then
                    cmd_req_o      <= '1';
                    cmd_rw_o       <= not ctrl_is_read_ff;
                    cmd_base_adr_o <= cmd_base_adr_ff;

                    if ctrl_is_read_ff = '1' then
                        state_nxt <= RD_GET_DATA;
                    else
                        state_nxt <= WR_GET_DATA;
                    end if;
                end if;

            when RD_GET_DATA =>
                ctrl_is_busy_o <= '1';

                if cmd_fifo_rrdy_i = '1' then
                    cmd_fifo_rden_o <= '1';

                    -- start new ram write access
                    for I in 0 to parallel_ram_accesses_c - 1 loop
                        cur_ram_idx_v                := to_integer(unsigned(access_ram_idx(I)));
                        ram_wr_en_o(cur_ram_idx_v)   <= '1';
                        ram_addr_int(cur_ram_idx_v)  <= access_ram_addr(I);
                        ram_wdata_int(cur_ram_idx_v) <= cmd_fifo_data_i((I + 1) * DCMA_DATA_WIDTH - 1 downto I * DCMA_DATA_WIDTH);
                    end loop;
                    ram_access_counter_nxt <= std_ulogic_vector(unsigned(ram_access_counter_ff) + 1);
                    if unsigned(ram_access_counter_ff) = 2 ** nr_ram_accesses_per_transfer_log2 - 1 then
                        state_nxt              <= IDLE;
                        ram_access_counter_nxt <= (others => '0');
                    end if;
                end if;
        end case;
    end process;

    wdata_fifo_inst : sync_fifo
        generic map(
            DATA_WIDTH     => AXI_DATA_WIDTH + 1, -- + 1 for wlast
            NUM_ENTRIES    => dcma_to_axi_fifo_entries_c,
            NUM_SFULL      => dcma_num_pipeline_reg_c + 1,
            DIRECT_OUT     => true,
            DIRECT_OUT_REG => false
        )
        port map(
            clk_i    => clk_i,
            rst_i    => areset_n_i,
            wdata_i  => wdata_fifo_wdata,
            we_i     => wdata_fifo_wren,
            wfull_o  => open,
            wsfull_o => wdata_fifo_full,
            rdata_o  => wdata_fifo_rdata,
            re_i     => wdata_fifo_rden,
            rempty_o => wdata_fifo_empty
        );

    wdata_fifo_wdata_gen : for I in 0 to parallel_ram_accesses_c - 1 generate
        wdata_fifo_wdata((I + 1) * DCMA_DATA_WIDTH - 1 downto I * DCMA_DATA_WIDTH) <= ram_rdata_int(to_integer(unsigned(last_access_ram_idx_ff(dcma_num_pipeline_reg_c)(I))));
    end generate;
    wdata_fifo_wdata(wdata_fifo_wdata'left) <= wdata_fifo_wlast_ff(dcma_num_pipeline_reg_c);
    wdata_fifo_wren                         <= wdata_fifo_wren_ff(dcma_num_pipeline_reg_c);

    wdata_fifo_rdata_comb : process(cmd_fifo_wrdy_i, wdata_fifo_empty, wdata_fifo_rdata)
    begin
        -- default
        cmd_fifo_wren_o    <= '0';
        cmd_fifo_wr_last_o <= wdata_fifo_rdata(wdata_fifo_rdata'length - 1);
        cmd_fifo_data_o    <= wdata_fifo_rdata(wdata_fifo_rdata'length - 2 downto 0);
        wdata_fifo_rden    <= '0';

        if wdata_fifo_empty = '0' and cmd_fifo_wrdy_i = '1' then
            wdata_fifo_rden <= '1';
            cmd_fifo_wren_o <= '1';
        end if;
    end process;

    access_ram_calc_comb : process(cur_addr_ff, ram_access_counter_ff)
        variable cache_addr_v : unsigned(DCMA_ADDR_WIDTH - 1 downto 0);
    begin
        for I in 0 to parallel_ram_accesses_c - 1 loop
            cache_addr_v       := resize(unsigned(cur_addr_ff) + (I + parallel_ram_accesses_c * resize(unsigned(ram_access_counter_ff), cache_addr_v'length)) * DCMA_DATA_WIDTH / 8, cache_addr_v'length);
            access_ram_idx(I)  <= std_ulogic_vector(cache_addr_v(ram_log2_c + data_width_log2_c - 1 downto data_width_log2_c)); -- cache_addr mod nr_brams
            access_ram_addr(I) <= std_ulogic_vector(resize(shift_right(cache_addr_v, ram_log2_c + data_width_log2_c), RAM_ADDR_WIDTH)); -- cache_addr / nr_brams
        end loop;
    end process;

    connect_ram_ports_with_internal_signals_gen : for I in 0 to NUM_RAMS - 1 generate
        -- RAM signals
        ram_wdata_o(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I) <= ram_wdata_int(I);
        ram_addr_o(RAM_ADDR_WIDTH * (I + 1) - 1 downto RAM_ADDR_WIDTH * I)    <= ram_addr_int(I);

        ram_rdata_int(I) <= ram_rdata_i(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I);
    end generate;
end architecture rtl;
