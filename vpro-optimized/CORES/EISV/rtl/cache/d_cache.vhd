--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--  SPDX-FileContributor: Stephan Nolting <IMS, Uni Hannover, 2015>
--
-- ----------------------------------------------------------------------------
-- d_cache.vhd - General purpose data cache
-- n-way associative, allocate on write-miss, dirty block write-back
-- ----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;

entity d_cache is
    generic(
        log2_associativity_g : natural := 3; -- log2 of associativity degree
        log2_num_lines_g     : natural := 4; -- log2 of number of cache lines
        log2_line_size_g     : natural := 8 -- log2 of size of cache line (size in 32b words)
    );
    port(
        -- global control --
        clk_i          : in  std_ulogic; -- global clock line, rising-edge
        rst_i          : in  std_ulogic; -- global reset line, high-active, sync
        ce_i           : in  std_ulogic; -- global clock enable, high-active
        stall_i        : in  std_ulogic; -- freeze output if any stall
        clear_i        : in  std_ulogic; -- force reload of cache
        flush_i        : in  std_ulogic; -- force flush of cache
        -- CPU data interface --
        cpu_oe_i       : in  std_ulogic; -- output reg enable
        cpu_req_i      : in  std_ulogic; -- access to cached memory space
        cpu_adr_i      : in  std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
        cpu_rden_i     : in  std_ulogic; -- read enable
        cpu_wren_i     : in  std_ulogic_vector(03 downto 0); -- write enable
        cpu_data_o     : out std_ulogic_vector(31 downto 0); -- read-data word
        cpu_data_i     : in  std_ulogic_vector(31 downto 0); -- write-data word
        cpu_stall_o    : out std_ulogic; -- stall CPU (miss)
        -- memory system interface --
        mem_base_adr_o : out std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
        mem_dat_i      : in  std_ulogic_vector(31 downto 0);
        mem_dat_o      : out std_ulogic_vector(31 downto 0);
        mem_req_o      : out std_ulogic; -- memory request
        mem_busy_i     : in  std_ulogic; -- memory command buffer full
        mem_wrdy_i     : in  std_ulogic; -- write fifo is ready
        mem_rw_o       : out std_ulogic; -- read/write a block from/to memory
        mem_rden_o     : out std_ulogic; -- FIFO read enable
        mem_wren_o     : out std_ulogic; -- FIFO write enable
        mem_wr_last_o  : out std_ulogic; -- last word of write-block
        mem_rrdy_i     : in  std_ulogic; -- read data ready
        -- access statistics --
        hit_o          : out std_ulogic; -- valid hit access
        miss_o         : out std_ulogic -- valid miss access
    );
end d_cache;

