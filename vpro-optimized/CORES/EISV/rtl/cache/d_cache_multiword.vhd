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

use std.textio.all;

entity d_cache_multiword is
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
        clk_i                  : in  std_ulogic; -- global clock line, rising-edge
        rst_i                  : in  std_ulogic; -- global reset line, high-active, sync
        ce_i                   : in  std_ulogic; -- global clock enable, high-active
        stall_i                : in  std_ulogic; -- freeze output if any stall
        clear_i                : in  std_ulogic; -- force reload of cache
        flush_i                : in  std_ulogic; -- force flush of cache
        -- CPU instruction interface --
        cpu_oe_i               : in  std_ulogic; -- "IR" update enable
        cpu_req_i              : in  std_ulogic;
        cpu_adr_i              : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
        cpu_rden_i             : in  std_ulogic; -- this is a valid read request -- read enable
        cpu_wren_i             : in  std_ulogic_vector(03 downto 0); -- write enable
        cpu_stall_o            : out std_ulogic; -- stall CPU (miss)
        cpu_data_i             : in  std_ulogic_vector(WORD_WIDTH - 1 downto 0); -- write-data word
        -- Quad word --
        data_o                 : out multi_cmd_t; -- multiple cmds starting at addr!
        dcache_prefetch_i      : in  std_ulogic;
        dcache_prefetch_addr_i : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        -- memory system interface --
        mem_base_adr_o         : out std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
        mem_dat_i              : in  std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
        mem_req_o              : out std_ulogic; -- request data from memory
        mem_wait_i             : in  std_ulogic; -- memory command buffer full
        mem_ren_o              : out std_ulogic; -- read enable
        mem_rdy_i              : in  std_ulogic; -- applied data is valid
        mem_dat_o              : out std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
        mem_wrdy_i             : in  std_ulogic; -- write fifo is ready
        mem_rw_o               : out std_ulogic; -- read/write a block from/to memory
        mem_wren_o             : out std_ulogic; -- FIFO write enable
        mem_wr_last_o          : out std_ulogic; -- last word of write-block
        mem_wr_done_i          : in  std_ulogic_vector(1 downto 0); -- '00' not done, '01' done, '10' data error, '11' req error
        mem_busy_o             : out std_ulogic; -- busy signal forces MUX (DCache/DMA -> AXI) to choose DCache
        -- access statistics --
        hit_o                  : out std_ulogic; -- valid hit access
        miss_o                 : out std_ulogic -- valid miss access
    );
end d_cache_multiword;

