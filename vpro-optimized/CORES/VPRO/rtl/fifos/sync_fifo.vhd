--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System - Generic simple FIFO                      #
-- # FIFO memory core is constructed from distributed RAM                      #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity sync_fifo is
    generic(
        DATA_WIDTH     : natural := rf_data_width_c; -- data width of FIFO entries
        NUM_ENTRIES    : natural := 8;  -- number of FIFO entries, should be a power of 2!
        NUM_SFULL      : natural := 2;  -- offset between RD and WR for issueing 'special full' signal
        DIRECT_OUT     : boolean := false; -- direct output of first data when true
        DIRECT_OUT_REG : boolean := false -- direct output (one cycle delay) when true (e.g. write & read not in same cycle!)
    );
    port(
        -- globals --
        clk_i    : in  std_ulogic;
        rst_i    : in  std_ulogic;      -- polarity: see package
        -- write port --
        wdata_i  : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        we_i     : in  std_ulogic;
        wfull_o  : out std_ulogic;
        wsfull_o : out std_ulogic;      -- almost full signal
        -- read port (slave clock domain) --
        rdata_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        re_i     : in  std_ulogic;
        rempty_o : out std_ulogic
    );
    --	attribute keep_hierarchy : string;
    --	attribute keep_hierarchy of sync_fifo : entity is "true";
end sync_fifo;

architecture fifo_rtl of sync_fifo is

    -- FIFO address width --
    constant faw_c : natural := index_size(NUM_ENTRIES);

    -- core memory --
    type fifo_mem_t is array (0 to NUM_ENTRIES - 1) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal fifo_mem : fifo_mem_t;

    attribute ram_style : string;
    attribute ram_style of fifo_mem : signal is "distributed";

    -- access control --
    signal pnt_diff                                          : std_ulogic_vector(faw_c + 1 downto 0);
    signal pnt_diff_abs                                      : unsigned(faw_c downto 0);
    signal w_pnt, w_pnt_nxt                                  : std_ulogic_vector(faw_c downto 0) := (others => '0'); -- +1 bit for wrap-around
    signal r_pnt, r_pnt_nxt                                  : std_ulogic_vector(faw_c downto 0) := (others => '0'); -- +1 bit for wrap-around
    signal empty_int                                         : std_ulogic; -- slave side: FIFO empty
    signal full_int                                          : std_ulogic; -- master side: FIFO full
    signal rdata_o_buf_prev1, rdata_o_buf_prev2              : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rdata_o_buf                                       : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rdata_o_reg, rdata_o_reg_nxt                      : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal direct_in_forward_flag, direct_in_forward_flag_ff : std_ulogic;
