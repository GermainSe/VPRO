--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_specializations.all;
use core_v2pro.package_datawidths.all;

entity dma_crossbar_dma_module is
    generic(
        NUM_RAMS                  : integer := 32;
        ASSOCIATIVITY_LOG2        : integer := 2;
        RAM_ADDR_WIDTH            : integer := 12;
        DCMA_ADDR_WIDTH           : integer := 32; -- Address Width
        DCMA_DATA_WIDTH           : integer := 64; -- Data Width
        VPRO_DATA_WIDTH           : integer := 16;
        ADDR_WORD_BITWIDTH        : integer;
        ADDR_WORD_SELECT_BITWIDTH : integer;
        ADDR_SET_BITWIDTH         : integer;
        RAM_LOG2                  : integer
    );
    port(
        clk_i                    : in  std_ulogic; -- Clock 
        areset_n_i               : in  std_ulogic;
        -- dma interface --
        dma_base_adr_i           : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
        dma_size_i               : in  std_ulogic_vector(20 - 1 downto 0); -- quantity
        dma_dat_o                : out std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- data from main memory
        dma_dat_i                : in  std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- data to main memory
        dma_req_i                : in  std_ulogic; -- memory request
        dma_busy_o               : out std_ulogic; -- no request possible right now
        dma_rw_i                 : in  std_ulogic; -- read/write a block from/to memory
        dma_rden_i               : in  std_ulogic; -- FIFO read enable
        dma_wren_i               : in  std_ulogic; -- FIFO write enable
        dma_wrdy_o               : out std_ulogic; -- data can be written
        dma_wr_last_i            : in  std_ulogic; -- last word of write-block -- @suppress "Unused port: dma_wr_last_i is not used in core_v2pro.dma_crossbar_dma_module(rtl)"
        dma_rrdy_o               : out std_ulogic; -- read data ready
        is_dma_access_allowed_i  : in  std_ulogic;
        -- ram interface --
        access_ram_idx_o         : out std_ulogic_vector(RAM_LOG2 - 1 downto 0);
        access_ram_addr_o        : out std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);
        access_ram_is_read_o     : out std_ulogic;
        access_ram_wdata_valid_o : out std_ulogic_vector(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto 0);
        access_ram_rdata_valid_i : in  std_ulogic;
        access_ram_rrdy_o        : out std_ulogic;
        access_ram_wdata_o       : out std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- Data Input  
        access_ram_rdata_i       : in  std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- Data Output
        -- controller interface --
        ctrl_addr_o              : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
        ctrl_is_read_o           : out std_ulogic;
        ctrl_valid_o             : out std_ulogic;
        ctrl_is_hit_i            : in  std_ulogic;
        ctrl_line_offset_i       : in  std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0)
    );
end dma_crossbar_dma_module;

