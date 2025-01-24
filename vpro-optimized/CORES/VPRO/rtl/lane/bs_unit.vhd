--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System - Barrelshifter                            #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

entity bs_unit is
    generic(
        only_right_shift : boolean := true -- whether to implement the tree for shift in left direction
    );
    port(
        -- global control --
        ce_i       : in  std_ulogic;
        clk_i      : in  std_ulogic;
        function_i : in  std_ulogic_vector(03 downto 0);
        -- operands --
        opa_i      : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
        opb_i      : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
        -- result --
        data_o     : out std_ulogic_vector(rf_data_width_c - 1 downto 0)
    );
end entity bs_unit;

architecture bs_unit_rtl of bs_unit is

    -- local types --
    type mask_array_t is array (0 to 31) of std_ulogic_vector(rf_data_width_c - 1 downto 0);

    -- init mask function for sign bit cancellation - pretty tricky, huh? ;) --
    -- index # = number of cleared MSBs in resulting vector
    function init_mask(n : natural) return mask_array_t is
        variable mask_array_v : mask_array_t;
    begin
        mask_array_v := (others => (others => '0'));
        for i in 0 to n - 1 loop
            if (i >= rf_data_width_c) then -- this is just for 24 bit
                mask_array_v(i) := (others => '0');
            else
                mask_array_v(i) := std_ulogic_vector(to_unsigned((2 ** (rf_data_width_c - i)) - 1, rf_data_width_c));
            end if;
        end loop;                       -- i
        return mask_array_v;
    end function init_mask;

    constant mask_array : mask_array_t := init_mask(32);

    -- pipeline registers --
    signal shift_amount_ff1                                 : std_ulogic_vector(01 downto 0);
    signal shift_1_ff, shift_1_nxt, shift_2_ff, shift_2_nxt : std_ulogic_vector(rf_data_width_c - 1 downto 0);

    -- masking --
    signal opb_ff1  : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal mask_ff2 : std_ulogic_vector(rf_data_width_c - 1 downto 0);

    -- control --
    signal is_signed_ff1 : std_ulogic;
    signal is_signed_ff2 : std_ulogic;
    signal left_shift    : std_ulogic;

