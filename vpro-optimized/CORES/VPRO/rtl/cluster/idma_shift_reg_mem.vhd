--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
--coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity idma_shift_reg_mem is
    generic(
        ADDR_WIDTH : integer := 10;
        DATA_WIDTH : integer := 16
    );
    port(
        clk     : in  std_ulogic;       -- Clock 
        wr_en   : in  std_ulogic;
        wr_addr : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        rd_addr : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        wdata   : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        rdata   : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
    );
end entity idma_shift_reg_mem;

architecture RTL of idma_shift_reg_mem is
    type ram_type is array (2 ** ADDR_WIDTH - 1 downto 0) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal RAM : ram_type;              
begin             
--coverage off
    process(clk)
    begin
        if rising_edge(clk) then
            if (wr_en = '1') then
                RAM(to_integer(unsigned(wr_addr))) <= wdata;
            end if;
        end if;
    end process;

    rdata <= RAM(to_integer(unsigned(rd_addr)));             
--coverage on
end architecture RTL;
