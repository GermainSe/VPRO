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

entity dcma_cache_line_access is
    generic(
        NUM_CLUSTERS          : integer := 8;
        --        NUM_RAMS              : integer := 32;
        ASSOCIATIVITY_LOG2    : integer := 2;
        --        RAM_ADDR_WIDTH        : integer := 12;
        DCMA_ADDR_WIDTH       : integer := 32; -- Address Width
        DCMA_DATA_WIDTH       : integer := 64; -- Data Width
        CACHE_LINE_SIZE_BYTES : integer := 1024;
        TAG_ADDR_WIDTH        : integer;
        SET_ADDR_WIDTH        : integer;
        NUM_CACHE_LINES_LOG2  : integer
    );
    port(
        clk_i                         : in  std_ulogic; -- Clock 
        areset_n_i                    : in  std_ulogic;
        -- DMA crossbar interface --
        dma_addr_i                    : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0); -- word addr
        dma_is_read_i                 : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        dma_valid_i                   : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        dma_is_hit_o                  : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        dma_line_offset_o             : out std_ulogic_vector(NUM_CLUSTERS * ASSOCIATIVITY_LOG2 - 1 downto 0);
        -- DCMA controller interface --
        dcma_reset_i                  : in  std_ulogic;
        tag_mem_is_hit_i              : in  std_ulogic;
        tag_mem_line_offset_i         : in  std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);
        tag_mem_rd_o                  : out std_ulogic;
        tag_mem_addr_o                : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
        tag_mem_is_read_o             : out std_ulogic;
        -- overwritten cache line --
        overwritten_valid_i           : in  std_ulogic;
        overwritten_tag_addr_i        : in  std_ulogic_vector(TAG_ADDR_WIDTH - 1 downto 0);
        overwritten_set_addr_i        : in  std_ulogic_vector(SET_ADDR_WIDTH - 1 downto 0);
        -- accessed cache lines
        cache_line_accessed_valid_o   : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        cache_line_accessed_addr_o    : out std_ulogic_vector(NUM_CLUSTERS * NUM_CACHE_LINES_LOG2 - 1 downto 0);
        cache_line_accessed_is_read_o : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0)
    );
end dcma_cache_line_access;

