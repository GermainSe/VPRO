--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System Complex Addressing Unit                    #
-- # This unit has 3 cycles latency!                                           #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity address_unit is
    generic(
        ADDR_WIDTH_g        : natural := 10;
        OFFSET_WIDTH_g      : natural := 10;
        OFFSET_REGISTERED_g : boolean := false
    );
    port(
        -- global control --
        ce_i     : in  std_ulogic;
        clk_i    : in  std_ulogic;
        -- looping variables --
        x_i      : in  std_ulogic_vector(5 downto 0);
        y_i      : in  std_ulogic_vector(5 downto 0);
        z_i      : in  std_ulogic_vector(9 downto 0);
        -- operands --
        alpha_i  : in  std_ulogic_vector(5 downto 0);
        beta_i   : in  std_ulogic_vector(5 downto 0);
        gamma_i  : in  std_ulogic_vector(5 downto 0);
        offset_i : in  std_ulogic_vector(OFFSET_WIDTH_g - 1 downto 0); -- delayed by two cycles
        -- final address --
        addr_o   : out std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0) -- cut to 10-bit. maximum address is 1025 inside RF
    );
end entity address_unit;

architecture address_unit_rtl of address_unit is
    -- calculation of
    --    addr = x * alpha + y * beta + offset
    -- 3 pipeline stages (cycles latency)
    --    registered ouput
    --    registered offset (two stages), other inputs unregistered

    -- buffer
    signal x_tmp_result, x_tmp_result_nxt : std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0);
    signal y_tmp_result, y_tmp_result_nxt : std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0);
    signal z_tmp_result, z_tmp_result_nxt : std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0);
    signal tmp_result, tmp_result_nxt     : std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0);
    signal offset_ff1, offset_ff2         : std_ulogic_vector(OFFSET_WIDTH_g - 1 downto 0);

    -- output register
    signal addr_o_nxt : std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0);
    signal addr_o_int : std_ulogic_vector(ADDR_WIDTH_g - 1 downto 0);

begin

    x_tmp_result_nxt <= std_ulogic_vector(resize(unsigned(x_i) * unsigned(alpha_i), x_tmp_result_nxt'length));
    y_tmp_result_nxt <= std_ulogic_vector(resize(unsigned(y_i) * unsigned(beta_i), x_tmp_result_nxt'length));
    z_tmp_result_nxt <= std_ulogic_vector(resize(unsigned(z_i) * unsigned(gamma_i), z_tmp_result_nxt'length));

    tmp_result_nxt <= std_ulogic_vector(unsigned(x_tmp_result) + unsigned(y_tmp_result) + unsigned(z_tmp_result));

    addr_o <= addr_o_int;

    registered_offset : if OFFSET_REGISTERED_g generate
        -- offset is expected to be registered externally (two cycles delay) by vector lane
        addr_o_nxt <= std_ulogic_vector(unsigned(offset_i) + unsigned(tmp_result));
    end generate;
    unregistered_offset : if not OFFSET_REGISTERED_g generate
        -- offset is unregistered and has to be delayed for two cycles
        addr_o_nxt <= std_ulogic_vector(unsigned(offset_ff2) + unsigned(tmp_result));
    end generate;

    --   _i x -> x_tmp_result_nxt | 
    --                              x_tmp_result  +  -> tmp_result_nxt | 
    --                                                                   tmp_result + off  |  
    --                                                                                       addr_o

    sync_process : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                -- first stage
                x_tmp_result <= x_tmp_result_nxt;
                y_tmp_result <= y_tmp_result_nxt;
                z_tmp_result <= z_tmp_result_nxt;

                offset_ff1 <= offset_i;

                -- second stage
                tmp_result <= tmp_result_nxt;
                offset_ff2 <= offset_ff1;

                -- third stage (output)
                addr_o_int <= addr_o_nxt;
            end if;
        end if;
    end process;

end architecture address_unit_rtl;

