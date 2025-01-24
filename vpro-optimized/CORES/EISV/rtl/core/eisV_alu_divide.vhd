--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- ----------------------------------------------------------------------------
-- Divide.vhd - Divider unit
-- Original by Grant Ayers, University of Utah, XUM Project MIPS32 core
-- Modified by Stephan Nolting, Diploma thesis, IMS, Uni Hannover, 2014/2015
-- ----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_alu_divide is
    port(
        clk_i                : in  std_ulogic;
        rst_ni               : in  std_ulogic; -- high-active, sync
        ex_clk_en_i          : in  std_ulogic; -- clock enable
        ex_op_div_i          : in  std_ulogic; -- True to initiate a signed divide
        ex_op_divu_i         : in  std_ulogic; -- True to initiate an unsigned divide
        ex_dividend_i        : in  std_ulogic_vector(31 downto 0);
        ex_divisor_is_zero_i : in  std_ulogic;
        ex_divisor_i         : in  std_ulogic_vector(31 downto 0);
        --        divisor_bit_i      : in  std_ulogic_vector(04 downto 0);
        ex_quotient_o        : out std_ulogic_vector(31 downto 0);
        ex_remainder_o       : out std_ulogic_vector(31 downto 0);
        ex_stall_o           : out std_ulogic -- True while calculating
    );
end eisV_alu_divide;

architecture rtl of eisV_alu_divide is

    -- On any cycle that one of Op_Div or Op_Divu are true, the Dividend and
    -- Divisor will be captured and a multi-cycle divide operation initiated.
    -- Stall will go true on the next cycle and the first cycle of the divide
    -- operation completed.  After some time (about 32 cycles), Stall will go
    -- false on the same cycle that the result becomes valid.  Op_Div or Op_Divu
    -- will abort any currently running divide operation and initiate a new one.

    signal ex_active_ff  : std_ulogic;  -- True if the divider is running
    signal ex_neg_ff     : std_ulogic;  -- True if the result will be negative
    signal ex_cycle_ff   : std_ulogic_vector(04 downto 0); -- Number of cycles to go
    signal ex_result_ff  : std_ulogic_vector(31 downto 0); -- Begin with dividend, end with quotient
    signal ex_denom_ff   : std_ulogic_vector(31 downto 0); -- Divisor
    signal ex_remain_ff  : std_ulogic_vector(31 downto 0); -- Running remainder
    signal ex_sub        : std_ulogic_vector(32 downto 0); -- Calculate the current digit
    signal ex_rem_neg_ff : std_ulogic;  -- True if the remainder will be negative

begin

    -- Assignments -----------------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------

    -- Calculate the current digit
    ex_sub <= std_ulogic_vector(unsigned('0' & ex_remain_ff(30 downto 0) & ex_result_ff(31)) - unsigned('0' & ex_denom_ff));

    -- Send the results to our master
    ex_quotient_o  <= ex_result_ff when (ex_neg_ff = '0') else std_ulogic_vector(0 - unsigned(ex_result_ff));
    ex_remainder_o <= ex_remain_ff when (ex_rem_neg_ff = '0') else std_ulogic_vector(0 - unsigned(ex_remain_ff));
    ex_stall_o     <= ex_active_ff;

    -- Divider State Machine -------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    div_fsm : process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            ex_active_ff  <= '0';
            ex_neg_ff     <= '0';
            ex_rem_neg_ff <= '0';
            ex_cycle_ff   <= (others => '0');
            ex_result_ff  <= (others => '0');
            ex_denom_ff   <= (others => '0');
            ex_remain_ff  <= (others => '0');
        elsif rising_edge(clk_i) then

            if (ex_clk_en_i = '1') then
                if (ex_op_div_i = '1') then
                    -- Set up for a signed divide.  Remember the resulting sign,
                    -- and make the operands positive.
                    ex_cycle_ff   <= "11111";
                    if (ex_dividend_i(31) = '0') then
                        ex_result_ff <= ex_dividend_i;
                    else
                        ex_result_ff <= std_ulogic_vector(0 - unsigned(ex_dividend_i));
                    end if;
                    if (ex_divisor_i(31) = '0') then
                        ex_denom_ff <= ex_divisor_i;
                    else
                        ex_denom_ff <= std_ulogic_vector(0 - unsigned(ex_divisor_i));
                    end if;
                    ex_remain_ff  <= (others => '0');
                    ex_neg_ff     <= ex_dividend_i(31) xor ex_divisor_i(31);
                    if ex_divisor_is_zero_i = '1' then
                        ex_neg_ff <= '0';
                    end if;
                    ex_rem_neg_ff <= ex_dividend_i(31);
                    ex_active_ff  <= '1';
                elsif (ex_op_divu_i = '1') then
                    -- Set up for an unsigned divide.
                    ex_cycle_ff   <= "11111";
                    ex_result_ff  <= ex_dividend_i;
                    ex_denom_ff   <= ex_divisor_i;
                    ex_remain_ff  <= (others => '0');
                    ex_neg_ff     <= '0';
                    ex_rem_neg_ff <= '0';
                    ex_active_ff  <= '1';
                elsif (ex_active_ff = '1') then
                    -- Run an iteration of the divide.
                    if (ex_sub(32) = '0') then
                        ex_remain_ff <= ex_sub(31 downto 0);
                        ex_result_ff <= ex_result_ff(30 downto 0) & '1';
                    else
                        ex_remain_ff <= ex_remain_ff(30 downto 0) & ex_result_ff(31);
                        ex_result_ff <= ex_result_ff(30 downto 0) & '0';
                    end if;
                    if (ex_cycle_ff = "00000") then
                        ex_active_ff <= '0';
                    end if;
                    ex_cycle_ff <= std_ulogic_vector(unsigned(ex_cycle_ff) - 1);
                end if;
            end if;
        end if;
    end process div_fsm;

end rtl;
