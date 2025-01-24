--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eisV_register_file_ff is
    generic(
        ADDR_WIDTH : natural := 5;
        DATA_WIDTH : natural := 32
    );
    port(
        -- Clock and Reset
        clk_i        : in  std_ulogic;
        rst_ni       : in  std_ulogic;  -- @suppress "Unused port: rst_ni is not used in eisv.eisV_register_file_ff(RTL)"
        --Read port R1
        id_raddr_a_i : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        id_rdata_a_o : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        --Read port R2
        id_raddr_b_i : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        id_rdata_b_o : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        -- Write port W
        wb_waddr_i   : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
        wb_wdata_i   : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        wb_we_i      : in  std_ulogic
    );
end entity eisV_register_file_ff;

architecture RTL of eisV_register_file_ff is

    -- number of integer registers
    constant NUM_WORDS : natural := 2 ** ADDR_WIDTH;

    -- integer register file
    type mem_t is array (0 to NUM_WORDS - 1) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal mem_ff : mem_t;

begin

    -------------------------------------------------------------------------------
    ---- READ : Read address decoder RAD
    -------------------------------------------------------------------------------
    reg_file_read : process(mem_ff, id_raddr_a_i, id_raddr_b_i)
    begin
        if (id_raddr_a_i = "00000") then
            id_rdata_a_o <= (others => '0');
        else
            id_rdata_a_o <= mem_ff(to_integer(unsigned(id_raddr_a_i(4 downto 0))));
        end if;
        if (id_raddr_b_i = "00000") then
            id_rdata_b_o <= (others => '0');
        else
            id_rdata_b_o <= mem_ff(to_integer(unsigned(id_raddr_b_i(4 downto 0))));
        end if;
    end process reg_file_read;

    -------------------------------------------------------------------------------
    ---- WRITE : Write operation
    -------------------------------------------------------------------------------
    reg_file_write : process(clk_i)
    begin
        if rising_edge(clk_i) then
            -- write port
            if (wb_we_i = '1') then
                if (wb_waddr_i /= "00000") then
                    mem_ff(to_integer(unsigned(wb_waddr_i))) <= wb_wdata_i;
                end if;
            end if;
        end if;
    end process reg_file_write;

end architecture RTL;