architecture rtl of dma_crossbar_dma_module is

    --    attribute keep_hierarchy : string;
    --    attribute keep_hierarchy of rtl : architecture is "yes";

    -- constants
    constant data_width_log2_c            : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH))));
    constant vpro_data_width_bytes_log2_c : integer := integer(ceil(log2(real(VPRO_DATA_WIDTH / 8))));
    constant ram_log2_c                   : integer := integer(ceil(log2(real(NUM_RAMS))));
    constant align_width_log2_c           : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH))));

    constant DMA_CROSSBAR_REQ_FIFO_WIDTH_c : natural := (dma_base_adr_i'length + dma_size_i'length) + 1; -- = addr + req_length + rw

    -- types

    -- registers
    signal cur_addr_ff, cur_addr_nxt                             : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- word addr
    signal end_addr_ff, end_addr_nxt                             : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- word addr
    signal is_read_ff, is_read_nxt                               : std_ulogic;
    signal addr_align_offset_ff, addr_align_offset_nxt           : std_ulogic_vector(align_offset_vector_length_c - 1 downto 0);
    signal addr_align_offset_last_ff, addr_align_offset_last_nxt : std_ulogic_vector(align_offset_vector_length_c - 1 downto 0);

    signal ctrl_valid_o_ff, ctrl_valid_o_nxt     : std_ulogic;
    signal ctrl_is_read_o_ff, ctrl_is_read_o_nxt : std_ulogic;
    signal ctrl_addr_o_ff, ctrl_addr_o_nxt       : std_ulogic_vector(ctrl_addr_o'range);

    -- signals
    signal dma_busy_o_int : std_ulogic;

    signal ctrl_addr_int        : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal ctrl_line_offset_int : std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);

    signal incr_cur_addr : std_ulogic;

    signal rdata_fifo_wdata : std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    signal rdata_fifo_wren  : std_ulogic;
    signal rdata_fifo_full  : std_ulogic;
    signal rdata_fifo_empty : std_ulogic;

    signal wdata_fifo_rdata : std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    signal wdata_fifo_rden  : std_ulogic;
    signal wdata_fifo_full  : std_ulogic;
    signal wdata_fifo_empty : std_ulogic;

    signal req_fifo_wdata : std_ulogic_vector(DMA_CROSSBAR_REQ_FIFO_WIDTH_c - 1 downto 0);
    signal req_fifo_rdata : std_ulogic_vector(DMA_CROSSBAR_REQ_FIFO_WIDTH_c - 1 downto 0);
    signal req_fifo_wren  : std_ulogic;
    signal req_fifo_rden  : std_ulogic;
    signal req_fifo_full  : std_ulogic;
    signal req_fifo_empty : std_ulogic;

    signal access_ram_idx         : std_ulogic_vector(RAM_LOG2 - 1 downto 0);
    signal access_ram_addr        : std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);
    signal access_ram_is_read     : std_ulogic;
    signal access_ram_wdata_valid : std_ulogic_vector(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto 0);
    signal access_ram_rrdy        : std_ulogic;
    signal access_ram_wdata       : std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- Data Input  
