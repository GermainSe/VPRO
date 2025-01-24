--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
-- ----------------------------------------------------------------------------
--! @file eisV_dma.vhd
--! @brief DMA to direct access MM without cache
-- ----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library eisv;
use eisv.eisV_pkg.all;

entity eisV_dma is
    port(
        -- global control --
        clk_i             : in  std_ulogic; -- global clock line, rising-edge
        rst_i             : in  std_ulogic; -- global reset line, high-active, sync
        ce_i              : in  std_ulogic; -- global clock enable, high-active
        stall_i           : in  std_ulogic; -- freeze output if any stall
        stall_o           : out std_ulogic; -- freeze output if any stall

        cpu_req_i         : in  std_ulogic; -- access to cached memory space
        cpu_adr_i         : in  std_ulogic_vector(31 downto 0);
        cpu_rden_i        : in  std_ulogic; -- read enable
        cpu_wren_i        : in  std_ulogic_vector(03 downto 0); -- write enable
        cpu_data_o        : out std_ulogic_vector(31 downto 0); -- read-data word
        cpu_data_i        : in  std_ulogic_vector(31 downto 0); -- write-data word

        -- memory system interface --
        mem_read_length_o : out std_ulogic_vector(19 downto 0); --length of that block in bytes
        mem_base_adr_o    : out std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
        mem_dat_i         : in  std_ulogic_vector(dc_cache_word_width_c - 1 downto 0);
        mem_dat_o         : out std_ulogic_vector(dc_cache_word_width_c - 1 downto 0);
        mem_req_o         : out std_ulogic; -- memory request
        mem_busy_i        : in  std_ulogic; -- memory command buffer full
        mem_wrdy_i        : in  std_ulogic; -- write fifo is ready
        mem_rw_o          : out std_ulogic; -- read/write a block from/to memory
        mem_rden_o        : out std_ulogic; -- FIFO read enable
        mem_wren_o        : out std_ulogic; -- FIFO write enable
        mem_wr_last_o     : out std_ulogic; -- last word of write-block
        mem_wr_done_i     : in  std_ulogic_vector(1 downto 0); -- '00' not done, '01' done, '10' data error, '11' req error
        mem_rrdy_i        : in  std_ulogic -- read data ready
    );
end eisV_dma;