architecture d_cache_multiword_behav of d_cache_multiword is
    -- helper function for trace extraction --
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

    -- dirty flag --
    signal dirty_flag, dirty_flag_nxt : arb_flag_t;

    -- valid flag --
    signal valid_flag, valid_flag_nxt : arb_flag_t;

    -- tag memory access --
    signal tag_mem_we                                : std_ulogic; -- write enable for tag memory
    signal tag_wr_data, tag_wr_data_nxt, tag_rd_data : std_ulogic_vector(tag_width_c - 1 downto 0); -- tag of a data line
    signal tag_wr_adr, tag_wr_adr_nxt                : std_ulogic_vector(LOG2_NUM_LINES - 1 downto 0); -- address of a tag ~ line address
    signal tag_rd_adr                                : std_ulogic_vector(LOG2_NUM_LINES - 1 downto 0); -- address of a tag ~ line address

    -- cache data memory access --
    signal data_mem_we  : std_ulogic;   -- write enable for data memory
    signal cpu_mem_we   : std_ulogic;
    signal mem_wr_adr   : std_ulogic_vector(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto 0); -- inside 128-bit word, addresses 32-bit block
    signal cpu_rd_adr   : std_ulogic_vector(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto 0); -- inside 128-bit word, addresses 32-bit block
    signal mem_rd_adr   : std_ulogic_vector(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto 0); -- inside 128-bit word, addresses 32-bit block
    signal cache_mem_en : std_ulogic;

    -- arbiter --
    type arb_state_t is (S_IDLE, S_RD_MISS, S_WR_MISS, S_WR_MISS2, S_WR_MISS3, S_DOWNLOAD_REQ, S_DOWNLOAD, S_RESYNC, S_FLUSH0, S_FLUSH1, S_FLUSH_DELAY, S_UPLOAD_REQ, S_UPLOAD0, S_UPLOAD1, S_UPLOAD_WAIT_DONE, S_DOWNLOAD_PREFETCH);

    signal arb_state, arb_state_nxt : arb_state_t;
    signal base_adr, base_adr_nxt   : std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- cpu address
    signal cache_pnt, cache_pnt_nxt : std_ulogic_vector(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0); -- for fetch of external data 128-bit, address inside cache for that data
    signal cpu_stall, cpu_stall_nxt : std_ulogic;

    signal mem_wren_nxt, mem_wren       : std_ulogic;
    signal mem_wr_last_nxt, mem_wr_last : std_ulogic;

    signal cache_cnt, cache_cnt_nxt : std_ulogic_vector(LOG2_LINE_SIZE downto 0);
    signal mem_base_adr_ff          : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
    signal mem_base_adr_o_nxt       : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);

    -- others --
    signal cache_hit : std_ulogic;

    -- address of flag/line (e.g. in tag mem)
    -- line inside cache
    signal cpu_adr_buff_line : unsigned(LOG2_NUM_LINES - 1 downto 0);
    signal cpu_adr_i_line    : std_ulogic_vector(LOG2_NUM_LINES - 1 downto 0);
    -- address of that line in cache mem (128-bit)
    -- 32-bit word inside line
    signal cpu_adr_buff_word : std_ulogic_vector(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 downto 0);
    signal cpu_adr_i_word    : std_ulogic_vector(LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto 0);
    -- tag of that line
    signal cpu_adr_i_tag     : std_ulogic_vector(tag_width_c - 1 downto 0);
    signal cpu_adr_buff_tag  : std_ulogic_vector(tag_width_c - 1 downto 0);

    type read_address_t is array (0 to (INSTR_WORD_COUNT - 1)) of unsigned(single_ram_addr_width_c - 1 downto 0);
    signal cpu_data, cpu_data_read : multi_cmd_t;
    signal cpu_read_address        : read_address_t;
    signal cpu_batch_word_index_ff : std_ulogic_vector(instr_word_count_log2_c - 1 downto 0);
    signal mem_data, mem_data_read : multi_cmd_t;
    signal mem_read_address        : read_address_t;
    signal mem_batch_word_index_ff : std_ulogic_vector(instr_word_count_log2_c - 1 downto 0);

    -- FLUSH
    signal pending_flush, pending_flush_nxt : std_ulogic;

    -- CLEAR
    signal pending_clear, pending_clear_nxt : std_ulogic;

    -- PREFETCH
    signal pending_prefetch, pending_prefetch_nxt           : std_ulogic;
    signal pending_prefetch_addr, pending_prefetch_addr_nxt : std_ulogic_vector(dcache_prefetch_addr_i'range);

    -- PENDING CPU REQ
    signal pending_cpu_req, pending_cpu_req_nxt : std_ulogic;

    -- UPLOAD
    signal upload_cache_pnt, upload_cache_pnt_nxt   : unsigned(LOG2_LINE_SIZE - 1 downto 0);
    signal upload_cache_line_nxt, upload_cache_line : unsigned(LOG2_NUM_LINES - 1 downto 0);
    signal arb_state_ret, arb_state_ret_nxt         : arb_state_t;

    -- WRITE
    -- buffer data to write to cache if download first
    signal wr_en_buffer_nxt, wr_en_buffer         : std_ulogic_vector(03 downto 0);
    signal wr_data_buffer_nxt, wr_data_buffer     : std_ulogic_vector(WORD_WIDTH - 1 downto 0);
    signal wr_data_mux                            : std_ulogic_vector(WORD_WIDTH - 1 downto 0);
    signal wr_wen_mux                             : std_ulogic_vector(03 downto 0);
    signal wr_addr_mux                            : std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
    signal mem_dat_o_buffer_nxt, mem_dat_o_buffer : std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
    signal mem_wrdy_nxt, mem_wrdy_ff              : std_ulogic;
    signal cache_mem_en_ff, cache_mem_en_nxt      : std_ulogic;

    -- used block upon miss + ff
    signal miss_use_block                         : integer range 0 to 2 ** log2_associativity_g - 1;
    signal mem_access_block_nxt, mem_access_block : integer range 0 to 2 ** log2_associativity_g - 1;

    -- from cpu signal, use this block (based on cache hit)
    signal cache_access_block     : integer range 0 to 2 ** log2_associativity_g - 1;
    signal cpu_access_block       : integer range 0 to 2 ** log2_associativity_g - 1;
    signal cpu_cache_access_block : integer range 0 to 2 ** log2_associativity_g - 1;

    signal flush_stall_cnt, flush_stall_cnt_nxt : integer range 0 to 2 * 2 ** LOG2_LINE_SIZE - 1;

    type enable_wr_t is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(WORD_WIDTH / 8 - 1 downto 0);
    signal mem_enable_wr_ff, mem_enable_wr_nxt : enable_wr_t;
    type addr_wr_t is array (0 to INSTR_WORD_COUNT - 1) of unsigned(log2_associativity_g + LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0);
    signal mem_addr_wr_ff, mem_addr_wr_nxt     : addr_wr_t;
    type data_wr_t is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(WORD_WIDTH - 1 downto 0);
    signal mem_data_wr_ff, mem_data_wr_nxt     : data_wr_t;

    -- RAM signals
    type ram_data_type is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(cpu_data_i'length - 1 downto 0);
    type ram_addr_type is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(single_ram_addr_width_c - 1 downto 0);
    type ram_wren_type is array (0 to INSTR_WORD_COUNT - 1) of std_ulogic_vector(cpu_data_i'length / 8 - 1 downto 0);

    signal cpu_ram_rd_en      : std_ulogic_vector(INSTR_WORD_COUNT - 1 downto 0);
    signal cpu_ram_rdata      : ram_data_type;
    signal cpu_ram_rd_addr    : ram_addr_type;
    signal mem_ram_wr_en      : ram_wren_type;
    signal mem_ram_rd_en      : std_ulogic_vector(INSTR_WORD_COUNT - 1 downto 0);
    signal mem_ram_wdata      : ram_data_type;
    signal mem_ram_rdata      : ram_data_type;
    signal mem_ram_rd_addr    : ram_addr_type;
    signal mem_ram_wr_addr    : ram_addr_type;

    signal reset_n : std_ulogic;

    signal cache_line_replacer_valid : std_ulogic;
    signal cache_line_replacer_line  : std_ulogic_vector(log2_associativity_g - 1 downto 0);

    signal prefetch_adr_buff_line : std_ulogic_vector(cpu_adr_buff_line'range);
    signal prefetch_adr_buff_word : std_ulogic_vector(cpu_adr_buff_word'range);
    signal prefetch_adr_buff_tag  : std_ulogic_vector(cpu_adr_buff_tag'range);

    signal addr_tag_compare : std_ulogic_vector(tag_width_c - 1 downto 0);

    type ram_single_type is array (2 ** single_ram_addr_width_c - 1 downto 0) of std_ulogic_vector(WORD_WIDTH - 1 downto 0); -- 2D Array Declaration for RAM signal
    type ram_array_type is array (INSTR_WORD_COUNT - 1 downto 0) of ram_single_type;

    signal ram : ram_array_type;
begin
    reset_n <= not rst_i;

    -- Assignments -----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    -- CPU address --
    -- structure: ||-TAG-|-LINE-|-WORD-||  {cpu addr}
    --                      2     2^7 + 2 (32-bit)
    cpu_adr_i_word <= cpu_adr_i(LOG2_LINE_SIZE - 1 + log2(MEMORY_WORD_WIDTH / 8) downto log2(WORD_WIDTH / 8)); -- 32-bit word select in line with 128-bit words
    cpu_adr_i_line <= cpu_adr_i(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)); -- line select
    cpu_adr_i_tag  <= cpu_adr_i(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + LOG2_NUM_LINES + log2(MEMORY_WORD_WIDTH / 8)); -- line's tag

    cpu_adr_buff_line <= unsigned(base_adr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)));
    cpu_adr_buff_word <= base_adr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto log2(MEMORY_WORD_WIDTH / 8));
    cpu_adr_buff_tag  <= base_adr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + LOG2_NUM_LINES + log2(MEMORY_WORD_WIDTH / 8)); -- line's tag

    prefetch_adr_buff_line <= pending_prefetch_addr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8));
    prefetch_adr_buff_word <= pending_prefetch_addr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto log2(MEMORY_WORD_WIDTH / 8));
    prefetch_adr_buff_tag  <= pending_prefetch_addr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + LOG2_NUM_LINES + log2(MEMORY_WORD_WIDTH / 8)); -- line's tag

    -- Cache access --
    wraddr_process : process(cache_pnt)
    begin
        mem_wr_adr                                                                                                                                                         <= (others => '0');
        mem_wr_adr(LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 + (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8)) downto (log2(MEMORY_WORD_WIDTH / 8) - log2(WORD_WIDTH / 8))) <= cache_pnt;
    end process;

    -- access statistics --
    hit_o  <= '1' when ((cpu_rden_i = '1') or (cpu_wren_i /= "0000")) and (cache_hit = '1') else '0';
    miss_o <= '1' when ((cpu_rden_i = '1') or (cpu_wren_i /= "0000")) and (cache_hit = '0') else '0';

    mem_base_adr_o <= mem_base_adr_ff;

    -- Control arbiter (sync) ------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    arbiter_sync : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            -- arbiter --
            arb_state             <= S_IDLE;
            arb_state_ret         <= S_IDLE;
            pending_flush         <= '0';
            pending_clear         <= '0';
            cpu_stall             <= '0';
            mem_wren              <= '0';
            mem_wrdy_ff           <= '0';
            mem_wr_last           <= '0';
            mem_base_adr_ff       <= (others => '0');
            mem_dat_o_buffer      <= (others => '0');
            base_adr              <= (others => '0');
            cache_pnt             <= (others => '0');
            cache_cnt             <= (others => '0');
            cache_mem_en_ff       <= '0';
            upload_cache_pnt      <= (others => '0');
            upload_cache_line     <= (others => '0');
            tag_wr_adr            <= (others => '0');
            tag_wr_data           <= (others => '0');
            wr_data_buffer        <= (others => '0');
            wr_en_buffer          <= (others => '0');
            valid_flag            <= (others => (others => '0')); -- all lines are invalid after reset
            dirty_flag            <= (others => (others => '0'));
            mem_access_block      <= 0;
            flush_stall_cnt       <= 0;
            pending_prefetch      <= '0';
            pending_prefetch_addr <= (others => '-');
            pending_cpu_req       <= '0';
        elsif rising_edge(clk_i) then
            if (ce_i = '1') then
                -- arbiter --
                arb_state       <= arb_state_nxt;
                valid_flag      <= valid_flag_nxt;
                base_adr        <= base_adr_nxt;
                cache_pnt       <= cache_pnt_nxt;
                cpu_stall       <= cpu_stall_nxt;
                mem_wren        <= mem_wren_nxt;
                mem_wr_last     <= mem_wr_last_nxt;
                cache_cnt       <= cache_cnt_nxt;
                mem_base_adr_ff <= mem_base_adr_o_nxt;
                tag_wr_adr      <= tag_wr_adr_nxt;
                tag_wr_data     <= tag_wr_data_nxt;

                arb_state_ret     <= arb_state_ret_nxt;
                pending_flush     <= pending_flush_nxt;
                pending_clear     <= pending_clear_nxt;
                upload_cache_pnt  <= upload_cache_pnt_nxt;
                upload_cache_line <= upload_cache_line_nxt;

                dirty_flag <= dirty_flag_nxt;

                wr_data_buffer <= wr_data_buffer_nxt;
                wr_en_buffer   <= wr_en_buffer_nxt;

                cache_mem_en_ff <= cache_mem_en_nxt;

                mem_dat_o_buffer <= mem_dat_o_buffer_nxt;
                mem_wrdy_ff      <= mem_wrdy_nxt;
                mem_access_block <= mem_access_block_nxt;
                flush_stall_cnt  <= flush_stall_cnt_nxt;

                pending_prefetch      <= pending_prefetch_nxt;
                pending_prefetch_addr <= pending_prefetch_addr_nxt;

                pending_cpu_req <= pending_cpu_req_nxt;
            end if;
        end if;
    end process arbiter_sync;

    -- CPU STALL --
    cpu_stall_o <= cpu_stall;

    -- Control arbiter (comb) ------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    arbiter_comb : process(arb_state, valid_flag, base_adr, cpu_adr_buff_line, cpu_adr_buff_word, mem_access_block, miss_use_block, cache_hit, cache_pnt, cpu_stall, stall_i, cache_cnt, cpu_adr_i_line, cpu_adr_i_word, cpu_adr_i, cpu_rden_i, mem_rdy_i, mem_wait_i, clear_i, tag_wr_adr, tag_wr_data, cpu_adr_i_tag, arb_state_ret, mem_wrdy_i, pending_flush, tag_rd_data, upload_cache_line, upload_cache_pnt, flush_i, cpu_wren_i, pending_clear, dirty_flag, cpu_req_i, cpu_data_i, wr_data_buffer, wr_en_buffer, cache_mem_en_ff, cache_access_block, flush_stall_cnt, mem_wr_done_i, dcache_prefetch_addr_i, dcache_prefetch_i, pending_prefetch, pending_prefetch_addr, prefetch_adr_buff_line, prefetch_adr_buff_tag, prefetch_adr_buff_word, pending_cpu_req, cpu_adr_buff_tag, mem_base_adr_ff, cpu_cache_access_block, mem_dat_o_buffer, mem_data, mem_wr_last, mem_wrdy_ff, mem_wren)
        -- cpu_adr_i_next_tag, access_to_last_words_no_multiword_possible, cache_next_hit, cpu_adr_i_next_line
    begin
        flush_stall_cnt_nxt <= flush_stall_cnt;
        -- arbiter defaults --
        arb_state_nxt       <= arb_state;
        base_adr_nxt        <= base_adr;
        valid_flag_nxt      <= valid_flag;
        cache_pnt_nxt       <= cache_pnt;
        cache_cnt_nxt       <= cache_cnt;

        arb_state_ret_nxt     <= arb_state_ret;
        pending_flush_nxt     <= (pending_flush or flush_i) and cpu_req_i;
        upload_cache_pnt_nxt  <= upload_cache_pnt;
        upload_cache_line_nxt <= upload_cache_line;

        dirty_flag_nxt    <= dirty_flag;
        pending_clear_nxt <= (pending_clear or clear_i) and cpu_req_i;

        pending_prefetch_nxt      <= pending_prefetch or dcache_prefetch_i;
        pending_prefetch_addr_nxt <= pending_prefetch_addr;
        if dcache_prefetch_i = '1' and pending_prefetch = '0' then
            pending_prefetch_addr_nxt <= dcache_prefetch_addr_i;
        end if;

        wr_data_buffer_nxt <= wr_data_buffer;
        wr_en_buffer_nxt   <= wr_en_buffer;

        -- tag mem defaults --
        tag_mem_we <= '0';

        cpu_rd_adr <= cpu_adr_i_line & cpu_adr_i_word; --to compensate 128 instead 32 bit

        mem_rd_adr                                                                                                           <= (others => '0');
        mem_rd_adr(mem_rd_adr'left downto mem_rd_adr'left - (LOG2_NUM_LINES - 1))                                            <= std_ulogic_vector(upload_cache_line);
        mem_rd_adr(mem_rd_adr'left - LOG2_NUM_LINES downto mem_rd_adr'left - LOG2_NUM_LINES - (upload_cache_pnt'length - 1)) <= std_ulogic_vector(upload_cache_pnt);

        -- ext mem defaults --
        -- buffer request (wren/data_o) if wrdy is set to 0
        mem_dat_o_buffer_nxt <= mem_dat_o_buffer;
        if (mem_wrdy_ff = '1' and mem_wrdy_i = '0') then -- this is begin of a "stall"
            for i in 0 to MEMORY_WORD_WIDTH / WORD_WIDTH - 1 loop
                mem_dat_o_buffer_nxt(i * WORD_WIDTH + 31 downto i * WORD_WIDTH) <= mem_data(MEMORY_WORD_WIDTH / WORD_WIDTH - 1 - i);
            end loop;
        end if;

        mem_wrdy_nxt <= mem_wrdy_i;

        mem_dat_o <= mem_dat_o_buffer;
        if (mem_wrdy_ff = '1') then
            for i in 0 to MEMORY_WORD_WIDTH / WORD_WIDTH - 1 loop
                mem_dat_o(i * WORD_WIDTH + 31 downto i * WORD_WIDTH) <= mem_data(MEMORY_WORD_WIDTH / WORD_WIDTH - 1 - i);
            end loop;
        end if;

        mem_ren_o  <= '0';
        mem_req_o  <= '0';
        mem_rw_o   <= '0';
        mem_busy_o <= '0';

        mem_wren_nxt    <= '0';
        mem_wr_last_nxt <= '0';
        mem_wren_o      <= mem_wren;
        mem_wr_last_o   <= mem_wr_last;
        if (mem_wrdy_i = '0') then
            mem_wren_o      <= '0';
            mem_wr_last_o   <= '0';
            mem_wren_nxt    <= mem_wren;
            mem_wr_last_nxt <= mem_wr_last;
        end if;

        cache_mem_en_nxt <= '0';

        -- cpu defaults --
        cpu_stall_nxt <= cpu_stall;
        cache_mem_en  <= cpu_req_i or cache_mem_en_ff;
        wr_data_mux   <= cpu_data_i;
        wr_wen_mux    <= cpu_wren_i;
        wr_addr_mux   <= cpu_adr_i;

        -- data mem defaults --
        data_mem_we <= '0';
        cpu_mem_we  <= '0';
        if (cpu_req_i = '1') and (cpu_wren_i /= "0000") and (stall_i = '0') and cache_hit = '1' then
            cpu_mem_we <= '1';
        end if;

        -- Addr output to external memory --
        mem_base_adr_o_nxt <= mem_base_adr_ff;

        tag_wr_adr_nxt  <= tag_wr_adr;
        tag_wr_data_nxt <= tag_wr_data;

        tag_rd_adr <= cpu_adr_i_line;

        addr_tag_compare <= cpu_adr_buff_tag;
        if cpu_req_i = '1' and cpu_stall = '0' then
            addr_tag_compare <= cpu_adr_i_tag;
        end if;

        mem_access_block_nxt <= mem_access_block;
        cpu_access_block     <= cpu_cache_access_block;

        pending_cpu_req_nxt <= pending_cpu_req;
        if cpu_req_i = '1' and cache_hit = '0' and pending_prefetch = '1' then
            wr_data_buffer_nxt  <= cpu_data_i;
            wr_en_buffer_nxt    <= cpu_wren_i;
            pending_cpu_req_nxt <= '1';
            base_adr_nxt        <= cpu_adr_i;
            cpu_stall_nxt       <= '1';
        end if;

        cache_line_replacer_valid <= '0';

        -- state machine --
        case (arb_state) is

            when S_IDLE =>              -- normal access
                -------------------------------------------------------
                mem_access_block_nxt                  <= cache_access_block;
                base_adr_nxt(ADDR_WIDTH - 1 downto 0) <= cpu_adr_i(ADDR_WIDTH - 1 downto 0);
                arb_state_ret_nxt                     <= S_IDLE;
                cache_cnt_nxt                         <= std_ulogic_vector(to_unsigned(2 ** (LOG2_LINE_SIZE), LOG2_LINE_SIZE + 1));
                cpu_stall_nxt                         <= '0'; -- stall cpu

                if (pending_cpu_req = '1') then
                    if stall_i = '0' then
                        pending_cpu_req_nxt <= '0';
                        base_adr_nxt        <= base_adr;
                        cpu_stall_nxt       <= '1';

                        tag_wr_adr_nxt  <= std_ulogic_vector(cpu_adr_buff_line);
                        tag_wr_data_nxt <= cpu_adr_buff_tag;

                        cache_line_replacer_valid <= '1';
                        mem_access_block_nxt      <= miss_use_block; -- store used block

                        if unsigned(wr_en_buffer) = 0 then
                            -- valid read access and (regular) MISS
                            arb_state_nxt <= S_RD_MISS;
                        else
                            arb_state_nxt <= S_WR_MISS;
                        end if;
                    end if;
                elsif (cpu_req_i = '1') and (cpu_rden_i = '1') and (stall_i = '0') then
                    if (cache_hit = '0') then
                        -- valid access and (regular) MISS
                        tag_wr_adr_nxt            <= cpu_adr_i_line;
                        tag_wr_data_nxt           <= cpu_adr_i_tag;
                        cache_line_replacer_valid <= '1';
                        mem_access_block_nxt      <= miss_use_block; -- store used block
                        arb_state_nxt             <= S_RD_MISS;
                        cpu_stall_nxt             <= '1'; -- freeze CPU
                    end if;

                elsif (cpu_req_i = '1') and (cpu_wren_i /= "0000") and (stall_i = '0') then -- valid write access 
                    cache_mem_en <= '1'; -- enable cache access
                    if (cache_hit = '0') then -- MISS
                        wr_en_buffer_nxt          <= cpu_wren_i;
                        wr_data_buffer_nxt        <= cpu_data_i;
                        tag_wr_adr_nxt            <= cpu_adr_i_line;
                        tag_wr_data_nxt           <= cpu_adr_i_tag;
                        cache_line_replacer_valid <= '1';
                        mem_access_block_nxt      <= miss_use_block; -- store used block
                        arb_state_nxt             <= S_WR_MISS;
                        cpu_stall_nxt             <= '1'; -- stall cpu
                    else                -- valid write
                        dirty_flag_nxt(cache_access_block)(to_integer(unsigned(cpu_adr_i_line))) <= '1';
                        cpu_mem_we                                                               <= '1'; -- allow write access       
                    end if;
                elsif (pending_flush = '1') then -- sync mem with cache
                    upload_cache_line_nxt <= (others => '0');
                    mem_access_block_nxt  <= 0;
                    arb_state_nxt         <= S_FLUSH0;
                    cpu_stall_nxt         <= '1'; -- stall cpu
                elsif (pending_clear = '1') then -- clear cache; invalidate all cache lines                    
                    dirty_flag_nxt    <= (others => (others => '0'));
                    valid_flag_nxt    <= (others => (others => '0'));
                    pending_clear_nxt <= '0';
                elsif (pending_prefetch = '1') then
                    tag_rd_adr       <= prefetch_adr_buff_line;
                    addr_tag_compare <= prefetch_adr_buff_tag;
                    if cache_hit = '0' then
                        -- miss
                        tag_wr_adr_nxt            <= prefetch_adr_buff_line;
                        tag_wr_data_nxt           <= prefetch_adr_buff_tag;
                        base_adr_nxt              <= pending_prefetch_addr;
                        cache_line_replacer_valid <= '1';
                        mem_access_block_nxt      <= miss_use_block; -- store used block
                        arb_state_nxt             <= S_DOWNLOAD_PREFETCH;
                    else
                        -- hit: do nothing
                        pending_prefetch_nxt <= '0';
                    end if;
                end if;

            when S_RD_MISS =>           -- that was a miss - prepare update
                -------------------------------------------------------
                tag_rd_adr <= std_ulogic_vector(cpu_adr_buff_line); -- tag data returns async!
                if (dirty_flag(mem_access_block)(to_integer(cpu_adr_buff_line)) = '1') then
                    -- Upload previous dirty data
                    upload_cache_line_nxt                                                                  <= cpu_adr_buff_line;
                    upload_cache_pnt_nxt                                                                   <= (others => '0');
                    mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= tag_rd_data & std_ulogic_vector(cpu_adr_buff_line);
                    mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');
                    arb_state_nxt                                                                          <= S_UPLOAD_REQ; -- upload line
                    arb_state_ret_nxt                                                                      <= S_RD_MISS;
                else
                    cache_pnt_nxt                                                                          <= cpu_adr_buff_word; -- set cache pointer
                    cache_pnt_nxt(LOG2_LINE_SIZE - 1 downto 0)                                             <= (others => '0');
                    tag_mem_we                                                                             <= '1'; -- set new tag   
                    mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= base_adr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8));
                    mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');
                    arb_state_nxt                                                                          <= S_DOWNLOAD_REQ;
                    arb_state_ret_nxt                                                                      <= S_IDLE;
                end if;

            when S_WR_MISS =>           -- write miss: check destination block
                -------------------------------------------------------
                -- WRITE ALLOCATE:
                -- if destination is dirty -> WRITE BACK to mm (this will be another tag when loaded)
                -- get requested line from mem (set valid flag)
                -- perform initial write access (set dirty flag)
                --                arb_state_nxt <= S_WR_MISS; -- always come back here...
                tag_rd_adr <= std_ulogic_vector(cpu_adr_buff_line); -- tag data returns async!
                if (dirty_flag(mem_access_block)(to_integer(cpu_adr_buff_line)) = '1') then
                    -- Upload previous dirty data
                    upload_cache_line_nxt                                                                  <= cpu_adr_buff_line;
                    upload_cache_pnt_nxt                                                                   <= (others => '0');
                    mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= tag_rd_data & std_ulogic_vector(cpu_adr_buff_line);
                    mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');
                    arb_state_nxt                                                                          <= S_UPLOAD_REQ; -- upload line
                    arb_state_ret_nxt                                                                      <= S_WR_MISS2;
                    -- invalidate it, so it will be downloaded when upload returns
                    valid_flag_nxt(mem_access_block)(to_integer(cpu_adr_buff_line))                        <= '0';
                else
                    arb_state_nxt <= S_WR_MISS2;
                end if;

            when S_WR_MISS2 =>
                -------------------------------------------------------
                -- no cache hit [not based on current cpu_adr_i but on buffered]
                -- Download data
                cache_pnt_nxt                                                                          <= cpu_adr_buff_word; -- set cache pointer
                cache_pnt_nxt(LOG2_LINE_SIZE - 1 downto 0)                                             <= (others => '0');
                cache_cnt_nxt                                                                          <= std_ulogic_vector(to_unsigned(2 ** (LOG2_LINE_SIZE), LOG2_LINE_SIZE + 1));
                mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= base_adr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8));
                mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');
                arb_state_nxt                                                                          <= S_DOWNLOAD_REQ;
                arb_state_ret_nxt                                                                      <= S_WR_MISS3;

            when S_WR_MISS3 =>
                -- write access and set dirty
                dirty_flag_nxt(mem_access_block)(to_integer(unsigned(cpu_adr_buff_line))) <= '1';
                cache_mem_en                                                              <= '1'; -- enable cache access
                cpu_mem_we                                                                <= '1'; -- allow write access  
                wr_addr_mux                                                               <= base_adr;
                wr_data_mux                                                               <= wr_data_buffer;
                wr_wen_mux                                                                <= wr_en_buffer;
                --                cpu_access_block <= mem_access_block;
                --                    mem_rd_adr                                                            <= base_adr(LOG2_LINE_SIZE + LOG2_NUM_LINES - 1 + log2(MEMORY_WORD_WIDTH / 8) downto log2(WORD_WIDTH / 8)); -- address backup for resync          
                cpu_stall_nxt                                                             <= '0'; -- resume cpu operation
                arb_state_nxt                                                             <= S_IDLE;
                arb_state_ret_nxt                                                         <= S_IDLE;

            when S_DOWNLOAD_REQ =>
                -------------------------------------------------------
                mem_busy_o <= '1';
                if (mem_wait_i = '0') then
                    mem_req_o     <= '1';
                    mem_rw_o      <= '0';
                    arb_state_nxt <= S_DOWNLOAD;
                    -- set valid flag --
                    tag_mem_we    <= '1';
                end if;

            when S_DOWNLOAD =>          -- loop for updating cache line
                -------------------------------------------------------
                mem_busy_o   <= '1';
                cache_mem_en <= '1';    -- enable cache access
                data_mem_we  <= '1';    -- allow write access
                if mem_rdy_i = '1' and not ((cpu_req_i = '1') and (cpu_wren_i /= "0000") and (stall_i = '0') and cache_hit = '1') then -- data valid?
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

                if (arb_state_ret = S_IDLE) and pending_cpu_req = '0' then
                    cpu_stall_nxt <= '0'; -- resume cpu operation
                end if;
                arb_state_nxt <= arb_state_ret;

                if prefetch_adr_buff_tag = cpu_adr_buff_tag and prefetch_adr_buff_line = std_ulogic_vector(cpu_adr_buff_line) then
                    pending_cpu_req_nxt <= '0';
                    if arb_state_ret = S_IDLE then
                        cpu_stall_nxt <= '0'; -- resume cpu operation
                    end if;
                end if;

                valid_flag_nxt(mem_access_block)(to_integer(unsigned(tag_wr_adr))) <= '1'; -- set valid flag

                pending_prefetch_nxt <= '0';

            when S_FLUSH0 =>            -- check tag
                -------------------------------------------------------------------------
                mem_busy_o           <= '1';
                arb_state_nxt        <= S_FLUSH0;
                mem_access_block_nxt <= mem_access_block;

                if valid_flag(mem_access_block)(to_integer(upload_cache_line)) = '1' and dirty_flag(mem_access_block)(to_integer(upload_cache_line)) = '1' then
                    -- upload this dirty (valid) line
                    arb_state_nxt        <= S_FLUSH1;
                    upload_cache_pnt_nxt <= (others => '0');
                else
                    if (resize(upload_cache_line, upload_cache_line'length + 1) = 2 ** LOG2_NUM_LINES - 1) then -- last line done
                        if (mem_access_block = 2 ** log2_associativity_g - 1) then -- last block done
                            arb_state_nxt     <= S_IDLE;
                            arb_state_ret_nxt <= S_IDLE;
                            cpu_stall_nxt     <= '0'; -- resume cpu operation
                            pending_flush_nxt <= '0';
                        else
                            -- continue with next block
                            mem_access_block_nxt  <= mem_access_block + 1;
                            upload_cache_line_nxt <= (others => '0');
                        end if;
                    else                -- continue with next line
                        upload_cache_line_nxt <= upload_cache_line + 1;
                    end if;
                end if;

            when S_FLUSH1 =>            -- write all dirty lines back to memory
                -------------------------------------------------------------------------
                mem_busy_o                                                                             <= '1';
                arb_state_nxt                                                                          <= S_FLUSH1; -- always come back here...
                tag_rd_adr                                                                             <= std_ulogic_vector(upload_cache_line); -- tag data returns async!
                mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= tag_rd_data & std_ulogic_vector(upload_cache_line);
                mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');

                if (upload_cache_pnt = 2 ** LOG2_LINE_SIZE - 1) then -- line completed, last word in line
                    arb_state_nxt <= S_FLUSH0;
                else
                    arb_state_nxt       <= S_UPLOAD_REQ; -- upload modified line
                    arb_state_ret_nxt   <= S_FLUSH_DELAY; -- instead to S_FLUSH1, wait for counter... 2*line_size
                    flush_stall_cnt_nxt <= 2 * 2 ** LOG2_LINE_SIZE - 1;
                end if;

            when S_FLUSH_DELAY =>
                if (flush_stall_cnt /= 0) then
                    flush_stall_cnt_nxt <= flush_stall_cnt - 1;
                else
                    arb_state_nxt <= S_FLUSH1;
                end if;

            when S_UPLOAD_REQ =>
                -------------------------------------------------------
                mem_busy_o <= '1';
                if (mem_wait_i = '0') then
                    mem_req_o     <= '1';
                    mem_rw_o      <= '1';
                    arb_state_nxt <= S_UPLOAD0;
                    --                    cache_mem_en  <= '1'; -- enable cache access
                end if;

            when S_UPLOAD0 =>           -- upload a block to memory -- @suppress "Dead state 'S_UPLOAD': state does not have outgoing transitions"
                -------------------------------------------------------------------------    
                mem_busy_o    <= '1';
                arb_state_nxt <= S_UPLOAD0; -- always come back here...             
                -- data from cache 
                --  Line: upload_cache_line
                --  Element: upload_cache_pnt_nxt (iterating here)

                -- due to next cycle data output of cache mem, this will address first data already here
                cache_mem_en     <= '1'; -- enable cache access
                cache_mem_en_nxt <= '1'; -- enable cache access

                if (mem_wrdy_i = '1') and not (cpu_req_i = '1' and cache_hit = '1' and unsigned(cpu_wren_i) /= 0) then
                    upload_cache_pnt_nxt <= upload_cache_pnt + 1;
                    mem_wren_nxt         <= '1';

                    if (upload_cache_pnt = 2 ** LOG2_LINE_SIZE - 1) then
                        upload_cache_pnt_nxt                                            <= upload_cache_pnt;
                        mem_wr_last_nxt                                                 <= '1';
                        dirty_flag_nxt(mem_access_block)(to_integer(upload_cache_line)) <= '0';
                        arb_state_nxt                                                   <= S_UPLOAD1;
                    end if;
                end if;

            when S_UPLOAD1 =>           -- upload a block to memory -- @suppress "Dead state 'S_UPLOAD': state does not have outgoing transitions"
                -------------------------------------------------------
                -- last write out
                -- data is requested, wr_nxt/mem_wr_last_nxt/... was set
                mem_busy_o <= '1';
                if (mem_wrdy_i = '1') then
                    if mem_wr_done_i = "01" then
                        arb_state_nxt <= arb_state_ret;
                    else
                        arb_state_nxt <= S_UPLOAD_WAIT_DONE;
                    end if;
                end if;

            when S_UPLOAD_WAIT_DONE =>
                mem_busy_o <= '1';
                case mem_wr_done_i is
                    when "01" =>
                        arb_state_nxt <= arb_state_ret;
                    when "10" =>
                        arb_state_nxt <= S_UPLOAD_REQ;
                    when "11" =>
                        arb_state_nxt <= S_UPLOAD_REQ;
                    when others =>
                end case;

            when S_DOWNLOAD_PREFETCH =>
                -------------------------------------------------------
                mem_busy_o <= '1';
                if cpu_req_i = '0' then
                    tag_rd_adr                                                                     <= std_ulogic_vector(prefetch_adr_buff_line); -- tag data returns async!
                    valid_flag_nxt(mem_access_block)(to_integer(unsigned(prefetch_adr_buff_line))) <= '0';

                    if (dirty_flag(mem_access_block)(to_integer(unsigned(prefetch_adr_buff_line))) = '1') then
                        -- Upload previous dirty data
                        upload_cache_line_nxt                                                                  <= unsigned(prefetch_adr_buff_line);
                        upload_cache_pnt_nxt                                                                   <= (others => '0');
                        mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= tag_rd_data & std_ulogic_vector(prefetch_adr_buff_line);
                        mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');
                        arb_state_nxt                                                                          <= S_UPLOAD_REQ; -- upload line
                        arb_state_ret_nxt                                                                      <= S_DOWNLOAD_PREFETCH;
                    else
                        cache_pnt_nxt                                                                          <= prefetch_adr_buff_word; -- set cache pointer
                        cache_pnt_nxt(LOG2_LINE_SIZE - 1 downto 0)                                             <= (others => '0');
                        tag_mem_we                                                                             <= '1'; -- set new tag      
                        mem_base_adr_o_nxt(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8)) <= pending_prefetch_addr(ADDR_WIDTH - 1 downto LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8));
                        mem_base_adr_o_nxt(LOG2_LINE_SIZE + log2(MEMORY_WORD_WIDTH / 8) - 1 downto 0)          <= (others => '0');
                        arb_state_nxt                                                                          <= S_DOWNLOAD_REQ;
                        arb_state_ret_nxt                                                                      <= S_IDLE;
                    end if;
                end if;
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

    cache_hit_miss : process(tag_rd_adr, valid_flag, tag_mem, mem_access_block, addr_tag_compare, cpu_adr_i_line, cpu_adr_i_tag)
    begin
        cache_hit          <= '0';
        cache_access_block <= 0;
        -- async read from tag mem --
        tag_rd_data        <= tag_mem(mem_access_block)(to_integer(unsigned(tag_rd_adr)));

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
            if (tag_mem(bl)(to_integer(unsigned(cpu_adr_i_line))) = cpu_adr_i_tag) then
                if (valid_flag(bl)(to_integer(unsigned(cpu_adr_i_line))) = '1') then
                    cpu_cache_access_block <= bl;
                end if;
            end if;
        end loop;
    end process;

    -- Cache data memory -----------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    data_mem_comb : process(cache_mem_en, data_mem_we, mem_wr_adr, mem_dat_i, stall_i, wr_addr_mux, wr_data_mux, wr_wen_mux, arb_state, mem_rdy_i, cpu_access_block, mem_access_block, cpu_mem_we)
        variable enable_v                  : std_ulogic_vector(WORD_WIDTH / 8 - 1 downto 0);
        variable data_v                    : std_ulogic_vector(WORD_WIDTH - 1 downto 0);
        variable addr_v                    : unsigned(log2_associativity_g + LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0);
        variable data_i_endianess_switched : std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
        variable mem_block_vec             : std_ulogic_vector(log2_associativity_g - 1 downto 0);
        variable cpu_block_vec             : std_ulogic_vector(log2_associativity_g - 1 downto 0);

        variable concat : std_ulogic_vector(log2_associativity_g + LOG2_NUM_LINES + LOG2_LINE_SIZE - 1 downto 0);
    begin
        mem_enable_wr_nxt <= (others => (others => '0'));
        mem_addr_wr_nxt   <= (others => (others => '-'));
        mem_data_wr_nxt   <= (others => (others => '-'));

        if (cache_mem_en = '1') then    -- enable
            mem_block_vec := std_ulogic_vector(to_unsigned(mem_access_block, log2_associativity_g));
            cpu_block_vec := std_ulogic_vector(to_unsigned(cpu_access_block, log2_associativity_g));
            if arb_state = S_WR_MISS3 then
                cpu_block_vec := std_ulogic_vector(to_unsigned(mem_access_block, log2_associativity_g));
            end if;

            if stall_i = '0' and cpu_mem_we = '1' then
                -- cpu data write to memory

                data_v := wr_data_mux;

                -- cache address = associativity & ram_addr & ram_idx & word 

                concat := cpu_block_vec & wr_addr_mux(LOG2_NUM_LINES + LOG2_LINE_SIZE + log2(INSTR_WORD_COUNT) + log2(WORD_WIDTH / 8) - 1 downto log2(INSTR_WORD_COUNT) + log2(WORD_WIDTH / 8));
                addr_v := unsigned(concat);

                for i in 0 to INSTR_WORD_COUNT - 1 loop -- all 8 memories
                    enable_v := (others => '0');
                    if (to_integer(unsigned(wr_addr_mux(log2(INSTR_WORD_COUNT) + log2(WORD_WIDTH / 8) - 1 downto log2(WORD_WIDTH / 8)))) = i) then
                        -- addressed subword (32 out of 128)   log2(16)=4 downto log2(4) = 2   1 of 8
                        enable_v := wr_wen_mux;
                    end if;
                    -- BUG??? downto log2(MEMORY_WORD_WIDTH/8)
                    -- cache pointer including line base in cache mem
                    
                    mem_enable_wr_nxt(i) <= enable_v;
                    mem_addr_wr_nxt(i)   <= addr_v;
                    mem_data_wr_nxt(i)   <= data_v;
                end loop;
            elsif data_mem_we = '1' and arb_state = S_DOWNLOAD and mem_rdy_i = '1' then
                -- data from MM interface are written into memory

                concat := mem_block_vec & mem_wr_adr(mem_wr_adr'left downto log2(INSTR_WORD_COUNT));
                addr_v := unsigned(concat);

                enable_v                  := (others => '0');
                data_i_endianess_switched := convert_wordorder(mem_dat_i);

                if INSTR_WORD_COUNT = 16 and MEMORY_WORD_WIDTH = 512 then
                    mem_enable_wr_nxt <= (others => (others => '1'));
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
                        mem_enable_wr_nxt(i) <= enable_v;
                        mem_data_wr_nxt(i)   <= data_v;
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
                mem_enable_wr_ff <= (others => (others => '0'));
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

    -- cache output --
    data_mem_read_addresses : process(mem_rd_adr, mem_access_block)
        -- INSTR_WORD_COUNT cache element base address
        variable this_batch_address : unsigned(single_ram_addr_width_c - 1 downto 0);
        -- INSTR_WORD_COUNT cache element base address of next 128-bit block
        variable next_batch_address : unsigned(single_ram_addr_width_c - 1 downto 0);
        variable batch_word_index   : integer;
        variable block_vec          : std_ulogic_vector(log2_associativity_g - 1 downto 0);

        variable concat : std_ulogic_vector(log2_associativity_g + mem_rd_adr'left downto log2(INSTR_WORD_COUNT));
    begin
        block_vec        := std_ulogic_vector(to_unsigned(mem_access_block, log2_associativity_g));
        batch_word_index := to_integer(unsigned(mem_rd_adr(log2(INSTR_WORD_COUNT) - 1 downto 0)));

        concat             := block_vec & mem_rd_adr(mem_rd_adr'left downto log2(INSTR_WORD_COUNT));
        this_batch_address := unsigned(concat);
        next_batch_address := unsigned(concat) + 1;

        for i in 0 to (INSTR_WORD_COUNT - 1) loop
            -- if batch word address is > 0, fetch thos indizes from next batch (start this batch @0 (fetch from x)
            if (i >= batch_word_index) then
                -- this batch
                mem_read_address(i) <= this_batch_address;
            else
                -- next 128-bit batch
                mem_read_address(i) <= next_batch_address;
            end if;

            if INSTR_WORD_COUNT = 16 and MEMORY_WORD_WIDTH = 512 then
                mem_read_address(i) <= this_batch_address; -- all RAM modules get the same addr
            end if;
        end loop;

    end process data_mem_read_addresses;

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

    data_mem_read : process(arb_state, cache_mem_en, cpu_ram_rdata, mem_ram_rdata, cpu_read_address, mem_read_address, data_mem_we)
    begin
        -- default
        cpu_ram_rd_en <= (others => '0');
        mem_ram_rd_en <= (others => '0');

        for i in 0 to (INSTR_WORD_COUNT - 1) loop
            cpu_data_read(i) <= cpu_ram_rdata(i); -- @suppress "Incorrect array size in assignment: expected (<32>) but was (<WORD_WIDTH>)"
            mem_data_read(i) <= mem_ram_rdata(i); -- @suppress "Incorrect array size in assignment: expected (<32>) but was (<WORD_WIDTH>)"

            cpu_ram_rd_addr(i) <= std_ulogic_vector(cpu_read_address(i));
            mem_ram_rd_addr(i) <= std_ulogic_vector(mem_read_address(i));
        end loop;

        if cache_mem_en = '1' then
            cpu_ram_rd_en <= (others => '1');
            if arb_state = S_UPLOAD0 and data_mem_we = '0' then
                mem_ram_rd_en <= (others => '1');
            end if;
        end if;
    end process data_mem_read;

    -- TODO: additional register (then, the data_distributor should not assume 1 cycle delay but two)
    data_mem_read_address_seq : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            cpu_batch_word_index_ff <= (others => '0');
            mem_batch_word_index_ff <= (others => '0');
        elsif rising_edge(clk_i) then
            if (ce_i = '1' and cache_mem_en = '1') then -- enable
                if ((cpu_oe_i = '1') or (arb_state = S_RESYNC)) and cpu_mem_we = '0' then
                    cpu_batch_word_index_ff <= std_ulogic_vector(unsigned(cpu_rd_adr(instr_word_count_log2_c - 1 downto 0)));
                end if;
                --                if (arb_state = S_UPLOAD0) or (arb_state = S_UPLOAD1) then
                if data_mem_we = '0' then
                    mem_batch_word_index_ff <= std_ulogic_vector(unsigned(mem_rd_adr(instr_word_count_log2_c - 1 downto 0)));
                end if;
                --                end if;
            end if;
        end if;
    end process data_mem_read_address_seq;

    data_mem_reorder : process(cpu_batch_word_index_ff, cpu_data_read, mem_batch_word_index_ff, mem_data_read)
    begin
        -- cpu
        for i in 0 to (INSTR_WORD_COUNT - 1) loop
            if (unsigned(cpu_batch_word_index_ff) < INSTR_WORD_COUNT - i) then
                cpu_data(i) <= cpu_data_read(i + to_integer(unsigned(cpu_batch_word_index_ff)));
            else
                cpu_data(i) <= cpu_data_read(to_integer(unsigned('0' & cpu_batch_word_index_ff) + i - INSTR_WORD_COUNT));
            end if;
        end loop;
        cpu_data(8 to cpu_data'right) <= (others => (others => ('-')));

        -- mem
        for i in 0 to (INSTR_WORD_COUNT - 1) loop
            if (unsigned(mem_batch_word_index_ff) < INSTR_WORD_COUNT - i) then
                mem_data(i) <= mem_data_read(i + to_integer(unsigned(mem_batch_word_index_ff)));
            else
                mem_data(i) <= mem_data_read(to_integer(unsigned('0' & mem_batch_word_index_ff) + i - INSTR_WORD_COUNT));
            end if;
        end loop;

        if INSTR_WORD_COUNT = 16 and MEMORY_WORD_WIDTH = 512 then
            mem_data <= mem_data_read;
        end if;
    end process data_mem_reorder;

    cpu_data_output_reg : process(clk_i)
    begin
        if rising_edge(clk_i) then
            data_o <= cpu_data;
        end if;
    end process;

    -- TODO: other line replacer strategy possibilities (RANDOM, LIFO, others)
    -- -- Random generator ------------------------------------------------------------------------------------
    -- -- --------------------------------------------------------------------------------------------------------
    --    -- random generator --
    --    signal lfsr : std_ulogic_vector(9 downto 0);
    --
    -- random_gen : process(clk_i, rst_i)
    -- begin
    --     if (rst_i = '1') then
    --         lfsr <= (others => '0');
    --     elsif rising_edge(clk_i) then
    --         lfsr <= lfsr(8 downto 0) & (lfsr(9) xnor lfsr(6));
    --     end if;
    -- end process random_gen;

    -- random_use : process(lfsr)
    -- begin
    --     miss_use_block <= to_integer(unsigned(lfsr(log2_associativity_g - 1 downto 0)));
    --     -- avoid same in row
    --     --        if (miss_use_block = access_block) then
    --     --            miss_use_block <= to_integer(unsigned(not lfsr(log2_associativity_g - 1 downto 0)));
    --     --        end if;
    -- end process random_use;

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
            addr_i       => cpu_adr_i,
            valid_i      => cache_line_replacer_valid,
            cache_line_o => cache_line_replacer_line
        );

    miss_use_block <= to_integer(unsigned(cache_line_replacer_line));

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            for I in 0 to INSTR_WORD_COUNT - 1 loop
                -- cpu read
                if (cpu_ram_rd_en(I) = '1') then
                    cpu_ram_rdata(I) <= ram(I)(to_integer(unsigned(cpu_ram_rd_addr(I))));
                end if;
            end loop;
        end if;
    end process;

    process(clk_i)
    begin
        if rising_edge(clk_i) then
            for I in 0 to INSTR_WORD_COUNT - 1 loop
                -- cpu write and mem write
                if (mem_ram_rd_en(I) = '1') or (unsigned(mem_ram_wr_en(I)) /= 0) then
                    assert not (unsigned(mem_ram_wr_en(I)) /= 0 and mem_ram_rd_en(I) = '1') report "GLEICHZEITIG CPU WRITE AND MEM RD/WR" severity error;

                    mem_ram_rdata(I) <= ram(I)(to_integer(unsigned(mem_ram_rd_addr(I))));
                    for byte in 0 to WORD_WIDTH / 8 - 1 loop
                        if (mem_ram_wr_en(I)(byte) = '1') then
                            ram(I)(to_integer(unsigned(mem_ram_wr_addr(I))))((byte + 1) * 8 - 1 downto byte * 8) <= mem_ram_wdata(I)((byte + 1) * 8 - 1 downto byte * 8);
                        end if;
                    end loop;
                end if;
            end loop;
        end if;
    end process;

    -- Trace Extraction ------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    process(clk_i)
        variable wr_line         : line;
        file wr_file             : text open write_mode is "vsim_dcache_traces.txt";
        variable hit_or_miss_vec : std_ulogic_vector(0 downto 0);
    begin
        if rising_edge(clk_i) then
            hit_or_miss_vec(0) := cache_hit;
            if arb_state = S_IDLE then
                if (cpu_req_i = '1') and (cpu_rden_i = '1') and (stall_i = '0') then
                    write(wr_line, "RD" & "," & time'image(now) & "," & to_string(cpu_adr_i) & "," & to_string(hit_or_miss_vec));
                    writeline(wr_file, wr_line);
                elsif (cpu_req_i = '1') and (cpu_wren_i /= "0000") and (stall_i = '0') then
                    write(wr_line, "WR" & "," & time'image(now) & "," & to_string(cpu_adr_i) & "," & to_string(hit_or_miss_vec));
                    writeline(wr_file, wr_line);
                end if;
            end if;
        end if;
    end process;
end d_cache_multiword_behav;