architecture RTL of dcma_cache_line_access is
    -- constants
    constant num_cluster_log2_c   : integer := integer(ceil(log2(real(NUM_CLUSTERS))));
    constant register_hit_input_c : boolean := true;

    -- ADDR: |TAG|SET|WORD_SEL|WORD|
    constant addr_set_width_c         : integer := SET_ADDR_WIDTH;
    constant addr_word_offset_width_c : integer := integer(ceil(log2(real(DCMA_DATA_WIDTH / 8))));
    constant addr_word_sel_width_c    : integer := integer(ceil(log2(real(CACHE_LINE_SIZE_BYTES / (DCMA_DATA_WIDTH / 8)))));
    constant addr_tag_width_c         : integer := TAG_ADDR_WIDTH;

    -- types
    type cluster_associativity_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);
    type cluster_dcma_addr_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    type cluster_tag_addr_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(TAG_ADDR_WIDTH - 1 downto 0);
    type cluster_set_addr_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(addr_set_width_c - 1 downto 0);
    type cluster_cache_line_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(NUM_CACHE_LINES_LOG2 - 1 downto 0);

    -- registers
    signal dma_line_offset_ff, dma_line_offset_nxt                         : cluster_associativity_array_t;
    signal miss_priority_pointer_ff, miss_priority_pointer_nxt             : std_ulogic_vector(num_cluster_log2_c - 1 downto 0); -- for dma round robin
    signal current_dma_access_tag_ff, current_dma_access_tag_nxt           : cluster_tag_addr_array_t;
    signal current_dma_access_set_ff, current_dma_access_set_nxt           : cluster_set_addr_array_t;
    signal current_dma_access_valid_ff, current_dma_access_valid_nxt       : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal cache_line_accessed_valid_ff, cache_line_accessed_valid_nxt     : std_ulogic_vector(cache_line_accessed_valid_o'range);
    signal cache_line_accessed_addr_ff, cache_line_accessed_addr_nxt       : cluster_cache_line_t;
    signal cache_line_accessed_is_read_ff, cache_line_accessed_is_read_nxt : std_ulogic_vector(cache_line_accessed_is_read_o'range);
    signal tag_mem_is_hit_ff                                               : std_ulogic;
    signal tag_mem_line_offset_ff                                          : std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);

    -- signals
    signal dma_hit_found               : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal dma_addr_int                : cluster_dcma_addr_array_t;
    signal new_cache_line_access_found : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
begin
    seq : process(areset_n_i, clk_i)
    begin
        if areset_n_i = '0' then
            dma_line_offset_ff             <= (others => (others => '0'));
            current_dma_access_tag_ff      <= (others => (others => '0'));
            current_dma_access_set_ff      <= (others => (others => '0'));
            current_dma_access_valid_ff    <= (others => '0');
            miss_priority_pointer_ff       <= (others => '0');
            cache_line_accessed_valid_ff   <= (others => '0');
            cache_line_accessed_addr_ff    <= (others => (others => '0'));
            cache_line_accessed_is_read_ff <= (others => '0');
            tag_mem_is_hit_ff              <= '0';
            tag_mem_line_offset_ff         <= (others => '0');
        elsif rising_edge(clk_i) then
            dma_line_offset_ff             <= dma_line_offset_nxt;
            current_dma_access_tag_ff      <= current_dma_access_tag_nxt;
            current_dma_access_set_ff      <= current_dma_access_set_nxt;
            current_dma_access_valid_ff    <= current_dma_access_valid_nxt;
            miss_priority_pointer_ff       <= miss_priority_pointer_nxt;
            cache_line_accessed_valid_ff   <= cache_line_accessed_valid_nxt;
            cache_line_accessed_addr_ff    <= cache_line_accessed_addr_nxt;
            cache_line_accessed_is_read_ff <= cache_line_accessed_is_read_nxt;
            tag_mem_is_hit_ff              <= tag_mem_is_hit_i;
            tag_mem_line_offset_ff         <= tag_mem_line_offset_i;
        end if;
    end process;

    cache_line_accessed_valid_o   <= cache_line_accessed_valid_ff;
    cache_line_accessed_is_read_o <= cache_line_accessed_is_read_ff;

    dma_cache_line_access_comb : process(current_dma_access_set_ff, current_dma_access_tag_ff, dma_addr_int, current_dma_access_valid_ff, dma_valid_i, dma_hit_found, dma_line_offset_ff, tag_mem_line_offset_ff, dma_is_read_i, overwritten_valid_i, overwritten_set_addr_i, overwritten_tag_addr_i, dcma_reset_i, tag_mem_line_offset_i)
        variable tag   : std_ulogic_vector(addr_tag_width_c - 1 downto 0);
        variable set   : std_ulogic_vector(addr_set_width_c - 1 downto 0);
        variable tag_j : std_ulogic_vector(addr_tag_width_c - 1 downto 0);
        variable set_j : std_ulogic_vector(addr_set_width_c - 1 downto 0);
    begin
        --default
        current_dma_access_tag_nxt   <= current_dma_access_tag_ff;
        current_dma_access_set_nxt   <= current_dma_access_set_ff;
        new_cache_line_access_found  <= (others => '0');
        current_dma_access_valid_nxt <= current_dma_access_valid_ff;
        dma_line_offset_nxt          <= dma_line_offset_ff;

        cache_line_accessed_valid_nxt   <= (others => '0');
        cache_line_accessed_addr_nxt    <= (others => (others => '-'));
        cache_line_accessed_is_read_nxt <= dma_is_read_i;

        dma_is_hit_o <= (others => '0');

        for I in NUM_CLUSTERS - 1 downto 0 loop
            if dcma_reset_i = '1' or (overwritten_valid_i = '1' and overwritten_tag_addr_i = current_dma_access_tag_ff(I) and overwritten_set_addr_i = current_dma_access_set_ff(I)) then
                current_dma_access_valid_nxt(I) <= '0';
            end if;

            set := dma_addr_int(I)(addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_word_sel_width_c + addr_word_offset_width_c);
            tag := dma_addr_int(I)(addr_tag_width_c + addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c);

            cache_line_accessed_addr_nxt(I)(cache_line_accessed_addr_nxt(I)'left downto ASSOCIATIVITY_LOG2) <= set; -- @suppress "Incorrect array size in assignment: expected (<NUM_CACHE_LINES_LOG2 + -1*ASSOCIATIVITY_LOG2>) but was (<SET_ADDR_WIDTH>)"

            if dma_valid_i(I) = '1' then
                --                dma_is_hit_nxt(I) <= '1';
                dma_is_hit_o(I) <= '1';

                cache_line_accessed_valid_nxt(I)                                 <= '1';
                cache_line_accessed_addr_nxt(I)(ASSOCIATIVITY_LOG2 - 1 downto 0) <= dma_line_offset_ff(I);

                -- check if DMA access is already loaded
                if (current_dma_access_valid_ff(I) = '0' or current_dma_access_tag_ff(I) /= tag or current_dma_access_set_ff(I) /= set) then
                    new_cache_line_access_found(I) <= '1';
                    dma_is_hit_o(I)                <= '0';

                    cache_line_accessed_valid_nxt(I) <= '0';

                    if ASSOCIATIVITY_LOG2 = 0 then
                        if I > 0 then
                            for J in 0 to I - 1 loop
                                set_j := dma_addr_int(J)(addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_word_sel_width_c + addr_word_offset_width_c);
                                tag_j := dma_addr_int(J)(addr_tag_width_c + addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c - 1 downto addr_set_width_c + addr_word_sel_width_c + addr_word_offset_width_c);
                                -- check if other DMAs access the same cache line, then do not overwrite the cache line
                                if dma_valid_i(J) = '1' and tag /= tag_j and set = set_j then
                                    new_cache_line_access_found(I) <= '0';
                                end if;
                            end loop;
                        end if;
                    end if;

                    -- for J in NUM_CLUSTERS - 1 downto 0 loop
                    -- check if other DMAs access the same cache line
                    --    if current_dma_access_valid_ff(J) = '1' and tag = current_dma_access_tag_ff(J) and set = current_dma_access_set_ff(J) and not (overwritten_valid_i = '1' and overwritten_tag_addr_i = current_dma_access_tag_ff(J) and overwritten_set_addr_i = current_dma_access_set_ff(J)) then
                    --        dma_is_hit_nxt(I) <= '1';

                    --       new_cache_line_access_found(I) <= '0';

                    --       current_dma_access_tag_nxt(I)   <= tag;
                    --       current_dma_access_set_nxt(I)   <= set;
                    --       current_dma_access_valid_nxt(I) <= '1';

                    --       dma_line_offset_nxt(I) <= dma_line_offset_ff(J);

                    --       cache_line_accessed_valid_nxt(I)                                 <= '1';
                    --       cache_line_accessed_addr_nxt(I)(ASSOCIATIVITY_LOG2 - 1 downto 0) <= dma_line_offset_ff(J);
                    --   end if;
                    --end loop;

                    -- hit found
                    if dma_hit_found(I) = '1' then
                        current_dma_access_tag_nxt(I)   <= tag;
                        current_dma_access_set_nxt(I)   <= set;
                        current_dma_access_valid_nxt(I) <= '1';

                        cache_line_accessed_valid_nxt(I) <= '1';

                        if register_hit_input_c then
                            cache_line_accessed_addr_nxt(I)(ASSOCIATIVITY_LOG2 - 1 downto 0) <= tag_mem_line_offset_ff;
                            dma_line_offset_nxt(I)                                           <= tag_mem_line_offset_ff;
                        end if;

                        if not register_hit_input_c then
                            cache_line_accessed_addr_nxt(I)(ASSOCIATIVITY_LOG2 - 1 downto 0) <= tag_mem_line_offset_i;
                            dma_line_offset_nxt(I)                                           <= tag_mem_line_offset_i;
                        end if;
                    end if;
                end if;
            end if;
        end loop;
    end process;

    dcma_controller_communication_comb : process(miss_priority_pointer_ff, new_cache_line_access_found, dma_addr_int, dma_is_read_i, tag_mem_is_hit_ff, tag_mem_is_hit_i)
        variable current_dma_pointer : integer;
        --        variable access_found        : boolean;
    begin
        -- default
        current_dma_pointer := to_integer(unsigned(miss_priority_pointer_ff));
        tag_mem_rd_o        <= '0';
        tag_mem_addr_o      <= (others => '-');
        tag_mem_is_read_o   <= '-';

        dma_hit_found             <= (others => '0');
        miss_priority_pointer_nxt <= std_ulogic_vector(unsigned(miss_priority_pointer_ff) + 1);

        if register_hit_input_c then
            if tag_mem_is_hit_ff = '1' then
                dma_hit_found(to_integer(unsigned(miss_priority_pointer_ff) - 1)) <= '1';
            end if;
        end if;

        if new_cache_line_access_found(current_dma_pointer) = '1' then
            tag_mem_rd_o      <= '1';
            tag_mem_addr_o    <= dma_addr_int(current_dma_pointer);
            tag_mem_is_read_o <= dma_is_read_i(current_dma_pointer);

            if not register_hit_input_c then
                if tag_mem_is_hit_i = '1' then
                    dma_hit_found(to_integer(unsigned(miss_priority_pointer_ff))) <= '1';
                end if;
            end if;
            --        else
            --            access_found := false;
            --            for cluster in NUM_CLUSTERS - 1 downto 0 loop
            --                if new_cache_line_access_found(cluster) = '1' then
            --                    access_found        := true;
            --                    current_dma_pointer := cluster;
            --                end if;
            --            end loop;
            --
            --            if access_found then
            --                tag_mem_rd_o      <= '1';
            --                tag_mem_addr_o    <= dma_addr_int(current_dma_pointer);
            --                tag_mem_is_read_o <= dma_is_read_i(current_dma_pointer);
            --
            --                if tag_mem_is_hit_i = '1' then
            --                    dma_hit_found(current_dma_pointer) <= '1';
            --                end if;
            --            end if;
        end if;
    end process;

    connect_dma_ports_with_internal_signals_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        -- DMA signals
        dma_addr_int(I) <= std_ulogic_vector(shift_left(unsigned(dma_addr_i(DCMA_ADDR_WIDTH * (I + 1) - 1 downto DCMA_ADDR_WIDTH * I)), addr_word_offset_width_c));

        cache_line_accessed_addr_o(cache_line_accessed_addr_ff(I)'length * (I + 1) - 1 downto cache_line_accessed_addr_ff(I)'length * I) <= cache_line_accessed_addr_ff(I);

        dma_line_offset_o(ASSOCIATIVITY_LOG2 * (I + 1) - 1 downto ASSOCIATIVITY_LOG2 * I) <= dma_line_offset_ff(I);
    end generate;
end architecture RTL;
