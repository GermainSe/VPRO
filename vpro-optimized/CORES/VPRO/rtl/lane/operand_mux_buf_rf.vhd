--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2023, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - MUX based on rdata from rf and buffer                              #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity operand_mux_buf_rf is
    port(
        vcmd_i            : in  vpro_command_t; -- immediate
        src1_addr_sel_i   : in  std_ulogic;
        src2_addr_sel_i   : in  std_ulogic;
        src1_buf_i        : in  std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- with flag data
        src2_buf_i        : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
        src1_rdata_i      : in  std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- with flag data
        src2_rdata_i      : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
        mac_init_source_i : in  MAC_INIT_SOURCE_t;
        alu_opa_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0);
        alu_opb_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0);
        alu_opc_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0);
        old_flags_o       : out std_ulogic_vector(01 downto 0)
    );
end entity operand_mux_buf_rf;

architecture RTL of operand_mux_buf_rf is

    signal imm_a     : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal imm_cmd_a : std_ulogic_vector(vpro_cmd_src2_imm_len_c - 1 downto 0);
begin

    imm_cmd_a <= vpro_cmd2src2_imm(vcmd_i);

    imm_extract_src1 : process(imm_cmd_a)
    begin
        -- source 1 as immediate --
        if vpro_cmd_src2_imm_len_c < rf_data_width_c then
            imm_a                  <= (others => imm_cmd_a(imm_cmd_a'left)); -- @suppress "Dead code"
            imm_a(imm_cmd_a'range) <= imm_cmd_a;
        else                            -- @suppress "Dead code"
            imm_a <= imm_cmd_a(rf_data_width_c - 1 downto 0);
        end if;
    end process;

    alu_operands_s5 : process(imm_a, mac_init_source_i, src1_addr_sel_i, src1_buf_i, src1_rdata_i, src2_addr_sel_i, src2_buf_i, src2_rdata_i)
    begin
        -- operand a --
        alu_opa_o <= src1_buf_i(rf_data_width_c - 1 downto 0); -- pre-selected value
        if (src1_addr_sel_i = '1') then
            alu_opa_o <= src1_rdata_i(rf_data_width_c - 1 downto 0);
        end if;

        -- operand b --
        alu_opb_o <= src2_buf_i;        -- pre-selected value
        if (src2_addr_sel_i = '1') then
            alu_opb_o <= src2_rdata_i;
        end if;

        -- operand c --
        alu_opc_o <= (others => '0');
        if mac_init_source_i = ADDR then
            alu_opc_o <= src2_rdata_i(rf_data_width_c - 1 downto 0);
        elsif mac_init_source_i = IMM then
            alu_opc_o <= imm_a;
        end if;

        -- flag input --
        old_flags_o(z_fbus_c) <= src1_rdata_i(z_rf_c);
        old_flags_o(n_fbus_c) <= src1_rdata_i(n_rf_c);
        if src1_addr_sel_i = '0' then   -- use buffer (chain) for 'old' flag content
            old_flags_o(z_fbus_c) <= src1_buf_i(z_rf_c);
            old_flags_o(n_fbus_c) <= src1_buf_i(n_rf_c);
        end if;
    end process alu_operands_s5;
end architecture RTL;
