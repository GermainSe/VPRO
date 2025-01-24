--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # idma.vhd - Intelligent DMA Controller                                     #
-- # use only with 2-cycle-latency local memory!                               #
-- #############################################################################
--coverage off

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_specializations.all;
use core_v2pro.package_datawidths.all;

entity idma is
    generic(
        CLUSTER_ID         : natural := 0; -- absolute ID of this cluster
        num_vu_per_cluster : natural := 1
    );
    port(
        -- global control --
        clk_i           : in  std_ulogic; -- global clock line, rising-edge
        rst_i           : in  std_ulogic; -- global reset line, sync, polarity: see package
        -- control interface --
        io_clk_i        : in  std_ulogic; -- io configuration clock
        io_rst_i        : in  std_ulogic; -- io reset line, sync
        io_ren_i        : in  std_ulogic; -- read enable
        io_wen_i        : in  std_ulogic; -- write enable (full word)
        io_adr_i        : in  std_ulogic_vector(15 downto 0); -- data address, word-indexed
        io_data_i       : in  std_ulogic_vector(31 downto 0); -- data output
        io_data_o       : out std_ulogic_vector(31 downto 0); -- data input
        idma_cmd_i      : in  dma_command_t;
        idma_cmd_we_i   : in  std_ulogic;
        idma_cmd_full_o : out std_ulogic;
        -- external memory system interface --
        mem_base_adr_o  : out std_ulogic_vector(31 downto 0); -- addressing bytes (only on boundaries!)
        mem_size_o      : out std_ulogic_vector(19 downto 0); -- quantity in bytes
        mem_dat_i       : in  std_ulogic_vector(mm_data_width_c - 1 downto 0); -- data from main memory
        mem_dat_o       : out std_ulogic_vector(mm_data_width_c - 1 downto 0); -- data to main memory
        mem_req_o       : out std_ulogic; -- memory request
        mem_busy_i      : in  std_ulogic; -- no request possible right now
        mem_rw_o        : out std_ulogic; -- read/write a block from/to memory
        mem_rden_o      : out std_ulogic; -- FIFO read enable
        mem_wren_o      : out std_ulogic; -- FIFO write enable
        mem_wrdy_i      : in  std_ulogic; -- data can be written
        mem_wr_last_o   : out std_ulogic; -- last word of write-block
        mem_rrdy_i      : in  std_ulogic; -- read data ready
        -- local memory system interface (unique connection for each LM) --
        loc_adr_o       : out std_ulogic_vector(lm_addr_width_c - 1 downto 0); -- data address
        loc_dat_i       : in  lm_dma_word_t(0 to num_vu_per_cluster - 1); -- data from local memories
        loc_dat_o       : out std_ulogic_vector(mm_data_width_c - 1 downto 0); -- data to local memories
        loc_rden_o      : out lm_1b_t(0 to num_vu_per_cluster - 1); -- read enable
        loc_wren_o      : out lm_wren_t(0 to num_vu_per_cluster - 1); -- write enable
        -- debug (cnt)
        dma_busy_o      : out std_ulogic
    );
end idma;

