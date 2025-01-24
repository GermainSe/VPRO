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

entity dcma_controller is
    generic(
        NUM_CLUSTERS          : integer := 8;
        NUM_RAMS              : integer := 32;
        ASSOCIATIVITY_LOG2    : integer := 2;
        RAM_ADDR_WIDTH        : integer := 12;
        DCMA_ADDR_WIDTH       : integer := 32; -- Address Width
        DCMA_DATA_WIDTH       : integer := 64; -- Data Width
        CACHE_LINE_SIZE_BYTES : integer := 1024
    );
    port(
        clk_i                : in  std_ulogic; -- Clock 
        areset_n_i           : in  std_ulogic;
        -- dma crossbar interface --
        dma_addr_i           : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0); -- word addr
        dma_is_read_i        : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        dma_valid_i          : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        dma_is_hit_o         : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        dma_line_offset_o    : out std_ulogic_vector(NUM_CLUSTERS * ASSOCIATIVITY_LOG2 - 1 downto 0);
        -- ram axi crossbar interface --
        ram_axi_cache_addr_o : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- cache line aligned byte addr
        ram_axi_mem_addr_o   : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- memory byte addr
        ram_axi_is_read_o    : out std_ulogic;
        ram_axi_valid_o      : out std_ulogic;
        ram_axi_is_busy_i    : in  std_ulogic;
        -- control signals from io fabric
        dcma_flush           : in  std_ulogic;
        dcma_reset           : in  std_ulogic;
        dcma_busy            : out std_ulogic
    );
end dcma_controller;

