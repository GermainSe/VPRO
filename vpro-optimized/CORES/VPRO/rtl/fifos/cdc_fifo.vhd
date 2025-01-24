--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System - Generic clock domain crossing FIFO       #
-- # FIFO memory core is constructed from distributed RAM                      #
-- # ------------------------------------------------------------------------- #
-- https://zipcpu.com/blog/2018/07/06/afifo.html
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity cdc_fifo is
    generic(
        DATA_WIDTH  : natural := 96;    -- data width of FIFO entries
        NUM_ENTRIES : natural := 32;    -- number of FIFO entries, should be a power of 2!
        NUM_SYNC_FF : natural := 2;     -- number of synchronization FF stages
        NUM_SFULL   : natural := 1;     -- offset between RD and WR for issueing 'special full' signal
        ASYNC       : boolean := false
    );
    port(
        -- write port (master clock domain) --
        m_clk_i   : in  std_ulogic;
        m_rst_i   : in  std_ulogic;     -- async, polarity: see package
        m_data_i  : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        m_we_i    : in  std_ulogic;
        m_full_o  : out std_ulogic;
        m_sfull_o : out std_ulogic;     -- almost full signal
        -- read port (slave clock domain) --
        s_clk_i   : in  std_ulogic;     -- polarity: see package
        s_rst_i   : in  std_ulogic;     -- async, high-active
        s_data_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        s_re_i    : in  std_ulogic;
        s_empty_o : out std_ulogic
    );
    attribute keep_hierarchy : string;
    attribute keep_hierarchy of cdc_fifo : entity is "true";
end cdc_fifo;

architecture cdc_fifo_rtl of cdc_fifo is

    -- FIFO address width --
    constant faw_c : natural := index_size(NUM_ENTRIES);

    -- core memory --
    type fifo_mem_t is array (0 to NUM_ENTRIES - 1) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal fifo_mem : fifo_mem_t;

    attribute ram_style : string;
    attribute ram_style of fifo_mem : signal is "distributed";

    -- access control --
    signal pnt_diff     : std_ulogic_vector(faw_c + 1 downto 0) := (others => '0');
    signal pnt_diff_abs : integer range 0 to NUM_ENTRIES;
    signal w_addr       : std_ulogic_vector(faw_c - 1 downto 0) := (others => '0');
    signal r_addr       : std_ulogic_vector(faw_c - 1 downto 0) := (others => '0');
    signal w_addr_gr    : std_ulogic_vector(faw_c downto 0)     := (others => '0');
    signal w_addr_gr_ff : std_ulogic_vector(faw_c downto 0)     := (others => '0');
    signal r_addr_gr    : std_ulogic_vector(faw_c downto 0)     := (others => '0');
    signal r_addr_gr_ff : std_ulogic_vector(faw_c downto 0)     := (others => '0');
    signal w_pnt        : std_ulogic_vector(faw_c downto 0)     := (others => '0'); -- +1 bit for wrap-around
    signal r_pnt        : std_ulogic_vector(faw_c downto 0)     := (others => '0'); -- +1 bit for wrap-around
    signal empty_int    : std_ulogic                            := '0'; -- slave side: FIFO empty
    signal full_int     : std_ulogic                            := '0'; -- master side: FIFO full

    -- cdc synchronizer --
    type pnt_sync_t is array (0 to NUM_SYNC_FF - 1) of std_ulogic_vector(faw_c downto 0);
    signal w_addr_gr_sync  : pnt_sync_t                        := (others => (others => '0'));
    signal r_addr_gr_sync  : pnt_sync_t                        := (others => (others => '0'));
    signal r_addr_bin_sync : std_ulogic_vector(faw_c downto 0) := (others => '0');

