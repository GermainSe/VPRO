--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- ----------------------------------------------------------------------------
--! @file i_cache.vhd 
--! @brief Instruction cache for the MIPS32 CPU and the VPRO
--! Configurable number of lines and line size (generics)
--! Line size must be at least 128 bit
--! Cache is direct-mapped
-- ----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

-- synthesis translate_off
use std.textio.all;
-- synthesis translate_on

entity i_cache is
    generic(
        LOG2_NUM_LINES       : natural := 3; -- log2 of number of cache lines
        LOG2_LINE_SIZE       : natural := 6; -- log2 of size of cache line (size in MEMORY_WORD_WIDTH-bit words)
        log2_associativity_g : natural := 2; -- 1 ~ 2-block, 2 ~ 4-block
        INSTR_WORD_COUNT     : natural := 16; -- number of output instruction words
        WORD_WIDTH           : natural := 32; -- width of one instruction word
        MEMORY_WORD_WIDTH    : natural := 512; -- width of one instruction word
        ADDR_WIDTH           : natural := 32 -- width of address
    );
    port(
        -- global control --
        clk_i           : in  std_ulogic; -- global clock line, rising-edge
        rst_i           : in  std_ulogic; -- global reset line, high-active, sync
        ce_i            : in  std_ulogic; -- global clock enable, high-active
        stall_i         : in  std_ulogic; -- freeze output if any stall
        clear_i         : in  std_ulogic; -- force reload of cache
        -- CPU instruction interface --
        cpu_oe_i        : in  std_ulogic; -- "IR" update enable
        cpu_instr_req_i : in  std_ulogic;
        cpu_instr_adr_i : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
        cpu_stall_o     : out std_ulogic; -- stall CPU (miss)
        -- Quad word --
        instr_o         : out std_ulogic_vector(WORD_WIDTH - 1 downto 0); -- multiple cmds starting at addr!
        -- memory system interface --
        mem_base_adr_o  : out std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
        mem_dat_i       : in  std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
        mem_req_o       : out std_ulogic; -- request data from memory
        mem_wait_i      : in  std_ulogic; -- memory command buffer full
        mem_ren_o       : out std_ulogic; -- read enable
        mem_rdy_i       : in  std_ulogic; -- applied data is valid
        -- access statistics --
        hit_o           : out std_ulogic; -- valid hit access
        miss_o          : out std_ulogic -- valid miss access
    );
end i_cache;

