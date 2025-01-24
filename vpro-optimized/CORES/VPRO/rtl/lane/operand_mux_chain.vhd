--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2023, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - MUX based on the command. Chain Input or Immediate.                # 
-- # Sel Signal for Addr in following stage is set.                            #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity operand_mux_chain is
    port(
        vcmd_i             : in  vpro_command_t;
        lane_chain_input_i : in  lane_chain_data_input_t;
        src1_src_i         : in  operand_src_t;
        src2_src_i         : in  operand_src_t;
        src1_buf_o         : out std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- includes flag data
        src1_addr_sel_o    : out std_ulogic;
        src2_buf_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0); -- without flag
        src2_addr_sel_o    : out std_ulogic
    );
end entity operand_mux_chain;

architecture RTL of operand_mux_chain is

    signal imm_a, imm_b         : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal imm_cmd_a, imm_cmd_b : std_ulogic_vector(vpro_cmd_src1_imm_len_c - 1 downto 0);

begin
    imm_cmd_a <= vpro_cmd2src1_imm(vcmd_i);
    imm_cmd_b <= vpro_cmd2src2_imm(vcmd_i);

    imm_extract_src1 : process(imm_cmd_a)
    begin
        -- source 1 as immediate --
        if vpro_cmd_src1_imm_len_c < rf_data_width_c then
            imm_a                  <= (others => imm_cmd_a(imm_cmd_a'left)); -- @suppress "Dead code"
            imm_a(imm_cmd_a'range) <= imm_cmd_a;
        else                            -- @suppress "Dead code"
            imm_a <= imm_cmd_a(rf_data_width_c - 1 downto 0);
        end if;
    end process;

    imm_extract_src2 : process(imm_cmd_b)
    begin
        -- source 1 as immediate --
        if vpro_cmd_src2_imm_len_c < rf_data_width_c then
            imm_b                  <= (others => imm_cmd_b(imm_cmd_b'left)); -- @suppress "Dead code"
            imm_b(imm_cmd_b'range) <= imm_cmd_b;
        else                            -- @suppress "Dead code"
            imm_b <= imm_cmd_b(rf_data_width_c - 1 downto 0);
        end if;

    end process;

    alu_operands_s4 : process(lane_chain_input_i, src1_src_i, src2_src_i, imm_a, imm_b)
    begin
        -- operand a --
        src1_buf_o      <= (others => '-');
        src1_addr_sel_o <= '1';
        case src1_src_i is
            when IMMEDIATE =>
                src1_buf_o      <= "00" & imm_a;
                src1_addr_sel_o <= '0';
            when CHAIN_LANE =>
                src1_buf_o      <= lane_chain_input_i(0).data;
                src1_addr_sel_o <= '0';
            when CHAIN_LS =>
                src1_buf_o      <= lane_chain_input_i(2).data;
                src1_addr_sel_o <= '0';
            when REG =>
        end case;

        -- operand b --
        src2_buf_o      <= (others => '-');
        src2_addr_sel_o <= '1';
        case src2_src_i is
            when IMMEDIATE =>
                src2_buf_o      <= imm_b;
                src2_addr_sel_o <= '0';
            when CHAIN_LANE =>
                src2_buf_o      <= lane_chain_input_i(0).data(rf_data_width_c - 1 downto 0);
                src2_addr_sel_o <= '0';
            when CHAIN_LS =>
                src2_buf_o      <= lane_chain_input_i(2).data(rf_data_width_c - 1 downto 0);
                src2_addr_sel_o <= '0';
            when REG =>
        end case;
    end process alu_operands_s4;

end architecture RTL;