begin

    -- left '0 = 0
    left_shift <= '1' when function_i(0) = '0' else '0';

    bs_seq : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                -- pipeline register --
                shift_amount_ff1 <= opb_i(1 downto 0);
                is_signed_ff1    <= (function_i(1) and opa_i(rf_data_width_c - 1)) or left_shift;
                is_signed_ff2    <= is_signed_ff1;
                opb_ff1          <= opb_i;
                mask_ff2         <= mask_array(to_integer(unsigned(opb_ff1(4 downto 0))));

                shift_1_ff <= shift_1_nxt;
                shift_2_ff <= shift_2_nxt;
            end if;
        end if;
    end process;

    version_24_bit_bs : if rf_data_width_c = 24 generate
        -- Barrelshifter --------------------------------------------------------------------------
        -- -------------------------------------------------------------------------------------------
        bs_core : process(left_shift, opa_i, opb_i, shift_1_ff, shift_amount_ff1)
        begin
            -- coverage off 
            if (left_shift = '0' or only_right_shift) then -- right (arithmetic, always push opa_i(23))
            -- coverage on
                -- stage 1: COARSE shift --
                case opb_i(4 downto 2) is
                    when "000" =>       --no shift
                        shift_1_nxt(23 downto 00) <= opa_i;
                    when "001" =>       --by 4
                        shift_1_nxt(23 downto 20) <= (others => opa_i(23));
                        shift_1_nxt(19 downto 00) <= opa_i(23 downto 04);
                    when "010" =>       --by 8
                        shift_1_nxt(23 downto 16) <= (others => opa_i(23));
                        shift_1_nxt(15 downto 00) <= opa_i(23 downto 08);
                    when "011" =>       --by 12
                        shift_1_nxt(23 downto 12) <= (others => opa_i(23));
                        shift_1_nxt(11 downto 00) <= opa_i(23 downto 12);
                    when "100" =>       --by 16
                        shift_1_nxt(23 downto 08) <= (others => opa_i(23));
                        shift_1_nxt(07 downto 00) <= opa_i(23 downto 16);
                    when "101" =>       --by 20
                        shift_1_nxt(23 downto 04) <= (others => opa_i(23));
                        shift_1_nxt(03 downto 00) <= opa_i(23 downto 20);
                    when others =>      --by 24/all
                        shift_1_nxt(23 downto 00) <= (others => opa_i(23));
                end case;
                -- stage 2: FINE shift --
                case shift_amount_ff1 is
                    when "00" =>        --no shift
                        shift_2_nxt(23 downto 00) <= shift_1_ff(23 downto 0);
                    when "01" =>        --by 1
                        shift_2_nxt(23 downto 23) <= (others => shift_1_ff(23));
                        shift_2_nxt(22 downto 00) <= shift_1_ff(23 downto 1);
                    when "10" =>        --by 2
                        shift_2_nxt(23 downto 22) <= (others => shift_1_ff(23));
                        shift_2_nxt(21 downto 00) <= shift_1_ff(23 downto 2);
                    when others =>      --by 3
                        shift_2_nxt(23 downto 21) <= (others => shift_1_ff(23));
                        shift_2_nxt(20 downto 00) <= shift_1_ff(23 downto 3);
                end case;
            -- coverage off
            else                        -- left (arithmetic & logic)
                -- stage 1: COARSE shift --
                case opb_i(4 downto 2) is
                    when "000" =>       --no shift
                        shift_1_nxt(23 downto 00) <= opa_i;
                    when "001" =>       --by 4
                        shift_1_nxt(03 downto 00) <= (others => '0');
                        shift_1_nxt(23 downto 04) <= opa_i(19 downto 00);
                    when "010" =>       --by 8
                        shift_1_nxt(07 downto 00) <= (others => '0');
                        shift_1_nxt(23 downto 08) <= opa_i(15 downto 00);
                    when "011" =>       --by 12
                        shift_1_nxt(13 downto 00) <= (others => '0');
                        shift_1_nxt(23 downto 12) <= opa_i(11 downto 00);
                    when "100" =>       --by 16
                        shift_1_nxt(15 downto 00) <= (others => '0');
                        shift_1_nxt(23 downto 16) <= opa_i(07 downto 00);
                    when "101" =>       --by 20
                        shift_1_nxt(19 downto 00) <= (others => '0');
                        shift_1_nxt(23 downto 20) <= opa_i(03 downto 00);
                    when others =>      --by 24/all
                        shift_1_nxt(23 downto 00) <= (others => '0');
                end case;
                -- stage 2: FINE shift --
                case shift_amount_ff1 is
                    when "00" =>        --no shift
                        shift_2_nxt(23 downto 00) <= shift_1_ff(23 downto 0);
                    when "01" =>        --by 1
                        shift_2_nxt(00 downto 00) <= (others => '0');
                        shift_2_nxt(23 downto 01) <= shift_1_ff(22 downto 0);
                    when "10" =>        --by 2
                        shift_2_nxt(01 downto 00) <= (others => '0');
                        shift_2_nxt(23 downto 02) <= shift_1_ff(21 downto 0);
                    when others =>      --by 3
                        shift_2_nxt(02 downto 00) <= (others => '0');
                        shift_2_nxt(23 downto 03) <= shift_1_ff(20 downto 0);
                end case;
            end if;
            -- coverage on
        end process bs_core;
    end generate;                       -- 24-bit

    -- coverage off
    version_16_bit_bs : if rf_data_width_c = 16 generate
        -- Barrelshifter --------------------------------------------------------------------------
        -- -------------------------------------------------------------------------------------------
        bs_core : process(left_shift, opa_i, opb_i(4 downto 2), shift_1_ff, shift_amount_ff1)
        begin
            -- coverage off 
            if (left_shift = '0' or only_right_shift) then -- right (arithmetic, always push opa_i(23))
            -- coverage on 
                -- stage 1: COARSE shift --
                case opb_i(4 downto 2) is
                    when "000" =>       --no shift
                        shift_1_nxt(15 downto 00) <= opa_i;
                    when "001" =>       --by 4
                        shift_1_nxt(15 downto 12) <= (others => opa_i(opa_i'left));
                        shift_1_nxt(11 downto 00) <= opa_i(opa_i'left downto 04);
                    when "010" =>       --by 8
                        shift_1_nxt(15 downto 08) <= (others => opa_i(opa_i'left));
                        shift_1_nxt(07 downto 00) <= opa_i(opa_i'left downto 08);
                    when "011" =>       --by 12
                        shift_1_nxt(15 downto 03) <= (others => opa_i(opa_i'left));
                        shift_1_nxt(03 downto 00) <= opa_i(opa_i'left downto 12);
                    when others =>      --by 16/all
                        shift_1_nxt <= (others => opa_i(opa_i'left));
                end case;
                -- stage 2: FINE shift --
                case shift_amount_ff1 is
                    when "00" =>        --no shift
                        shift_2_nxt(15 downto 00) <= shift_1_ff(shift_1_ff'left downto 0);
                    when "01" =>        --by 1
                        shift_2_nxt(15 downto 15) <= (others => shift_1_ff(shift_1_ff'left));
                        shift_2_nxt(14 downto 00) <= shift_1_ff(shift_1_ff'left downto 1);
                    when "10" =>        --by 2
                        shift_2_nxt(15 downto 14) <= (others => shift_1_ff(shift_1_ff'left));
                        shift_2_nxt(13 downto 00) <= shift_1_ff(shift_1_ff'left downto 2);
                    when others =>      --by 3
                        shift_2_nxt(15 downto 13) <= (others => shift_1_ff(shift_1_ff'left));
                        shift_2_nxt(12 downto 00) <= shift_1_ff(shift_1_ff'left downto 3);
                end case;
            -- coverage off 
            else                        -- left (arithmetic & logic)
                -- stage 1: COARSE shift --
                case opb_i(4 downto 2) is
                    when "000" =>       --no shift
                        shift_1_nxt(15 downto 00) <= opa_i;
                    when "001" =>       --by 4
                        shift_1_nxt(03 downto 00)         <= (others => '0');
                        shift_1_nxt(opa_i'left downto 04) <= opa_i(opa_i'left - 4 downto 00);
                    when "010" =>       --by 8
                        shift_1_nxt(07 downto 00)         <= (others => '0');
                        shift_1_nxt(opa_i'left downto 08) <= opa_i(opa_i'left - 8 downto 00);
                    when "011" =>       --by 12
                        shift_1_nxt(13 downto 00)         <= (others => '0');
                        shift_1_nxt(opa_i'left downto 12) <= opa_i(opa_i'left - 12 downto 00);
                    when others =>      --by 16/all
                        shift_1_nxt(opa_i'left downto 00) <= (others => '0');
                end case;
                -- stage 2: FINE shift --
                case shift_amount_ff1 is
                    when "00" =>        --no shift
                        shift_2_nxt(opa_i'left downto 00) <= shift_1_ff(opa_i'left downto 0);
                    when "01" =>        --by 1
                        shift_2_nxt(00 downto 00)         <= (others => '0');
                        shift_2_nxt(opa_i'left downto 01) <= shift_1_ff(opa_i'left - 1 downto 0);
                    when "10" =>        --by 2
                        shift_2_nxt(01 downto 00)         <= (others => '0');
                        shift_2_nxt(opa_i'left downto 02) <= shift_1_ff(opa_i'left - 2 downto 0);
                    when others =>      --by 3
                        shift_2_nxt(02 downto 00)         <= (others => '0');
                        shift_2_nxt(opa_i'left downto 03) <= shift_1_ff(opa_i'left - 3 downto 0);
                end case;
            end if;
            -- coverage on 
        end process bs_core;
    end generate;                       -- 16-bit

    -- Output Stage ---------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    output_stage : process(shift_2_ff, is_signed_ff2, mask_ff2)
    begin
        if (is_signed_ff2 = '1') then   -- signed / arithmetical right shift
            data_o <= shift_2_ff;
        else                            -- unsigned / logical right shift
            data_o <= shift_2_ff and mask_ff2;
        end if;
    end process output_stage;

end architecture bs_unit_rtl;