architecture d_cache_behav of d_cache is

    -- constants --
    constant all_one_c       : std_ulogic_vector(log2_line_size_g - 1 downto 0)     := (others => '1');
    constant index_size_c    : natural                                              := log2_num_lines_g + log2_line_size_g;
    constant tag_size_c      : natural                                              := 32 - index_size_c - 2;
    constant max_block_sel_c : std_ulogic_vector(log2_associativity_g - 1 downto 0) := (others => '1');

    -- cache line memory --
    type cache_mem_t is array (0 to 2 ** (log2_associativity_g + index_size_c) - 1) of std_ulogic_vector(7 downto 0);
    signal cache_mem_ll : cache_mem_t;
    signal cache_mem_lh : cache_mem_t;
    signal cache_mem_hl : cache_mem_t;
    signal cache_mem_hh : cache_mem_t;

    -- arbitration flags flag --
    type arb_flag_t is array (0 to 2 ** log2_associativity_g - 1) of std_ulogic_vector(2 ** log2_num_lines_g - 1 downto 0);
    signal valid_flag, dirty_flag : arb_flag_t;

    -- tag memory --
    type tag_mem_st is array (0 to 2 ** log2_num_lines_g - 1) of std_ulogic_vector(tag_size_c - 1 downto 0);
    type tag_mem_t is array (0 to 2 ** log2_associativity_g - 1) of tag_mem_st;
    signal tag_mem : tag_mem_t;

    -- arbiter flags access --
    signal flag_block_sel     : std_ulogic_Vector(log2_associativity_g - 1 downto 0);
    signal flag_adr           : std_ulogic_vector(log2_num_lines_g - 1 downto 0);
    signal set_valid          : std_ulogic;
    signal set_dirty          : std_ulogic;
    signal clr_valid          : std_ulogic;
    signal clr_dirty          : std_ulogic;
    signal valid_flag_rd_data : std_ulogic_vector(2 ** log2_associativity_g - 1 downto 0);
    signal dirty_flag_rd_data : std_ulogic_vector(2 ** log2_associativity_g - 1 downto 0);

    -- tag memory access --
    signal tag_mem_we        : std_ulogic;
    signal tag_mem_block_sel : std_ulogic_vector(log2_associativity_g - 1 downto 0);
    signal tag_mem_adr       : std_ulogic_vector(log2_num_lines_g - 1 downto 0);
    signal tag_mem_wr_data   : std_ulogic_vector(tag_size_c - 1 downto 0);
    type tag_mem_rd_t is array (0 to 2 ** log2_associativity_g - 1) of std_ulogic_vector(tag_size_c - 1 downto 0);
    signal tag_mem_rd_data   : tag_mem_rd_t;

    -- hit detector --
    signal hit_block_sel : std_ulogic_vector(log2_associativity_g - 1 downto 0);
    signal cache_hit     : std_ulogic;

    -- data memory access --
    signal data_mem_en           : std_ulogic;
    signal data_mem_we           : std_ulogic_vector(03 downto 0);
    signal data_mem_wr_block_sel : std_ulogic_vector(log2_associativity_g - 1 downto 0);
    signal data_mem_rd_block_sel : std_ulogic_vector(log2_associativity_g - 1 downto 0);
    signal data_mem_wr_adr       : std_ulogic_vector(index_size_c - 1 downto 0);
    signal data_mem_rd_adr       : std_ulogic_vector(index_size_c - 1 downto 0);
    signal data_mem_wr_data      : std_ulogic_vector(31 downto 0);
    signal data_mem_rd_data      : std_ulogic_vector(31 downto 0);
    signal data_mem_oe           : std_ulogic;

    -- arbiter --
    type arb_state_t is (S_IDLE, S_WR_MISS, S_RD_MISS, S_DOWNLOAD, S_UPLOAD, S_RESYNC, S_FLUSH0, S_FLUSH1, S_CLEAR0, S_CLEAR1);
    signal arb_state, arb_state_nxt         : arb_state_t;
    signal arb_state_ret, arb_state_ret_nxt : arb_state_t;
    signal base_adr, base_adr_nxt           : std_ulogic_vector(31 downto 0);
    signal acc_adr_buf, acc_adr_buf_nxt     : std_ulogic_vector(31 downto 0);
    signal acc_dat_buf, acc_dat_buf_nxt     : std_ulogic_vector(31 downto 0);
    signal acc_we_buf, acc_we_buf_nxt       : std_ulogic_vector(03 downto 0);
    signal acc_rd_buf, acc_rd_buf_nxt       : std_ulogic;
    signal cache_pnt, cache_pnt_nxt         : std_ulogic_vector(log2_line_size_g - 1 downto 0);
    signal block_sel, block_sel_nxt         : std_ulogic_vector(log2_associativity_g - 1 downto 0);
    signal cpu_stall, cpu_stall_nxt         : std_ulogic;
    signal flush_pnt, flush_pnt_nxt         : std_ulogic_vector(log2_num_lines_g downto 0);
    signal flush_sel, flush_sel_nxt         : std_ulogic_vector(log2_associativity_g downto 0);

    -- random generator --
    signal lfsr : std_ulogic_vector(9 downto 0);

    -- others --
    signal cpu_word_adr      : std_ulogic_vector(log2_line_size_g - 1 downto 0);
    signal cpu_line_sel      : std_ulogic_vector(log2_num_lines_g - 1 downto 0);
    signal use_line          : std_ulogic_vector(log2_num_lines_g - 1 downto 0);
    signal use_line_pre      : std_ulogic_vector(log2_num_lines_g - 1 downto 0);
    signal cpu_tag           : std_ulogic_vector(31 - 2 - log2_line_size_g - log2_num_lines_g downto 0);
    signal mem_req_o_nxt     : std_ulogic;
    signal mem_rw_o_nxt      : std_ulogic;
    signal mem_wren_o_nxt    : std_ulogic;
    signal mem_wr_last_o_nxt : std_ulogic;

    signal pending_clear, pending_clear_nxt : std_ulogic;
    signal pending_flush, pending_flush_nxt : std_ulogic;

    -- debug --
    --type debug_cache_mem_t  is array(0 to 2**(log2_associativity_g+index_size_c)-1) of std_ulogic_vector(31 downto 0);
    --signal debug_cache_mem : debug_cache_mem_t;

