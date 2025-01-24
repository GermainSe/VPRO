--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
-- coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity dcma_async_mem is
    generic(
        ADDR_WIDTH : integer := 10;
        DATA_WIDTH : integer := 16
    );
    port(
        clk   : in  std_ulogic;         -- Clock 
        wr_en : in  std_ulogic;
        addr  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        wdata : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        rdata : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity dcma_async_mem;

architecture RTL of dcma_async_mem is
    type ram_type is array (2 ** ADDR_WIDTH - 1 downto 0) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal RAM : ram_type; -- := (others => (others => '0'));
    
--    attribute ram_style : string;
--    attribute ram_style of RAM : variable is "distributed";
begin
    process(clk)
    begin
        if rising_edge(clk) then
            if (wr_en = '1') then
                RAM(to_integer(unsigned(addr))) <= wdata;
            end if;
        end if;
    end process;

    rdata <= RAM(to_integer(unsigned(addr)));
end architecture RTL;