begin

    -- Write pointer ------------------------------------------------------------
    -- -----------------------------------------------------------------------------
    write_pointer : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then
            w_pnt <= (others => '0');
        elsif rising_edge(clk_i) then
            w_pnt <= w_pnt_nxt;
        end if;
    end process write_pointer;

    --      if (we_i = '1') and (full_int = '0') then -- writing to not-full fifo?
    w_pnt_nxt <= std_ulogic_vector(unsigned(w_pnt) + 1) when (we_i = '1') else w_pnt;

    -- adresses equal? --
    -- turn off branch & condition coverage for following line, first item (see _user.pdf, p.985)
    -- coverage off -item bc 1
    full_int <= '1' when (w_pnt(faw_c) /= r_pnt(faw_c)) and (w_pnt(faw_c - 1 downto 0) = r_pnt(faw_c - 1 downto 0)) else '0';
    wfull_o  <= full_int;

    -- special full signal --
    pnt_diff     <= std_ulogic_vector(unsigned('0' & w_pnt) - unsigned('0' & r_pnt));
    --pnt_diff_abs <= to_integer(unsigned(pnt_diff)) when pnt_diff(pnt_diff'left) = '0' else to_integer(0 - unsigned(pnt_diff));
    pnt_diff_abs <= unsigned(pnt_diff(faw_c downto 0));
    wsfull_o     <= '1' when ((NUM_ENTRIES - to_integer(pnt_diff_abs)) <= NUM_SFULL) else '0';

    -- Memory write access ---------------------------------------------------------
    -- -----------------------------------------------------------------------------
    write_access : process(clk_i)
    begin
        if rising_edge(clk_i) then
            --    if (we_i = '1') and (full_int = '0') then
            if (we_i = '1') then
                fifo_mem(to_integer(unsigned(w_pnt(faw_c - 1 downto 0)))) <= wdata_i;
            end if;
        end if;
    end process write_access;

    -- Read pointer ----------------------------------------------------------------
    -- -----------------------------------------------------------------------------
    read_pointer : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then
            r_pnt <= (others => '0');
        elsif rising_edge(clk_i) then
            r_pnt <= r_pnt_nxt;
        end if;
    end process read_pointer;

    --      if (re_i = '1') and (empty_int = '0') then -- reading from not-empty fifo?
    r_pnt_nxt <= std_ulogic_vector(unsigned(r_pnt) + 1) when (re_i = '1') else r_pnt;

    -- FIFO slave side empty? --
    empty_int <= '1' when (r_pnt = w_pnt) else '0';
    rempty_o  <= empty_int;

    -- Memory read access ----------------------------------------------------------
    -- -----------------------------------------------------------------------------
    DIRECT_OUT_REG_Gen : if DIRECT_OUT_REG generate

        -- always read into register (next read word)
        -- output is registered as well
        -- if re_i, forward read register to output register
        -- bypass for direct read if previous empty (or chain of empty + reading those word)
        direct_in_forward_flag <= '1' when (empty_int = '1') or (direct_in_forward_flag_ff = '1' and re_i = '1') or ((r_pnt_nxt = w_pnt) and (we_i = '1')) else '0';

        read_access_sync : process(clk_i)
        begin
            -- registered output of this fifo
            if rising_edge(clk_i) then
                --                if direct_in_forward_flag = '0' then
                --                    rdata_o_buf <= fifo_mem(to_integer(unsigned(r_pnt_nxt(faw_c - 1 downto 0)))); 
                --                            -- TODO: logic fix if using registered r_pnt (to shorten this crit path?)
                --                            -- e.g. calc nxt + 2, store in reg, then read registered nxt + 1 here 
                --                            -- (additional address register, but shorter crit path if r_pnt_nxt -> mem -> buf is critical)
                --                else
                --                    rdata_o_buf <= wdata_i;
                --                end if;
                rdata_o_buf_prev1 <= fifo_mem(to_integer(unsigned(r_pnt_nxt(faw_c - 1 downto 0))));
                rdata_o_buf_prev2 <= wdata_i;
            end if;
        end process read_access_sync;

        rdata_o_buf <= rdata_o_buf_prev1 when (direct_in_forward_flag_ff = '0') else rdata_o_buf_prev2;

        read_access_buffer_sync : process(clk_i)
        begin
            if rising_edge(clk_i) then  -- buffer output register
                rdata_o_reg               <= rdata_o_reg_nxt;
                direct_in_forward_flag_ff <= direct_in_forward_flag;
            end if;
        end process read_access_buffer_sync;

        read_access_buffer : process(re_i, rdata_o_buf, rdata_o_reg)
        begin
            if (re_i = '1') then        -- bypass (registered) to output
                rdata_o         <= rdata_o_buf;
                rdata_o_reg_nxt <= rdata_o_buf;
            else                        -- buffer output
                rdata_o_reg_nxt <= rdata_o_reg;
                rdata_o         <= rdata_o_reg;
            end if;
        end process read_access_buffer;
    end generate;

    DIRECT_OUT_False_Gen : if DIRECT_OUT = false and DIRECT_OUT_REG = false generate
        read_access_sync : process(clk_i)
        begin
            if rising_edge(clk_i) then
                if (re_i = '1') then    -- direct out is false !
                    rdata_o <= fifo_mem(to_integer(unsigned(r_pnt(faw_c - 1 downto 0))));
                end if;
            end if;
        end process read_access_sync;
    end generate;

    DIRECT_OUT_TRUE_Gen : if DIRECT_OUT and DIRECT_OUT_REG = false generate
        read_access_async : process(fifo_mem, r_pnt)
        begin
            if (DIRECT_OUT) then
                rdata_o <= fifo_mem(to_integer(unsigned(r_pnt(faw_c - 1 downto 0))));
            end if;
        end process read_access_async;
    end generate;

end fifo_rtl;
