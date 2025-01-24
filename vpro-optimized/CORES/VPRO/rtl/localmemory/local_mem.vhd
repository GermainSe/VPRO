--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System Simple Local Memory                        #
-- #############################################################################
-- coverage off

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity local_mem is
    generic(
        ADDR_WIDTH_g : natural := 13;   -- must be 11..15
        DATA_WIDTH_g : natural := 16
    );
    port(
        -- port A --
        a_clk_i  : in  std_ulogic;
        a_addr_i : in  std_ulogic_vector(19 downto 0); -- TODO make this ADDR_WIDTH ?!
        a_di_i   : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        a_we_i   : in  std_ulogic_vector(DATA_WIDTH_g / 8 - 1 downto 0);
        a_re_i   : in  std_ulogic;
        a_do_o   : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        -- port B --
        b_clk_i  : in  std_ulogic;
        b_addr_i : in  std_ulogic_vector(19 downto 0);
        b_di_i   : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        b_we_i   : in  std_ulogic_vector(DATA_WIDTH_g / 8 - 1 downto 0);
        b_re_i   : in  std_ulogic;
        b_do_o   : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0)
    );
end local_mem;

architecture local_mem_rtl of local_mem is
    type mem_t is array (0 to (2 ** ADDR_WIDTH_g) - 1) of std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
    shared variable lm : mem_t;

    signal last_a_re_nxt, last_a_re : std_ulogic;
    signal last_b_re_nxt, last_b_re : std_ulogic;

    -- from mem_array
    signal lm_do_a, lm_do_b : std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);

    -- registered if valid and stall
    signal next_lm_do_a_nxt, next_lm_do_a : std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
    signal next_lm_do_b_nxt, next_lm_do_b : std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);

    -- output register
    signal a_do_o_nxt, b_do_o_nxt : std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);

begin
    -- ----------------------
    -- READ
    -- ----------------------

    mem_sync_rd_a : process(a_clk_i)
    begin
        if rising_edge(a_clk_i) then
            if (a_re_i = '1') then
                lm_do_a <= lm(to_integer(unsigned(a_addr_i(ADDR_WIDTH_g - 1 downto 0))));
            end if;
        end if;
    end process;

    mem_sync_rd_b : process(b_clk_i)
    begin
        if rising_edge(b_clk_i) then
            if (b_re_i = '1') then
                lm_do_b <= lm(to_integer(unsigned(b_addr_i(ADDR_WIDTH_g - 1 downto 0))));
            end if;
        end if;
    end process;

    -- ----------------------
    -- OUTPUT Register
    -- ----------------------

    last_a_re_nxt    <= a_re_i;
    last_b_re_nxt    <= b_re_i;
    next_lm_do_a_nxt <= std_ulogic_vector(lm_do_a);
    next_lm_do_b_nxt <= std_ulogic_vector(lm_do_b);

    register_clk_a : process(a_clk_i)
    begin
        if rising_edge(a_clk_i) then
            last_a_re <= last_a_re_nxt;
            if (a_re_i = '0' and last_a_re = '1') then -- valid ram_do @ stall start
                next_lm_do_a <= next_lm_do_a_nxt;
            end if;
        end if;
    end process;

    register_clk_b : process(b_clk_i)
    begin
        if rising_edge(b_clk_i) then
            last_b_re <= last_b_re_nxt;
            if (b_re_i = '0' and last_b_re = '1') then -- valid ram_do @ stall start
                next_lm_do_b <= next_lm_do_b_nxt;
            end if;
        end if;
    end process;

    output_buffer : process(a_re_i, last_a_re, lm_do_a, next_lm_do_a, b_re_i, last_b_re, lm_do_b, next_lm_do_b)
    begin
        if (a_re_i = '1' or last_a_re = '1') then -- different logic to RF!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!??????????????????????????????????
            a_do_o_nxt <= lm_do_a;
        else
            a_do_o_nxt <= next_lm_do_a;
        end if;

        if (b_re_i = '1' or last_b_re = '1') then
            b_do_o_nxt <= lm_do_b;
        else
            b_do_o_nxt <= next_lm_do_b;
        end if;
    end process;

    -- additional output register (begind mux, to match BRAM instanciation)
    output_buffer_seq_a : process(a_clk_i)
    begin
        if rising_edge(a_clk_i) then
            if (last_a_re = '1') then
                a_do_o <= a_do_o_nxt;
            end if;
        end if;
    end process;

    output_buffer_seq_b : process(b_clk_i)
    begin
        if rising_edge(b_clk_i) then
            if (last_b_re = '1') then
                b_do_o <= b_do_o_nxt;
            end if;
        end if;
    end process;

    -- ----------------------
    -- WRITE
    -- ----------------------

    write_a : process(a_clk_i)
    begin
        if rising_edge(a_clk_i) then
            for I in 0 to DATA_WIDTH_g / 8 - 1 loop
                if (a_we_i(I) = '1') then
                    lm(to_integer(unsigned(a_addr_i(ADDR_WIDTH_g - 1 downto 0))))((I + 1) * 8 - 1 downto I * 8) := a_di_i((I + 1) * 8 - 1 downto I * 8);
                end if;
            end loop;
        end if;
    end process;

    write_b : process(b_clk_i)
    begin
        if rising_edge(b_clk_i) then
            for I in 0 to DATA_WIDTH_g / 8 - 1 loop
                if (b_we_i(I) = '1') then
                    lm(to_integer(unsigned(b_addr_i(ADDR_WIDTH_g - 1 downto 0))))((I + 1) * 8 - 1 downto I * 8) := b_di_i((I + 1) * 8 - 1 downto I * 8);
                end if;
            end loop;
        end if;
    end process;

end local_mem_rtl;
-- coverage on