architecture dma_rtl of idma is

    -- descriptor widths configuration --
    constant ext_base_size_c          : natural := dma_cmd_ext_base_len_c;
    constant loc_base_size_c          : natural := dma_cmd_loc_base_len_c; --32;    
    constant block_x_size_c           : natural := dma_cmd_x_size_len_c;
    constant block_y_size_c           : natural := dma_cmd_y_size_len_c;
    constant block_stride_size_c      : natural := dma_cmd_x_stride_len_c;
    constant lm_broadcast_mask_size_c : natural := num_vu_per_cluster; --15 + 19 + 19; -- TODO maybe const 8?

    -- descriptor type --
    type descriptor_t is record
        ext_base_reg      : std_ulogic_vector(ext_base_size_c - 1 downto 0);
        loc_base_reg      : std_ulogic_vector(loc_base_size_c - 1 downto 0);
        block_x_reg       : std_ulogic_vector(block_x_size_c - 1 downto 0);
        block_y_reg       : std_ulogic_vector(block_y_size_c - 1 downto 0);
        block_stride_reg  : std_ulogic_vector(block_stride_size_c - 1 downto 0);
        dir_reg           : std_ulogic;
        pad_top           : std_ulogic;
        pad_bottom        : std_ulogic;
        pad_left          : std_ulogic;
        pad_right         : std_ulogic;
        lm_broadcast_mask : std_ulogic_vector(lm_broadcast_mask_size_c - 1 downto 0);
    end record;

    constant descriptor_emtpy_c : descriptor_t := (
        ext_base_reg      => (others => '0'),
        loc_base_reg      => (others => '0'),
        block_x_reg       => (others => '0'),
        block_y_reg       => (others => '0'),
        block_stride_reg  => (others => '0'),
        dir_reg           => '0',
        pad_top           => '0',
        pad_bottom        => '0',
        pad_left          => '0',
        pad_right         => '0',
        lm_broadcast_mask => (others => '0')
    );
    -- descriptor registers --
    signal descriptor_dma       : descriptor_t;

    -- resulting descriptor register --
    constant descriptor_queue_depth_c : natural := num_idma_fifo_entries_c;
    constant descriptor_size_c        : natural := ext_base_size_c + loc_base_size_c + block_x_size_c + block_y_size_c + block_stride_size_c + lm_broadcast_mask_size_c + 4 + 1;
    signal descriptor_in              : std_ulogic_vector(descriptor_size_c - 1 downto 0); -- host side
    signal descriptor_out             : std_ulogic_vector(descriptor_size_c - 1 downto 0); -- DMA side

    -- descriptor queue arbitration --
    signal descriptor_issue : std_ulogic; -- issue new descriptor
    signal queue_full       : std_ulogic; -- fifo is full - force wait
    signal descriptor_re    : std_ulogic;
    signal descriptor_nrdy  : std_ulogic;
    signal descriptor_avail : std_ulogic; -- a DMA descriptor is available
    signal busy_sync2       : std_ulogic_vector(1 downto 0); -- sync stage 2 for CDC
    signal busy_sync1       : std_ulogic_vector(1 downto 0); -- sync stage 1 for CDC
    signal fsm_busy         : std_ulogic; -- DMA still busy
    signal fifo_busy        : std_ulogic; -- FIFO still not empty

    --  -- DMA CMD arbiter --
    type descrior_arb_state_t is (S_IDLE, S_DESCRIPTOR_FETCH, S_DESCRIPTOR_EXECUTE);
    signal descrior_arb_state, descrior_arb_state_nxt : descrior_arb_state_t;

    signal current_descriptor, current_descriptor_nxt                                      : descriptor_t;
    signal next_descriptor, next_descriptor_nxt                                            : descriptor_t;
    signal next_descriptor_valid, next_descriptor_valid_nxt                                : std_ulogic;
    signal current_descriptor_done, current_descriptor_start, current_descriptor_start_nxt : std_ulogic;
    signal fetched_next_descr_last_cyc, fetched_next_descr_last_cyc_nxt                    : std_ulogic;

    --  -- DMA arbiter --
    type transfer_arb_state_t is (S_IDLE, S_E2L_REQUEST, S_L2E_REQUEST, S_E2L, S_L2E);
    signal transfer_arb_state, transfer_arb_state_nxt : transfer_arb_state_t;

    -- port internals
    signal loc_wren_int : std_ulogic_vector(mm_data_width_c / vpro_data_width_c - 1 downto 0);
    signal loc_rden_int : std_ulogic;
    signal loc_dat_int  : std_ulogic_vector(mm_data_width_c - 1 downto 0);

    signal loc_rden_int_ff1, loc_rden_int_ff2, loc_rden_int_ff3, loc_rden_int_ff4 : std_ulogic;

    -- iteration counter
    signal loc_adr_o_int, loc_adr_o_int_nxt                 : std_ulogic_vector(loc_base_size_c - 1 downto 0);
    signal mem_adr_o_int, mem_adr_o_int_nxt                 : std_ulogic_vector(31 downto 0);
    signal remaining_x_words, remaining_x_words_nxt         : unsigned(block_x_size_c - 1 downto 0);
    signal mem_remaining_x_words, mem_remaining_x_words_nxt : unsigned(block_x_size_c - 1 downto 0);
    signal remaining_y_words, remaining_y_words_nxt         : unsigned(block_y_size_c - 1 downto 0);
    signal mem_block_adr_offset_nxt, mem_block_adr_offset   : unsigned(block_x_size_c - 1 downto 0);

    -- buffer to hold local rd data [rd delay of LM requires later mem bus to be wr_rdy, else buffer data]
    constant l2e_fifo_depth_c                                            : natural := 16;
    constant l2e_fifo_depth_log2_c                                       : natural := index_size(l2e_fifo_depth_c);
    signal mem_l2e_fifo_full, mem_l2e_fifo_full_fifo, mem_l2e_fifo_empty : std_ulogic;
    signal mem_l2e_fifo_wr_free                                          : std_ulogic_vector(l2e_fifo_depth_log2_c DOWNTO 0);

    -- DMA Padding Registers
    signal padding_width_top, padding_width_top_reg, padding_width_top_cdc          : unsigned(11 downto 0) := (others => '0');
    signal padding_width_bottom, padding_width_bottom_reg, padding_width_bottom_cdc : unsigned(11 downto 0) := (others => '0');
    signal padding_width_left, padding_width_left_reg, padding_width_left_cdc       : unsigned(11 downto 0) := (others => '0');
    signal padding_width_right, padding_width_right_reg, padding_width_right_cdc    : unsigned(11 downto 0) := (others => '0');
    signal padding_value, padding_value_reg, padding_value_cdc                      : unsigned(15 downto 0) := (others => '0');
    signal padding_active, padding_active_nxt                                       : boolean := false;

    -- for busy signal preset (based on descriptor write/issue)
    signal descriptor_issue_ff : std_ulogic_vector(6 downto 0) := (others => '0');
    signal queue_sfull         : std_ulogic;

    signal sr_e2l_wr_full  : std_ulogic;
    signal sr_e2l_wr_en    : std_ulogic_vector(integer(ceil(log2(real(mm_data_width_c / vpro_data_width_c)))) DOWNTO 0);
    signal sr_e2l_wdata    : std_ulogic_vector(mm_data_width_c - 1 DOWNTO 0);
    signal sr_e2l_rd_count : std_ulogic_vector(integer(ceil(log2(real(mm_data_width_c / vpro_data_width_c)))) DOWNTO 0);
    signal sr_e2l_rd_en    : std_ulogic_vector(integer(ceil(log2(real(mm_data_width_c / vpro_data_width_c)))) DOWNTO 0);
    signal sr_e2l_rdata    : std_ulogic_vector(mm_data_width_c - 1 DOWNTO 0);
    signal sr_l2e_wr_full  : std_ulogic;
    signal sr_l2e_wr_en    : std_ulogic_vector(integer(ceil(log2(real(mm_data_width_c / vpro_data_width_c)))) DOWNTO 0);
    signal sr_l2e_wdata    : std_ulogic_vector(mm_data_width_c - 1 DOWNTO 0);
    signal sr_l2e_rd_count : std_ulogic_vector(integer(ceil(log2(real(mm_data_width_c / vpro_data_width_c)))) DOWNTO 0);
    signal sr_l2e_rd_en    : std_ulogic_vector(integer(ceil(log2(real(mm_data_width_c / vpro_data_width_c)))) DOWNTO 0);
    signal sr_l2e_rdata    : std_ulogic_vector(mm_data_width_c - 1 DOWNTO 0);

    signal loc_align_offset                                      : std_ulogic_vector(align_offset_vector_length_c - 1 downto 0); -- without delay for lm accesses
    signal ext_align_offset_ff, ext_align_offset_nxt             : std_ulogic_vector(align_offset_vector_length_c - 1 downto 0);
    signal ext_param_is_read_ff, ext_param_is_read_nxt           : std_ulogic;
    signal loc_align_offset_ff, loc_align_offset_nxt             : std_ulogic_vector(align_offset_vector_length_c - 1 downto 0); -- with delay for mm accesses
    signal remaining_ext_words_ff, remaining_ext_words_nxt       : std_ulogic_vector(block_x_size_c downto 0); -- counts how many subwords are left
    signal remaining_sr_l2e_words_ff, remaining_sr_l2e_words_nxt : std_ulogic_vector(block_x_size_c - 1 downto 0); -- counts how many subwords are left
    signal mem_size_o_int                                        : std_ulogic_vector(mem_size_o'range);
    signal mem_req_o_int                                         : std_ulogic;
    signal remaining_ext_words                                   : std_ulogic_vector(remaining_ext_words_ff'range);
    signal ext_align_offset                                      : std_ulogic_vector(ext_align_offset_ff'range);
    signal ext_param_is_read                                     : std_ulogic;
    signal next_ext_params_sent_ff                               : std_ulogic;
    signal next_ext_params_sent_nxt                              : std_ulogic;

    signal idma_fifo_rdata : std_ulogic_vector(mm_data_width_c - 1 DOWNTO 0);
    signal idma_fifo_rd_en : std_ulogic;
    signal dma_busy_int    : std_ulogic;

    signal mem_req_base_adr_ff            : std_ulogic_vector(mem_base_adr_o'range);
    signal mem_req_base_adr_nxt           : std_ulogic_vector(mem_base_adr_o'range);
    signal mem_req_remaining_y_words_ff   : unsigned(block_y_size_c - 1 downto 0);
    signal mem_req_remaining_y_words_nxt  : unsigned(block_y_size_c - 1 downto 0);
    signal mem_req_started_cur_descr_ff   : std_ulogic;
    signal mem_req_started_cur_descr_nxt  : std_ulogic;
    signal mem_req_started_next_descr_ff  : std_ulogic;
    signal mem_req_started_next_descr_nxt : std_ulogic;
    signal mem_req_cur_descr_done_ff      : std_ulogic;
    signal mem_req_cur_descr_done_nxt     : std_ulogic;
    signal mem_req_next_descr_done_ff     : std_ulogic;
    signal mem_req_next_descr_done_nxt    : std_ulogic;
    signal outstanding_mem_req_ff         : std_ulogic;
    signal outstanding_mem_req_nxt        : std_ulogic;

    signal start_new_l2e_req         : std_ulogic;
    signal l2e_remaining_x_words_ff  : unsigned(remaining_x_words'range);
    signal l2e_remaining_x_words_nxt : unsigned(remaining_x_words'range);
    signal l2e_remaining_y_words_ff  : unsigned(remaining_y_words'range);
    signal l2e_remaining_y_words_nxt : unsigned(remaining_y_words'range);
    signal l2e_loc_adr_ff            : std_ulogic_vector(loc_adr_o_int'range);
    signal l2e_loc_adr_nxt           : std_ulogic_vector(loc_adr_o_int'range);
    signal l2e_busy_ff               : std_ulogic;
    signal l2e_busy_nxt              : std_ulogic;
    signal l2e_next_descr_active_ff  : std_ulogic;
    signal l2e_next_descr_active_ff2 : std_ulogic;
    signal l2e_next_descr_active_ff3 : std_ulogic;
    signal l2e_next_descr_active_ff4 : std_ulogic;
    signal l2e_next_descr_active_ff5 : std_ulogic;
    signal l2e_next_descr_active_nxt : std_ulogic;

    signal l2e_current_lm_broadcast_mask_ff  : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_current_lm_broadcast_mask_ff2 : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_current_lm_broadcast_mask_ff3 : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_current_lm_broadcast_mask_ff4 : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_current_lm_broadcast_mask_ff5 : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_next_lm_broadcast_mask_ff     : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_next_lm_broadcast_mask_ff2    : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_next_lm_broadcast_mask_ff3    : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_next_lm_broadcast_mask_ff4    : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);
    signal l2e_next_lm_broadcast_mask_ff5    : std_ulogic_vector(current_descriptor.lm_broadcast_mask'range);

    signal ext_param_fifo_full  : std_ulogic;
    signal ext_param_fifo_rdata : std_ulogic_vector(1 + remaining_ext_words'length + ext_align_offset'length - 1 downto 0);
    signal ext_param_fifo_wdata : std_ulogic_vector(1 + remaining_ext_words'length + ext_align_offset'length - 1 downto 0);
    signal ext_param_fifo_rden  : std_ulogic;
    signal ext_param_fifo_wren  : std_ulogic;
    signal ext_param_fifo_empty : std_ulogic;

begin             
--coverage off
    assert (lm_addr_width_c = loc_base_size_c) report "Check config. lm_addr_width_c /= loc_base_size_c!" severity failure;

    loc_mem_signal_process : process(current_descriptor, loc_dat_i, loc_wren_int, loc_adr_o_int, loc_rden_int, mem_l2e_fifo_full_fifo, mem_l2e_fifo_wr_free, l2e_loc_adr_ff, l2e_next_descr_active_ff, next_descriptor.lm_broadcast_mask, l2e_current_lm_broadcast_mask_ff5, l2e_next_lm_broadcast_mask_ff5, l2e_busy_ff, l2e_next_descr_active_ff5)
    begin
        loc_rden_o  <= (others => '0');
        loc_adr_o   <= (others => '0');
        loc_wren_o  <= (others => (others => '0'));
        loc_dat_int <= (others => '0');

        loc_adr_o <= loc_adr_o_int;
        if l2e_busy_ff = '1' then
            loc_adr_o <= l2e_loc_adr_ff;
        end if;

        for i in 0 to num_vu_per_cluster - 1 loop
            if l2e_next_descr_active_ff = '1' then
                if next_descriptor.lm_broadcast_mask(i) = '1' then
                    loc_rden_o(i) <= loc_rden_int;
                end if;
            else
                if current_descriptor.lm_broadcast_mask(i) = '1' then
                    loc_wren_o(i) <= loc_wren_int;
                    loc_rden_o(i) <= loc_rden_int;
                end if;
            end if;

            if l2e_next_descr_active_ff5 = '1' then
                if l2e_next_lm_broadcast_mask_ff5(i) = '1' then
                    loc_dat_int <= loc_dat_i(i);
                end if;
            else
                if l2e_current_lm_broadcast_mask_ff5(i) = '1' then
                    loc_dat_int <= loc_dat_i(i);
                end if;
            end if;
        end loop;

        mem_l2e_fifo_full <= '0';
        if (mem_l2e_fifo_full_fifo = '1' or (unsigned(mem_l2e_fifo_wr_free) <= 5)) then -- mem_l2e_fifo_wr_free > 3 (to allow 3 cycles lm read delay)
            mem_l2e_fifo_full <= '1';
        end if;
    end process;

    lm_delay_process : process(clk_i)
    begin
        if rising_edge(clk_i) then
            loc_rden_int_ff1 <= loc_rden_int;
            loc_rden_int_ff2 <= loc_rden_int_ff1;
            loc_rden_int_ff3 <= loc_rden_int_ff2;
            loc_rden_int_ff4 <= loc_rden_int_ff3;

            l2e_current_lm_broadcast_mask_ff  <= current_descriptor.lm_broadcast_mask;
            l2e_current_lm_broadcast_mask_ff2 <= l2e_current_lm_broadcast_mask_ff;
            l2e_current_lm_broadcast_mask_ff3 <= l2e_current_lm_broadcast_mask_ff2;
            l2e_current_lm_broadcast_mask_ff4 <= l2e_current_lm_broadcast_mask_ff3;
            l2e_current_lm_broadcast_mask_ff5 <= l2e_current_lm_broadcast_mask_ff4;

            l2e_next_lm_broadcast_mask_ff  <= next_descriptor.lm_broadcast_mask;
            l2e_next_lm_broadcast_mask_ff2 <= l2e_next_lm_broadcast_mask_ff;
            l2e_next_lm_broadcast_mask_ff3 <= l2e_next_lm_broadcast_mask_ff2;
            l2e_next_lm_broadcast_mask_ff4 <= l2e_next_lm_broadcast_mask_ff3;
            l2e_next_lm_broadcast_mask_ff5 <= l2e_next_lm_broadcast_mask_ff4;
        end if;
    end process lm_delay_process;

    local_to_extern_fifo : idma_fifo
        generic map(
            DWIDTH_WR         => mm_data_width_c, -- data width at write port
            DWIDTH_RD         => mm_data_width_c, -- data width at read port
            DEPTH_WR          => l2e_fifo_depth_c, -- fifo depth (number of words with write data width), must be a power of 2
            AWIDTH_WR         => index_size(l2e_fifo_depth_c), -- address width of memory write port, set to log2(DEPTH_WR) -- DEPTH=64 => 6
            AWIDTH_RD         => index_size(l2e_fifo_depth_c), -- address width of memory read port,  set to log2(DEPTH_WR*DWIDTH_WR/DWIDTH_RD) => 4
            ASYNC             => 0,     -- 0: sync fifo, 1: async fifo
            ADD_READ_SYNC_REG => 0,
            --          ADD_READ_SYNC_REG => 2,     -- 0: 2 sync regs for async fifo on read side, 1: 1 cycle additional delay for rd_count+rd_empty
            SYNC_OUTREG       => 1,     -- 0: no read data output register if sync fifo, 1: always generate output register
            BIG_ENDIAN        => 1      -- 0: big endian conversion if DWIDTH_WR /= DWIDTH_RD
        )
        port map(
            -- *** write port ***
            clk_wr     => clk_i,
            reset_n_wr => rst_i,
            clken_wr   => '1',
            flush_wr   => '0',
            wr_free    => mem_l2e_fifo_wr_free,
            wr_full    => mem_l2e_fifo_full_fifo,
            wr_en      => loc_rden_int_ff4, -- as loc_rden_o    -- delay 3 cycles
            wdata      => loc_dat_int,
            -- *** read port ***
            clk_rd     => clk_i,
            reset_n_rd => rst_i,
            clken_rd   => '1',
            flush_rd   => '0',
            rd_count   => open,
            rd_empty   => mem_l2e_fifo_empty,
            rd_en      => idma_fifo_rd_en, -- mem_wren_o
            rdata      => idma_fifo_rdata
        );

    -- Descriptor Fetch FSM --------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    descriptor_arbiter_sync_rst : process(clk_i, rst_i)
    begin
        if (rst_i = active_reset_c) then
            descrior_arb_state          <= S_IDLE;
            current_descriptor          <= descriptor_emtpy_c;
            current_descriptor_start    <= '0';
            next_descriptor             <= descriptor_emtpy_c;
            next_descriptor_valid       <= '0';
            fetched_next_descr_last_cyc <= '0';
        elsif rising_edge(clk_i) then
            descrior_arb_state          <= descrior_arb_state_nxt;
            current_descriptor          <= current_descriptor_nxt;
            current_descriptor_start    <= current_descriptor_start_nxt;
            next_descriptor             <= next_descriptor_nxt;
            next_descriptor_valid       <= next_descriptor_valid_nxt;
            fetched_next_descr_last_cyc <= fetched_next_descr_last_cyc_nxt;
        end if;
    end process descriptor_arbiter_sync_rst;

    descriptor_arbiter_comb : process(descrior_arb_state, descriptor_avail, descriptor_dma, current_descriptor_done, current_descriptor, next_descriptor, next_descriptor_valid, fetched_next_descr_last_cyc)
    begin
        descrior_arb_state_nxt          <= descrior_arb_state;
        current_descriptor_nxt          <= current_descriptor;
        descriptor_re                   <= '0';
        current_descriptor_start_nxt    <= '0';
        fifo_busy                       <= '0';
        next_descriptor_nxt             <= next_descriptor;
        next_descriptor_valid_nxt       <= next_descriptor_valid;
        fetched_next_descr_last_cyc_nxt <= '0';

        -- FSM --
        case descrior_arb_state is
            when S_IDLE =>
                if fetched_next_descr_last_cyc = '1' then -- use descriptor that was fetched in the last cycle
                    fifo_busy                    <= '1';
                    current_descriptor_nxt       <= descriptor_dma;
                    descrior_arb_state_nxt       <= S_DESCRIPTOR_EXECUTE;
                    current_descriptor_start_nxt <= '1';
                elsif next_descriptor_valid = '1' then -- use descriptor that was already fetched and stored in a buffer
                    next_descriptor_valid_nxt    <= '0';
                    fifo_busy                    <= '1';
                    current_descriptor_nxt       <= next_descriptor;
                    descrior_arb_state_nxt       <= S_DESCRIPTOR_EXECUTE;
                    current_descriptor_start_nxt <= '1';
                elsif descriptor_avail = '1' then --                    fetch new descriptor from FIFO
                    fifo_busy              <= '1';
                    descriptor_re          <= '1'; -- from descriptor fifo get data next cycle
                    descrior_arb_state_nxt <= S_DESCRIPTOR_FETCH;
                end if;

            when S_DESCRIPTOR_FETCH =>
                fifo_busy                    <= '1';
                current_descriptor_nxt       <= descriptor_dma;
                descrior_arb_state_nxt       <= S_DESCRIPTOR_EXECUTE;
                current_descriptor_start_nxt <= '1';

                if descriptor_avail = '1' then --                    fetch next descriptor
                    descriptor_re                   <= '1'; -- from descriptor fifo get data next cycle
                    fetched_next_descr_last_cyc_nxt <= '1';
                end if;

            when S_DESCRIPTOR_EXECUTE =>
                if descriptor_avail = '1' and next_descriptor_valid = '0' and fetched_next_descr_last_cyc = '0' then --                    fetch next descriptor
                    descriptor_re                   <= '1'; -- from descriptor fifo get data next cycle
                    fetched_next_descr_last_cyc_nxt <= '1';
                end if;

                if fetched_next_descr_last_cyc = '1' then
                    next_descriptor_valid_nxt <= '1';
                    next_descriptor_nxt       <= descriptor_dma;
                end if;

                if current_descriptor_done = '1' then
                    descrior_arb_state_nxt <= S_IDLE;
                    if fetched_next_descr_last_cyc = '1' then -- use descriptor that was fetched in the last cycle
                        fifo_busy                    <= '1';
                        current_descriptor_nxt       <= descriptor_dma;
                        descrior_arb_state_nxt       <= S_DESCRIPTOR_EXECUTE;
                        current_descriptor_start_nxt <= '1';
                    elsif next_descriptor_valid = '1' then -- use descriptor that was already fetched and stored in a buffer
                        next_descriptor_valid_nxt    <= '0';
                        fifo_busy                    <= '1';
                        current_descriptor_nxt       <= next_descriptor;
                        descrior_arb_state_nxt       <= S_DESCRIPTOR_EXECUTE;
                        current_descriptor_start_nxt <= '1';
                    elsif descriptor_avail = '1' then --                    fetch new descriptor from FIFO
                        fifo_busy              <= '1';
                        descriptor_re          <= '1'; -- from descriptor fifo get data next cycle
                        descrior_arb_state_nxt <= S_DESCRIPTOR_FETCH;
                    end if;
                else
                    fifo_busy <= '1';
                end if;
        end case;
    end process descriptor_arbiter_comb;

    -- Transfer Control FSM --------------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------------
    transfer_arbiter_sync_rst : process(clk_i, rst_i)
    begin
        if (rst_i = active_reset_c) then
            transfer_arb_state        <= S_IDLE;
            loc_adr_o_int             <= (others => '0');
            mem_adr_o_int             <= (others => '0');
            remaining_x_words         <= (others => '0');
            mem_remaining_x_words     <= (others => '0');
            remaining_y_words         <= (others => '0');
            mem_block_adr_offset      <= (others => '0');
            padding_active            <= false;
            ext_align_offset_ff       <= (others => '0');
            ext_param_is_read_ff      <= '0';
            loc_align_offset_ff       <= (others => '0');
            remaining_ext_words_ff    <= (others => '0');
            remaining_sr_l2e_words_ff <= (others => '0');

            mem_req_remaining_y_words_ff  <= (others => '0');
            mem_req_base_adr_ff           <= (others => '0');
            mem_req_started_next_descr_ff <= '0';
            mem_req_started_cur_descr_ff  <= '0';
            mem_req_cur_descr_done_ff     <= '0';
            mem_req_next_descr_done_ff    <= '0';

            l2e_remaining_x_words_ff <= (others => '0');
            l2e_remaining_y_words_ff <= (others => '0');
            l2e_loc_adr_ff           <= (others => '0');
            l2e_busy_ff              <= '0';
            l2e_next_descr_active_ff <= '0';

            outstanding_mem_req_ff  <= '0';
            next_ext_params_sent_ff <= '0';
        elsif rising_edge(clk_i) then
            transfer_arb_state        <= transfer_arb_state_nxt;
            loc_adr_o_int             <= loc_adr_o_int_nxt;
            mem_adr_o_int             <= mem_adr_o_int_nxt;
            remaining_x_words         <= remaining_x_words_nxt;
            mem_remaining_x_words     <= mem_remaining_x_words_nxt;
            remaining_y_words         <= remaining_y_words_nxt;
            mem_block_adr_offset      <= mem_block_adr_offset_nxt;
            padding_active            <= padding_active_nxt;
            ext_align_offset_ff       <= ext_align_offset_nxt;
            ext_param_is_read_ff      <= ext_param_is_read_nxt;
            loc_align_offset_ff       <= loc_align_offset_nxt;
            remaining_ext_words_ff    <= remaining_ext_words_nxt;
            remaining_sr_l2e_words_ff <= remaining_sr_l2e_words_nxt;

            mem_req_remaining_y_words_ff  <= mem_req_remaining_y_words_nxt;
            mem_req_base_adr_ff           <= mem_req_base_adr_nxt;
            mem_req_started_next_descr_ff <= mem_req_started_next_descr_nxt;
            mem_req_started_cur_descr_ff  <= mem_req_started_cur_descr_nxt;
            mem_req_cur_descr_done_ff     <= mem_req_cur_descr_done_nxt;
            mem_req_next_descr_done_ff    <= mem_req_next_descr_done_nxt;

            l2e_remaining_x_words_ff  <= l2e_remaining_x_words_nxt;
            l2e_remaining_y_words_ff  <= l2e_remaining_y_words_nxt;
            l2e_loc_adr_ff            <= l2e_loc_adr_nxt;
            l2e_busy_ff               <= l2e_busy_nxt;
            l2e_next_descr_active_ff  <= l2e_next_descr_active_nxt;
            l2e_next_descr_active_ff2 <= l2e_next_descr_active_ff;
            l2e_next_descr_active_ff3 <= l2e_next_descr_active_ff2;
            l2e_next_descr_active_ff4 <= l2e_next_descr_active_ff3;
            l2e_next_descr_active_ff5 <= l2e_next_descr_active_ff4;

            outstanding_mem_req_ff  <= outstanding_mem_req_nxt;
            next_ext_params_sent_ff <= next_ext_params_sent_nxt;
        end if;
    end process transfer_arbiter_sync_rst;

    e2l_mem_req_proc : process(current_descriptor.block_y_reg, current_descriptor.pad_bottom, current_descriptor.pad_top, mem_busy_i, padding_width_bottom, padding_width_top, mem_block_adr_offset, mem_req_remaining_y_words_ff, mem_req_base_adr_ff, current_descriptor.ext_base_reg, current_descriptor.dir_reg, next_descriptor.block_y_reg, next_descriptor.dir_reg, next_descriptor.ext_base_reg, next_descriptor_valid, mem_size_o_int, mem_req_started_next_descr_ff, current_descriptor_start, next_descriptor.block_x_reg, next_descriptor.block_stride_reg, next_descriptor.pad_bottom, next_descriptor.pad_left, next_descriptor.pad_right, next_descriptor.pad_top, outstanding_mem_req_ff, mem_req_cur_descr_done_ff, mem_req_next_descr_done_ff, current_descriptor.block_stride_reg, current_descriptor.block_x_reg, current_descriptor.pad_left, current_descriptor.pad_right, padding_width_left, padding_width_right, mem_req_started_cur_descr_ff)
        variable y                       : unsigned(block_y_size_c - 1 downto 0);
        variable size_subtraction_by_pad : unsigned(11 downto 0);
        variable size_final              : unsigned(block_x_size_c - 1 downto 0);
        variable mem_block_adr_offset_v  : unsigned(mem_block_adr_offset'range);
    begin
        -- default
        mem_req_o                      <= '0';
        mem_rw_o                       <= '-';
        mem_req_base_adr_nxt           <= mem_req_base_adr_ff;
        mem_base_adr_o                 <= mem_req_base_adr_ff;
        mem_size_o                     <= mem_size_o_int;
        mem_req_remaining_y_words_nxt  <= mem_req_remaining_y_words_ff;
        mem_req_started_cur_descr_nxt  <= mem_req_started_cur_descr_ff;
        mem_req_started_next_descr_nxt <= mem_req_started_next_descr_ff;
        mem_req_cur_descr_done_nxt     <= mem_req_cur_descr_done_ff;
        mem_req_next_descr_done_nxt    <= mem_req_next_descr_done_ff;

        size_subtraction_by_pad := (others => '0');
        if (current_descriptor.pad_right = '1') and (current_descriptor.pad_left = '1') then
            size_subtraction_by_pad := (padding_width_left) + (padding_width_right);
        elsif (current_descriptor.pad_left = '1') then
            size_subtraction_by_pad := padding_width_left;
        elsif (current_descriptor.pad_right = '1') then
            size_subtraction_by_pad := padding_width_right;
        end if;
        size_final              := unsigned(current_descriptor.block_x_reg(block_x_size_c - 1 downto 0)) - size_subtraction_by_pad;

        mem_block_adr_offset_v := resize((size_final + unsigned(current_descriptor.block_stride_reg) - 1) & "0", mem_block_adr_offset_v'length); -- *2 due to 2-byte elements (mm addressing is byte aligned)

        outstanding_mem_req_nxt <= outstanding_mem_req_ff;

        if mem_req_cur_descr_done_ff = '0' and mem_req_started_cur_descr_ff = '0' and outstanding_mem_req_ff = '1' then
            y := to_unsigned(0, y'length);

            outstanding_mem_req_nxt       <= '0';
            mem_req_started_cur_descr_nxt <= '1';

            if (current_descriptor.dir_reg = '0') and (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom))) then -- first row is always padding, as last row
                mem_req_remaining_y_words_nxt <= unsigned(current_descriptor.block_y_reg) - 1;
                mem_req_base_adr_nxt          <= current_descriptor.ext_base_reg;
            else
                if mem_busy_i = '0' then
                    -- start a request to rd from mm
                    mem_req_o      <= '1';
                    mem_rw_o       <= current_descriptor.dir_reg;
                    mem_base_adr_o <= current_descriptor.ext_base_reg;

                    mem_req_remaining_y_words_nxt <= unsigned(current_descriptor.block_y_reg);
                    mem_req_base_adr_nxt          <= current_descriptor.ext_base_reg;

                    if (mem_busy_i = '0') then
                        mem_req_remaining_y_words_nxt <= unsigned(current_descriptor.block_y_reg) - 1;
                        if (current_descriptor.dir_reg = '0') and (current_descriptor.pad_top = '1' and y < padding_width_top) then
                            mem_req_base_adr_nxt <= current_descriptor.ext_base_reg; -- std_ulogic_vector(unsigned(mem_adr_o_int) + to_unsigned(2, mem_adr_o_int'length));
                        else
                            mem_req_base_adr_nxt <= std_ulogic_vector(unsigned(current_descriptor.ext_base_reg) + mem_block_adr_offset_v);
                        end if;
                    end if;
                else
                    outstanding_mem_req_nxt       <= '1';
                    mem_req_started_cur_descr_nxt <= '0';
                end if;
            end if;
        end if;

        if mem_req_cur_descr_done_ff = '0' and mem_req_started_cur_descr_ff = '1' then
            y := unsigned(current_descriptor.block_y_reg) - mem_req_remaining_y_words_ff;

            if mem_busy_i = '0' then
                -- check if block transfer is completed
                if (mem_req_remaining_y_words_ff /= 0) then -- all words written to lm
                    if (current_descriptor.dir_reg = '0') and (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom))) then -- first row is always padding, as last row
                        mem_req_remaining_y_words_nxt <= unsigned(mem_req_remaining_y_words_ff) - 1;
                    else
                        -- else start new transfer
                        mem_req_o <= '1';
                        mem_rw_o  <= current_descriptor.dir_reg;

                        mem_req_remaining_y_words_nxt <= unsigned(mem_req_remaining_y_words_ff) - 1;
                        mem_req_base_adr_nxt          <= std_ulogic_vector(unsigned(mem_req_base_adr_ff) + mem_block_adr_offset);
                    end if;
                end if;
            end if;
        end if;

        -- wait for all data transfers to finish
        --        if (current_descriptor_done = '1') and (mem_req_remaining_y_words_ff = 0) then
        --            mem_req_busy_nxt <= '0';
        --        end if;

        if mem_req_remaining_y_words_ff = 0 and mem_req_started_cur_descr_ff = '1' then
            mem_req_cur_descr_done_nxt <= '1';
            if mem_req_started_next_descr_ff = '1' then
                mem_req_next_descr_done_nxt <= '1';
            end if;

            if mem_busy_i = '0' and mem_req_started_next_descr_ff = '0' and next_descriptor_valid = '1' and (next_descriptor.dir_reg = '1' or (unsigned(next_descriptor.block_y_reg) = 1 and next_descriptor.pad_left = '0' and next_descriptor.pad_right = '0' and next_descriptor.pad_top = '0' and next_descriptor.pad_bottom = '0')) then -- start mem req of the next req, only if req is 1D or l2e, otherwise there will be problems with padding
                outstanding_mem_req_nxt                     <= '0';
                mem_req_started_next_descr_nxt              <= '1';
                mem_req_o                                   <= '1';
                mem_rw_o                                    <= next_descriptor.dir_reg;
                mem_base_adr_o                              <= next_descriptor.ext_base_reg;
                mem_size_o                                  <= (others => '0');
                mem_size_o(block_x_size_c - 1 + 1 downto 1) <= next_descriptor.block_x_reg; -- +1 due to 2-byte block elements size
                mem_req_remaining_y_words_nxt               <= unsigned(next_descriptor.block_y_reg) - 1;
                mem_req_base_adr_nxt                        <= std_ulogic_vector(unsigned(next_descriptor.ext_base_reg) + ((unsigned(next_descriptor.block_x_reg) + unsigned(next_descriptor.block_stride_reg) - 1) & "0"));
            end if;
        end if;

        if current_descriptor_start = '1' then
            mem_req_started_next_descr_nxt <= '0';
            mem_req_started_cur_descr_nxt  <= '0';
            mem_req_cur_descr_done_nxt     <= '0';
            mem_req_next_descr_done_nxt    <= '0';
            if mem_req_started_next_descr_ff = '1' then
                mem_req_started_cur_descr_nxt <= mem_req_started_next_descr_ff;
                mem_req_cur_descr_done_nxt    <= mem_req_next_descr_done_ff;
            end if;

            outstanding_mem_req_nxt <= '1';
            if mem_req_started_next_descr_ff = '1' and mem_req_started_next_descr_ff = '1' then
                -- request already done, skip
                outstanding_mem_req_nxt <= '0';
            end if;

            if mem_req_remaining_y_words_ff = 0 and mem_req_started_cur_descr_ff = '1' and mem_busy_i = '0' and mem_req_started_next_descr_ff = '0' and next_descriptor_valid = '1' and (next_descriptor.dir_reg = '1' or (unsigned(next_descriptor.block_y_reg) = 1 and next_descriptor.pad_left = '0' and next_descriptor.pad_right = '0' and next_descriptor.pad_top = '0' and next_descriptor.pad_bottom = '0')) then
                outstanding_mem_req_nxt       <= '0';
                mem_req_started_cur_descr_nxt <= '1';
            end if;
        end if;

    end process;

    l2e_lm_rd_en_proc : process(current_descriptor.block_x_reg, current_descriptor.pad_right, padding_width_right, l2e_remaining_x_words_ff, mem_l2e_fifo_full, current_descriptor.loc_base_reg, l2e_loc_adr_ff, current_descriptor.block_y_reg, l2e_remaining_y_words_ff, l2e_busy_ff, next_descriptor.block_x_reg, next_descriptor.block_y_reg, next_descriptor.dir_reg, next_descriptor.loc_base_reg, next_descriptor_valid, l2e_next_descr_active_ff, next_descriptor.pad_right, descrior_arb_state, current_descriptor.dir_reg, start_new_l2e_req)
        variable x                    : unsigned(block_x_size_c - 1 downto 0);
        variable num_cyclewords_loc   : unsigned(align_offset_log2_c downto 0); -- how many words are supposed to be accessed from loc in this cycle?
        variable l2e_loc_align_offset : unsigned(loc_align_offset'range);
    begin
        -- default
        l2e_busy_nxt              <= l2e_busy_ff;
        loc_rden_int              <= '0';
        l2e_remaining_x_words_nxt <= l2e_remaining_x_words_ff;
        l2e_remaining_y_words_nxt <= l2e_remaining_y_words_ff;
        l2e_loc_adr_nxt           <= l2e_loc_adr_ff;
        l2e_next_descr_active_nxt <= l2e_next_descr_active_ff;
        l2e_loc_align_offset      := (others => '0');
        if align_offset_log2_c /= 0 then
            l2e_loc_align_offset := unsigned(l2e_loc_adr_ff(align_offset_log2_c - 1 downto 0));
        end if;

        x                  := unsigned(current_descriptor.block_x_reg) - l2e_remaining_x_words_ff;
        num_cyclewords_loc := (others => '0');
        for I in 0 to 2 ** align_offset_log2_c - 1 loop
            if I >= l2e_loc_align_offset and I - l2e_loc_align_offset < l2e_remaining_x_words_ff then
                if current_descriptor.pad_right = '0' or (x + I - l2e_loc_align_offset < unsigned(current_descriptor.block_x_reg) - padding_width_right) then
                    num_cyclewords_loc := num_cyclewords_loc + 1;
                end if;
            end if;
        end loop;

        if l2e_next_descr_active_ff = '1' then
            x                  := unsigned(next_descriptor.block_x_reg) - l2e_remaining_x_words_ff;
            num_cyclewords_loc := (others => '0');
            for I in 0 to 2 ** align_offset_log2_c - 1 loop
                if I >= l2e_loc_align_offset and I - l2e_loc_align_offset < l2e_remaining_x_words_ff then
                    if next_descriptor.pad_right = '0' or (x + I - l2e_loc_align_offset < unsigned(next_descriptor.block_x_reg) - padding_width_right) then
                        num_cyclewords_loc := num_cyclewords_loc + 1;
                    end if;
                end if;
            end loop;
        end if;

        if start_new_l2e_req = '1' then
            l2e_busy_nxt              <= '1';
            l2e_next_descr_active_nxt <= '0';
            if l2e_next_descr_active_ff = '0' then -- do not start new req if done already
                l2e_remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                l2e_remaining_y_words_nxt <= unsigned(current_descriptor.block_y_reg);
                l2e_loc_adr_nxt           <= current_descriptor.loc_base_reg;
            end if;
        else
            if descrior_arb_state = S_DESCRIPTOR_EXECUTE then
                -- read lm data and write to fifo
                if (mem_l2e_fifo_full = '0') and (l2e_remaining_x_words_ff /= 0) then
                    loc_rden_int              <= '1';
                    l2e_loc_adr_nxt           <= std_ulogic_vector(unsigned(l2e_loc_adr_ff) + num_cyclewords_loc);
                    l2e_remaining_x_words_nxt <= l2e_remaining_x_words_ff - num_cyclewords_loc;
                    if l2e_remaining_x_words_ff - num_cyclewords_loc = 0 then
                        l2e_remaining_y_words_nxt <= l2e_remaining_y_words_ff - 1;
                        if l2e_remaining_y_words_ff - 1 /= 0 then
                            l2e_remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                            if l2e_next_descr_active_ff = '1' then
                                l2e_remaining_x_words_nxt <= unsigned(next_descriptor.block_x_reg);
                            end if;
                        end if;
                    end if;
                end if;

                if (l2e_remaining_x_words_ff = 0 and l2e_remaining_y_words_ff = 0) or (l2e_remaining_x_words_ff - num_cyclewords_loc = 0 and mem_l2e_fifo_full = '0' and l2e_remaining_y_words_ff = 1) then
                    if next_descriptor_valid = '1' and next_descriptor.dir_reg = '1' and current_descriptor.dir_reg = '1' and l2e_next_descr_active_ff = '0' then -- start data loading of the next req, only if req is l2e
                        l2e_next_descr_active_nxt <= '1';
                        l2e_busy_nxt              <= '1';
                        l2e_remaining_x_words_nxt <= unsigned(next_descriptor.block_x_reg);
                        l2e_remaining_y_words_nxt <= unsigned(next_descriptor.block_y_reg);
                        l2e_loc_adr_nxt           <= next_descriptor.loc_base_reg;
                    else
                        l2e_busy_nxt <= '0';
                    end if;
                end if;
            end if;

            --            if current_descriptor_start = '1' then
            --                l2e_next_descr_active_nxt <= '0';
            --            end if;
        end if;
    end process;

    loc_align_offset_gen : if align_offset_log2_c /= 0 generate
        loc_align_offset <= loc_adr_o_int(align_offset_log2_c - 1 downto 0);
    end generate;
    loc_align_offset_constant_gen : if align_offset_log2_c = 0 generate
        loc_align_offset <= (others => '0');
    end generate;

    remaining_ext_words <= std_ulogic_vector(shift_right(unsigned(mem_size_o_int(remaining_ext_words'range)), integer(ceil(log2(real(vpro_data_width_c / 8)))))); -- byte to word conversion

    transfer_arbiter_comb : process(transfer_arb_state, current_descriptor_start, current_descriptor, loc_adr_o_int, mem_adr_o_int, remaining_x_words, remaining_y_words, mem_block_adr_offset, mem_remaining_x_words, mem_l2e_fifo_empty, padding_width_bottom, padding_width_left, padding_width_right, padding_width_top, padding_active, padding_value, loc_align_offset, loc_align_offset_ff, sr_l2e_wr_full, idma_fifo_rdata, sr_e2l_rd_count, sr_e2l_rdata, remaining_sr_l2e_words_ff, mem_req_remaining_y_words_ff, outstanding_mem_req_ff, mem_req_started_next_descr_ff, ext_param_fifo_full, next_ext_params_sent_ff)
        variable x : unsigned(block_x_size_c - 1 downto 0);
        variable y : unsigned(block_y_size_c - 1 downto 0);

        variable size_subtraction_by_pad : unsigned(11 downto 0);
        variable size_final              : unsigned(block_x_size_c - 1 downto 0);

        variable num_cyclewords_loc     : unsigned(align_offset_log2_c downto 0); -- how many words are supposed to be accessed from loc in this cycle?
        variable num_cyclewords_ext     : unsigned(align_offset_log2_c downto 0); -- how many words are supposed to be accessed from ext in this cycle?
        variable num_cyclewords_padding : unsigned(align_offset_log2_c downto 0); -- how many padding words are supposed to be written in this cycle?
        variable already_padded         : boolean;
        variable already_padded_ended   : boolean;
    begin
        transfer_arb_state_nxt     <= transfer_arb_state;
        loc_adr_o_int_nxt          <= loc_adr_o_int;
        mem_adr_o_int_nxt          <= mem_adr_o_int;
        remaining_x_words_nxt      <= remaining_x_words;
        mem_remaining_x_words_nxt  <= mem_remaining_x_words;
        remaining_y_words_nxt      <= remaining_y_words;
        current_descriptor_done    <= '0';
        mem_block_adr_offset_nxt   <= mem_block_adr_offset;
        padding_active_nxt         <= padding_active;
        loc_align_offset_nxt       <= loc_align_offset_ff;
        remaining_sr_l2e_words_nxt <= remaining_sr_l2e_words_ff;
        start_new_l2e_req          <= '0';

        size_subtraction_by_pad := (others => '0');
        if (current_descriptor.pad_right = '1') and (current_descriptor.pad_left = '1') then
            size_subtraction_by_pad := (padding_width_left) + (padding_width_right);
        elsif (current_descriptor.pad_left = '1') then
            size_subtraction_by_pad := padding_width_left;
        elsif (current_descriptor.pad_right = '1') then
            size_subtraction_by_pad := padding_width_right;
        end if;
        size_final              := unsigned(current_descriptor.block_x_reg(block_x_size_c - 1 downto 0)) - size_subtraction_by_pad;

        mem_size_o_int                                  <= (others => '0');
        mem_size_o_int(block_x_size_c - 1 + 1 downto 1) <= std_ulogic_vector(size_final); -- +1 due to 2-byte block elements size
        --        loc_dat_o                                       <= mem_dat_i;
        loc_dat_o                                       <= (others => '-');

        mem_req_o_int    <= '0';
        ext_align_offset <= (others => '0'); -- + 1 for byte to word conversion
        if align_offset_log2_c /= 0 then
            ext_align_offset <= mem_adr_o_int(align_offset_log2_c - 1 + 1 downto 0 + 1); -- + 1 for byte to word conversion
        end if;
        next_ext_params_sent_nxt <= next_ext_params_sent_ff;
        ext_param_is_read        <= '0';

        sr_l2e_wr_en <= (others => '0');
        sr_e2l_rd_en <= (others => '0');
        loc_wren_int <= (others => '0');
        --        loc_rden_int  <= '0';
        fsm_busy     <= '1';

        sr_l2e_wdata    <= (others => '-');
        idma_fifo_rd_en <= '0';

        x                  := unsigned(current_descriptor.block_x_reg) - remaining_x_words;
        num_cyclewords_loc := (others => '0');
        for I in 0 to 2 ** align_offset_log2_c - 1 loop
            if I >= unsigned(loc_align_offset) and I - unsigned(loc_align_offset) < remaining_x_words then
                if current_descriptor.pad_right = '0' or (x + I - unsigned(loc_align_offset) < unsigned(current_descriptor.block_x_reg) - padding_width_right) then
                    num_cyclewords_loc := num_cyclewords_loc + 1;
                end if;
            end if;
        end loop;

        y                      := unsigned(current_descriptor.block_y_reg) - (remaining_y_words + 1);
        num_cyclewords_padding := (others => '0');
        already_padded         := false;
        already_padded_ended   := false;
        for I in 0 to 2 ** align_offset_log2_c - 1 loop
            if I >= unsigned(loc_align_offset) and I - unsigned(loc_align_offset) < remaining_x_words then
                if (not already_padded_ended) and (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom)) or ((x + I - unsigned(loc_align_offset) < padding_width_left) and (current_descriptor.pad_left = '1')) or ((x + I - unsigned(loc_align_offset) >= unsigned(current_descriptor.block_x_reg) - padding_width_right) and (current_descriptor.pad_right = '1'))) then
                    num_cyclewords_padding := num_cyclewords_padding + 1;
                    already_padded         := true;
                elsif already_padded then
                    already_padded_ended := true;
                end if;
            end if;
        end loop;

        num_cyclewords_ext := (others => '0');
        for I in 0 to 2 ** align_offset_log2_c - 1 loop
            if I >= unsigned(loc_align_offset_ff) and I - unsigned(loc_align_offset_ff) < unsigned(remaining_sr_l2e_words_ff) then
                num_cyclewords_ext := num_cyclewords_ext + 1;
            end if;
        end loop;

        -- FSM for MM signals --
        case transfer_arb_state is
            when S_IDLE =>
                fsm_busy <= '0';
                if current_descriptor_start = '1' then
                    fsm_busy              <= '1';
                    loc_adr_o_int_nxt     <= current_descriptor.loc_base_reg;
                    mem_adr_o_int_nxt     <= current_descriptor.ext_base_reg;
                    remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg); -- redundant due to assign in REQ state
                    remaining_y_words_nxt <= unsigned(current_descriptor.block_y_reg);

                    loc_align_offset_nxt <= (others => '0');
                    if align_offset_log2_c /= 0 then
                        loc_align_offset_nxt <= current_descriptor.loc_base_reg(align_offset_log2_c - 1 downto 0);
                    end if;

                    mem_block_adr_offset_nxt <= resize((size_final + unsigned(current_descriptor.block_stride_reg) - 1) & "0", mem_block_adr_offset_nxt'length); -- *2 due to 2-byte elements (mm addressing is byte aligned)

                    if current_descriptor.dir_reg = '0' then
                        transfer_arb_state_nxt <= S_E2L_REQUEST;

                        x := to_unsigned(0, block_x_size_c);
                        y := to_unsigned(0, block_y_size_c);

                        padding_active_nxt <= (((y < padding_width_top) and (current_descriptor.pad_top = '1')) or ((y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom) and (current_descriptor.pad_bottom = '1')) or ((x < padding_width_left) and (current_descriptor.pad_left = '1')) or ((x >= unsigned(current_descriptor.block_x_reg) - padding_width_right) and (current_descriptor.pad_right = '1')));

                        if (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom))) then -- first row is always padding, as last row
                            remaining_x_words_nxt  <= unsigned(current_descriptor.block_x_reg);
                            remaining_y_words_nxt  <= unsigned(current_descriptor.block_y_reg) - 1;
                            transfer_arb_state_nxt <= S_E2L;
                        else
                            if ext_param_fifo_full = '0' then
                                -- start a request to rd from mm
                                --                    mem_req_e2l <= '1';
                                --                    mem_rw_e2l  <= '0';
                                --                    if (mem_busy_i = '0') then -- TODO: registered inputs?
                                mem_req_o_int     <= '1';
                                ext_param_is_read <= '1';
                                ext_align_offset  <= (others => '0'); -- + 1 for byte to word conversion
                                if align_offset_log2_c /= 0 then
                                    ext_align_offset <= current_descriptor.ext_base_reg(align_offset_log2_c - 1 + 1 downto 0 + 1); -- + 1 for byte to word conversion
                                end if;
                                mem_adr_o_int_nxt        <= std_ulogic_vector(unsigned(current_descriptor.ext_base_reg) + unsigned((size_final + unsigned(current_descriptor.block_stride_reg) - 1) & "0"));
                                next_ext_params_sent_nxt <= '0';
                                remaining_x_words_nxt    <= unsigned(current_descriptor.block_x_reg);
                                remaining_y_words_nxt    <= unsigned(current_descriptor.block_y_reg) - 1;
                                transfer_arb_state_nxt   <= S_E2L;
                                --                    end if;
                            end if;
                        end if;
                    else
                        transfer_arb_state_nxt <= S_L2E_REQUEST;

                        if ext_param_fifo_full = '0' then
                            -- start a request to wr to mm
                            start_new_l2e_req <= '1';
                            mem_req_o_int     <= '1';
                            mem_adr_o_int_nxt <= std_ulogic_vector(unsigned(current_descriptor.ext_base_reg) + unsigned((size_final + unsigned(current_descriptor.block_stride_reg) - 1) & "0"));
                            ext_align_offset  <= (others => '0');
                            if align_offset_log2_c /= 0 then
                                ext_align_offset <= current_descriptor.ext_base_reg(align_offset_log2_c - 1 + 1 downto 0 + 1); -- + 1 for byte to word conversion
                            end if;
                            --                remaining_x_words_nxt      <= unsigned(current_descriptor.block_x_reg);
                            remaining_sr_l2e_words_nxt <= std_ulogic_vector(unsigned(current_descriptor.block_x_reg));
                            --                    mem_remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                            remaining_y_words_nxt      <= unsigned(current_descriptor.block_y_reg) - 1;

                            loc_align_offset_nxt   <= (others => '0'); -- + 1 for byte to word conversion
                            if align_offset_log2_c /= 0 then
                                loc_align_offset_nxt <= current_descriptor.loc_base_reg(align_offset_log2_c - 1 downto 0);
                            end if;
                            transfer_arb_state_nxt <= S_L2E;
                        end if;
                    end if;
                end if;

            when S_E2L_REQUEST =>
                x := to_unsigned(0, block_x_size_c);
                y := unsigned(current_descriptor.block_y_reg) - (remaining_y_words);

                padding_active_nxt <= (((y < padding_width_top) and (current_descriptor.pad_top = '1')) or ((y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom) and (current_descriptor.pad_bottom = '1')) or ((x < padding_width_left) and (current_descriptor.pad_left = '1')) or ((x >= unsigned(current_descriptor.block_x_reg) - padding_width_right) and (current_descriptor.pad_right = '1')));

                if (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom))) then -- first row is always padding, as last row
                    remaining_x_words_nxt  <= unsigned(current_descriptor.block_x_reg);
                    remaining_y_words_nxt  <= remaining_y_words - 1;
                    transfer_arb_state_nxt <= S_E2L;
                else
                    if ext_param_fifo_full = '0' then
                        -- start a request to rd from mm
                        --                    mem_req_e2l <= '1';
                        --                    mem_rw_e2l  <= '0';
                        --                    if (mem_busy_i = '0') then -- TODO: registered inputs?
                        mem_req_o_int            <= '1';
                        ext_param_is_read        <= '1';
                        mem_adr_o_int_nxt        <= std_ulogic_vector(unsigned(mem_adr_o_int) + mem_block_adr_offset);
                        next_ext_params_sent_nxt <= '0';
                        remaining_x_words_nxt    <= unsigned(current_descriptor.block_x_reg);
                        remaining_y_words_nxt    <= remaining_y_words - 1;
                        transfer_arb_state_nxt   <= S_E2L;
                        --                    end if;
                    end if;
                end if;

            -- PADDING:
            --DMA loads from address: base + y * (x_end + stride) + x [common]
            --
            --4 COMPARE to decide if this index is a padded index:
            --y < width top
            --y > y_end - width bottom
            --x < width left
            --x > x_end - width right
            --
            --2 SUB (for above compare)
            --4 MUX (is flag for top/bottom/left/right in current cmd active)
            --1 OR4 to combine possibilities of padding
            --1 MUX to select pad value instead LM data if padding

            when S_E2L =>
                x := unsigned(current_descriptor.block_x_reg) - remaining_x_words;
                y := unsigned(current_descriptor.block_y_reg) - (remaining_y_words + 1);

                -- TODO: maybe register loc data write to cut critical path?

                if (padding_active) then
                    -- read padding data 
                    already_padded       := false;
                    already_padded_ended := false;
                    for I in 0 to 2 ** align_offset_log2_c - 1 loop
                        loc_dat_o((I + 1) * vpro_data_width_c - 1 downto I * vpro_data_width_c) <= std_ulogic_vector(padding_value);
                        if I >= unsigned(loc_align_offset) and I - unsigned(loc_align_offset) < remaining_x_words then
                            if (not already_padded_ended) and (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom)) or ((x + I - unsigned(loc_align_offset) < padding_width_left) and (current_descriptor.pad_left = '1')) or ((x + I - unsigned(loc_align_offset) >= unsigned(current_descriptor.block_x_reg) - padding_width_right) and (current_descriptor.pad_right = '1'))) then
                                loc_wren_int(I) <= '1';
                                already_padded  := true;
                            elsif already_padded then
                                already_padded_ended := true;
                            end if;
                        end if;
                    end loop;
                elsif (unsigned(sr_e2l_rd_count) >= num_cyclewords_loc) then
                    -- read mm data
                    for I in 0 to 2 ** align_offset_log2_c - 1 loop
                        if I + unsigned('0' & loc_align_offset) < 2 ** align_offset_log2_c and I < remaining_x_words then
                            loc_dat_o((1 + I + to_integer(unsigned(loc_align_offset))) * vpro_data_width_c - 1 downto (I + to_integer(unsigned(loc_align_offset))) * vpro_data_width_c) <= sr_e2l_rdata((I + 1) * vpro_data_width_c - 1 downto I * vpro_data_width_c);
                        end if;
                    end loop;
                    sr_e2l_rd_en <= std_ulogic_vector(num_cyclewords_loc);

                    for I in 0 to 2 ** align_offset_log2_c - 1 loop
                        if I >= unsigned(loc_align_offset) and I - unsigned(loc_align_offset) < remaining_x_words then
                            if current_descriptor.pad_right = '0' or (x + I - unsigned(loc_align_offset) < unsigned(current_descriptor.block_x_reg) - padding_width_right) then
                                loc_wren_int(I) <= '1';
                            end if;
                        end if;
                    end loop;
                end if;

                -- if data read, write to LM
                if (padding_active and remaining_x_words /= 0) or (unsigned(sr_e2l_rd_count) >= num_cyclewords_loc) then
                    --                    remaining_x_words_nxt <= remaining_x_words - 1;
                    --                    loc_wren_int          <= '1';
                    --                    loc_adr_o_int_nxt     <= std_ulogic_vector(unsigned(loc_adr_o_int) + 1);

                    x                     := unsigned(current_descriptor.block_x_reg) - remaining_x_words + num_cyclewords_loc;
                    remaining_x_words_nxt <= remaining_x_words - num_cyclewords_loc;
                    loc_adr_o_int_nxt     <= std_ulogic_vector(unsigned(loc_adr_o_int) + num_cyclewords_loc);

                    --                    if (remaining_y_words = 0) and (remaining_x_words - num_cyclewords_loc = 0) and mem_rrdy_i = '1' then
                    --                        current_descriptor_done <= '1';
                    --                        transfer_arb_state_nxt  <= S_IDLE;
                    --                    end if;

                    if (padding_active and remaining_x_words /= 0) then
                        x                     := unsigned(current_descriptor.block_x_reg) - remaining_x_words + num_cyclewords_padding;
                        remaining_x_words_nxt <= remaining_x_words - num_cyclewords_padding;
                        loc_adr_o_int_nxt     <= std_ulogic_vector(unsigned(loc_adr_o_int) + num_cyclewords_padding);

                        --                        if (remaining_y_words = 0) and (remaining_x_words - num_cyclewords_padding = 0) then
                        --                            current_descriptor_done <= '1';
                        --                            transfer_arb_state_nxt  <= S_IDLE;
                        --                        end if;
                    end if;

                    padding_active_nxt <= (((y < padding_width_top) and (current_descriptor.pad_top = '1')) or ((y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom) and (current_descriptor.pad_bottom = '1')) or ((x < padding_width_left) and (current_descriptor.pad_left = '1')) or ((x >= unsigned(current_descriptor.block_x_reg) - padding_width_right) and (current_descriptor.pad_right = '1')));

                    if ((remaining_x_words = num_cyclewords_loc) and not padding_active) or ((remaining_x_words = num_cyclewords_padding) and padding_active) then -- all words written to lm
                        if (remaining_y_words = 0) then
                            if (outstanding_mem_req_ff = '0') then
                                current_descriptor_done <= '1';
                                transfer_arb_state_nxt  <= S_IDLE;
                            end if;
                        else            -- new request required
                            y := unsigned(current_descriptor.block_y_reg) - (remaining_y_words);
                            if (current_descriptor.pad_top = '1' and y < padding_width_top) then
                                mem_adr_o_int_nxt <= mem_adr_o_int; -- std_ulogic_vector(unsigned(mem_adr_o_int) + to_unsigned(2, mem_adr_o_int'length));
                            else
                                mem_adr_o_int_nxt <= std_ulogic_vector(unsigned(mem_adr_o_int) + mem_block_adr_offset);
                            end if;

                            --                        transfer_arb_state_nxt <= S_E2L_REQUEST;

                            x := to_unsigned(0, block_x_size_c);
                            y := unsigned(current_descriptor.block_y_reg) - (remaining_y_words);

                            padding_active_nxt <= (((y < padding_width_top) and (current_descriptor.pad_top = '1')) or ((y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom) and (current_descriptor.pad_bottom = '1')) or ((x < padding_width_left) and (current_descriptor.pad_left = '1')) or ((x >= unsigned(current_descriptor.block_x_reg) - padding_width_right) and (current_descriptor.pad_right = '1')));

                            if (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom))) then -- first row is always padding, as last row
                                remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                                remaining_y_words_nxt <= remaining_y_words - 1;
                            --                                next_ext_params_sent_nxt <= '0';
                            --                            transfer_arb_state_nxt <= S_E2L;
                            else
                                if ext_param_fifo_full = '0' then
                                    -- start a request to rd from mm
                                    --                    mem_req_e2l <= '1';
                                    --                    mem_rw_e2l  <= '0';
                                    --                    if (mem_busy_i = '0') then -- TODO: registered inputs?
                                    next_ext_params_sent_nxt <= '0';
                                    if next_ext_params_sent_ff = '0' then
                                        mem_req_o_int     <= '1';
                                        ext_param_is_read <= '1';
                                        ext_align_offset  <= (others => '0'); -- + 1 for byte to word conversion
                                        if align_offset_log2_c /= 0 then
                                            ext_align_offset <= mem_adr_o_int(align_offset_log2_c - 1 + 1 downto 0 + 1); -- + 1 for byte to word conversion
                                        end if;
                                    end if;
                                    remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                                    remaining_y_words_nxt <= remaining_y_words - 1;
                                    --                                transfer_arb_state_nxt <= S_E2L;
                                    --                    end if;
                                end if;
                            end if;
                        end if;
                    end if;
                end if;

                -- check if block transfer is completed
                if (remaining_x_words = 0) then -- all words written to lm
                    if (remaining_y_words = 0) then
                        if (outstanding_mem_req_ff = '0') then
                            current_descriptor_done <= '1';
                            transfer_arb_state_nxt  <= S_IDLE;
                        end if;
                    else                -- new request required
                        if (current_descriptor.pad_top = '1' and y < padding_width_top) then
                            mem_adr_o_int_nxt <= mem_adr_o_int; -- std_ulogic_vector(unsigned(mem_adr_o_int) + to_unsigned(2, mem_adr_o_int'length));
                        else
                            mem_adr_o_int_nxt <= std_ulogic_vector(unsigned(mem_adr_o_int) + mem_block_adr_offset);
                        end if;

                        --                        transfer_arb_state_nxt <= S_E2L_REQUEST;

                        x := to_unsigned(0, block_x_size_c);
                        y := unsigned(current_descriptor.block_y_reg) - (remaining_y_words);

                        padding_active_nxt <= (((y < padding_width_top) and (current_descriptor.pad_top = '1')) or ((y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom) and (current_descriptor.pad_bottom = '1')) or ((x < padding_width_left) and (current_descriptor.pad_left = '1')) or ((x >= unsigned(current_descriptor.block_x_reg) - padding_width_right) and (current_descriptor.pad_right = '1')));

                        if (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom))) then -- first row is always padding, as last row
                            remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                            remaining_y_words_nxt <= remaining_y_words - 1;
                        --                            next_ext_params_sent_nxt <= '0';
                        --                            transfer_arb_state_nxt <= S_E2L;
                        else
                            if ext_param_fifo_full = '0' then
                                -- start a request to rd from mm
                                --                    mem_req_e2l <= '1';
                                --                    mem_rw_e2l  <= '0';
                                --                    if (mem_busy_i = '0') then -- TODO: registered inputs?
                                next_ext_params_sent_nxt <= '0';
                                if next_ext_params_sent_ff = '0' then
                                    mem_req_o_int     <= '1';
                                    ext_param_is_read <= '1';
                                    ext_align_offset  <= (others => '0'); -- + 1 for byte to word conversion
                                    if align_offset_log2_c /= 0 then
                                        ext_align_offset <= mem_adr_o_int(align_offset_log2_c - 1 + 1 downto 0 + 1); -- + 1 for byte to word conversion
                                    end if;
                                end if;
                                remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                                remaining_y_words_nxt <= remaining_y_words - 1;
                                --                                transfer_arb_state_nxt <= S_E2L;
                                --                    end if;
                            end if;
                        end if;
                    end if;
                end if;

                if next_ext_params_sent_ff = '0' and remaining_y_words /= 0 and (((remaining_x_words /= num_cyclewords_loc) and not padding_active) or ((remaining_x_words /= num_cyclewords_padding) and padding_active)) then
                    y := unsigned(current_descriptor.block_y_reg) - (remaining_y_words);
                    if (((current_descriptor.pad_top = '1') and (y < padding_width_top)) or ((current_descriptor.pad_bottom = '1') and (y >= unsigned(current_descriptor.block_y_reg) - padding_width_bottom))) then -- first row is always padding, as last row
                    --                        next_ext_params_sent_nxt <= '1';
                    else
                        if ext_param_fifo_full = '0' then
                            next_ext_params_sent_nxt <= '1';
                            mem_req_o_int            <= '1';
                            ext_param_is_read        <= '1';
                            ext_align_offset         <= (others => '0'); -- + 1 for byte to word conversion
                            if align_offset_log2_c /= 0 then
                                ext_align_offset <= mem_adr_o_int(align_offset_log2_c - 1 + 1 downto 0 + 1); -- + 1 for byte to word conversion
                            end if;
                        end if;
                    end if;
                end if;

            when S_L2E_REQUEST =>
                if ext_param_fifo_full = '0' then
                    start_new_l2e_req          <= '1';
                    -- start a request to wr to mm
                    mem_req_o_int              <= '1';
                    mem_adr_o_int_nxt          <= std_ulogic_vector(unsigned(mem_adr_o_int) + mem_block_adr_offset);
                    --                remaining_x_words_nxt      <= unsigned(current_descriptor.block_x_reg);
                    remaining_sr_l2e_words_nxt <= std_ulogic_vector(unsigned(current_descriptor.block_x_reg));
                    --                    mem_remaining_x_words_nxt <= unsigned(current_descriptor.block_x_reg);
                    remaining_y_words_nxt      <= remaining_y_words - 1;
                    loc_align_offset_nxt       <= (others => '0');
                    if align_offset_log2_c /= 0 then
                        loc_align_offset_nxt <= loc_adr_o_int(align_offset_log2_c - 1 downto 0);
                    end if;
                    transfer_arb_state_nxt     <= S_L2E;
                end if;

            when S_L2E =>
                --                -- read lm data and write to fifo
                --                if (mem_l2e_fifo_full = '0') and (remaining_x_words /= 0) then
                --                    loc_rden_int          <= '1';
                --                    loc_adr_o_int_nxt     <= std_ulogic_vector(unsigned(loc_adr_o_int) + num_cyclewords_loc);
                --                                    remaining_x_words_nxt <= remaining_x_words - num_cyclewords_loc;
                --                end if;

                -- read fifo and write to mm
                if (sr_l2e_wr_full = '0') and (mem_l2e_fifo_empty = '0') and (unsigned(remaining_sr_l2e_words_ff) /= 0) then
                    idma_fifo_rd_en <= '1';
                    sr_l2e_wr_en    <= std_ulogic_vector(num_cyclewords_ext);
                    for I in 0 to 2 ** align_offset_log2_c - 1 loop
                        if I + unsigned('0' & loc_align_offset_ff) < 2 ** align_offset_log2_c and I < unsigned(remaining_sr_l2e_words_ff) then
                            sr_l2e_wdata((I + 1) * vpro_data_width_c - 1 downto I * vpro_data_width_c) <= idma_fifo_rdata((1 + I + to_integer(unsigned(loc_align_offset_ff))) * vpro_data_width_c - 1 downto (I + to_integer(unsigned(loc_align_offset_ff))) * vpro_data_width_c);
                        end if;
                    end loop;

                    loc_align_offset_nxt       <= (others => '0');
                    remaining_sr_l2e_words_nxt <= std_ulogic_vector(unsigned(remaining_sr_l2e_words_ff) - num_cyclewords_ext);
                    loc_adr_o_int_nxt          <= std_ulogic_vector(unsigned(loc_adr_o_int) + num_cyclewords_ext);

                    if (unsigned(remaining_sr_l2e_words_ff) = num_cyclewords_ext) then
                        if (remaining_y_words = 0) then
                            if (mem_req_remaining_y_words_ff = 0 or mem_req_started_next_descr_ff = '1') and outstanding_mem_req_ff = '0' then
                                --                            if outstanding_mem_req_ff = '0' then
                                current_descriptor_done <= '1';
                                transfer_arb_state_nxt  <= S_IDLE;
                            end if;
                        elsif ext_param_fifo_full = '0' then -- new request required
                            mem_req_o_int              <= '1';
                            remaining_sr_l2e_words_nxt <= std_ulogic_vector(unsigned(current_descriptor.block_x_reg));
                            remaining_y_words_nxt      <= remaining_y_words - 1;
                            loc_align_offset_nxt       <= (others => '0');
                            if align_offset_log2_c /= 0 then
                                loc_align_offset_nxt <= std_ulogic_vector(resize(unsigned(loc_adr_o_int) + num_cyclewords_ext, align_offset_log2_c));
                            end if;
                            mem_adr_o_int_nxt          <= std_ulogic_vector(unsigned(mem_adr_o_int) + mem_block_adr_offset);
                        end if;
                    end if;
                end if;

                if (unsigned(remaining_sr_l2e_words_ff) = 0) then -- all words written to fifo
                    --                    if (unsigned(sr_l2e_rd_count) = 0) or (unsigned(remaining_ext_words_ff) = unsigned(sr_l2e_rd_count) and mem_wrdy_i = '1') then -- continue with new request when data shift (lm->mm) fifo is empty again
                    if (remaining_y_words = 0) then
                        if (mem_req_remaining_y_words_ff = 0 or mem_req_started_next_descr_ff = '1') and outstanding_mem_req_ff = '0' then
                            --                            if outstanding_mem_req_ff = '0' then
                            current_descriptor_done <= '1';
                            transfer_arb_state_nxt  <= S_IDLE;
                        end if;
                    elsif ext_param_fifo_full = '0' then -- new request required
                        mem_req_o_int              <= '1';
                        remaining_sr_l2e_words_nxt <= std_ulogic_vector(unsigned(current_descriptor.block_x_reg));
                        remaining_y_words_nxt      <= remaining_y_words - 1;
                        loc_align_offset_nxt       <= (others => '0');
                        if align_offset_log2_c /= 0 then
                            loc_align_offset_nxt <= loc_adr_o_int(align_offset_log2_c - 1 downto 0);
                        end if;
                        mem_adr_o_int_nxt          <= std_ulogic_vector(unsigned(mem_adr_o_int) + mem_block_adr_offset);
                    end if;
                    --                    end if;
                end if;

        end case;
    end process transfer_arbiter_comb;

    idma_shift_reg_ext_2_loc_inst : idma_shift_reg
        generic map(
            DATA_WIDTH      => mm_data_width_c,
            SUBDATA_WIDTH   => vpro_data_width_c,
            DATA_DEPTH_LOG2 => 2
        )
        port map(
            clk      => clk_i,
            reset_n  => rst_i,
            wr_full  => sr_e2l_wr_full,
            wr_en    => sr_e2l_wr_en,
            wdata    => sr_e2l_wdata,
            rd_count => sr_e2l_rd_count,
            rd_en    => sr_e2l_rd_en,
            rdata    => sr_e2l_rdata
        );

    idma_shift_reg_loc_2_ext_inst : idma_shift_reg
        generic map(
            DATA_WIDTH      => mm_data_width_c,
            SUBDATA_WIDTH   => vpro_data_width_c,
            DATA_DEPTH_LOG2 => 2
        )
        port map(
            clk      => clk_i,
            reset_n  => rst_i,
            wr_full  => sr_l2e_wr_full,
            wr_en    => sr_l2e_wr_en,
            wdata    => sr_l2e_wdata,
            rd_count => sr_l2e_rd_count,
            rd_en    => sr_l2e_rd_en,
            rdata    => sr_l2e_rdata
        );

    idma_shift_reg_comb : process(mem_rrdy_i, ext_align_offset_ff, sr_e2l_wr_full, remaining_ext_words_ff, sr_l2e_rd_count, sr_l2e_rdata, mem_wrdy_i, ext_param_fifo_empty, ext_param_fifo_rdata, ext_align_offset, mem_req_o_int, remaining_ext_words, mem_dat_i, ext_param_is_read_ff, ext_param_is_read)
        variable num_cyclewords : unsigned(align_offset_log2_c downto 0); -- how many subwords where accessed this cycle?
    begin
        -- default
        num_cyclewords          := (others => '0');
        sr_e2l_wr_en            <= (others => '0');
        sr_l2e_rd_en            <= (others => '0');
        ext_align_offset_nxt    <= ext_align_offset_ff;
        remaining_ext_words_nxt <= remaining_ext_words_ff;
        sr_e2l_wdata            <= (others => '-');
        mem_dat_o               <= std_ulogic_vector(shift_left(unsigned(sr_l2e_rdata), vpro_data_width_c * to_integer(unsigned(ext_align_offset_ff))));
        mem_wr_last_o           <= '0';
        mem_wren_o              <= '0';
        mem_rden_o              <= '0';
        ext_param_fifo_rden     <= '0';
        ext_param_fifo_wren     <= mem_req_o_int;
        ext_param_is_read_nxt   <= ext_param_is_read_ff;

        for I in 0 to 2 ** align_offset_log2_c - 1 loop
            if I >= unsigned(ext_align_offset_ff) and I - unsigned(ext_align_offset_ff) < unsigned(remaining_ext_words_ff) then
                num_cyclewords := num_cyclewords + 1;
            end if;
        end loop;

        if mem_rrdy_i = '1' and sr_e2l_wr_full = '0' and unsigned(remaining_ext_words_ff) > 0 and ext_param_is_read_ff = '1' then
            mem_rden_o           <= '1';
            ext_align_offset_nxt <= (others => '0');

            sr_e2l_wr_en <= std_ulogic_vector(num_cyclewords);
            sr_e2l_wdata <= std_ulogic_vector(shift_right(unsigned(mem_dat_i), vpro_data_width_c * to_integer(unsigned(ext_align_offset_ff))));

            remaining_ext_words_nxt <= std_ulogic_vector(unsigned(remaining_ext_words_ff) - num_cyclewords);
        end if;

        if mem_wrdy_i = '1' and unsigned(sr_l2e_rd_count) >= num_cyclewords and unsigned(remaining_ext_words_ff) /= 0 and ext_param_is_read_ff = '0' then
            mem_wren_o           <= '1';
            ext_align_offset_nxt <= (others => '0');

            sr_l2e_rd_en <= std_ulogic_vector(num_cyclewords);

            remaining_ext_words_nxt <= std_ulogic_vector(unsigned(remaining_ext_words_ff) - num_cyclewords);

            if unsigned(remaining_ext_words_ff) - num_cyclewords = 0 then
                mem_wr_last_o <= '1';
            end if;
        end if;

        --        if mem_req_o_int = '1' then
        if ((unsigned(remaining_ext_words_ff) <= unsigned(sr_l2e_rd_count) and unsigned(remaining_ext_words_ff) = num_cyclewords and mem_wrdy_i = '1') or (unsigned(remaining_ext_words_ff) = num_cyclewords and mem_rrdy_i = '1' and sr_e2l_wr_full = '0') or unsigned(remaining_ext_words_ff) = 0) then
            if ext_param_fifo_empty = '0' then
                ext_param_fifo_rden     <= '1';
                remaining_ext_words_nxt <= ext_param_fifo_rdata(ext_align_offset_nxt'length + remaining_ext_words_nxt'length - 1 downto ext_align_offset_nxt'length); --std_ulogic_vector(shift_right(unsigned(mem_size_o_int(remaining_ext_words_nxt'range)), integer(ceil(log2(real(vpro_data_width_c / 8)))))); -- byte to word conversion
                ext_align_offset_nxt    <= ext_param_fifo_rdata(ext_align_offset_nxt'range); --mem_adr_o_int(align_offset_log2_c - 1 + 1 downto 0 + 1); -- + 1 for byte to word conversion
                ext_param_is_read_nxt   <= ext_param_fifo_rdata(ext_align_offset_nxt'length + remaining_ext_words_nxt'length);
            elsif mem_req_o_int = '1' then
                ext_param_fifo_wren     <= '0';
                remaining_ext_words_nxt <= remaining_ext_words;
                ext_align_offset_nxt    <= ext_align_offset;
                ext_param_is_read_nxt   <= ext_param_is_read;
            end if;
        end if;
    end process;

    ext_param_fifo_inst : sync_fifo
        generic map(
            DATA_WIDTH     => remaining_ext_words'length + ext_align_offset'length + 1,
            NUM_ENTRIES    => 2,
            NUM_SFULL      => 0,
            DIRECT_OUT     => true,
            DIRECT_OUT_REG => false
        )
        port map(
            clk_i    => clk_i,
            rst_i    => rst_i,
            wdata_i  => ext_param_fifo_wdata,
            we_i     => ext_param_fifo_wren,
            wfull_o  => ext_param_fifo_full,
            wsfull_o => open,
            rdata_o  => ext_param_fifo_rdata,
            re_i     => ext_param_fifo_rden,
            rempty_o => ext_param_fifo_empty
        );

    ext_param_fifo_wdata <= ext_param_is_read & remaining_ext_words & ext_align_offset;

    -- Debugging Stuff ----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    debug_fifo_check : process(io_clk_i)
    begin
        if rising_edge(io_clk_i) then
            if io_rst_i /= active_reset_c then
                assert (queue_full /= '1') report "DMA descriptor FIFO overflow!" severity error;
            end if;
        end if;
    end process debug_fifo_check;

    -- Read Status Registers ----------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    config_regs_rd : process(io_clk_i)
    begin
        if rising_edge(io_clk_i) then
            busy_sync1 <= fifo_busy & fsm_busy; -- CDC
            busy_sync2 <= busy_sync1;   -- CDC

            dma_busy_int <= '0';
            if ((busy_sync2(0) = '1') or (busy_sync2(1) = '1') or (queue_full = '1') or descriptor_issue = '1' or (to_integer(unsigned(descriptor_issue_ff)) /= 0)) then
                dma_busy_int <= '1';
            end if;

            io_data_o <= (others => '0');
            if (io_ren_i = '1') and (io_adr_i(io_addr_dma_busy_addr_c'range) = io_addr_dma_busy_addr_c) then
                io_data_o(2 downto 0) <= queue_sfull & busy_sync2;
            end if;
        end if;
    end process config_regs_rd;

    dma_busy_o <= dma_busy_int;

    -- DMA Descriptor Queue --------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------
    idma_cmd_full_o <= queue_sfull;

    assert_check_mask : process(clk_i)
        variable unit_mask_extend_v : std_ulogic_vector(lm_broadcast_mask_size_c - 1 downto 0);
    begin
        if falling_edge(clk_i) and io_rst_i /= active_reset_c then
            if ((idma_cmd_we_i = '1') and (idma_cmd_i.cluster(CLUSTER_ID) = '1')) then
                unit_mask_extend_v := (others => '0');

                -- only use 'num_vu bits of the mask
                if (lm_broadcast_mask_size_c > dma_cmd_unit_mask_len_c) then
                    unit_mask_extend_v(dma_cmd_unit_mask_len_c - 1 downto 0) := idma_cmd_i.unit_mask;
                else
                    unit_mask_extend_v(lm_broadcast_mask_size_c - 1 downto 0) := idma_cmd_i.unit_mask(lm_broadcast_mask_size_c - 1 downto 0);
                end if;
                if (unsigned(unit_mask_extend_v) = 0) and (not queue_full) = '1' then
                    report "[ERROR] DMA host created (dma direct in) Command has no unit selected (unit mask)!" severity failure;
                end if;
            end if;
        end if;
    end process;

    desc_fifo_in : process(queue_full, idma_cmd_i, idma_cmd_we_i)
        variable unit_mask_extend_v : std_ulogic_vector(lm_broadcast_mask_size_c - 1 downto 0);
    begin
        -- FIFO we --
        descriptor_issue <= '0';

        descriptor_in      <= (others => '0');
        unit_mask_extend_v := (others => '0');

        -- only use 'num_vu bits of the mask
        if (lm_broadcast_mask_size_c > dma_cmd_unit_mask_len_c) then
            unit_mask_extend_v(dma_cmd_unit_mask_len_c - 1 downto 0) := idma_cmd_i.unit_mask;
        else
            unit_mask_extend_v(lm_broadcast_mask_size_c - 1 downto 0) := idma_cmd_i.unit_mask(lm_broadcast_mask_size_c - 1 downto 0);
        end if;

        descriptor_in <= idma_cmd_i.dir & idma_cmd_i.pad & unit_mask_extend_v & idma_cmd_i.ext_base & idma_cmd_i.loc_base & idma_cmd_i.x_size & idma_cmd_i.y_size & idma_cmd_i.x_stride;

        if ((idma_cmd_we_i = '1') and (idma_cmd_i.cluster(CLUSTER_ID) = '1')) then
            descriptor_issue <= (not queue_full);
        end if;
    end process;

    -- for the busy signal of the dma, first cycles after write will indicate busy!
    descriptor_start_ff : process(io_clk_i, io_rst_i)
    begin
        if (io_rst_i = active_reset_c) then
            descriptor_issue_ff <= (others => '0');
        elsif rising_edge(io_clk_i) then
            descriptor_issue_ff(0)                                 <= descriptor_issue;
            descriptor_issue_ff(descriptor_issue_ff'left downto 1) <= descriptor_issue_ff(descriptor_issue_ff'left - 1 downto 0);
        end if;
    end process;

    -- Descriptor FIFO --
    descriptor_queue : cdc_fifo
        generic map(
            DATA_WIDTH  => descriptor_size_c, -- data width of FIFO entries
            NUM_ENTRIES => descriptor_queue_depth_c, -- number of FIFO entries, should be a power of 2!
            NUM_SYNC_FF => num_idma_sync_ff_c, -- number of synchronization FF stages
            NUM_SFULL   => 4            -- offset between RD and WR for issueing 'special full' signal
        )
        port map(
            -- write port (master clock domain) --
            m_clk_i   => io_clk_i,
            m_rst_i   => io_rst_i,      -- async
            m_data_i  => descriptor_in,
            m_we_i    => descriptor_issue, -- write new descriptor to fifo
            m_full_o  => queue_full,
            m_sfull_o => queue_sfull,   -- almost full signal
            -- read port (slave clock domain) --
            s_clk_i   => clk_i,
            s_rst_i   => rst_i,         -- async
            s_data_o  => descriptor_out,
            s_re_i    => descriptor_re,
            s_empty_o => descriptor_nrdy
        );

    descriptor_avail <= not descriptor_nrdy;

    -- de-assemble descriptor --
    descriptor_dma.dir_reg           <= descriptor_out(descriptor_size_c - 1);
    descriptor_dma.pad_top           <= descriptor_out(descriptor_size_c - 5);
    descriptor_dma.pad_right         <= descriptor_out(descriptor_size_c - 4);
    descriptor_dma.pad_bottom        <= descriptor_out(descriptor_size_c - 3);
    descriptor_dma.pad_left          <= descriptor_out(descriptor_size_c - 2);
    descriptor_dma.lm_broadcast_mask <= descriptor_out(descriptor_size_c - 6 downto block_stride_size_c + block_y_size_c + block_x_size_c + loc_base_size_c + ext_base_size_c);
    descriptor_dma.ext_base_reg      <= descriptor_out(block_stride_size_c + block_y_size_c + block_x_size_c + loc_base_size_c + ext_base_size_c - 1 downto block_stride_size_c + block_y_size_c + block_x_size_c + loc_base_size_c);
    descriptor_dma.loc_base_reg      <= descriptor_out(block_stride_size_c + block_y_size_c + block_x_size_c + loc_base_size_c - 1 downto block_stride_size_c + block_y_size_c + block_x_size_c);
    descriptor_dma.block_x_reg       <= descriptor_out(block_stride_size_c + block_y_size_c + block_x_size_c - 1 downto block_stride_size_c + block_y_size_c);
    descriptor_dma.block_y_reg       <= descriptor_out(block_stride_size_c + block_y_size_c - 1 downto block_stride_size_c);
    descriptor_dma.block_stride_reg  <= descriptor_out(block_stride_size_c - 1 downto 0);

    -- DMA Padding Register --------------------------------------------------------------------------
    -- -----------------------------------------------------------------------------------------------
    padding_io_write : process(io_clk_i, io_rst_i)
    begin
        if (io_rst_i = active_reset_c) then
            padding_width_top_reg    <= (others => '0');
            padding_width_bottom_reg <= (others => '0');
            padding_width_left_reg   <= (others => '0');
            padding_width_right_reg  <= (others => '0');
            padding_value_reg        <= (others => '0');
        elsif rising_edge(io_clk_i) then
            if (io_wen_i = '1') then
                case (io_adr_i(io_addr_dma_pad_top_c'range)) is
                    when io_addr_dma_pad_top_c =>
                        padding_width_top_reg <= unsigned(io_data_i(padding_width_top'left downto 0));
                    when io_addr_dma_pad_bottom_c =>
                        padding_width_bottom_reg <= unsigned(io_data_i(padding_width_bottom'left downto 0));
                    when io_addr_dma_pad_left_c =>
                        padding_width_left_reg <= unsigned(io_data_i(padding_width_left'left downto 0));
                    when io_addr_dma_pad_right_c =>
                        padding_width_right_reg <= unsigned(io_data_i(padding_width_right'left downto 0));
                    when io_addr_dma_pad_value_c =>
                        padding_value_reg <= unsigned(io_data_i(padding_value'left downto 0));
                    when others =>
                end case;
            end if;
        end if;
    end process padding_io_write;

    padding_io : process(clk_i)
    begin
        if rising_edge(clk_i) then
            padding_width_top_cdc <= padding_width_top_reg;
            padding_width_top     <= padding_width_top_cdc;

            padding_width_bottom_cdc <= padding_width_bottom_reg;
            padding_width_bottom     <= padding_width_bottom_cdc;

            padding_width_left_cdc <= padding_width_left_reg;
            padding_width_left     <= padding_width_left_cdc;

            padding_width_right_cdc <= padding_width_right_reg;
            padding_width_right     <= padding_width_right_cdc;

            padding_value_cdc <= padding_value_reg;
            padding_value     <= padding_value_cdc;
        end if;
    end process padding_io;             
--coverage on
end dma_rtl;