begin

    -- Assignments -----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    -- CPU address --
    cpu_word_adr <= cpu_adr_i((log2_line_size_g - 1) + 2 downto 2); -- word select
    cpu_line_sel <= cpu_adr_i((index_size_c - 1) + 2 downto log2_line_size_g + 2); -- line select
    cpu_tag      <= cpu_adr_i(31 downto 31 - (tag_size_c - 1)); -- line's tag

    -- Cache block, that is going to be 'used' --
    use_line     <= base_adr(index_size_c - 1 + 2 downto log2_line_size_g + 2);
    use_line_pre <= acc_adr_buf(index_size_c - 1 + 2 downto log2_line_size_g + 2);

    -- Adr output to external memory --
    mem_base_adr_o(31 downto log2_line_size_g + 2)    <= base_adr(31 downto log2_line_size_g + 2);
    mem_base_adr_o(log2_line_size_g - 1 + 2 downto 0) <= (others => '0');

    -- Control arbiter (sync) ------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    arbiter_sync : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            -- arbiter --
            arb_state     <= S_IDLE;
            arb_state_ret <= S_IDLE;
            cpu_stall     <= '0';
            base_adr      <= (others => '0');
            cache_pnt     <= (others => '0');
            block_sel     <= (others => '0');
            acc_adr_buf   <= (others => '0');
            acc_dat_buf   <= (others => '0');
            acc_we_buf    <= (others => '0');
            acc_rd_buf    <= '0';
            flush_pnt     <= (others => '0');
            flush_sel     <= (others => '0');
            pending_clear <= '0';
            pending_flush <= '0';
            -- Buffer --
            mem_req_o     <= '0';
            mem_rw_o      <= '0';
            mem_wren_o    <= '0';
            mem_wr_last_o <= '0';
        elsif rising_edge(clk_i) then
            if (ce_i = '1') then
                -- arbiter --
                arb_state     <= arb_state_nxt;
                arb_state_ret <= arb_state_ret_nxt;
                cpu_stall     <= cpu_stall_nxt;
                base_adr      <= base_adr_nxt;
                cache_pnt     <= cache_pnt_nxt;
                block_sel     <= block_sel_nxt;
                acc_adr_buf   <= acc_adr_buf_nxt;
                acc_dat_buf   <= acc_dat_buf_nxt;
                acc_we_buf    <= acc_we_buf_nxt;
                acc_rd_buf    <= acc_rd_buf_nxt;
                flush_pnt     <= flush_pnt_nxt;
                flush_sel     <= flush_sel_nxt;
                pending_clear <= pending_clear_nxt;
                pending_flush <= pending_flush_nxt;
                -- Buffer --
                mem_req_o     <= mem_req_o_nxt;
                mem_rw_o      <= mem_rw_o_nxt;
                mem_wren_o    <= mem_wren_o_nxt;
                mem_wr_last_o <= mem_wr_last_o_nxt;
            end if;
        end if;
    end process arbiter_sync;

    -- STALL CPU --
    cpu_stall_o <= cpu_stall;

    -- Control arbiter (comb) ------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    arbiter_comb : process(arb_state, arb_state_ret, cpu_stall, cache_hit, acc_adr_buf, flush_pnt, block_sel, valid_flag_rd_data, dirty_flag_rd_data, hit_block_sel, lfsr, stall_i, acc_dat_buf, acc_we_buf, acc_rd_buf, cache_pnt, base_adr, use_line, use_line_pre, tag_mem_rd_data, cpu_rden_i, cpu_wren_i, cpu_line_sel, cpu_word_adr, cpu_adr_i, cpu_data_i, cpu_req_i, mem_rrdy_i, mem_wrdy_i, mem_busy_i, mem_dat_i, flush_i, clear_i, flush_sel, pending_flush, pending_clear)
        variable any_we_v : std_ulogic;
    begin
        -- arbiter defaults --
        arb_state_ret_nxt <= arb_state_ret;
        arb_state_nxt     <= arb_state;
        cpu_stall_nxt     <= cpu_stall;
        acc_adr_buf_nxt   <= acc_adr_buf;
        acc_dat_buf_nxt   <= acc_dat_buf;
        acc_we_buf_nxt    <= acc_we_buf;
        acc_rd_buf_nxt    <= acc_rd_buf;
        cache_pnt_nxt     <= cache_pnt;
        block_sel_nxt     <= block_sel;
        base_adr_nxt      <= base_adr;
        flush_pnt_nxt     <= flush_pnt;
        flush_sel_nxt     <= flush_sel;
        pending_flush_nxt <= pending_flush or flush_i;
        pending_clear_nxt <= pending_clear or clear_i;

        -- any write access at all? --
        any_we_v := cpu_wren_i(3) or cpu_wren_i(2) or cpu_wren_i(1) or cpu_wren_i(0);

        -- arbiter flag defaults --
        flag_block_sel <= hit_block_sel;
        flag_adr       <= cpu_line_sel;
        set_valid      <= '0';
        set_dirty      <= '0';
        clr_valid      <= '0';
        clr_dirty      <= '0';

        -- modify content? --
        if ((cache_hit = '1') and (any_we_v = '1')) or ((arb_state = S_RESYNC) and (acc_we_buf /= "0000")) then
            set_dirty <= '1';           -- set dirty flag
        end if;

        -- tag memory defaults --
        tag_mem_we        <= '0';
        tag_mem_block_sel <= hit_block_sel;
        tag_mem_adr       <= cpu_line_sel;
        tag_mem_wr_data   <= base_adr(31 downto 31 - (tag_size_c - 1));

        -- data memory defaults --
        data_mem_we           <= "0000";
        if (cache_hit = '1') then
            data_mem_we <= cpu_wren_i;
        end if;
        data_mem_en           <= cpu_req_i and (cpu_rden_i or any_we_v);
        data_mem_wr_block_sel <= hit_block_sel;
        data_mem_rd_block_sel <= hit_block_sel;
        data_mem_wr_adr       <= cpu_line_sel & cpu_word_adr;
        data_mem_rd_adr       <= cpu_line_sel & cpu_word_adr;
        data_mem_wr_data      <= cpu_data_i;
        data_mem_oe           <= '0';

        -- ext mem defaults --
        mem_req_o_nxt     <= '0';
        mem_rw_o_nxt      <= '0';
        mem_rden_o        <= '0';
        mem_wren_o_nxt    <= '0';
        mem_wr_last_o_nxt <= '0';

        -- state machine --
        case (arb_state) is

            when S_IDLE =>              -- normal access
                -------------------------------------------------------------------------
                cache_pnt_nxt   <= (others => '0');
                -- backup access --
                acc_adr_buf_nxt <= cpu_adr_i;
                acc_dat_buf_nxt <= cpu_data_i;
                acc_we_buf_nxt  <= cpu_wren_i;
                acc_rd_buf_nxt  <= cpu_rden_i;
                -- miss check --
                if (cpu_rden_i = '1') and (cache_hit = '0') and (stall_i = '0') then -- valid read access and MISS
                    -- if destination block is dirty -> write back to mem
                    -- get requested block from mem (set valid flag, clear dirty flag)
                    -- perform initial read access
                    block_sel_nxt <= lfsr(log2_associativity_g - 1 downto 0); -- use which block?
                    cpu_stall_nxt <= '1'; -- stall cpu
                    arb_state_nxt <= S_RD_MISS;
                elsif (cpu_wren_i /= "0000") and (cache_hit = '0') and (stall_i = '0') then -- valid write access and MISS
                    -- WRITE ALLOCATE:
                    -- if destination block is dirty -> WRITE BACK to mwm
                    -- get requested block from mem (set valid flag)
                    -- perform initial write access (set dirty flag)
                    block_sel_nxt <= lfsr(log2_associativity_g - 1 downto 0); -- use which block?
                    cpu_stall_nxt <= '1'; -- stall cpu
                    arb_state_nxt <= S_WR_MISS;
                elsif (pending_flush = '1') then -- sync mem with cache
                    cpu_stall_nxt <= '1'; -- stall cpu
                    flush_pnt_nxt <= (others => '0');
                    cache_pnt_nxt <= (others => '0');
                    flush_sel_nxt <= (others => '0');
                    arb_state_nxt <= S_FLUSH0;
                elsif (pending_clear = '1') then
                    cpu_stall_nxt <= '1'; -- stall cpu
                    flush_pnt_nxt <= (others => '0');
                    flush_sel_nxt <= (others => '0');
                    arb_state_nxt <= S_CLEAR0;
                end if;

            when S_RD_MISS =>           -- read miss: check destination block
                -------------------------------------------------------------------------
                data_mem_we   <= "0000"; -- do not write during read miss check, CPU is stalled, thus write enable input not valid
                cache_pnt_nxt <= (others => '0');
                tag_mem_adr   <= acc_adr_buf(index_size_c - 1 + 2 downto log2_line_size_g + 2);
                flag_adr      <= acc_adr_buf(index_size_c - 1 + 2 downto log2_line_size_g + 2);
                if (mem_busy_i = '0') then -- ready for new request?
                    if (valid_flag_rd_data(to_integer(unsigned(block_sel))) = '1') and (dirty_flag_rd_data(to_integer(unsigned(block_sel))) = '1') then -- block has been modified!
                        base_adr_nxt(31 downto log2_line_size_g + log2_num_lines_g + 2)                       <= tag_mem_rd_data(to_integer(unsigned(block_sel)));
                        base_adr_nxt(log2_line_size_g + log2_num_lines_g - 1 + 2 downto log2_line_size_g + 2) <= acc_adr_buf(index_size_c - 1 + 2 downto log2_line_size_g + 2);
                        base_adr_nxt(log2_line_size_g - 1 + 2 downto 2)                                       <= (others => '0');
                        mem_req_o_nxt                                                                         <= '1'; -- request memory block transfer
                        mem_rw_o_nxt                                                                          <= '1'; -- WRITE
                        arb_state_ret_nxt                                                                     <= S_RD_MISS; -- to do download afterwards
                        arb_state_nxt                                                                         <= S_UPLOAD;
                    else
                        base_adr_nxt(31 downto 0)                       <= acc_adr_buf(31 downto 0);
                        base_adr_nxt(log2_line_size_g - 1 + 2 downto 2) <= (others => '0'); -- word index = 0!
                        mem_req_o_nxt                                   <= '1'; -- request memory block transfer
                        mem_rw_o_nxt                                    <= '0'; -- READ
                        arb_state_ret_nxt                               <= S_RESYNC;
                        arb_state_nxt                                   <= S_DOWNLOAD;
                    end if;
                end if;

            when S_WR_MISS =>           -- write miss: check destination block
                -------------------------------------------------------------------------
                cache_pnt_nxt <= (others => '0');
                tag_mem_adr   <= use_line_pre;
                flag_adr      <= use_line_pre;
                if (mem_busy_i = '0') then -- ready for new request?
                    if (valid_flag_rd_data(to_integer(unsigned(block_sel))) = '1') and (dirty_flag_rd_data(to_integer(unsigned(block_sel))) = '1') then -- block has been modified!
                        base_adr_nxt(31 downto log2_line_size_g + log2_num_lines_g + 2)                       <= tag_mem_rd_data(to_integer(unsigned(block_sel)));
                        base_adr_nxt(log2_line_size_g + log2_num_lines_g - 1 + 2 downto log2_line_size_g + 2) <= acc_adr_buf(log2_line_size_g + log2_num_lines_g - 1 + 2 downto log2_line_size_g + 2); --use_line_pre;
                        base_adr_nxt(log2_line_size_g - 1 + 2 downto 2)                                       <= (others => '0');
                        mem_req_o_nxt                                                                         <= '1'; -- request memory block transfer
                        mem_rw_o_nxt                                                                          <= '1'; -- WRITE
                        arb_state_ret_nxt                                                                     <= S_WR_MISS; -- to do download afterwards
                        arb_state_nxt                                                                         <= S_UPLOAD;
                    else
                        base_adr_nxt(31 downto 0)                       <= acc_adr_buf(31 downto 0);
                        base_adr_nxt(log2_line_size_g - 1 + 2 downto 2) <= (others => '0'); -- word index = 0!
                        mem_req_o_nxt                                   <= '1'; -- request memory block transfer
                        mem_rw_o_nxt                                    <= '0'; -- READ
                        arb_state_ret_nxt                               <= S_RESYNC;
                        arb_state_nxt                                   <= S_DOWNLOAD;
                    end if;
                end if;

            when S_DOWNLOAD =>          -- download a block from memory
                -------------------------------------------------------------------------
                tag_mem_adr           <= use_line;
                flag_adr              <= use_line;
                tag_mem_block_sel     <= block_sel;
                flag_block_sel        <= block_sel;
                data_mem_wr_block_sel <= block_sel;
                data_mem_we           <= "0000"; -- do not write if data not ready, CPU is stalled, thus write enable input not valid
                if (mem_rrdy_i = '1') then -- data ready?
                    mem_rden_o       <= '1'; -- fifo read enable
                    data_mem_wr_adr  <= use_line & cache_pnt;
                    data_mem_wr_data <= mem_dat_i; -- data from ext mem interface
                    data_mem_en      <= '1'; -- allow cache access
                    cache_pnt_nxt    <= std_ulogic_vector(unsigned(cache_pnt) + 1);
                    data_mem_we      <= "1111"; -- allow write access (full words)
                end if;
                if (cache_pnt = all_one_c) then -- done?
                    set_valid     <= '1'; -- set valid flag
                    clr_dirty     <= '1'; -- clear dirty flag
                    tag_mem_we    <= '1'; -- set new tag
                    arb_state_nxt <= arb_state_ret;
                end if;

            when S_UPLOAD =>            -- upload a block to memory
                -------------------------------------------------------------------------
                tag_mem_block_sel     <= block_sel;
                flag_block_sel        <= block_sel;
                flag_adr              <= use_line;
                tag_mem_adr           <= use_line;
                data_mem_rd_block_sel <= block_sel;
                data_mem_wr_adr       <= use_line & cache_pnt;
                data_mem_rd_adr       <= use_line & cache_pnt;
                data_mem_wr_data      <= mem_dat_i; -- data from ext mem interface
                data_mem_we           <= "0000"; -- cache read access
                if (mem_wrdy_i = '1') then
                    data_mem_en    <= '1'; -- allow cache access
                    data_mem_oe    <= '1'; -- allow cache output
                    mem_wren_o_nxt <= '1'; -- write to FIFO
                end if;
                if (cache_pnt /= all_one_c) then
                    if (mem_busy_i = '0') then
                        cache_pnt_nxt <= std_ulogic_vector(unsigned(cache_pnt) + 1);
                    end if;
                else                    -- done?
                    --set_valid         <= '1'; -- set valid flag
                    clr_dirty         <= '1'; -- clear dirty flag
                    --tag_mem_we        <= '1'; -- set new tag
                    mem_wr_last_o_nxt <= '1'; -- this is the last data word
                    arb_state_nxt     <= arb_state_ret;
                end if;

            when S_RESYNC =>            -- re-sync cache access with cpu pipeline
                -------------------------------------------------------------------------
                flag_adr       <= acc_adr_buf(index_size_c - 1 + 2 downto log2_line_size_g + 2);
                flag_block_sel <= block_sel;
                if (acc_we_buf /= "0000") or (acc_rd_buf = '1') then -- pending read/write request
                    data_mem_en <= '1';
                end if;
                if (acc_we_buf /= "0000") then
                    set_dirty <= '1';   -- set dirty flag
                end if;
                data_mem_rd_block_sel <= block_sel;
                data_mem_wr_block_sel <= block_sel;
                data_mem_wr_adr       <= acc_adr_buf(log2_line_size_g + log2_num_lines_g - 1 + 2 downto 2);
                data_mem_rd_adr       <= acc_adr_buf(log2_line_size_g + log2_num_lines_g - 1 + 2 downto 2);
                data_mem_we           <= acc_we_buf;
                data_mem_wr_data      <= acc_dat_buf;
                -- FIXME begin (uncomment?) --
                if (stall_i = '0') then
                    cpu_stall_nxt <= '0'; -- resume cpu operation
                    arb_state_nxt <= S_IDLE;
                end if;
            -- FIXME end (uncomment?) --

            when S_FLUSH0 =>            -- check all blocks
                -------------------------------------------------------------------------
                block_sel_nxt <= flush_sel(log2_associativity_g - 1 downto 0);
                flush_sel_nxt <= std_ulogic_vector(unsigned(flush_sel) + 1);
                flush_pnt_nxt <= (others => '0');
                if (flush_sel(log2_associativity_g) = '1') then
                    arb_state_nxt     <= S_IDLE;
                    cpu_stall_nxt     <= '0'; -- resume cpu operation
                    pending_flush_nxt <= '0';
                else
                    arb_state_nxt <= S_FLUSH1;
                end if;

            when S_FLUSH1 =>            -- write all dirty lines back to memory
                -------------------------------------------------------------------------
                cache_pnt_nxt     <= (others => '0');
                arb_state_ret_nxt <= S_FLUSH1; -- always come back here...
                tag_mem_adr       <= flush_pnt(log2_num_lines_g - 1 downto 0);
                flag_adr          <= flush_pnt(log2_num_lines_g - 1 downto 0);
                --flag_block_sel    <= block_sel;
                if (flush_pnt(log2_num_lines_g) = '1') then -- all cache lines done?
                    arb_state_nxt <= S_FLUSH0;
                else                    -- next cache line
                    flush_pnt_nxt                                                                         <= std_ulogic_vector(unsigned(flush_pnt) + 1); -- prepare for next line
                    base_adr_nxt(31 downto log2_line_size_g + log2_num_lines_g + 2)                       <= tag_mem_rd_data(to_integer(unsigned(block_sel))); -- tag
                    base_adr_nxt(log2_line_size_g + log2_num_lines_g - 1 + 2 downto log2_line_size_g + 2) <= flush_pnt(log2_num_lines_g - 1 downto 0); -- index
                    base_adr_nxt(log2_line_size_g - 1 + 2 downto 2)                                       <= (others => '0'); -- word address
                    if (mem_busy_i = '0') then -- ready for new request?
                        if (dirty_flag_rd_data(to_integer(unsigned(block_sel))) = '1') and (valid_flag_rd_data(to_integer(unsigned(block_sel))) = '1') then
                            mem_req_o_nxt <= '1'; -- request memory block transfer
                            mem_rw_o_nxt  <= '1'; -- WRITE
                            arb_state_nxt <= S_UPLOAD; -- upload modified line
                        end if;
                    end if;
                end if;

            when S_CLEAR0 =>            -- invalidate all cache entries
                -------------------------------------------------------------------------
                block_sel_nxt <= flush_sel(log2_associativity_g - 1 downto 0);
                flush_sel_nxt <= std_ulogic_vector(unsigned(flush_sel) + 1);
                flush_pnt_nxt <= (others => '0');
                if (flush_sel(log2_associativity_g) = '1') then
                    pending_clear_nxt <= '0';
                    cpu_stall_nxt     <= '0'; -- resume cpu operation
                    arb_state_nxt     <= S_IDLE;
                else
                    arb_state_nxt <= S_CLEAR1;
                end if;

            when S_CLEAR1 =>            -- invalidate all cache entries
                -------------------------------------------------------------------------
                flag_adr       <= flush_pnt(log2_num_lines_g - 1 downto 0);
                flag_block_sel <= block_sel;
                if (flush_pnt(log2_num_lines_g) = '1') then -- all cache lines done?
                    arb_state_nxt <= S_CLEAR0;
                else                    -- next cache line
                    flush_pnt_nxt <= std_ulogic_vector(unsigned(flush_pnt) + 1); -- prepare for next line
                    clr_valid     <= '1';
                    clr_dirty     <= '1';
                end if;

        end case;
    end process arbiter_comb;

    -- Arbitration flags memory ----------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    arb_flag_mem : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            dirty_flag <= (others => (others => '0'));
            valid_flag <= (others => (others => '0')); -- here we NEED a reset state!
        elsif rising_edge(clk_i) then
            -- valid flags
            if (ce_i = '1') then
                if (clr_valid = '1') then
                    valid_flag(to_integer(unsigned(flag_block_sel)))(to_integer(unsigned(flag_adr))) <= '0';
                elsif (set_valid = '1') then
                    valid_flag(to_integer(unsigned(flag_block_sel)))(to_integer(unsigned(flag_adr))) <= '1';
                end if;
                -- dirty flags
                if (clr_dirty = '1') then
                    dirty_flag(to_integer(unsigned(flag_block_sel)))(to_integer(unsigned(flag_adr))) <= '0';
                elsif (set_dirty = '1') then
                    dirty_flag(to_integer(unsigned(flag_block_sel)))(to_integer(unsigned(flag_adr))) <= '1';
                end if;
            end if;
        end if;
    end process arb_flag_mem;

    arb_flag_mem_async_rd : process(valid_flag, dirty_flag, flag_adr)
    begin
        for i in 0 to 2 ** log2_associativity_g - 1 loop
            valid_flag_rd_data(i) <= valid_flag(i)(to_integer(unsigned(flag_adr)));
            dirty_flag_rd_data(i) <= dirty_flag(i)(to_integer(unsigned(flag_adr)));
        end loop;                       -- i
    end process arb_flag_mem_async_rd;

    -- Cache tag memory ------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    tag_mem_sync : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                if (tag_mem_we = '1') then
                    tag_mem(to_integer(unsigned(tag_mem_block_sel)))(to_integer(unsigned(tag_mem_adr))) <= tag_mem_wr_data;
                end if;
            end if;
        end if;
    end process tag_mem_sync;

    tag_mem_async_rd : process(tag_mem, tag_mem_adr)
    begin
        for i in 0 to 2 ** log2_associativity_g - 1 loop
            tag_mem_rd_data(i) <= tag_mem(i)(to_integer(unsigned(tag_mem_adr)));
        end loop;                       -- i
    end process tag_mem_async_rd;

    -- Hit detector ----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    hit_detector : process(tag_mem_rd_data, cpu_tag, valid_flag_rd_data)
    begin
        hit_block_sel <= (others => '0');
        cache_hit     <= '0';
        for i in 0 to 2 ** log2_associativity_g - 1 loop
            if (tag_mem_rd_data(i) = cpu_tag) and (valid_flag_rd_data(i) = '1') then -- tag match and valid entry?
                hit_block_sel <= std_ulogic_vector(to_unsigned(i, log2_associativity_g));
                cache_hit     <= '1';
                exit;
            end if;
        end loop;                       -- i
    end process hit_detector;

    -- access statistics --
    hit_o  <= '1' when ((cpu_rden_i = '1') or (cpu_wren_i /= "0000")) and (cache_hit = '1') else '0';
    miss_o <= '1' when ((cpu_rden_i = '1') or (cpu_wren_i /= "0000")) and (cache_hit = '0') else '0';

    -- Cache data memory -----------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    data_mem_sync : process(clk_i)
        variable wr_addr_pre_v, rd_addr_pre_v : std_ulogic_vector(log2_associativity_g + index_size_c - 1 downto 0);
        variable wr_addr_v, rd_addr_v         : integer range 0 to 2 ** (log2_associativity_g + index_size_c) - 1;
    begin
        if rising_edge(clk_i) then
            --			if (ce_i = '1') then
            wr_addr_pre_v := data_mem_wr_block_sel & data_mem_wr_adr;
            rd_addr_pre_v := data_mem_rd_block_sel & data_mem_rd_adr;
            wr_addr_v     := to_integer(unsigned(wr_addr_pre_v));
            rd_addr_v     := to_integer(unsigned(rd_addr_pre_v));

            if (data_mem_we(0) = '1') and (data_mem_en = '1') then
                cache_mem_ll(wr_addr_v) <= data_mem_wr_data(07 downto 00);
            end if;
            if (cpu_oe_i = '1') or (data_mem_oe = '1') then
                data_mem_rd_data(07 downto 00) <= cache_mem_ll(rd_addr_v);
            end if;

            if (data_mem_we(1) = '1') and (data_mem_en = '1') then
                cache_mem_lh(wr_addr_v) <= data_mem_wr_data(15 downto 08);
            end if;
            if (cpu_oe_i = '1') or (data_mem_oe = '1') then
                data_mem_rd_data(15 downto 08) <= cache_mem_lh(rd_addr_v);
            end if;

            if (data_mem_we(2) = '1') and (data_mem_en = '1') then
                cache_mem_hl(wr_addr_v) <= data_mem_wr_data(23 downto 16);
            end if;
            if (cpu_oe_i = '1') or (data_mem_oe = '1') then
                data_mem_rd_data(23 downto 16) <= cache_mem_hl(rd_addr_v);
            end if;

            if (data_mem_we(3) = '1') and (data_mem_en = '1') then
                cache_mem_hh(wr_addr_v) <= data_mem_wr_data(31 downto 24);
            end if;
            if (cpu_oe_i = '1') or (data_mem_oe = '1') then
                data_mem_rd_data(31 downto 24) <= cache_mem_hh(rd_addr_v);
            end if;
            --			end if;
        end if;
    end process data_mem_sync;

    -- Data output --
    mem_dat_o  <= data_mem_rd_data;
    cpu_data_o <= data_mem_rd_data;

    -- Random generator ------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    random_gen : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            lfsr <= (others => '0');
        elsif rising_edge(clk_i) then
            --				if (ce_i = '1') then
            lfsr <= lfsr(8 downto 0) & (lfsr(9) xnor lfsr(6));
            --				end if;
        end if;
    end process random_gen;

    -- DEBUGGING STUFF -------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    --dedugging: process(cache_mem_ll, cache_mem_lh, cache_mem_hl, cache_mem_hh)
    --begin
    --  for i in 0 to 2**(log2_associativity_g+index_size_c)-1 loop
    --    debug_cache_mem(i) <= cache_mem_hh(i) & cache_mem_hl(i) & cache_mem_lh(i) & cache_mem_ll(i);
    --  end loop;
    --end process dedugging;

end d_cache_behav;
