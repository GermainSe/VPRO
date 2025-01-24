--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
-- coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity dcma_ram is
    generic(
        AWIDTH  : integer := 12;        -- Address Width
        DWIDTH  : integer := 64;        -- Data Width
        NUM_COL : integer := 4
    );
    port(
        clk      : in  std_ulogic;      -- Clock 
        -- Port A
        we_a     : in  std_ulogic_vector(NUM_COL - 1 downto 0); -- Write Enable
        mem_en_a : in  std_ulogic;      -- Memory Enable
        din_a    : in  std_ulogic_vector(DWIDTH - 1 downto 0); -- Data Input  
        addr_a   : in  std_ulogic_vector(AWIDTH - 1 downto 0); -- Address Input
        dout_a   : out std_ulogic_vector(DWIDTH - 1 downto 0); -- Data Output
        -- Port B
        we_b     : in  std_ulogic_vector(NUM_COL - 1 downto 0); -- Write Enable
        mem_en_b : in  std_ulogic;      -- Memory Enable
        din_b    : in  std_ulogic_vector(DWIDTH - 1 downto 0); -- Data Input  
        addr_b   : in  std_ulogic_vector(AWIDTH - 1 downto 0); -- Address Input
        dout_b   : out std_ulogic_vector(DWIDTH - 1 downto 0) -- Data Output
    );
end dcma_ram;

architecture rtl of dcma_ram is

    constant C_AWIDTH : integer := AWIDTH;
    constant C_DWIDTH : integer := DWIDTH;
    constant CWIDTH   : integer := DWIDTH / NUM_COL;

    -- Internal Signals
    type mem_t is array (natural range <>) of std_ulogic_vector(C_DWIDTH - 1 downto 0);

    shared variable mem : mem_t(2 ** C_AWIDTH - 1 downto 0); -- Memory Declaration            
begin
    -- RAM : Read has one latency, Write has one latency as well.
    process(clk)
    begin
        if (clk'event and clk = '1') then
            if (mem_en_a = '1') then
                for i in 0 to NUM_COL - 1 loop
                    if (we_a(i) = '1') then
                        mem(to_integer(unsigned(addr_a)))((i + 1) * CWIDTH - 1 downto i * CWIDTH) := din_a((i + 1) * CWIDTH - 1 downto i * CWIDTH);
                    end if;
                end loop;
                dout_a <= mem(to_integer(unsigned(addr_a)));
            end if;
        end if;
    end process;

    -- RAM : Read has one latency, Write has one latency as well.
    process(clk)
    begin
        if (clk'event and clk = '1') then
            if (mem_en_b = '1') then
                for i in 0 to NUM_COL - 1 loop
                    if (we_b(i) = '1') then
                        mem(to_integer(unsigned(addr_b)))((i + 1) * CWIDTH - 1 downto i * CWIDTH) := din_b((i + 1) * CWIDTH - 1 downto i * CWIDTH);
                    end if;
                end loop;
                dout_b <= mem(to_integer(unsigned(addr_b)));
            end if;
        end if;
    end process;
end rtl;
