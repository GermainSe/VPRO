--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity vector_incrementer is
    port(
        clk_i             : in  std_ulogic;
        --
        stall_i           : in  std_ulogic; -- stop increment; stall_pipeline_chain_in or stall_pipeline_chain_out
        reset_i           : in  std_ulogic; -- resets counters
        --
        x_end_i           : in  std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
        y_end_i           : in  std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
        z_end_i           : in  std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
        --
        x_o               : out std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
        y_o               : out std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
        z_o               : out std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
        --
        final_iteration_o : out std_ulogic
    );
end entity vector_incrementer;

architecture RTL of vector_incrementer is

    -- looping variables --
    signal x_cnt_ff, x_cnt_nxt : unsigned(vpro_cmd_x_end_len_c - 1 downto 0); -- loop counter
    signal y_cnt_ff, y_cnt_nxt : unsigned(vpro_cmd_y_end_len_c - 1 downto 0); -- loop counter
    signal z_cnt_ff, z_cnt_nxt : unsigned(vpro_cmd_z_end_len_c - 1 downto 0); -- loop counter

    signal x_end_ff : std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
    signal y_end_ff : std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
    signal z_end_ff : std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
begin

    x_o <= std_ulogic_vector(x_cnt_ff);
    y_o <= std_ulogic_vector(y_cnt_ff);
    z_o <= std_ulogic_vector(z_cnt_ff);

    final_iteration_o <= '1' when ((x_cnt_ff = unsigned(x_end_ff)) and --
                                   (y_cnt_ff = unsigned(y_end_ff)) and --
                                   (z_cnt_ff = unsigned(z_end_ff))) else
                         '0';

    -- Index Counters (Stage 0)  -----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------  
    index_cnts : process(reset_i, x_cnt_ff, x_end_ff, y_cnt_ff, y_end_ff, z_cnt_ff, stall_i)
    begin
        x_cnt_nxt <= x_cnt_ff;
        y_cnt_nxt <= y_cnt_ff;
        z_cnt_nxt <= z_cnt_ff;

        if (reset_i = '1') then
            x_cnt_nxt <= (others => '0');
            y_cnt_nxt <= (others => '0');
            z_cnt_nxt <= (others => '0');
        elsif (stall_i = '0') then
            if (x_cnt_ff /= unsigned(x_end_ff)) then
                x_cnt_nxt <= x_cnt_ff + 1;
                y_cnt_nxt <= y_cnt_ff;
                z_cnt_nxt <= z_cnt_ff;
            else
                if (y_cnt_ff /= unsigned(y_end_ff)) then
                    x_cnt_nxt <= (others => '0');
                    y_cnt_nxt <= y_cnt_ff + 1;
                    z_cnt_nxt <= z_cnt_ff;
                else
                    x_cnt_nxt <= (others => '0');
                    y_cnt_nxt <= (others => '0');
                    z_cnt_nxt <= z_cnt_ff + 1;
                end if;
            end if;
        end if;
    end process index_cnts;

    -- without reset --
    pipeline_regs : process(clk_i)
    begin
        if rising_edge(clk_i) then
            x_cnt_ff <= x_cnt_nxt;
            y_cnt_ff <= y_cnt_nxt;
            z_cnt_ff <= z_cnt_nxt;

            x_end_ff <= x_end_i;
            y_end_ff <= y_end_i;
            z_end_ff <= z_end_i;
        end if;
    end process pipeline_regs;

end architecture RTL;
