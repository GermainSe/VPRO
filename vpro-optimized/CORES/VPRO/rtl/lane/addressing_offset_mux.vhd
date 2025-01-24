--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2023, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Offset Mux for Indirect Addressing Offset Chain                    #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity addressing_offset_mux is
    generic(
        OFFSET_WIDTH_g : natural := 10
    );
    port(
        cmd_src_sel_i : in  std_ulogic_vector(2 downto 0);
        cmd_offset_i  : in  std_ulogic_vector(OFFSET_WIDTH_g - 1 downto 0);
        chain_input_i : in  lane_chain_data_input_t;
        offset_o      : out std_ulogic_vector(OFFSET_WIDTH_g - 1 downto 0)
    );
end entity addressing_offset_mux;

architecture RTL of addressing_offset_mux is

begin

--coverage off
    offset_o <= chain_input_i(0).data(OFFSET_WIDTH_g - 1 downto 0) when (cmd_src_sel_i = srcsel_indirect_chain_neighbor_c) else
                chain_input_i(2).data(OFFSET_WIDTH_g - 1 downto 0) when (cmd_src_sel_i = srcsel_indirect_chain_ls_c) else
                cmd_offset_i;
--coverage on

end architecture RTL;