architecture eisV_dma_behav of eisV_dma is
    constant subword_buffer_word_length_c : natural := integer(ceil(log2(real(dc_cache_word_width_c/cpu_data_o'length))));
    constant dc_cache_word_width_byte_log2_c : natural := integer(ceil(log2(real(dc_cache_word_width_c/8))));

    -- DAM
    type dma_state_t is (S_IDLE, S_RECEIVE, S_SEND_REQ, S_SEND, S_WAIT_SEND_DONE, S_RESEND, S_STALL_READ, S_STALL_WRITE);
    signal dma_state, dma_state_nxt                       : dma_state_t;
    signal dma_resend_data_word, dma_resend_data_word_nxt : std_ulogic_vector(dc_cache_word_width_c - 1 downto 0);
    signal dma_mem_base_adr_o_nxt, dma_mem_base_adr_o     : std_ulogic_vector(31 downto 0);

    signal cpu_wren_nxt, cpu_wren       : std_ulogic_vector(3 downto 0); -- byte write enable
    signal cpu_wr_data_nxt, cpu_wr_data : std_ulogic_vector(31 downto 0);

    signal dma_stall, dma_stall_nxt : std_ulogic;

    signal mem_read_length_nxt, mem_read_length : std_ulogic_vector(19 downto 0);
    signal subword_buffer_nxt, subword_buffer   : std_ulogic_vector(subword_buffer_word_length_c - 1 downto 0);
begin

    dma_sync : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            dma_resend_data_word <= (others => '0');
            dma_state            <= S_IDLE;
            dma_stall            <= '0';
            dma_mem_base_adr_o   <= (others => '0');
            cpu_wren             <= (others => '0');
            cpu_wr_data          <= (others => '0');
            mem_read_length      <= std_ulogic_vector(to_unsigned(cpu_data_o'length / 8, 20));
            subword_buffer       <= (others => '0');
        elsif rising_edge(clk_i) then
            if (ce_i = '1') then
                dma_resend_data_word <= dma_resend_data_word_nxt;
                dma_state            <= dma_state_nxt;
                dma_stall            <= dma_stall_nxt;
                dma_mem_base_adr_o   <= dma_mem_base_adr_o_nxt;
                cpu_wren             <= cpu_wren_nxt;
                cpu_wr_data          <= cpu_wr_data_nxt;
                mem_read_length      <= mem_read_length_nxt;
                subword_buffer       <= subword_buffer_nxt;
            end if;
        end if;
    end process dma_sync;

    mem_read_length_o <= mem_read_length_nxt;
    mem_base_adr_o    <= dma_mem_base_adr_o_nxt;

    dma_access : process(cpu_req_i, mem_busy_i, mem_rrdy_i, mem_wrdy_i, mem_dat_i, stall_i, dma_resend_data_word, dma_state, dma_mem_base_adr_o, cpu_data_i, cpu_rden_i, cpu_wren_i, cpu_adr_i, cpu_wren, cpu_wr_data, dma_stall, mem_read_length, subword_buffer, ce_i, mem_wr_done_i)
    begin
        dma_stall_nxt          <= '0';
        dma_mem_base_adr_o_nxt <= dma_mem_base_adr_o;

        subword_buffer_nxt <= subword_buffer;

        stall_o <= dma_stall;

        cpu_data_o <= dma_resend_data_word((mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 31 downto (mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32);

        mem_dat_o           <= (others => '0');
        mem_req_o           <= '0';
        mem_rw_o            <= '0';
        mem_rden_o          <= '0';
        mem_wren_o          <= '0';
        mem_wr_last_o       <= '0';
        mem_read_length_nxt <= mem_read_length;

        dma_state_nxt            <= dma_state;
        dma_resend_data_word_nxt <= dma_resend_data_word;

        cpu_wren_nxt    <= cpu_wren;
        cpu_wr_data_nxt <= cpu_wr_data;

        case (dma_state) is
            when S_IDLE =>
                if (cpu_req_i = '1') then -- data read length <= 4 ? 8  =>  one 64-bit word / 2 MIPS-words => write problem if writing 32-bit
                    if (cpu_rden_i = '1') or (cpu_wren_i /= "0000") then
                        dma_stall_nxt <= '1'; -- always stall at least one cycle
                    end if;
                    -- request:
                    if (mem_busy_i = '0') and (stall_i = '0') and (ce_i = '1') then -- ready for new request?		
                        dma_mem_base_adr_o_nxt  <= (others  => '0');
                        dma_mem_base_adr_o_nxt(31 downto dc_cache_word_width_byte_log2_c)  <= cpu_adr_i(31 downto dc_cache_word_width_byte_log2_c);
                        subword_buffer_nxt     <= cpu_adr_i(dc_cache_word_width_byte_log2_c - 1 downto 2);
                        mem_read_length_nxt    <= std_ulogic_vector(to_unsigned(dc_cache_word_width_c / 8, 20)); -- 4*4 byte = 128-bit

                        if (cpu_rden_i = '1') then -- valid read access
                            mem_req_o     <= '1'; -- request memory block transfer
                            mem_rw_o      <= '0'; -- READ
                            dma_state_nxt <= S_RECEIVE;
                        end if;

                        -- set not sending bytes to 0
                        dma_resend_data_word_nxt <= (others => '0');
                        cpu_wr_data_nxt          <= (others => '0');

                        if (cpu_wren_i /= "0000") then -- valid write access but subword / byte, read first, then append to write subword
                            mem_req_o       <= '1'; -- request memory block transfer
                            mem_rw_o        <= '0'; -- READ
                            cpu_wren_nxt    <= cpu_wren_i;
                            cpu_wr_data_nxt <= cpu_data_i;
                            dma_state_nxt   <= S_RESEND;
                        end if;

                    elsif (mem_busy_i = '1') and (stall_i = '0') and (ce_i = '1') then
                        dma_mem_base_adr_o_nxt  <= (others  => '0');
                        dma_mem_base_adr_o_nxt(31 downto dc_cache_word_width_byte_log2_c)  <= cpu_adr_i(31 downto dc_cache_word_width_byte_log2_c);
                        subword_buffer_nxt     <= cpu_adr_i(dc_cache_word_width_byte_log2_c - 1 downto 2);
                        mem_read_length_nxt    <= std_ulogic_vector(to_unsigned(dc_cache_word_width_c / 8, 20)); -- 4*4 byte = 128-bit

                        if (cpu_rden_i = '1') then -- valid read access
                            --mem_req_o     <= '1'; -- request memory block transfer
                            --mem_rw_o      <= '0'; -- READ
                            dma_state_nxt <= S_STALL_READ;
                        end if;

                        -- set not sending bytes to 0
                        dma_resend_data_word_nxt <= (others => '0');
                        cpu_wr_data_nxt          <= (others => '0');

                        if (cpu_wren_i /= "0000") then -- valid write access but subword / byte, read first, then append to write subword
                            --                            mem_req_o       <= '1'; -- request memory block transfer
                            --                            mem_rw_o        <= '0'; -- READ
                            cpu_wren_nxt    <= cpu_wren_i;
                            cpu_wr_data_nxt <= cpu_data_i;
                            dma_state_nxt   <= S_STALL_WRITE;
                        end if;
                    end if;
                end if;

            when S_STALL_READ =>
                dma_stall_nxt <= '1';
                if (mem_busy_i = '0') and (stall_i = '0') and (ce_i = '1') then -- ready for new request?                    
                    mem_req_o     <= '1'; -- request memory block transfer
                    mem_rw_o      <= '0'; -- READ
                    dma_state_nxt <= S_RECEIVE;
                end if;

            when S_STALL_WRITE =>
                dma_stall_nxt <= '1';
                if (mem_busy_i = '0') and (stall_i = '0') and (ce_i = '1') then -- ready for new request? 
                    mem_req_o     <= '1'; -- request memory block transfer
                    mem_rw_o      <= '0'; -- READ
                    dma_state_nxt <= S_RESEND;
                end if;

            when S_RECEIVE =>
                dma_stall_nxt <= '1';
                if (mem_rrdy_i = '1') and (stall_i = '0') then
                    mem_rden_o <= '1';  -- fifo read enable

                    dma_resend_data_word_nxt <= mem_dat_i;

                    dma_state_nxt <= S_IDLE; -- no other word to receive
                    dma_stall_nxt <= '0';
                end if;

            when S_SEND =>
                dma_stall_nxt <= '1';
                if (mem_wrdy_i = '1') and (stall_i = '0') then
                    mem_dat_o <= dma_resend_data_word;

                    mem_wren_o    <= '1'; -- write to FIFO
                    mem_wr_last_o <= '1';

                    if mem_wr_done_i = "01" then
                        dma_state_nxt <= S_IDLE; -- no other word to send
                        dma_stall_nxt <= '0';
                    else
                        dma_state_nxt <= S_WAIT_SEND_DONE; -- no other word to send
                    end if;
                end if;

            when S_WAIT_SEND_DONE =>
                dma_stall_nxt <= '1';
                case mem_wr_done_i is
                    when "01" =>
                        dma_state_nxt <= S_IDLE; -- no other word to send
                        dma_stall_nxt <= '0';
                    when "10" =>
                        dma_state_nxt <= S_SEND_REQ; -- no other word to send
                    when "11" =>
                        dma_state_nxt <= S_SEND_REQ; -- no other word to send
                    when others =>
                end case;

            when S_RESEND =>
                dma_stall_nxt <= '1';
                if (mem_rrdy_i = '1') and (stall_i = '0') then -- receiving data & ready for new request (write)
                    mem_rden_o <= '1';  -- fifo read enable

                    dma_resend_data_word_nxt <= mem_dat_i;
                    if (cpu_wren(3) = '1') then
                        dma_resend_data_word_nxt((mem_dat_i'length/cpu_data_o'length - 1  - to_integer(unsigned(subword_buffer))) * 32 + 31 downto (mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 24) <= cpu_wr_data(31 downto 24);
                    end if;
                    if (cpu_wren(2) = '1') then
                        dma_resend_data_word_nxt((mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 23 downto (mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 16) <= cpu_wr_data(23 downto 16);
                    end if;
                    if (cpu_wren(1) = '1') then
                        dma_resend_data_word_nxt((mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 15 downto (mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 8) <= cpu_wr_data(15 downto 8);
                    end if;
                    if (cpu_wren(0) = '1') then
                        dma_resend_data_word_nxt((mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 7 downto (mem_dat_i'length/cpu_data_o'length - 1 - to_integer(unsigned(subword_buffer))) * 32 + 0) <= cpu_wr_data(7 downto 0);
                    end if;

                    dma_state_nxt <= S_SEND_REQ; -- resend this
                end if;

            when S_SEND_REQ =>
                dma_stall_nxt <= '1';
                if (mem_busy_i = '0') and (stall_i = '0') then -- ready for req
                    mem_req_o <= '1';   -- request memory block transfer
                    mem_rw_o  <= '1';   -- WRITE

                    dma_state_nxt <= S_SEND; -- no other word to send
                end if;

        end case;
    end process dma_access;

end eisV_dma_behav;