architecture i_cache_behav of i_cache is

    -- helper function for trace extraction --
    --cadence synthesis off
    function to_string(a : std_ulogic_vector) return string is
        variable b    : string(1 to a'length) := (others => NUL);
        variable stri : integer               := 1;
    begin
        for i in a'range loop
            b(stri) := std_ulogic'image(a((i)))(2);
            stri    := stri + 1;
        end loop;
        return b;
    end function;
    --cadence synthesis on

    -- constants --
    constant tag_width_c             : natural := ADDR_WIDTH - log2(MEMORY_WORD_WIDTH / 8) - LOG2_LINE_SIZE - LOG2_NUM_LINES;
    constant instr_word_count_log2_c : integer := log2(INSTR_WORD_COUNT);

    -- cache line memory --
    constant TOTAL_MEM_SIZE          : natural := (2 ** (LOG2_NUM_LINES + LOG2_LINE_SIZE + log2_associativity_g)) * MEMORY_WORD_WIDTH; -- in bits
    constant RAM_MEM_SIZE            : natural := TOTAL_MEM_SIZE / INSTR_WORD_COUNT; -- in bits
    --    constant MEM_WORD_COUNT          : natural := (((2 ** (LOG2_NUM_LINES + LOG2_LINE_SIZE + log2_associativity_g)) * (MEMORY_WORD_WIDTH / WORD_WIDTH)) / INSTR_WORD_COUNT);
    constant single_ram_addr_width_c : integer := log2(RAM_MEM_SIZE / WORD_WIDTH);

    -- tag memory --
    type tag_mem_st is array (0 to 2 ** LOG2_NUM_LINES - 1) of std_ulogic_vector(tag_width_c - 1 downto 0);
    type tag_mem_t is array (0 to 2 ** log2_associativity_g - 1) of tag_mem_st;
    signal tag_mem : tag_mem_t;

    type arb_flag_t is array (0 to 2 ** log2_associativity_g - 1) of std_ulogic_vector(2 ** LOG2_NUM_LINES - 1 downto 0);

    type ram_single_type is array (2 ** single_ram_addr_width_c - 1 downto 0) of std_ulogic_vector(WORD_WIDTH - 1 downto 0); -- 2D Array Declaration for RAM signal
    type ram_array_type is array (INSTR_WORD_COUNT - 1 downto 0) of ram_single_type; 

    signal ram : ram_array_type;

    -- valid flag --
    signal valid_flag, valid_flag_nxt : arb_flag_t;

    -- tag memory access --
    signal tag_mem_we                   : std_ulogic; -- write enable for tag memory
    signal tag_wr_data, tag_wr_data_nxt : std_ulogic_vector(tag_width_c - 1 downto 0); -- tag of a data line
    signal tag_wr_adr, tag_wr_adr_nxt   : std_ulogic_vector(LOG2_NUM_LINES - 1 downto 0); -- address of a tag ~ line address
    signal tag_rd_adr                   : std_ulogic_vector(LOG2_NUM_LINES - 1 downto 0); -- address of a tag ~ line address

    -- cache data memory access --
    signal data_mem_we  : std_ulogic;   -- write enable for data memory
    signal mem_wr_adr   : std_ulogic_vector(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto 0); -- inside 128-bit word, addresses 32-bit block
    signal cpu_rd_adr   : std_ulogic_vector(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto 0); -- inside 128-bit word, addresses 32-bit block
    signal cache_mem_en : std_ulogic;

    -- arbiter --
    type arb_state_t is (S_IDLE, S_RD_MISS, S_DOWNLOAD_REQ, S_DOWNLOAD, S_RESYNC);

    signal arb_state, arb_state_nxt : arb_state_t;
    signal base_adr, base_adr_nxt   : std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- cpu address
    signal cache_pnt, cache_pnt_nxt : std_ulogic_vector(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0); -- for fetch of external data 128-bit, address inside cache for that data
    signal cpu_stall, cpu_stall_nxt : std_ulogic;

    signal cache_cnt, cache_cnt_nxt : std_ulogic_vector(LOG2_LINE_SIZE downto 0);
    signal mem_base_adr_ff          : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
    signal mem_base_adr_o_nxt       : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);

    -- others --
    signal cache_hit : std_ulogic;

    -- address of flag/line (e.g. in tag mem)
    -- line inside cache
    signal cpu_adr_buff_line    : unsigned(LOG2_NUM_LINES - 1 downto 0);
    signal cpu_instr_adr_i_line : std_ulogic_vector(LOG2_NUM_LINES - 1 downto 0);
    -- address of that line in cache mem (128-bit)
    -- 32-bit word inside line
    signal cpu_adr_buff_word    : std_ulogic_vector(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 downto 0);
    signal cpu_instr_adr_i_word : std_ulogic_vector(LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto 0);
    -- tag of that line
    signal cpu_instr_adr_i_tag  : std_ulogic_vector(tag_width_c - 1 downto 0);
    signal cpu_adr_buff_tag     : std_ulogic_vector(tag_width_c - 1 downto 0);

    type read_address_t is array (0 to (INSTR_WORD_COUNT - 1)) of unsigned(single_ram_addr_width_c - 1 downto 0);
    signal cpu_data, cpu_data_read : multi_cmd_t;
    signal cpu_read_address        : read_address_t;
    signal cpu_batch_word_index_ff : std_ulogic_vector(instr_word_count_log2_c - 1 downto 0);

    -- CLEAR
    signal pending_clear, pending_clear_nxt : std_ulogic;

    -- used block upon miss + ff
    signal miss_use_block                         : integer range 0 to 2 ** log2_associativity_g - 1;
    signal mem_access_block_nxt, mem_access_block : integer range 0 to 2 ** log2_associativity_g - 1;

    -- from cpu signal, use this block (based on cache hit)
    signal cache_access_block     : integer range 0 to 2 ** log2_associativity_g - 1;
    signal cpu_access_block       : integer range 0 to 2 ** log2_associativity_g - 1;
    signal cpu_cache_access_block : integer range 0 to 2 ** log2_associativity_g - 1;

    signal flush_stall_cnt, flush_stall_cnt_nxt : integer range 0 to 2 * 2 ** LOG2_LINE_SIZE - 1;

    --
    -- CHANGE of write behavior to eliminate critical path
    -- buffer all write signals one additional cycle
    -- TODO: check write with one cycle delay
    --        possible error: write + read in same cycle (read address not delayed, but output; in data_distributor)
    --        should not cause error as attribtue given: write_first
    --

    signal mem_enable_wr_ff, mem_enable_wr_nxt : std_ulogic_vector(INSTR_WORD_COUNT - 1 downto 0);
    type addr_wr_t is array (0 to INSTR_WORD_COUNT - 1) of unsigned(log2_associativity_g + LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0);
    signal mem_addr_wr_ff, mem_addr_wr_nxt     : addr_wr_t;
    type data_wr_t is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(WORD_WIDTH - 1 downto 0);
    signal mem_data_wr_ff, mem_data_wr_nxt     : data_wr_t;

    -- RAM signals
    type ram_data_type is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(instr_o'length - 1 downto 0);
    type ram_addr_type is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(single_ram_addr_width_c - 1 downto 0);

    signal cpu_ram_rd_en   : std_ulogic_vector(INSTR_WORD_COUNT - 1 downto 0);
    signal cpu_ram_rdata   : ram_data_type;
    signal cpu_ram_rd_addr : ram_addr_type;
    signal mem_ram_wr_en   : std_ulogic_vector(INSTR_WORD_COUNT - 1 downto 0);
    signal mem_ram_wdata   : ram_data_type;
    signal mem_ram_wr_addr : ram_addr_type;

    signal reset_n : std_ulogic;

    signal cache_line_replacer_valid : std_ulogic;
    signal cache_line_replacer_line  : std_ulogic_vector(log2_associativity_g - 1 downto 0);

    signal addr_tag_compare : std_ulogic_vector(tag_width_c - 1 downto 0);
begin
    reset_n <= not rst_i;

    -- Assignments -----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    -- CPU address --
    -- structure: ||-TAG-|-LINE-|-WORD-||  {cpu addr}
    --                      2     2^7 + 2 (32-bit)
    cpu_instr_adr_i_word <= cpu_instr_adr_i(LOG2_LINE_SIZE - 1 + log2(MEMORY_WORD_WIDTH / 8) downto log2(WORD_WIDTH / 8)); -- 32-bit word select in line with 128-bit words
    cpu_instr_adr_i_line <= cpu_instr_adr_i(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)); -- line select
    cpu_instr_adr_i_tag  <= cpu_instr_adr_i(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + LOG2_NUM_LINES + log2(MEMORY_WORD_WIDTH / 8)); -- line's tag

    cpu_adr_buff_line <= unsigned(base_adr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)));
    cpu_adr_buff_word <= base_adr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto log2(MEMORY_WORD_WIDTH / 8));
    cpu_adr_buff_tag  <= base_adr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + LOG2_NUM_LINES + log2(MEMORY_WORD_WIDTH / 8)); -- line's tag

    -- Cache access --
    wraddr_process : process(cache_pnt)
    begin
        mem_wr_adr                                                                                                                                                         <= (others => '0');
        mem_wr_adr(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8))) <= cache_pnt;
    end process;

    -- access statistics --
    hit_o  <= '1' when (cpu_instr_req_i = '1') and (cache_hit = '1') else '0';
    miss_o <= '1' when (cpu_instr_req_i = '1') and (cache_hit = '0') else '0';

    mem_base_adr_o <= mem_base_adr_ff;

    -- Control arbiter (sync) ------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    arbiter_sync : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            -- arbiter --
            arb_state        <= S_IDLE;
            pending_clear    <= '0';
            cpu_stall        <= '0';
            mem_base_adr_ff  <= (others => '0');
            base_adr         <= (others => '0');
            cache_pnt        <= (others => '0');
            cache_cnt        <= (others => '0');
            tag_wr_adr       <= (others => '0');
            tag_wr_data      <= (others => '0');
            valid_flag       <= (others => (others => '0')); -- all lines are invalid after reset
            mem_access_block <= 0;
            flush_stall_cnt  <= 0;
        elsif rising_edge(clk_i) then
            if (ce_i = '1') then
                -- arbiter --
                arb_state       <= arb_state_nxt;
                valid_flag      <= valid_flag_nxt;
                base_adr        <= base_adr_nxt;
                cache_pnt       <= cache_pnt_nxt;
                cpu_stall       <= cpu_stall_nxt;
                cache_cnt       <= cache_cnt_nxt;
                mem_base_adr_ff <= mem_base_adr_o_nxt;
                tag_wr_adr      <= tag_wr_adr_nxt;
                tag_wr_data     <= tag_wr_data_nxt;

                pending_clear <= pending_clear_nxt;

                mem_access_block <= mem_access_block_nxt;
                flush_stall_cnt  <= flush_stall_cnt_nxt;
            end if;
        end if;
    end process arbiter_sync;

    -- CPU STALL --
    cpu_stall_o <= cpu_stall;

    --base_addr_next_multiword <= std_ulogic_vector(unsigned(base_adr) + INSTR_WORD_COUNT * (WORD_WIDTH / 8));

    -- Control arbiter (comb) ------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    arbiter_comb : process(arb_state, base_adr, cache_access_block, cache_cnt, cache_hit, cache_pnt, clear_i, cpu_adr_buff_line, cpu_adr_buff_tag, cpu_adr_buff_word, cpu_cache_access_block, cpu_instr_adr_i, cpu_instr_adr_i_line, cpu_instr_adr_i_tag, cpu_instr_adr_i_word, cpu_instr_req_i, cpu_stall, flush_stall_cnt, mem_access_block, mem_base_adr_ff, mem_rdy_i, mem_wait_i, miss_use_block, pending_clear, stall_i, tag_wr_adr, tag_wr_data, valid_flag)
        -- cpu_instr_adr_i_next_tag, access_to_last_words_no_multiword_possible, cache_next_hit, cpu_instr_adr_i_next_line
    begin
        flush_stall_cnt_nxt <= flush_stall_cnt;
        -- arbiter defaults --
        arb_state_nxt       <= arb_state;
        base_adr_nxt        <= base_adr;
        valid_flag_nxt      <= valid_flag;
        cache_pnt_nxt       <= cache_pnt;
        cache_cnt_nxt       <= cache_cnt;

        pending_clear_nxt <= (pending_clear or clear_i) and cpu_instr_req_i;

        -- tag mem defaults --
        tag_mem_we <= '0';

        cpu_rd_adr <= cpu_instr_adr_i_line & cpu_instr_adr_i_word; --to compensate 128 instead 32 bit

        --        mem_rd_adr <= (others => '-');  --to compensate 128 instead 32 bit

        mem_ren_o <= '0';
        mem_req_o <= '0';

        -- cpu defaults --
        cpu_stall_nxt <= cpu_stall;
        cache_mem_en  <= cpu_instr_req_i;

        -- data mem defaults --
        data_mem_we <= '0';

        -- Addr output to external memory --
        --mem_base_adr_o(31 downto 2) <= base_adr(31 downto 2) when (arb_state = S_DOWNLOAD) else (others => '0'); -- reduce switching activity
        --      mem_base_adr_o_nxt <= (others => '0');
        mem_base_adr_o_nxt <= mem_base_adr_ff;
        --        mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= base_adr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8));
        --        mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');

        tag_wr_adr_nxt  <= tag_wr_adr;
        tag_wr_data_nxt <= tag_wr_data;

        tag_rd_adr <= cpu_instr_adr_i_line;

        addr_tag_compare <= cpu_adr_buff_tag;
        if cpu_instr_req_i = '1' and cpu_stall = '0' then
            addr_tag_compare <= cpu_instr_adr_i_tag;
        end if;

        mem_access_block_nxt <= mem_access_block;
        cpu_access_block     <= cpu_cache_access_block;

        cache_line_replacer_valid <= '0';

        -- state machine --
        case (arb_state) is

            when S_IDLE =>              -- normal access
                -------------------------------------------------------
                mem_access_block_nxt                  <= cache_access_block;
                base_adr_nxt(ADDR_WIDTH - 1 downto 0) <= cpu_instr_adr_i(ADDR_WIDTH - 1 downto 0);
                cache_cnt_nxt                         <= std_ulogic_vector(to_unsigned(2 ** (LOG2_LINE_SIZE), LOG2_LINE_SIZE + 1));
                cpu_stall_nxt                         <= '0'; -- stall cpu

                if (cpu_instr_req_i = '1') and (stall_i = '0') then
                    if (cache_hit = '0') then
                        -- valid access and (regular) MISS
                        tag_wr_adr_nxt            <= cpu_instr_adr_i_line;
                        tag_wr_data_nxt           <= cpu_instr_adr_i_tag;
                        cache_line_replacer_valid <= '1';
                        mem_access_block_nxt      <= miss_use_block; -- store used block
                        arb_state_nxt             <= S_RD_MISS;
                        cpu_stall_nxt             <= '1'; -- freeze CPU
                    end if;
                elsif (pending_clear = '1') then -- clear cache; invalidate all cache lines                    
                    valid_flag_nxt    <= (others => (others => '0'));
                    pending_clear_nxt <= '0';
                end if;

            when S_RD_MISS =>           -- that was a miss - prepare update
                -------------------------------------------------------
                tag_rd_adr                                                                             <= std_ulogic_vector(cpu_adr_buff_line); -- tag data returns async!
                cache_pnt_nxt                                                                          <= cpu_adr_buff_word; -- set cache pointer
                cache_pnt_nxt(LOG2_LINE_SIZE - 1 downto 0)                                             <= (others => '0');
                tag_mem_we                                                                             <= '1'; -- set new tag   
                mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= base_adr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8));
                mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');
                arb_state_nxt                                                                          <= S_DOWNLOAD_REQ;

            when S_DOWNLOAD_REQ =>
                -------------------------------------------------------
                if (mem_wait_i = '0') then
                    mem_req_o     <= '1';
                    arb_state_nxt <= S_DOWNLOAD;
                    -- set valid flag --
                    tag_mem_we    <= '1';
                end if;

            when S_DOWNLOAD =>          -- loop for updating cache line
                -------------------------------------------------------
                cache_mem_en <= '1';    -- enable cache access
                data_mem_we  <= '1';    -- allow write access
                if mem_rdy_i = '1' then -- data valid?
                    cache_pnt_nxt <= std_ulogic_vector(unsigned(cache_pnt) + 1);
                    cache_cnt_nxt <= std_ulogic_vector(unsigned(cache_cnt) - 1);
                    mem_ren_o     <= '1'; -- read from FIFO
                end if;
                if (to_integer(unsigned(cache_cnt)) = 0) then -- done?
                    arb_state_nxt <= S_RESYNC;
                end if;

            when S_RESYNC =>            -- resync instruction flow -- @suppress "Dead state 'S_RESYNC': state does not have outgoing transitions"
                -------------------------------------------------------
                cache_mem_en <= '1';    -- enable cache access

                if cpu_stall = '1' then
                    cpu_access_block <= mem_access_block;
                    cpu_rd_adr       <= base_adr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto log2(WORD_WIDTH / 8)); -- address backup for resync
                end if;

                cpu_stall_nxt <= '0';   -- resume cpu operation
                arb_state_nxt <= S_IDLE;

                valid_flag_nxt(mem_access_block)(to_integer(unsigned(tag_wr_adr))) <= '1'; -- set valid flag

        end case;
    end process arbiter_comb;

    -- Cache tag memory ------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    tag_mem_sync : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                if (tag_mem_we = '1') then
                    tag_mem(mem_access_block)(to_integer(unsigned(tag_wr_adr))) <= tag_wr_data;
                end if;
            end if;
        end if;
    end process tag_mem_sync;

    cache_hit_miss : process(tag_rd_adr, valid_flag, tag_mem, addr_tag_compare, cpu_instr_adr_i_line, cpu_instr_adr_i_tag)
    begin
        cache_hit          <= '0';
        cache_access_block <= 0;
        -- async read from tag mem --

        -- cache hit? (correct tag and valid entry) --
        for bl in 0 to 2 ** log2_associativity_g - 1 loop
            if (tag_mem(bl)(to_integer(unsigned(tag_rd_adr))) = addr_tag_compare) then
                if (valid_flag(bl)(to_integer(unsigned(tag_rd_adr))) = '1') then
                    cache_access_block <= bl;
                    cache_hit          <= '1';
                end if;
            end if;
        end loop;

        -- constant cpu_cache_access_block path to reduce crit path
        cpu_cache_access_block <= 0;
        -- cache hit? (correct tag and valid entry) --
        for bl in 0 to 2 ** log2_associativity_g - 1 loop
            if (tag_mem(bl)(to_integer(unsigned(cpu_instr_adr_i_line))) = cpu_instr_adr_i_tag) then
                if (valid_flag(bl)(to_integer(unsigned(cpu_instr_adr_i_line))) = '1') then
                    cpu_cache_access_block <= bl;
                end if;
            end if;
        end loop;
    end process;

    -- Cache data memory -----------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    data_mem_comb : process(cache_mem_en, data_mem_we, mem_wr_adr, mem_dat_i, arb_state, mem_rdy_i, mem_access_block)
        variable enable_v                  : std_ulogic_vector(WORD_WIDTH / 8 - 1 downto 0);
        variable data_v                    : std_ulogic_vector(WORD_WIDTH - 1 downto 0);
        variable addr_v                    : unsigned(log2_associativity_g + LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0);
        variable data_i_endianess_switched : std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
        variable mem_block_vec             : std_ulogic_vector(log2_associativity_g - 1 downto 0);

        variable concat : std_ulogic_vector(log2_associativity_g + LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0);
    begin
        mem_enable_wr_nxt <= (others => '0');
        mem_addr_wr_nxt   <= (others => (others => '-'));
        mem_data_wr_nxt   <= (others => (others => '-'));

        if (cache_mem_en = '1') then    -- enable
            mem_block_vec := std_ulogic_vector(to_unsigned(mem_access_block, log2_associativity_g));

            if data_mem_we = '1' and arb_state = S_DOWNLOAD and mem_rdy_i = '1' then
                -- data from MM interface are written into memory

                concat := mem_block_vec & mem_wr_adr(mem_wr_adr'left downto log2(INSTR_WORD_COUNT));
                addr_v := unsigned(concat);

                enable_v                  := (others => '0');
                data_i_endianess_switched := convert_wordorder(mem_dat_i);

                if INSTR_WORD_COUNT = 16 and MEMORY_WORD_WIDTH = 512 then
                    mem_enable_wr_nxt <= (others => '1');
                    for i in 0 to INSTR_WORD_COUNT - 1 loop -- all 16 memories
                        mem_data_wr_nxt(i) <= data_i_endianess_switched((i + 1) * WORD_WIDTH - 1 downto i * WORD_WIDTH);
                    end loop;
                end if;

                if not (INSTR_WORD_COUNT = 16 and MEMORY_WORD_WIDTH = 512) then
                    for i in 0 to INSTR_WORD_COUNT - 1 loop -- all 8 memories
                        if (i < MEMORY_WORD_WIDTH / WORD_WIDTH) then
                            data_v := data_i_endianess_switched((i + 1) * WORD_WIDTH - 1 downto i * WORD_WIDTH);
                            if (unsigned(mem_wr_adr(log2(INSTR_WORD_COUNT) - 1 downto log2(WORD_WIDTH))) = 0) then -- TODO: BUGs? instead log(...) => log2(MEMORY_WORD_WIDTH / 8) - 1 downto log2(WORD_WIDTH / 8) ?
                                enable_v := (others => '1');
                            end if;
                        else
                            data_v := data_i_endianess_switched(((i - MEMORY_WORD_WIDTH / WORD_WIDTH) + 1) * WORD_WIDTH - 1 downto (i - MEMORY_WORD_WIDTH / WORD_WIDTH) * WORD_WIDTH);
                            if (unsigned(mem_wr_adr(log2(INSTR_WORD_COUNT) - 1 downto log2(WORD_WIDTH))) = 1) then
                                enable_v := (others => '1');
                            end if;
                        end if;
                        if unsigned(enable_v) /= 0 then
                            mem_enable_wr_nxt(i) <= '1';
                        end if;
                        mem_data_wr_nxt(i) <= data_v;
                    end loop;
                end if;

                for i in 0 to INSTR_WORD_COUNT - 1 loop -- all 8 memories
                    -- all memories get the same addr
                    mem_addr_wr_nxt(i) <= addr_v;
                end loop;
            end if;

        end if;
    end process;

    WR_DELAYED_WRITE_GEN : if true generate
        data_mem_wr_buffer_sync : process(clk_i, rst_i)
        begin
            if (rst_i = '1') then
                mem_enable_wr_ff <= (others => '0');
                mem_addr_wr_ff   <= (others => (others => '0'));
                mem_data_wr_ff   <= (others => (others => '0'));
            elsif rising_edge(clk_i) then
                if (ce_i = '1') then
                    mem_enable_wr_ff <= mem_enable_wr_nxt;
                    mem_addr_wr_ff   <= mem_addr_wr_nxt;
                    mem_data_wr_ff   <= mem_data_wr_nxt;
                end if;
            end if;
        end process;
    end generate;

    WR_DIRECT_WRITE_GEN : if false generate
        mem_enable_wr_ff <= mem_enable_wr_nxt;
        mem_addr_wr_ff   <= mem_addr_wr_nxt;
        mem_data_wr_ff   <= mem_data_wr_nxt;
    end generate;

    data_mem_write : process(mem_addr_wr_ff, mem_data_wr_ff, mem_enable_wr_ff)
    begin
        for i in 0 to INSTR_WORD_COUNT - 1 loop -- all 8 memories
            mem_ram_wr_addr(i) <= std_ulogic_vector(mem_addr_wr_ff(i)); -- @suppress "Incorrect array size in assignment: expected (<single_ram_addr_width_c>) but was (<LOG2_LINE_SIZE + LOG2_NUM_LINES + log2_associativity_g>)"

            mem_ram_wdata(i) <= mem_data_wr_ff(i);

            mem_ram_wr_en(i) <= mem_enable_wr_ff(i);
        end loop;
    end process data_mem_write;

    data_cpu_read_addresses : process(cpu_access_block, cpu_rd_adr)
        -- INSTR_WORD_COUNT cache element base address
        variable this_batch_address : unsigned(single_ram_addr_width_c - 1 downto 0);
        -- INSTR_WORD_COUNT cache element base address of next 128-bit block
        variable next_batch_address : unsigned(single_ram_addr_width_c - 1 downto 0);
        variable batch_word_index   : integer;
        variable block_vec          : std_ulogic_vector(log2_associativity_g - 1 downto 0);

        variable concat      : std_ulogic_vector(log2_associativity_g + cpu_rd_adr'left downto log2(INSTR_WORD_COUNT));
        variable concat_next : std_ulogic_vector(log2_associativity_g + cpu_rd_adr'left downto log2(INSTR_WORD_COUNT));
    begin
        block_vec        := std_ulogic_vector(to_unsigned(cpu_access_block, log2_associativity_g));
        batch_word_index := to_integer(unsigned(cpu_rd_adr(log2(INSTR_WORD_COUNT) - 1 downto 0)));

        concat             := block_vec & cpu_rd_adr(cpu_rd_adr'left downto log2(INSTR_WORD_COUNT));
        concat_next        := block_vec & cpu_rd_adr(cpu_rd_adr'left downto log2(INSTR_WORD_COUNT)); -- block_next_vec ?!
        this_batch_address := unsigned(concat);
        next_batch_address := unsigned(concat_next) + 1;

        for i in 0 to (INSTR_WORD_COUNT - 1) loop
            -- if batch word address is > 0, fetch thos indizes from next batch (start this batch @0 (fetch from x)
            if (i >= batch_word_index) then
                -- this batch
                cpu_read_address(i) <= this_batch_address;
            else
                -- next 128-bit batch
                cpu_read_address(i) <= next_batch_address;
            end if;
        end loop;
    end process data_cpu_read_addresses;

    -- https://www.xilinx.com/support/answers/57959.html

    data_mem_read : process(cache_mem_en, cpu_ram_rdata, cpu_read_address)
    begin
        -- default
        cpu_ram_rd_en <= (others => '0');

        for i in 0 to (INSTR_WORD_COUNT - 1) loop
            cpu_data_read(i) <= cpu_ram_rdata(i); -- @suppress "Incorrect array size in assignment: expected (<32>) but was (<WORD_WIDTH>)"

            cpu_ram_rd_addr(i) <= std_ulogic_vector(cpu_read_address(i));
        end loop;

        --        if cache_mem_en = '1' and cache_mem_wen_ff = '0' and ((cpu_oe_i = '1') or (arb_state = S_RESYNC) or (arb_state = S_UPLOAD0) or (arb_state = S_UPLOAD1)) then
        if cache_mem_en = '1' then
            cpu_ram_rd_en <= (others => '1');
            --            if ((cpu_oe_i = '1') or (arb_state = S_RESYNC)) and cpu_mem_we = '0' then
            --                cpu_ram_rd_en <= (others => '1');
            --            end if;
        end if;
    end process data_mem_read;

    -- TODO: additional register (then, the data_distributor should not assume 1 cycle delay but two)
    data_mem_read_address_seq : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            cpu_batch_word_index_ff <= (others => '0');
        elsif rising_edge(clk_i) then
            if (ce_i = '1' and cache_mem_en = '1') then -- enable
                if ((cpu_oe_i = '1') or (arb_state = S_RESYNC)) then
                    cpu_batch_word_index_ff <= std_ulogic_vector(unsigned(cpu_rd_adr(instr_word_count_log2_c - 1 downto 0)));
                end if;
            end if;
        end if;
    end process data_mem_read_address_seq;

    data_mem_reorder : process(cpu_batch_word_index_ff, cpu_data_read)
    begin
        -- cpu
        if INSTR_WORD_COUNT /= 8 then
            --            report "WARNING: data_mem_reorder logic not optimized for this INSTR_WORD_COUNT size" severity warning;
            for i in 0 to (INSTR_WORD_COUNT - 1) loop
                --                if (i + unsigned(cpu_batch_word_index_ff) < INSTR_WORD_COUNT) then
                --                    cpu_data(i) <= cpu_data_read(i + to_integer(unsigned(cpu_batch_word_index_ff)));
                --                else
                --                    cpu_data(i) <= cpu_data_read(i + to_integer(unsigned(cpu_batch_word_index_ff)) - INSTR_WORD_COUNT);
                --                end if;
                if (unsigned(cpu_batch_word_index_ff) < INSTR_WORD_COUNT - i) then
                    cpu_data(i) <= cpu_data_read(i + to_integer(unsigned(cpu_batch_word_index_ff)));
                else
                    cpu_data(i) <= cpu_data_read(to_integer(unsigned('0' & cpu_batch_word_index_ff) + i - INSTR_WORD_COUNT));
                end if;
            end loop;
            cpu_data(8 to cpu_data'right) <= (others => (others => ('-')));
        end if;

        if INSTR_WORD_COUNT = 8 then
            case cpu_batch_word_index_ff(2 downto 0) is
                when "111" =>
                    cpu_data(0 to 0) <= cpu_data_read(7 to 7);
                    cpu_data(1 to 7) <= cpu_data_read(0 to 6);
                when "110" =>
                    cpu_data(0 to 1) <= cpu_data_read(6 to 7);
                    cpu_data(2 to 7) <= cpu_data_read(0 to 5);
                when "101" =>
                    cpu_data(0 to 2) <= cpu_data_read(5 to 7);
                    cpu_data(3 to 7) <= cpu_data_read(0 to 4);
                when "100" =>
                    cpu_data(0 to 3) <= cpu_data_read(4 to 7);
                    cpu_data(4 to 7) <= cpu_data_read(0 to 3);
                when "011" =>
                    cpu_data(0 to 4) <= cpu_data_read(3 to 7);
                    cpu_data(5 to 7) <= cpu_data_read(0 to 2);
                when "010" =>
                    cpu_data(0 to 5) <= cpu_data_read(2 to 7);
                    cpu_data(6 to 7) <= cpu_data_read(0 to 1);
                when "001" =>
                    cpu_data(0 to 6) <= cpu_data_read(1 to 7);
                    cpu_data(7 to 7) <= cpu_data_read(0 to 0);
                when others =>
                    cpu_data <= cpu_data_read;
            end case;
        end if;
    end process data_mem_reorder;

    instr_o <= cpu_data(0);             -- @suppress "Incorrect array size in assignment: expected (<WORD_WIDTH>) but was (<32>)"

    cache_line_replacer_inst : dcache_line_replacer
        generic map(
            ASSOCIATIVITY_LOG2   => log2_associativity_g,
            ADDR_WIDTH           => ADDR_WIDTH,
            SET_ADDR_WIDTH       => LOG2_NUM_LINES,
            WORD_SEL_ADDR_WIDTH  => LOG2_LINE_SIZE,
            WORD_OFFS_ADDR_WIDTH => log2(MEMORY_WORD_WIDTH / 8)
        )
        port map(
            clk_i        => clk_i,
            areset_n_i   => reset_n,
            addr_i       => cpu_instr_adr_i,
            valid_i      => cache_line_replacer_valid,
            cache_line_o => cache_line_replacer_line
        );

    miss_use_block <= to_integer(unsigned(cache_line_replacer_line));

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            for I in 0 to INSTR_WORD_COUNT - 1 loop
                if (mem_ram_wr_en(I) = '1') then
                    ram(I)(to_integer(unsigned(mem_ram_wr_addr(I)))) <= mem_ram_wdata(I);
                end if;
                if (cpu_ram_rd_en(I) = '1') then
                    cpu_ram_rdata(I) <= ram(I)(to_integer(unsigned(cpu_ram_rd_addr(I))));
                end if;
            end loop;
        end if;
    end process;

    -- synthesis translate_off
    -- Trace Extraction ------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    process(clk_i)
        variable wr_line         : line;
        file wr_file             : text open write_mode is "vsim_icache_traces.txt";
        variable hit_or_miss_vec : std_ulogic_vector(0 downto 0);
    begin
        if rising_edge(clk_i) then
            hit_or_miss_vec(0) := cache_hit;
            if arb_state = S_IDLE then
                if (cpu_instr_req_i = '1') and (stall_i = '0') then
                    write(wr_line, "RD" & "," & time'image(now) & "," & to_string(cpu_instr_adr_i) & "," & to_string(hit_or_miss_vec));
                    writeline(wr_file, wr_line);
                end if;
            end if;
        end if;
    end process;
    -- synthesis translate_on
end i_cache_behav;