architecture RTL of dcma_controller is
    -- constants
    --    constant num_cluster_log2_c     : integer := integer(ceil(log2(real(NUM_CLUSTERS))));
    constant cache_mem_size_bytes_c : integer := NUM_RAMS * (2 ** RAM_ADDR_WIDTH) * DCMA_DATA_WIDTH / 8;
    constant num_cache_lines_c      : integer := cache_mem_size_bytes_c / CACHE_LINE_SIZE_BYTES;
    constant num_cache_lines_log2_c : integer := integer(ceil(log2(real(num_cache_lines_c))));
    constant num_sets_c             : integer := num_cache_lines_c / (2 ** ASSOCIATIVITY_LOG2);
    constant associativity_c        : integer := 2 ** ASSOCIATIVITY_LOG2;

    -- ADDR: |TAG|SET|WORD_SEL|WORD|
    constant addr_set_width_c         : integer := integer(ceil(log2(real(num_sets_c))));
    constant addr_word_offset_width_c : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH / 8))));
    constant addr_word_sel_width_c    : integer := integer(ceil(log2(real(CACHE_LINE_SIZE_BYTES / (DCMA_DATA_WIDTH / 8)))));
    constant addr_tag_width_c         : integer := DCMA_ADDR_WIDTH - addr_set_width_c - addr_word_sel_width_c - addr_word_offset_width_c;

    -- components 
    component dcma_async_mem
        generic(
            ADDR_WIDTH : integer := 12;
            DATA_WIDTH : integer := 16
        );
        port(
            clk   : in  std_ulogic;
            wr_en : in  std_ulogic;
            addr  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            wdata : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            rdata : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component dcma_async_mem;

    component cache_line_replacer
        generic(
            NUM_CLUSTERS         : integer := 8;
            ASSOCIATIVITY_LOG2   : integer := 2;
            DCMA_ADDR_WIDTH      : integer := 32;
            TAG_ADDR_WIDTH       : integer;
            SET_ADDR_WIDTH       : integer;
            WORD_SEL_ADDR_WIDTH  : integer;
            WORD_OFFS_ADDR_WIDTH : integer
        );
        port(
            clk_i            : in  std_ulogic;
            areset_n_i       : in  std_ulogic;
            line_accessed_i  : in  std_ulogic_vector(NUM_CLUSTERS * (SET_ADDR_WIDTH + ASSOCIATIVITY_LOG2) - 1 downto 0);
            accessed_valid_i : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            addr_i           : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
            valid_i          : in  std_ulogic;
            cache_line_o     : out std_ulogic_vector(SET_ADDR_WIDTH + ASSOCIATIVITY_LOG2 - 1 downto 0)
        );
    end component cache_line_replacer;

    component dcma_cache_line_access
        generic(
            NUM_CLUSTERS          : integer := 8;
            ASSOCIATIVITY_LOG2    : integer := 2;
            DCMA_ADDR_WIDTH       : integer := 32;
            DCMA_DATA_WIDTH       : integer := 64;
            CACHE_LINE_SIZE_BYTES : integer := 1024;
            TAG_ADDR_WIDTH        : integer;
            SET_ADDR_WIDTH        : integer;
            NUM_CACHE_LINES_LOG2  : integer
        );
        port(
            clk_i                         : in  std_ulogic;
            areset_n_i                    : in  std_ulogic;
            dma_addr_i                    : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0);
            dma_is_read_i                 : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_valid_i                   : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_is_hit_o                  : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            dma_line_offset_o             : out std_ulogic_vector(NUM_CLUSTERS * ASSOCIATIVITY_LOG2 - 1 downto 0);
            dcma_reset_i                  : in  std_ulogic;
            tag_mem_is_hit_i              : in  std_ulogic;
            tag_mem_line_offset_i         : in  std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);
            tag_mem_rd_o                  : out std_ulogic;
            tag_mem_addr_o                : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
            tag_mem_is_read_o             : out std_ulogic;
            overwritten_valid_i           : in  std_ulogic;
            overwritten_tag_addr_i        : in  std_ulogic_vector(TAG_ADDR_WIDTH - 1 downto 0);
            overwritten_set_addr_i        : in  std_ulogic_vector(SET_ADDR_WIDTH - 1 downto 0);
            cache_line_accessed_valid_o   : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
            cache_line_accessed_addr_o    : out std_ulogic_vector(NUM_CLUSTERS * NUM_CACHE_LINES_LOG2 - 1 downto 0);
            cache_line_accessed_is_read_o : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0)
        );
    end component dcma_cache_line_access;

    -- types
    type fsm_state_t is (IDLE, DOWNLOAD, DOWNLOAD_WAIT, UPLOAD, FLUSH, FLUSH_WAIT);
    --    type tag_mem_t is array (num_cache_lines_c - 1 downto 0) of std_ulogic_vector(addr_tag_width_c - 1 downto 0);
    --    type cluster_dcma_addr_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    --    type cluster_associativity_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);
    type cluster_cache_line_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(num_cache_lines_log2_c - 1 downto 0);
    type associativity_tag_addr_t is array (associativity_c - 1 downto 0) of std_ulogic_vector(num_cache_lines_log2_c - ASSOCIATIVITY_LOG2 - 1 downto 0);
    type associativity_tag_data_t is array (associativity_c - 1 downto 0) of std_ulogic_vector(addr_tag_width_c - 1 downto 0);

    -- registers
    signal state_ff, state_nxt               : fsm_state_t;
    signal dirty_mem_ff, dirty_mem_nxt       : std_ulogic_vector(num_cache_lines_c - 1 downto 0);
    signal valid_mem_ff, valid_mem_nxt       : std_ulogic_vector(num_cache_lines_c - 1 downto 0);
    signal miss_found_ff, miss_found_nxt     : std_ulogic;
    signal miss_addr_ff, miss_addr_nxt       : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal miss_is_read_ff, miss_is_read_nxt : std_ulogic;

    signal load_cache_addr_ff, load_cache_addr_nxt       : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal download_mem_addr_ff, download_mem_addr_nxt   : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal upload_mem_addr_ff, upload_mem_addr_nxt       : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal replace_cache_line_ff, replace_cache_line_nxt : std_ulogic_vector(addr_set_width_c + ASSOCIATIVITY_LOG2 - 1 downto 0);

    signal flush_counter_ff, flush_counter_nxt   : std_ulogic_vector(num_cache_lines_log2_c - 1 downto 0);
    signal flush_tag_data_ff, flush_tag_data_nxt : std_ulogic_vector(addr_tag_width_c - 1 downto 0);

    signal overwritten_valid_ff, overwritten_valid_nxt       : std_ulogic;
    signal overwritten_set_addr_ff, overwritten_set_addr_nxt : std_ulogic_vector(addr_set_width_c - 1 downto 0);
    signal overwritten_tag_addr_ff, overwritten_tag_addr_nxt : std_ulogic_vector(addr_tag_width_c - 1 downto 0);

    signal pending_flush_ff, pending_flush_nxt : std_ulogic;

    -- signals
    signal tag_mem_wr_en         : std_ulogic_vector(associativity_c - 1 downto 0);
    signal tag_mem_addr          : associativity_tag_addr_t;
    signal tag_mem_hit_calc_addr : associativity_tag_addr_t;
    signal tag_mem_wdata         : associativity_tag_data_t;
    signal tag_mem_rdata         : associativity_tag_data_t;

    signal cache_line_accessed         : cluster_cache_line_t;
    signal cache_line_accessed_int     : std_ulogic_vector(NUM_CLUSTERS * num_cache_lines_log2_c - 1 downto 0);
    signal cache_line_accessed_valid   : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal cache_line_accessed_is_read : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);

    --    signal dma_addr_int           : cluster_dcma_addr_array_t;
    signal miss_solved            : std_ulogic;
    signal replacer_addr_o        : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal replacer_valid_o       : std_ulogic;
    signal replacer_cache_line_i  : std_ulogic_vector(addr_set_width_c + ASSOCIATIVITY_LOG2 - 1 downto 0);
    signal empty_cache_line_found : std_ulogic;
    signal empty_cache_line       : std_ulogic_vector(num_cache_lines_log2_c - 1 downto 0);

    signal cache_line_access_hit         : std_ulogic;
    signal cache_line_access_line_offset : std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);
    signal cache_line_access_rd_en       : std_ulogic;
    signal cache_line_access_addr        : std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    signal cache_line_access_is_read     : std_ulogic;

    signal fsm_tag_mem_accessed : std_ulogic;

    signal dma_active_pipe_ff : std_ulogic_vector(dcma_num_pipeline_reg_c + 2 downto 0);
    signal dma_active_pip_nxt : std_ulogic;
    signal dma_active         : std_ulogic;