begin
    -- register to output
    ctrl_addr_o    <= ctrl_addr_o_ff;
    ctrl_is_read_o <= ctrl_is_read_o_ff;
    ctrl_valid_o   <= ctrl_valid_o_ff;

    additional_pipe_gen : if dcma_additional_pipeline_reg_in_dma_crossbar_c generate
        ram_ctrl_seq : process(clk_i)
        begin
            if rising_edge(clk_i) then
                access_ram_addr_o        <= access_ram_addr;
                access_ram_is_read_o     <= access_ram_is_read;
                access_ram_wdata_valid_o <= access_ram_wdata_valid;
                access_ram_rrdy_o        <= access_ram_rrdy;
                access_ram_wdata_o       <= access_ram_wdata;
            end if;
        end process;
        
        access_ram_idx_o         <= access_ram_idx;
    end generate;

    no_additional_pipe_gen : if not dcma_additional_pipeline_reg_in_dma_crossbar_c generate
        access_ram_idx_o         <= access_ram_idx;
        access_ram_addr_o        <= access_ram_addr;
        access_ram_is_read_o     <= access_ram_is_read;
        access_ram_wdata_valid_o <= access_ram_wdata_valid;
        access_ram_rrdy_o        <= access_ram_rrdy;
        access_ram_wdata_o       <= access_ram_wdata;
    end generate;

    seq : process(clk_i, areset_n_i)
    begin
        if areset_n_i = '0' then
            cur_addr_ff               <= (others => '0');
            end_addr_ff               <= (others => '0');
            is_read_ff                <= '0';
            addr_align_offset_ff      <= (others => '0');
            addr_align_offset_last_ff <= (others => '0');
            ctrl_valid_o_ff           <= '0';
            ctrl_is_read_o_ff         <= '0';
            ctrl_addr_o_ff            <= (others => '0');
        elsif rising_edge(clk_i) then
            cur_addr_ff               <= cur_addr_nxt;
            end_addr_ff               <= end_addr_nxt;
            is_read_ff                <= is_read_nxt;
            addr_align_offset_ff      <= addr_align_offset_nxt;
            addr_align_offset_last_ff <= addr_align_offset_last_nxt;
            ctrl_valid_o_ff           <= ctrl_valid_o_nxt;
            ctrl_is_read_o_ff         <= ctrl_is_read_o_nxt;
            ctrl_addr_o_ff            <= ctrl_addr_o_nxt;
        end if;
    end process;

    addr_calc_comb : process(cur_addr_ff, end_addr_ff, is_read_ff, incr_cur_addr, addr_align_offset_ff, addr_align_offset_last_ff, dma_busy_o_int, req_fifo_empty, req_fifo_rdata)
        variable end_addr_v : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
        variable base_adr_v : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
        variable size_v     : std_ulogic_vector(dma_size_i'length - 1 downto 0);
        variable rw_v       : std_ulogic;
    begin
        -- default
        cur_addr_nxt               <= cur_addr_ff;
        end_addr_nxt               <= end_addr_ff;
        is_read_nxt                <= is_read_ff;
        addr_align_offset_nxt      <= addr_align_offset_ff;
        addr_align_offset_last_nxt <= addr_align_offset_last_ff;
        req_fifo_rden              <= '0';

        base_adr_v := req_fifo_rdata(DCMA_ADDR_WIDTH - 1 downto 0);
        size_v     := req_fifo_rdata(DCMA_ADDR_WIDTH + dma_size_i'length - 1 downto DCMA_ADDR_WIDTH);
        rw_v       := req_fifo_rdata(DCMA_ADDR_WIDTH + dma_size_i'length);
        end_addr_v := std_ulogic_vector(resize(unsigned(base_adr_v) + unsigned(size_v), end_addr_v'length));
        if req_fifo_empty = '0' and dma_busy_o_int = '0' then
            req_fifo_rden <= '1';
            if align_offset_log2_c /= 0 then
                addr_align_offset_nxt      <= base_adr_v(align_width_log2_c - 1 + vpro_data_width_bytes_log2_c downto vpro_data_width_bytes_log2_c); -- @suppress "Incorrect array size in assignment: expected (<align_offset_vector_length_c>) but was (<align_width_log2_c>)"
                addr_align_offset_last_nxt <= std_ulogic_vector(unsigned(end_addr_v(align_width_log2_c - 1 + vpro_data_width_bytes_log2_c downto 0 + vpro_data_width_bytes_log2_c)) - 1); -- +vpro_data_width_bytes_log2_c for byte to word conversion -- @suppress "Incorrect array size in assignment: expected (<align_offset_vector_length_c>) but was (<align_width_log2_c>)"
            end if;
            cur_addr_nxt <= std_ulogic_vector(shift_right(unsigned(base_adr_v), ADDR_WORD_BITWIDTH));
            -- end_addr = base_addr + read_size
            end_addr_nxt <= std_ulogic_vector(shift_right(unsigned(end_addr_v), data_width_log2_c - 3));
            -- round up
            if unsigned(end_addr_v(data_width_log2_c - 3 - 1 downto 0)) /= 0 then
                end_addr_nxt <= std_ulogic_vector(1 + shift_right(unsigned(end_addr_v), data_width_log2_c - 3));
            end if;
            --                end_addr_nxt          <= std_ulogic_vector(resize(unsigned(dma_base_adr_int) + shift_right(unsigned(dma_size_int), data_width_log2_c - 3), end_addr_nxt'length));
            is_read_nxt  <= not rw_v;
        elsif incr_cur_addr = '1' then
            cur_addr_nxt <= std_ulogic_vector(unsigned(cur_addr_ff) + 1);
            if align_offset_log2_c /= 0 then
                addr_align_offset_nxt <= (others => '0');
            end if;
        end if;
    end process;

    ctrl_comb : process(cur_addr_ff, end_addr_ff, is_read_ff, incr_cur_addr, ctrl_is_hit_i, req_fifo_empty, req_fifo_rdata)
        variable base_adr_v : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
        variable rw_v       : std_ulogic;
    begin
        -- default
        ctrl_addr_int      <= cur_addr_ff;
        ctrl_is_read_o_nxt <= is_read_ff;
        ctrl_valid_o_nxt   <= '0';

        if incr_cur_addr = '1' then
            ctrl_addr_int <= std_ulogic_vector(unsigned(cur_addr_ff) + 1);
        end if;

        base_adr_v := req_fifo_rdata(DCMA_ADDR_WIDTH - 1 downto 0);
        rw_v       := req_fifo_rdata(DCMA_ADDR_WIDTH + dma_size_i'length);

        if unsigned(cur_addr_ff) < unsigned(end_addr_ff) then
            ctrl_valid_o_nxt <= '1';
        end if;

        if ctrl_is_hit_i = '1' and unsigned(cur_addr_ff) = unsigned(end_addr_ff) - 1 then
            ctrl_valid_o_nxt <= '0';

            -- start hit calc of new req
            if req_fifo_empty = '0' then
                ctrl_valid_o_nxt   <= '1';
                ctrl_addr_int      <= std_ulogic_vector(shift_right(unsigned(base_adr_v), ADDR_WORD_BITWIDTH));
                ctrl_is_read_o_nxt <= not rw_v;
            end if;
        end if;

    end process;

    dma_comb : process(cur_addr_ff, end_addr_ff, incr_cur_addr)
    begin
        -- default
        dma_busy_o_int <= '0';

        if unsigned(cur_addr_ff) < unsigned(end_addr_ff) and not (incr_cur_addr = '1' and unsigned(cur_addr_ff) + 1 = unsigned(end_addr_ff)) then
            dma_busy_o_int <= '1';
        end if;
    end process;

    ram_comb : process(is_dma_access_allowed_i, is_read_ff, dma_rden_i, rdata_fifo_full, wdata_fifo_empty, wdata_fifo_rdata, addr_align_offset_ff, addr_align_offset_last_ff, cur_addr_ff, end_addr_ff)
    begin
        -- default
        wdata_fifo_rden        <= '0';
        incr_cur_addr          <= '0';
        access_ram_wdata_valid <= (others => '0');
        access_ram_wdata       <= wdata_fifo_rdata;
        access_ram_rrdy        <= '0';

        if is_dma_access_allowed_i = '1' then
            if is_read_ff = '1' then
                if rdata_fifo_full = '0' or dma_rden_i = '1' then
                    access_ram_rrdy <= '1';
                    incr_cur_addr   <= '1';
                end if;
            else
                if wdata_fifo_empty = '0' then
                    wdata_fifo_rden <= '1';
                    for J in 0 to DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 loop
                        if J >= unsigned(addr_align_offset_ff) then
                            if unsigned(cur_addr_ff) + 1 = unsigned(end_addr_ff) then
                                if J <= unsigned(addr_align_offset_last_ff) then
                                    access_ram_wdata_valid(J) <= '1';
                                end if;
                            else
                                access_ram_wdata_valid(J) <= '1';
                            end if;
                        end if;
                    end loop;
                    incr_cur_addr   <= '1';
                end if;
            end if;
        end if;
    end process;

    rdata_fifo_wren  <= access_ram_rdata_valid_i;
    rdata_fifo_wdata <= access_ram_rdata_i;

    wdata_fifo_inst : sync_fifo
        generic map(
            DATA_WIDTH     => DCMA_DATA_WIDTH,
            NUM_ENTRIES    => 2 * dcma_to_dma_fifo_entries_c,
            NUM_SFULL      => 0,
            DIRECT_OUT     => true,
            DIRECT_OUT_REG => false
        )
        port map(
            clk_i    => clk_i,
            rst_i    => areset_n_i,
            wdata_i  => dma_dat_i,
            we_i     => dma_wren_i,
            wfull_o  => wdata_fifo_full,
            wsfull_o => open,
            rdata_o  => wdata_fifo_rdata,
            re_i     => wdata_fifo_rden,
            rempty_o => wdata_fifo_empty
        );

    dma_wrdy_o <= not wdata_fifo_full;

    rdata_fifo_inst : sync_fifo
        generic map(
            DATA_WIDTH     => DCMA_DATA_WIDTH,
            NUM_ENTRIES    => dcma_to_dma_fifo_entries_c,
            NUM_SFULL      => dcma_num_pipeline_reg_c + 2,
            DIRECT_OUT     => true,
            DIRECT_OUT_REG => false
        )
        port map(
            clk_i    => clk_i,
            rst_i    => areset_n_i,
            wdata_i  => rdata_fifo_wdata,
            we_i     => rdata_fifo_wren,
            wfull_o  => open,
            wsfull_o => rdata_fifo_full,
            rdata_o  => dma_dat_o,
            re_i     => dma_rden_i,
            rempty_o => rdata_fifo_empty
        );

    req_fifo_inst : sync_fifo
        generic map(
            DATA_WIDTH     => DMA_CROSSBAR_REQ_FIFO_WIDTH_c,
            NUM_ENTRIES    => 2,
            NUM_SFULL      => 0,
            DIRECT_OUT     => true,
            DIRECT_OUT_REG => false
        )
        port map(
            clk_i    => clk_i,
            rst_i    => areset_n_i,
            wdata_i  => req_fifo_wdata,
            we_i     => req_fifo_wren,
            wfull_o  => req_fifo_full,
            wsfull_o => open,
            rdata_o  => req_fifo_rdata,
            re_i     => req_fifo_rden,
            rempty_o => req_fifo_empty
        );

    req_fifo_wren  <= dma_req_i;
    req_fifo_wdata <= dma_rw_i & dma_size_i & dma_base_adr_i;
    dma_busy_o     <= req_fifo_full;

    dma_rrdy_o <= not rdata_fifo_empty;

    access_ram_calc_comb : process(cur_addr_ff, ctrl_line_offset_int, is_read_ff)
        variable set_v        : unsigned(ADDR_SET_BITWIDTH - 1 downto 0);
        variable cache_addr_v : unsigned(DCMA_ADDR_WIDTH - 1 downto 0);
        variable word_v       : unsigned(ADDR_WORD_SELECT_BITWIDTH - 1 downto 0);
    begin
        -- default
        access_ram_is_read <= is_read_ff;

        set_v  := unsigned(cur_addr_ff(ADDR_SET_BITWIDTH + ADDR_WORD_SELECT_BITWIDTH - 1 downto ADDR_WORD_SELECT_BITWIDTH));
        word_v := unsigned(cur_addr_ff(ADDR_WORD_SELECT_BITWIDTH - 1 downto 0));

        cache_addr_v := shift_left(resize(set_v, cache_addr_v'length), ADDR_WORD_SELECT_BITWIDTH) + word_v;
        if ASSOCIATIVITY_LOG2 /= 0 then
            cache_addr_v := shift_left(shift_left(resize(set_v, cache_addr_v'length), ASSOCIATIVITY_LOG2) + unsigned(ctrl_line_offset_int), ADDR_WORD_SELECT_BITWIDTH) + word_v;
        end if;

        access_ram_idx  <= std_ulogic_vector(cache_addr_v(ram_log2_c - 1 downto 0)); -- cache_addr mod nr_brams -- @suppress "Incorrect array size in assignment: expected (<RAM_LOG2>) but was (<ram_log2_c>)"
        access_ram_addr <= std_ulogic_vector(resize(shift_right(cache_addr_v, ram_log2_c), RAM_ADDR_WIDTH)); -- cache_addr / nr_brams
    end process;

    -- DMA signals
    ctrl_addr_o_nxt <= ctrl_addr_int;

    ctrl_line_offset_int <= ctrl_line_offset_i;
end architecture rtl;