begin

    -- Write pointer ------------------------------------------------------------
    -- -----------------------------------------------------------------------------
    write_pointer : process(m_clk_i, m_rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and m_rst_i = active_reset_c) then
            w_pnt <= (others => '0');
        elsif rising_edge(m_clk_i) then
            --      if (m_we_i = '1') and (full_int = '0') then -- writing to not-full fifo?
            if (m_we_i = '1') then
                w_pnt <= std_ulogic_vector(unsigned(w_pnt) + 1);
            end if;
        end if;
    end process write_pointer;

    process(m_clk_i)
    begin
        if rising_edge(m_clk_i) then
            w_addr_gr_ff <= w_addr_gr;  -- synchronize here!
        end if;
    end process;

    -- convert to Gray --
    w_addr_gr <= bin_to_gray(w_pnt);
    w_addr    <= w_pnt(faw_c - 1 downto 0);

    -- adrresses equal? --
    --full_int <= '1' when (w_addr_gr(faw_c) /= r_addr_gr_sync(NUM_SYNC_FF-1)(faw_c)) and
    --                     (w_addr_gr(faw_c-1 downto 0) = r_addr_gr_sync(NUM_SYNC_FF-1)(faw_c-1 downto 0)) else '0';
    r_addr_bin_sync <= gray_to_bin(r_addr_gr_sync(NUM_SYNC_FF - 1));

    -- turn off branch & condition coverage for following line, first item (see _user.pdf, p.985)
    -- coverage off -item bc 1
    full_int        <= '1' when ((w_pnt(faw_c) /= r_addr_bin_sync(faw_c)) and (w_pnt(faw_c - 1 downto 0) = r_addr_bin_sync(faw_c - 1 downto 0))) else
                       '0';
    m_full_o        <= full_int;

    pnt_diff     <= std_ulogic_vector(unsigned('0' & w_pnt) - unsigned('0' & r_addr_bin_sync));
    pnt_diff_abs <= to_integer(unsigned(pnt_diff(faw_c downto 0)));
    --pnt_diff_abs <= to_integer(unsigned(pnt_diff)) when pnt_diff(pnt_diff'left) = '0' else 
    --                to_integer((0 - unsigned(pnt_diff)));
    m_sfull_o    <= '1' when ((NUM_ENTRIES - pnt_diff_abs) <= NUM_SFULL) else '0';

    -- Read pointer synchronizer ------------------------------------------------
    -- -----------------------------------------------------------------------------
    read_pointer_sync : process(m_clk_i, m_rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and m_rst_i = active_reset_c) then
            r_addr_gr_sync <= (others => (others => '0'));
        elsif rising_edge(m_clk_i) then
            r_addr_gr_sync(0) <= r_addr_gr_ff;
            for i in 1 to NUM_SYNC_FF - 1 loop
                r_addr_gr_sync(i) <= r_addr_gr_sync(i - 1);
            end loop;                   --i
        end if;
    end process read_pointer_sync;

    -- Memory write access ------------------------------------------------------
    -- -----------------------------------------------------------------------------
    write_access : process(m_clk_i)
    begin
        if rising_edge(m_clk_i) then
            --    if (m_we_i = '1') and (full_int = '0') then
            if (m_we_i = '1') then
                fifo_mem(to_integer(unsigned(w_addr))) <= m_data_i;
            end if;
        end if;
    end process write_access;

    -- *******************************************************************************************
    -- Clock Domain Crossing
    -- *******************************************************************************************

    -- Read pointer -------------------------------------------------------------
    -- -----------------------------------------------------------------------------
    read_pointer : process(s_clk_i, s_rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and s_rst_i = active_reset_c) then
            r_pnt <= (others => '0');
        elsif rising_edge(s_clk_i) then
            --      if (s_re_i = '1') and (empty_int = '0') then -- reading from not-empty fifo?
            if (s_re_i = '1') then
                r_pnt <= std_ulogic_vector(unsigned(r_pnt) + 1);
            end if;
        end if;
    end process read_pointer;

    process(s_clk_i)
    begin
        if rising_edge(s_clk_i) then
            r_addr_gr_ff <= r_addr_gr;  -- synchronize here!
        end if;
    end process;

    -- convert to Gray --
    r_addr_gr <= bin_to_gray(r_pnt);
    r_addr    <= r_pnt(faw_c - 1 downto 0);

    -- FIFO slave side empty? --
    empty_int <= '1' when (r_addr_gr = w_addr_gr_sync(NUM_SYNC_FF - 1)) else '0';
    s_empty_o <= empty_int;

    -- Write pointer synchronizer -----------------------------------------------
    -- -----------------------------------------------------------------------------
    write_pointer_sync : process(s_clk_i, s_rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and s_rst_i = active_reset_c) then
            w_addr_gr_sync <= (others => (others => '0'));
        elsif rising_edge(s_clk_i) then
            w_addr_gr_sync(0) <= w_addr_gr_ff;
            for i in 1 to NUM_SYNC_FF - 1 loop
                w_addr_gr_sync(i) <= w_addr_gr_sync(i - 1);
            end loop;                   --i
        end if;
    end process write_pointer_sync;

    -- Memory read access -------------------------------------------------------
    -- -----------------------------------------------------------------------------
    rdata_sync_gen : if not ASYNC generate
        read_access : process(s_clk_i)
        begin
            if rising_edge(s_clk_i) then
                --    if (s_re_i = '1') and (empty_int = '0') then -- reading from not-enmpty fifo?
                if (s_re_i = '1') then
                    s_data_o <= fifo_mem(to_integer(unsigned(r_addr)));
                end if;
            end if;
        end process read_access;
    end generate;

    rdata_async_gen : if ASYNC generate
        s_data_o <= fifo_mem(to_integer(unsigned(r_addr)));
    end generate;

end cdc_fifo_rtl;