begin
    seq : process(areset_n_i, clk_i)
    begin
        if areset_n_i = '0' then
            state_ff                <= IDLE;
            dirty_mem_ff            <= (others => '0');
            valid_mem_ff            <= (others => '0');
            miss_found_ff           <= '0';
            miss_addr_ff            <= (others => '0');
            miss_is_read_ff         <= '0';
            load_cache_addr_ff      <= (others => '0');
            download_mem_addr_ff    <= (others => '0');
            upload_mem_addr_ff      <= (others => '0');
            replace_cache_line_ff   <= (others => '0');
            flush_counter_ff        <= (others => '0');
            overwritten_valid_ff    <= '0';
            overwritten_tag_addr_ff <= (others => '0');
            overwritten_set_addr_ff <= (others => '0');
            flush_tag_data_ff       <= (others => '0');
            pending_flush_ff        <= '0';
            dma_active_pipe_ff      <= (others => '0');
        elsif rising_edge(clk_i) then
            state_ff                <= state_nxt;
            dirty_mem_ff            <= dirty_mem_nxt;
            valid_mem_ff            <= valid_mem_nxt;
            miss_found_ff           <= miss_found_nxt;
            miss_addr_ff            <= miss_addr_nxt;
            miss_is_read_ff         <= miss_is_read_nxt;
            load_cache_addr_ff      <= load_cache_addr_nxt;
            download_mem_addr_ff    <= download_mem_addr_nxt;
            upload_mem_addr_ff      <= upload_mem_addr_nxt;
            replace_cache_line_ff   <= replace_cache_line_nxt;
            flush_counter_ff        <= flush_counter_nxt;
            overwritten_valid_ff    <= overwritten_valid_nxt;
            overwritten_tag_addr_ff <= overwritten_tag_addr_nxt;
            overwritten_set_addr_ff <= overwritten_set_addr_nxt;
            flush_tag_data_ff       <= flush_tag_data_nxt;
            pending_flush_ff        <= pending_flush_nxt;
            dma_active_pipe_ff(0)   <= dma_active_pip_nxt;
            if dcma_num_pipeline_reg_c > 0 then
                dma_active_pipe_ff(dma_active_pipe_ff'left downto 1) <= dma_active_pipe_ff(dma_active_pipe_ff'left - 1 downto 0);
            end if;
        end if;
    end process;

    dma_active_comb : process(dma_active_pipe_ff, dma_valid_i)
    begin
        dma_active_pip_nxt <= '0';
        for I in 0 to NUM_CLUSTERS - 1 loop
            if dma_valid_i(I) = '1' then
                dma_active_pip_nxt <= '1';
            end if;
        end loop;

        dma_active <= '0';
        for I in 0 to dma_active_pipe_ff'length - 1 loop
            if dma_active_pipe_ff(I) = '1' then
                dma_active <= '1';
            end if;
        end loop;
    end process;

    fsm_comb : process(state_ff, miss_found_ff, empty_cache_line_found, load_cache_addr_ff, download_mem_addr_ff, empty_cache_line, miss_addr_ff, dirty_mem_ff, replace_cache_line_ff, replacer_cache_line_i, valid_mem_ff, ram_axi_is_busy_i, upload_mem_addr_ff, flush_counter_ff, dcma_flush, dcma_reset, cache_line_accessed, cache_line_accessed_is_read, cache_line_accessed_valid, tag_mem_rdata, tag_mem_hit_calc_addr, flush_tag_data_ff, pending_flush_ff, dma_active)
        variable flush_counter_incr_v  : std_ulogic_vector(flush_counter_ff'range);
        variable flush_counter_incr2_v : std_ulogic_vector(flush_counter_ff'range);
        variable tag_mem_associativity : integer;
        variable set                   : std_ulogic_vector(addr_set_width_c - 1 downto 0);
        variable is_access_dirty       : boolean;
    begin
        --default
        state_nxt     <= state_ff;
        valid_mem_nxt <= valid_mem_ff;
        dirty_mem_nxt <= dirty_mem_ff;

        dcma_busy            <= '1';
        ram_axi_cache_addr_o <= (others => '0');
        ram_axi_mem_addr_o   <= (others => '0');
        ram_axi_is_read_o    <= '0';
        ram_axi_valid_o      <= '0';

        load_cache_addr_nxt   <= load_cache_addr_ff;
        download_mem_addr_nxt <= download_mem_addr_ff;
        upload_mem_addr_nxt   <= upload_mem_addr_ff;

        replacer_valid_o       <= '0';
        replacer_addr_o        <= miss_addr_ff;
        replace_cache_line_nxt <= replace_cache_line_ff;

        fsm_tag_mem_accessed <= '0';

        miss_solved <= '0';

        overwritten_valid_nxt    <= '0';
        overwritten_set_addr_nxt <= (others => '-');
        overwritten_tag_addr_nxt <= (others => '-');

        flush_counter_nxt     <= flush_counter_ff;
        flush_counter_incr_v  := std_ulogic_vector(unsigned(flush_counter_ff) + 1);
        flush_counter_incr2_v := std_ulogic_vector(unsigned(flush_counter_ff) + 2);
        flush_tag_data_nxt    <= flush_tag_data_ff;

        pending_flush_nxt <= pending_flush_ff;

        for I in 0 to associativity_c - 1 loop
            tag_mem_addr(I)  <= tag_mem_hit_calc_addr(I);
            tag_mem_wr_en(I) <= '0';
            tag_mem_wdata(I) <= (others => '-');
        end loop;

        for I in 0 to NUM_CLUSTERS - 1 loop
            if cache_line_accessed_valid(I) = '1' and cache_line_accessed_is_read(I) = '0' then
                dirty_mem_nxt(to_integer(unsigned(cache_line_accessed(I)))) <= '1';
            end if;
        end loop;

        case state_ff is
            -- SEIDLITZ: prefetch only in IDLE possible
            when IDLE =>
                if dma_active = '0' and pending_flush_ff = '0' then
                    dcma_busy <= '0';
                end if;

                if dma_active = '1' and dcma_flush = '1' then
                    pending_flush_nxt <= '1';
                end if;

                if (dcma_flush = '1' or pending_flush_ff = '1') and dma_active = '0' then
                    pending_flush_nxt <= '0';

                    -- set tag from tag memory
                    -- flush counter should be zero at this place
                    tag_mem_associativity               := to_integer(unsigned(flush_counter_ff(ASSOCIATIVITY_LOG2 - 1 downto 0)));
                    tag_mem_addr(tag_mem_associativity) <= flush_counter_ff(flush_counter_ff'left downto ASSOCIATIVITY_LOG2);
                    flush_tag_data_nxt                  <= tag_mem_rdata(tag_mem_associativity);
                    fsm_tag_mem_accessed                <= '1';

                    state_nxt <= FLUSH;
                elsif dcma_reset = '1' then
                    valid_mem_nxt <= (others => '0');
                elsif miss_found_ff = '1' then
                    -- if new cache line is empty, download new line from memory
                    -- else
                    --      if new cache line is dirty, upload to memory and download after that
                    --      else download and replace
                    if empty_cache_line_found = '1' then
                        -- internal cache addr
                        load_cache_addr_nxt <= std_ulogic_vector(shift_left(resize(unsigned(empty_cache_line), load_cache_addr_nxt'length), addr_word_offset_width_c + addr_word_sel_width_c));

                        -- cache aligned memory byte addr
                        download_mem_addr_nxt                                                                <= miss_addr_ff;
                        download_mem_addr_nxt(addr_word_offset_width_c + addr_word_sel_width_c - 1 downto 0) <= (others => '0');

                        replace_cache_line_nxt <= empty_cache_line; -- @suppress "Incorrect array size in assignment: expected (<addr_set_width_c + ASSOCIATIVITY_LOG2>) but was (<num_cache_lines_log2_c>)"

                        state_nxt <= DOWNLOAD;
                    else
                        -- get replace line from cache line replacer module
                        replacer_valid_o       <= '1';
                        replace_cache_line_nxt <= replacer_cache_line_i;

                        -- replace line becomes invalid
                        valid_mem_nxt(to_integer(unsigned(replacer_cache_line_i))) <= '0';

                        -- replace line also becomes invalid in CACHE LINE ACCESS MODULE
                        set                                 := miss_addr_ff(addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_word_sel_width_c + addr_word_offset_width_c);
                        tag_mem_associativity               := to_integer(unsigned(replacer_cache_line_i(ASSOCIATIVITY_LOG2 - 1 downto 0)));
                        tag_mem_addr(tag_mem_associativity) <= replacer_cache_line_i(replacer_cache_line_i'left downto ASSOCIATIVITY_LOG2); -- @suppress "Incorrect array size in assignment: expected (<num_cache_lines_log2_c + -1*ASSOCIATIVITY_LOG2>) but was (<addr_set_width_c>)"
                        fsm_tag_mem_accessed                <= '1';
                        overwritten_valid_nxt               <= '1';
                        overwritten_tag_addr_nxt            <= tag_mem_rdata(tag_mem_associativity);
                        overwritten_set_addr_nxt            <= set;

                        -- check if replace line is dirty
                        is_access_dirty := false;
                        for I in 0 to NUM_CLUSTERS - 1 loop
                            if cache_line_accessed_valid(I) = '1' and cache_line_accessed_is_read(I) = '0' and cache_line_accessed(I) = replacer_cache_line_i then
                                is_access_dirty := true;
                            end if;
                        end loop;

                        if valid_mem_ff(to_integer(unsigned(replacer_cache_line_i))) = '1' and (dirty_mem_ff(to_integer(unsigned(replacer_cache_line_i))) = '1' or is_access_dirty) then
                            -- old cache line mem addr has same set, but different tag than new 
                            upload_mem_addr_nxt                                                                <= miss_addr_ff;
                            upload_mem_addr_nxt(addr_word_offset_width_c + addr_word_sel_width_c - 1 downto 0) <= (others => '0');

                            -- replace tag with old one
                            --                            tag_mem_associativity := to_integer(unsigned(replacer_cache_line_i(ASSOCIATIVITY_LOG2 - 1 downto 0)));
                            --                            tag_mem_addr(tag_mem_associativity)                                                                                                                                                        <= replacer_cache_line_i(replacer_cache_line_i'left downto ASSOCIATIVITY_LOG2);
                            upload_mem_addr_nxt(addr_tag_width_c + addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c) <= tag_mem_rdata(tag_mem_associativity);
                            fsm_tag_mem_accessed                                                                                                                                                                       <= '1';

                            state_nxt <= UPLOAD;
                        else
                            state_nxt <= DOWNLOAD;
                        end if;

                        -- internal cache addr
                        load_cache_addr_nxt <= std_ulogic_vector(shift_left(resize(unsigned(replacer_cache_line_i), load_cache_addr_nxt'length), addr_word_offset_width_c + addr_word_sel_width_c));

                        -- cache aligned memory byte addr
                        download_mem_addr_nxt                                                                <= miss_addr_ff;
                        download_mem_addr_nxt(addr_word_offset_width_c + addr_word_sel_width_c - 1 downto 0) <= (others => '0');
                    end if;
                end if;

            when UPLOAD =>
                if dcma_flush = '1' then
                    pending_flush_nxt <= '1';
                end if;

                ram_axi_valid_o      <= '1';
                ram_axi_is_read_o    <= '0';
                ram_axi_cache_addr_o <= load_cache_addr_ff;
                ram_axi_mem_addr_o   <= upload_mem_addr_ff;
                if ram_axi_is_busy_i = '0' then
                    state_nxt <= DOWNLOAD;
                end if;

            when DOWNLOAD =>
                if dcma_flush = '1' then
                    pending_flush_nxt <= '1';
                end if;

                ram_axi_valid_o      <= '1';
                ram_axi_is_read_o    <= '1';
                ram_axi_cache_addr_o <= load_cache_addr_ff;
                ram_axi_mem_addr_o   <= download_mem_addr_ff;
                if ram_axi_is_busy_i = '0' then
                    state_nxt <= DOWNLOAD_WAIT;
                end if;

            when DOWNLOAD_WAIT =>
                if dcma_flush = '1' then
                    pending_flush_nxt <= '1';
                end if;

                if ram_axi_is_busy_i = '0' then
                    miss_solved <= '1';

                    valid_mem_nxt(to_integer(unsigned(replace_cache_line_ff))) <= '1';
                    dirty_mem_nxt(to_integer(unsigned(replace_cache_line_ff))) <= '0';

                    tag_mem_associativity                := to_integer(unsigned(replace_cache_line_ff(ASSOCIATIVITY_LOG2 - 1 downto 0)));
                    tag_mem_wr_en(tag_mem_associativity) <= '1';
                    tag_mem_addr(tag_mem_associativity)  <= replace_cache_line_ff(replace_cache_line_ff'left downto ASSOCIATIVITY_LOG2); -- @suppress "Incorrect array size in assignment: expected (<num_cache_lines_log2_c + -1*ASSOCIATIVITY_LOG2>) but was (<addr_set_width_c>)"
                    tag_mem_wdata(tag_mem_associativity) <= download_mem_addr_ff(addr_tag_width_c + addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c);
                    fsm_tag_mem_accessed                 <= '1';

                    state_nxt <= IDLE;
                end if;

            when FLUSH =>
                -- get tag memory of next data
                tag_mem_associativity               := to_integer(unsigned(flush_counter_incr_v(ASSOCIATIVITY_LOG2 - 1 downto 0)));
                tag_mem_addr(tag_mem_associativity) <= flush_counter_incr_v(flush_counter_incr_v'left downto ASSOCIATIVITY_LOG2);
                flush_tag_data_nxt                  <= tag_mem_rdata(tag_mem_associativity);
                fsm_tag_mem_accessed                <= '1';

                if valid_mem_ff(to_integer(unsigned(flush_counter_ff))) = '1' and dirty_mem_ff(to_integer(unsigned(flush_counter_ff))) = '1' then
                    if ram_axi_is_busy_i = '0' then
                        ram_axi_valid_o      <= '1';
                        ram_axi_is_read_o    <= '0';
                        ram_axi_cache_addr_o <= std_ulogic_vector(shift_left(resize(unsigned(flush_counter_ff), load_cache_addr_nxt'length), addr_word_offset_width_c + addr_word_sel_width_c));

                        -- old cache line mem addr has same set, but different tag than new 
                        -- set set
                        ram_axi_mem_addr_o(addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_word_sel_width_c + addr_word_offset_width_c) <= flush_counter_ff(addr_set_width_c + ASSOCIATIVITY_LOG2 - 1 downto ASSOCIATIVITY_LOG2);
                        -- set word to 0
                        ram_axi_mem_addr_o(addr_word_offset_width_c + addr_word_sel_width_c - 1 downto 0)                                                                   <= (others => '0');

                        -- set tag from tag memory
                        ram_axi_mem_addr_o(addr_tag_width_c + addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c) <= flush_tag_data_ff;

                        state_nxt <= FLUSH_WAIT;
                    end if;
                else
                    flush_counter_nxt <= std_ulogic_vector(unsigned(flush_counter_ff) + 1);
                    if unsigned(flush_counter_ff) = num_cache_lines_c - 1 then
                        flush_counter_nxt <= (others => '0');
                        state_nxt         <= IDLE;
                    end if;
                end if;

            when FLUSH_WAIT =>
                if ram_axi_is_busy_i = '0' then
                    dirty_mem_nxt(to_integer(unsigned(flush_counter_ff))) <= '0';
                    flush_counter_nxt                                     <= std_ulogic_vector(unsigned(flush_counter_ff) + 1);
                    --                    state_nxt                                             <= FLUSH;

                    -- get tag memory of next data
                    tag_mem_associativity               := to_integer(unsigned(flush_counter_incr2_v(ASSOCIATIVITY_LOG2 - 1 downto 0)));
                    tag_mem_addr(tag_mem_associativity) <= flush_counter_incr2_v(flush_counter_incr2_v'left downto ASSOCIATIVITY_LOG2);
                    flush_tag_data_nxt                  <= tag_mem_rdata(tag_mem_associativity);
                    fsm_tag_mem_accessed                <= '1';

                    if unsigned(flush_counter_ff) = num_cache_lines_c - 1 then
                        flush_counter_nxt <= (others => '0');
                        state_nxt         <= IDLE;
                    elsif valid_mem_ff(to_integer(unsigned(flush_counter_ff) + 1)) = '1' and dirty_mem_ff(to_integer(unsigned(flush_counter_ff) + 1)) = '1' then
                        ram_axi_valid_o      <= '1';
                        ram_axi_is_read_o    <= '0';
                        ram_axi_cache_addr_o <= std_ulogic_vector(shift_left(resize(unsigned(flush_counter_ff) + 1, load_cache_addr_nxt'length), addr_word_offset_width_c + addr_word_sel_width_c));

                        -- old cache line mem addr has same set, but different tag than new 
                        -- set set
                        ram_axi_mem_addr_o(addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_word_sel_width_c + addr_word_offset_width_c) <= flush_counter_incr_v(addr_set_width_c + ASSOCIATIVITY_LOG2 - 1 downto ASSOCIATIVITY_LOG2);
                        -- set word to 0
                        ram_axi_mem_addr_o(addr_word_offset_width_c + addr_word_sel_width_c - 1 downto 0)                                                                   <= (others => '0');

                        -- set tag from tag memory
                        ram_axi_mem_addr_o(addr_tag_width_c + addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c) <= flush_tag_data_ff;

                        state_nxt <= FLUSH_WAIT;
                    end if;
                end if;
        end case;
    end process;

    hit_calc_comb : process(cache_line_access_addr, cache_line_access_rd_en, fsm_tag_mem_accessed, tag_mem_rdata, valid_mem_ff, cache_line_access_is_read, miss_found_ff, miss_solved, miss_addr_ff, miss_is_read_ff)
        variable tag        : std_ulogic_vector(addr_tag_width_c - 1 downto 0);
        variable set        : std_ulogic_vector(addr_set_width_c - 1 downto 0);
        variable cache_line : unsigned(addr_set_width_c + ASSOCIATIVITY_LOG2 - 1 downto 0);
        variable hit_found  : std_ulogic;
    begin
        -- default
        tag_mem_hit_calc_addr         <= (others => (others => '0'));
        cache_line_access_hit         <= '0';
        cache_line_access_line_offset <= (others => '0');
        miss_found_nxt                <= miss_found_ff;
        miss_addr_nxt                 <= miss_addr_ff;
        miss_is_read_nxt              <= miss_is_read_ff;

        -- SEIDLITZ : miss_found is high for multiple cycles
        if miss_solved = '1' then
            miss_found_nxt <= '0';
        end if;

        set        := cache_line_access_addr(addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_word_sel_width_c + addr_word_offset_width_c);
        tag        := cache_line_access_addr(addr_tag_width_c + addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c);
        cache_line := shift_left(resize(unsigned(set), cache_line'length), ASSOCIATIVITY_LOG2);

        if fsm_tag_mem_accessed = '0' and cache_line_access_rd_en = '1' then
            hit_found := '0';
            for associativity in 0 to associativity_c - 1 loop
                tag_mem_hit_calc_addr(associativity) <= set; -- @suppress "Incorrect array size in assignment: expected (<num_cache_lines_log2_c + -1*ASSOCIATIVITY_LOG2>) but was (<addr_set_width_c>)"
                if tag = tag_mem_rdata(associativity) and valid_mem_ff(associativity + to_integer(cache_line)) = '1' then
                    hit_found                     := '1';
                    cache_line_access_hit         <= '1';
                    cache_line_access_line_offset <= std_ulogic_vector(to_unsigned(associativity, cache_line_access_line_offset'length));
                end if;
            end loop;

            if hit_found = '0' then
                --if no pending miss
                if miss_found_ff = '0' then
                    miss_found_nxt   <= '1';
                    miss_addr_nxt    <= cache_line_access_addr;
                    miss_is_read_nxt <= cache_line_access_is_read;
                end if;
            end if;
        end if;
    end process;

--    empty_cache_line_calc_comb : process(miss_addr_ff, valid_mem_ff)
--        variable set        : std_ulogic_vector(addr_set_width_c - 1 downto 0);
--        variable cache_line : unsigned(addr_set_width_c + ASSOCIATIVITY_LOG2 - 1 downto 0);
--    begin
--        --default
--        empty_cache_line_found <= '0';
--        empty_cache_line       <= (others => '0');
--
--        set := miss_addr_ff(addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_word_sel_width_c + addr_word_offset_width_c);
--
--        cache_line := shift_left(resize(unsigned(set), cache_line'length), ASSOCIATIVITY_LOG2);
--
--        for I in 2 ** ASSOCIATIVITY_LOG2 - 1 downto 0 loop
--            if valid_mem_ff(to_integer(unsigned(cache_line) + I)) = '0' then
--                empty_cache_line_found <= '1';
--                empty_cache_line       <= std_ulogic_vector(resize(unsigned(cache_line) + I, empty_cache_line'length));
--            end if;
--        end loop;
--
--    end process;

    -- empty cache line logic not necessary for FIFO replacement strategy
    empty_cache_line_found <= '0';
    empty_cache_line       <= (others => '0');

    connect_dma_ports_with_internal_signals_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        -- DMA signals
        cache_line_accessed(I) <= cache_line_accessed_int(cache_line_accessed(I)'length * (I + 1) - 1 downto cache_line_accessed(I)'length * I);
    end generate;

    tag_mem_gen : for I in 0 to associativity_c - 1 generate
        tag_mem_inst : dcma_async_mem
            generic map(
                ADDR_WIDTH => tag_mem_addr(I)'length,
                DATA_WIDTH => tag_mem_rdata(I)'length
            )
            port map(
                clk   => clk_i,
                wr_en => tag_mem_wr_en(I),
                addr  => tag_mem_addr(I),
                wdata => tag_mem_wdata(I),
                rdata => tag_mem_rdata(I)
            );
    end generate;

    dcma_cache_line_access_inst : dcma_cache_line_access
        generic map(
            NUM_CLUSTERS          => NUM_CLUSTERS,
            ASSOCIATIVITY_LOG2    => ASSOCIATIVITY_LOG2,
            DCMA_ADDR_WIDTH       => DCMA_ADDR_WIDTH,
            DCMA_DATA_WIDTH       => DCMA_DATA_WIDTH,
            CACHE_LINE_SIZE_BYTES => CACHE_LINE_SIZE_BYTES,
            TAG_ADDR_WIDTH        => addr_tag_width_c,
            SET_ADDR_WIDTH        => addr_set_width_c,
            NUM_CACHE_LINES_LOG2  => num_cache_lines_log2_c
        )
        port map(
            clk_i                         => clk_i,
            areset_n_i                    => areset_n_i,
            dma_addr_i                    => dma_addr_i,
            dma_is_read_i                 => dma_is_read_i,
            dma_valid_i                   => dma_valid_i,
            dma_is_hit_o                  => dma_is_hit_o,
            dma_line_offset_o             => dma_line_offset_o,
            dcma_reset_i                  => dcma_reset,
            tag_mem_is_hit_i              => cache_line_access_hit,
            tag_mem_line_offset_i         => cache_line_access_line_offset,
            tag_mem_rd_o                  => cache_line_access_rd_en,
            tag_mem_addr_o                => cache_line_access_addr,
            tag_mem_is_read_o             => cache_line_access_is_read,
            overwritten_valid_i           => overwritten_valid_ff,
            overwritten_tag_addr_i        => overwritten_tag_addr_ff,
            overwritten_set_addr_i        => overwritten_set_addr_ff,
            cache_line_accessed_valid_o   => cache_line_accessed_valid,
            cache_line_accessed_addr_o    => cache_line_accessed_int,
            cache_line_accessed_is_read_o => cache_line_accessed_is_read
        );

    cache_line_replacer_inst : cache_line_replacer
        generic map(
            NUM_CLUSTERS         => NUM_CLUSTERS,
            ASSOCIATIVITY_LOG2   => ASSOCIATIVITY_LOG2,
            DCMA_ADDR_WIDTH      => DCMA_ADDR_WIDTH,
            TAG_ADDR_WIDTH       => addr_tag_width_c,
            SET_ADDR_WIDTH       => addr_set_width_c,
            WORD_SEL_ADDR_WIDTH  => addr_word_sel_width_c,
            WORD_OFFS_ADDR_WIDTH => addr_word_offset_width_c
        )
        port map(
            clk_i            => clk_i,
            areset_n_i       => areset_n_i,
            line_accessed_i  => cache_line_accessed_int,
            accessed_valid_i => cache_line_accessed_valid,
            addr_i           => replacer_addr_o,
            valid_i          => replacer_valid_o,
            cache_line_o     => replacer_cache_line_i
        );

end architecture RTL;
