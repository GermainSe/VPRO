--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2023, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # Package Definitions for Data Widths                                       #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library core_v2pro;
package package_datawidths is

    function get_align_offset_vector_length(align_offset_log2 : natural) return natural;

    -- data width in RF, LM and MM
    constant lm_addr_width_c   : natural := 13; -- LM address width (10, ..., 15)
    -- constant lm_broadcast_mask_size_c : natural := 15 + 19 + 19;
    constant vpro_data_width_c : natural := 16;
    constant lm_data_width_c   : natural := 32;

    constant rf_data_width_c : natural := 16;

    constant mm_data_width_c : natural := 128;

    constant align_offset_log2_c          : natural := integer(ceil(log2(real(mm_data_width_c / vpro_data_width_c))));
    constant align_offset_vector_length_c : natural;

    -- dsp specialities for mul (fpga)
    constant opb_mul_data_width_c : natural := 16;

end package package_datawidths;

package body package_datawidths is

    function get_align_offset_vector_length(align_offset_log2 : natural)
    return natural is
    begin
        if align_offset_log2 = 0 then
            return 1;
        else
            return align_offset_log2;
        end if;
    end function;

    constant align_offset_vector_length_c : natural := get_align_offset_vector_length(align_offset_log2_c);

end package body package_datawidths;
