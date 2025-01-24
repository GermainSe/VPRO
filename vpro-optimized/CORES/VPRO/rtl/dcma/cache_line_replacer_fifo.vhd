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

entity cache_line_replacer is
    generic(
        NUM_CLUSTERS         : integer := 8;
        ASSOCIATIVITY_LOG2   : integer := 2;
        DCMA_ADDR_WIDTH      : integer := 32; -- Address Width
        TAG_ADDR_WIDTH       : integer;
        SET_ADDR_WIDTH       : integer;
        WORD_SEL_ADDR_WIDTH  : integer;
        WORD_OFFS_ADDR_WIDTH : integer
    );
    port(
        clk_i            : in  std_ulogic; -- Clock 
        areset_n_i       : in  std_ulogic;
        line_accessed_i  : in  std_ulogic_vector(NUM_CLUSTERS * (SET_ADDR_WIDTH + ASSOCIATIVITY_LOG2) - 1 downto 0);
        accessed_valid_i : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
        addr_i           : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- mem byte addr
        valid_i          : in  std_ulogic;
        cache_line_o     : out std_ulogic_vector(SET_ADDR_WIDTH + ASSOCIATIVITY_LOG2 - 1 downto 0)
    );
end cache_line_replacer;

architecture FIFO of cache_line_replacer is
    -- constants

    -- types
    type fifo_pointer_t is array (2 ** SET_ADDR_WIDTH - 1 downto 0) of std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0);

    -- registers
    signal fifo_pointer_ff, fifo_pointer_nxt : fifo_pointer_t;

    -- signals
begin
    seq : process(clk_i, areset_n_i)
    begin
        if areset_n_i = '0' then
            fifo_pointer_ff <= (others => (others => '0'));
        elsif rising_edge(clk_i) then
            fifo_pointer_ff <= fifo_pointer_nxt;
        end if;
    end process;

    comb : process(fifo_pointer_ff, valid_i, addr_i)
        variable set : std_ulogic_vector(SET_ADDR_WIDTH - 1 downto 0);
    begin
        --default
        fifo_pointer_nxt <= fifo_pointer_ff;
        set              := addr_i(SET_ADDR_WIDTH + WORD_SEL_ADDR_WIDTH + WORD_OFFS_ADDR_WIDTH - 1 downto WORD_SEL_ADDR_WIDTH + WORD_OFFS_ADDR_WIDTH);

        if ASSOCIATIVITY_LOG2 = 0 then
            cache_line_o <= set;
        end if;
        if ASSOCIATIVITY_LOG2 /= 0 then
            cache_line_o <= std_ulogic_vector(shift_left(resize(unsigned(set), SET_ADDR_WIDTH + ASSOCIATIVITY_LOG2), ASSOCIATIVITY_LOG2) + unsigned(fifo_pointer_ff(to_integer(unsigned(set)))));
        end if;

        if valid_i = '1' then
            fifo_pointer_nxt(to_integer(unsigned(set))) <= std_ulogic_vector(unsigned(fifo_pointer_ff(to_integer(unsigned(set)))) + 1);
        end if;
    end process;

end architecture FIFO;
