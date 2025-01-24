--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- #                                                                           #
-- # VPRO Command Registerfile. Modified by RISC-V Custom Extensions for VPRO  #
-- #                                                                           #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;

entity eisV_VPRO_ext_register_file is
    port(
        clk                   : in  std_ulogic;
        rst_n                 : in  std_ulogic; -- @suppress "Unused port: rst_n is not used in eisv.eisV_VPRO_ext_register_file(RTL)"
        -- VPRO custom extension
        ex_vpro_bundle_i      : in  vpro_bundle_t;
        ex_ready_o            : out std_ulogic; -- depends on fifo state (if not ready, the current vpro_bundle_i is still written out to the fifo but this ex_rdy will stall ID)
        -- VPRO current fifo states
        vpro_vpro_fifo_full_i : in  std_ulogic;
        -- generated VPRO Command (registered)
        mem_vpro_cmd_o        : out vpro_command_t;
        mem_vpro_we_o         : out std_ulogic
    );
end entity eisV_VPRO_ext_register_file;

architecture RTL of eisV_VPRO_ext_register_file is

    -- Registerfile for VPRO Commands
    type vpro_mem_t is array (0 to 7) of std_ulogic_vector(vpro_cmd_len_c - 1 downto 0); -- vpro_command_t;
    signal vpro_rf_mem                      : vpro_mem_t;
    signal vpro_rf_index, vpro_rf_index_ff  : integer range 0 to 7;
    signal vpro_command_rd, vpro_command_wr : vpro_command_t;

    -- VPRO Indizes (Mask (imm), Index (load))
    constant id          : natural := 0;
    constant func        : natural := 1;
    constant dst_offset  : natural := 2;
    constant dst_all     : natural := 3;
    constant src1_flag   : natural := 4;
    constant src1_offset : natural := 5;
    constant src1_all    : natural := 6;
    constant src2_flag   : natural := 7;
    constant src2_offset : natural := 8;
    constant src2_all    : natural := 9;
    constant src2_imm    : natural := 10;
    constant ends        : natural := 11;
    constant flags       : natural := 12;
    constant nowhere     : natural := 15;

    -- registered control for VPRO
    signal ex_vpro_trigger : std_ulogic;
    signal ex_vpro_wr      : std_ulogic;
    signal increment       : std_ulogic;
    signal increment_value : std_ulogic_vector(6 downto 0);

    signal ex_ready_int, ex_rdy_ff : std_ulogic;
    signal mem_vpro_trigger_ff     : std_ulogic;

    signal wb_vpro_trigger_ff : std_ulogic;
begin

    process(ex_vpro_bundle_i, vpro_rf_index_ff, vpro_vpro_fifo_full_i, ex_rdy_ff, mem_vpro_trigger_ff, wb_vpro_trigger_ff)
    begin
        vpro_rf_index <= vpro_rf_index_ff;
        increment     <= '0';
        ex_ready_int  <= '1';

        --
        -- if ready once set to 'stall', keep it until vpro and dma no longer full
        --
        if ex_rdy_ff = '0' then
            ex_ready_int <= not vpro_vpro_fifo_full_i;
        end if;

        --
        -- this is a vpro command, but fifo is full -> stall pipeline. mem stage vpro command write out is performaned. buffer in io_fabric
        --
        if ex_vpro_bundle_i.valid = '1' then
            case (ex_vpro_bundle_i.vpro_op) is
                when VPRO_LI =>
                    ex_ready_int  <= not vpro_vpro_fifo_full_i;
                    increment     <= ex_vpro_bundle_i.imm_u_type(17);
                    vpro_rf_index <= to_integer(unsigned(ex_vpro_bundle_i.imm_u_type(16 downto 14)));

                when VPRO_LW =>
                    ex_ready_int  <= not vpro_vpro_fifo_full_i;
                    vpro_rf_index <= to_integer(unsigned(ex_vpro_bundle_i.imm_s_type(11 downto 9)));

                when others => null;
            end case;
        end if;

        --
        -- last cycle was a vpro command, now vpro command fifo is full. buffer in io_fabric. start to stall ex stage
        --
        if (mem_vpro_trigger_ff = '1') then
            ex_ready_int <= not (vpro_vpro_fifo_full_i);
        end if;

        --
        -- last cyce was a trigger, this cycle fifo is full (registered in eis-v top)
        --  if this cycle fifo is full, the last cycle triggered command is buffered in io_fabric
        --    -> begin stall until fifo is not full again
        --
        if wb_vpro_trigger_ff = '1' and vpro_vpro_fifo_full_i = '1' then
            ex_ready_int <= '0';
        end if;
    end process;

    ex_ready_o <= ex_ready_int;

    register_proc : process(clk)
    begin
        if rising_edge(clk) then
            ex_rdy_ff        <= ex_ready_int;
            vpro_rf_index_ff <= vpro_rf_index;
        end if;
    end process;

    -- async read
    vpro_command_rd <= vpro_vec2cmd(vpro_rf_mem(vpro_rf_index));

    -- modification
    process(vpro_command_rd, ex_vpro_bundle_i, increment_value, increment)
        variable param_mask_imm_v : std_ulogic_vector(12 downto 0);
        variable value_imm_v      : unsigned(31 downto 0);
        variable imm_tmp          : vpro_command_t;
    begin
        vpro_command_wr <= vpro_command_rd;
        ex_vpro_trigger <= '0';
        ex_vpro_wr      <= '0';

        increment_value(4 downto 0) <= ex_vpro_bundle_i.regfile_op_a_addr;
        increment_value(6 downto 5) <= ex_vpro_bundle_i.imm_u_type(19 downto 18);
        if ex_vpro_bundle_i.imm_u_type(17) = '0' then -- use src1 data instead immediate
            increment_value <= ex_vpro_bundle_i.regfile_op_a(increment_value'range);
        end if;

        param_mask_imm_v := ex_vpro_bundle_i.imm_u_type(13 downto 1);
        if ex_vpro_bundle_i.imm_u_type(17) = '0' then -- use src1 data instead immediate
            value_imm_v := resize(unsigned(increment_value), 32);
        else
            value_imm_v := unsigned(ex_vpro_bundle_i.regfile_op_b);
        end if;

        if ex_vpro_bundle_i.valid = '1' then
            case (ex_vpro_bundle_i.vpro_op) is
                when VPRO_LI =>
                    -- trigger
                    ex_vpro_trigger <= ex_vpro_bundle_i.imm_s_type(0);
                    ex_vpro_wr      <= '1';

                    -- paramter mask, last most important if multi assignments
                    -- instanziation of several adders, cause every parameter could be modified...
                    -- for dst_all, src1_all, src2_all, ends:
                    --   the parameters are used and added without overflow / carry chain
                    -- imm first, cause it sets all based on rd command (in function)
                    if param_mask_imm_v(src2_imm) = '1' then
                        if increment = '0' then
                            vpro_command_wr          <= vpro_src2_imm2cmd(vpro_command_rd, std_ulogic_vector(value_imm_v(vpro_cmd_src2_imm_len_c - 1 downto 0)));
                            vpro_command_wr.src2_sel <= srcsel_imm_c;
                        else
                            vpro_command_wr          <= vpro_src2_imm2cmd(vpro_command_rd, std_ulogic_vector(unsigned(vpro_cmd2src2_imm(vpro_command_rd)) + value_imm_v(vpro_cmd_src2_imm_len_c - 1 downto 0)));
                            vpro_command_wr.src2_sel <= srcsel_imm_c;
                        end if;
                    end if;

                    if param_mask_imm_v(id) = '1' then
                        if increment = '0' then
                            vpro_command_wr.id <= std_ulogic_vector(value_imm_v(vpro_command_wr.id'range));
                        else
                            vpro_command_wr.id <= std_ulogic_vector(unsigned(vpro_command_rd.id) + value_imm_v(vpro_command_wr.id'range));
                        end if;
                    end if;

                    if param_mask_imm_v(func) = '1' then
                        assert increment = '0' report "[VPRO.LI] func modified. Increment cannot be applied!" severity failure;
                        vpro_command_wr.func   <= std_ulogic_vector(value_imm_v(vpro_command_wr.func'range));
                        vpro_command_wr.fu_sel <= std_ulogic_vector(value_imm_v(vpro_command_wr.fu_sel'length - 1 + vpro_command_wr.func'length downto vpro_command_wr.func'length));
                    end if;

                    if param_mask_imm_v(dst_offset) = '1' then
                        if increment = '0' then
                            vpro_command_wr.dst_offset <= std_ulogic_vector(value_imm_v(vpro_command_wr.dst_offset'range));
                        else
                            vpro_command_wr.dst_offset <= std_ulogic_vector(unsigned(vpro_command_rd.dst_offset) + value_imm_v(vpro_command_wr.dst_offset'range));
                        end if;
                    end if;

                    if param_mask_imm_v(dst_all) = '1' then
                        vpro_command_wr.dst_sel <= std_ulogic_vector(value_imm_v(vpro_cmd_dst_sel_len_c + vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c));

                        if increment = '0' then
                            vpro_command_wr.dst_offset <= std_ulogic_vector(value_imm_v(vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c));
                            vpro_command_wr.dst_alpha  <= std_ulogic_vector(value_imm_v(vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c));
                            vpro_command_wr.dst_beta   <= std_ulogic_vector(value_imm_v(vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_gamma_len_c));
                            vpro_command_wr.dst_gamma  <= std_ulogic_vector(value_imm_v(vpro_cmd_dst_gamma_len_c - 1 downto 0));
                        else
                            vpro_command_wr.dst_offset <= std_ulogic_vector(unsigned(vpro_command_rd.dst_offset) + value_imm_v(vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c));
                            vpro_command_wr.dst_alpha  <= std_ulogic_vector(unsigned(vpro_command_rd.dst_alpha) + value_imm_v(vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c));
                            vpro_command_wr.dst_beta   <= std_ulogic_vector(unsigned(vpro_command_rd.dst_beta) + value_imm_v(vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_gamma_len_c));
                            vpro_command_wr.dst_gamma  <= std_ulogic_vector(unsigned(vpro_command_rd.dst_gamma) + value_imm_v(vpro_cmd_dst_gamma_len_c - 1 downto 0));
                        end if;
                    end if;

                    if param_mask_imm_v(src1_flag) = '1' then
                        assert increment = '0' report "[VPRO.LI] src1 flag modified. Increment cannot be applied!" severity failure;
                        vpro_command_wr.src1_sel <= std_ulogic_vector(value_imm_v(vpro_command_wr.src1_sel'range));
                    end if;

                    if param_mask_imm_v(src1_offset) = '1' then
                        if increment = '0' then
                            vpro_command_wr.src1_offset <= std_ulogic_vector(value_imm_v(vpro_command_wr.src1_offset'range));
                        else
                            vpro_command_wr.src1_offset <= std_ulogic_vector(unsigned(vpro_command_rd.src1_offset) + value_imm_v(vpro_command_wr.src1_offset'range));
                        end if;
                    end if;

                    if param_mask_imm_v(src1_all) = '1' then
                        vpro_command_wr.src1_sel <= std_ulogic_vector(value_imm_v(vpro_cmd_src1_sel_len_c + vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c));

                        if increment = '0' then
                            vpro_command_wr.src1_offset <= std_ulogic_vector(value_imm_v(vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c));
                            vpro_command_wr.src1_alpha  <= std_ulogic_vector(value_imm_v(vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c));
                            vpro_command_wr.src1_beta   <= std_ulogic_vector(value_imm_v(vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_gamma_len_c));
                            vpro_command_wr.src1_gamma  <= std_ulogic_vector(value_imm_v(vpro_cmd_src1_gamma_len_c - 1 downto 0));
                        else
                            vpro_command_wr.src1_offset <= std_ulogic_vector(unsigned(vpro_command_rd.src1_offset) + value_imm_v(vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c));
                            vpro_command_wr.src1_alpha  <= std_ulogic_vector(unsigned(vpro_command_rd.src1_alpha) + value_imm_v(vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c));
                            vpro_command_wr.src1_beta   <= std_ulogic_vector(unsigned(vpro_command_rd.src1_beta) + value_imm_v(vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_gamma_len_c));
                            vpro_command_wr.src1_gamma  <= std_ulogic_vector(unsigned(vpro_command_rd.src1_gamma) + value_imm_v(vpro_cmd_src1_gamma_len_c - 1 downto 0));
                        end if;
                    end if;

                    if param_mask_imm_v(src2_flag) = '1' then
                        assert increment = '0' report "[VPRO.LI] src2 flag modified. Increment cannot be applied!" severity failure;
                        vpro_command_wr.src2_sel <= std_ulogic_vector(value_imm_v(vpro_command_wr.src2_sel'range));
                    end if;

                    if param_mask_imm_v(src2_offset) = '1' then
                        if increment = '0' then
                            vpro_command_wr.src2_offset <= std_ulogic_vector(value_imm_v(vpro_command_wr.src2_offset'range));
                        else
                            vpro_command_wr.src2_offset <= std_ulogic_vector(unsigned(vpro_command_rd.src2_offset) + value_imm_v(vpro_command_wr.src2_offset'range));
                        end if;
                    end if;

                    if param_mask_imm_v(src2_all) = '1' then
                        vpro_command_wr.src2_sel <= std_ulogic_vector(value_imm_v(vpro_cmd_src2_sel_len_c + vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c));

                        if increment = '0' then
                            vpro_command_wr.src2_offset <= std_ulogic_vector(value_imm_v(vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c));
                            vpro_command_wr.src2_alpha  <= std_ulogic_vector(value_imm_v(vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c));
                            vpro_command_wr.src2_beta   <= std_ulogic_vector(value_imm_v(vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_gamma_len_c));
                            vpro_command_wr.src2_gamma  <= std_ulogic_vector(value_imm_v(vpro_cmd_src2_gamma_len_c - 1 downto 0));
                        else
                            vpro_command_wr.src2_offset <= std_ulogic_vector(unsigned(vpro_command_rd.src2_offset) + value_imm_v(vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c));
                            vpro_command_wr.src2_alpha  <= std_ulogic_vector(unsigned(vpro_command_rd.src2_alpha) + value_imm_v(vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c));
                            vpro_command_wr.src2_beta   <= std_ulogic_vector(unsigned(vpro_command_rd.src2_beta) + value_imm_v(vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_gamma_len_c));
                            vpro_command_wr.src2_gamma  <= std_ulogic_vector(unsigned(vpro_command_rd.src2_gamma) + value_imm_v(vpro_cmd_src2_gamma_len_c - 1 downto 0));
                        end if;
                    end if;

                    if param_mask_imm_v(ends) = '1' then
                        if increment = '0' then
                            vpro_command_wr.x_end <= std_ulogic_vector(value_imm_v(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c + vpro_cmd_x_end_len_c - 1 downto vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c));
                            vpro_command_wr.y_end <= std_ulogic_vector(value_imm_v(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c - 1 downto vpro_cmd_z_end_len_c));
                            vpro_command_wr.z_end <= std_ulogic_vector(value_imm_v(vpro_cmd_z_end_len_c - 1 downto 0));
                        else
                            vpro_command_wr.x_end <= std_ulogic_vector(unsigned(vpro_command_rd.x_end) + value_imm_v(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c + vpro_cmd_x_end_len_c - 1 downto vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c));
                            vpro_command_wr.y_end <= std_ulogic_vector(unsigned(vpro_command_rd.y_end) + value_imm_v(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c - 1 downto vpro_cmd_z_end_len_c));
                            vpro_command_wr.z_end <= std_ulogic_vector(unsigned(vpro_command_rd.z_end) + value_imm_v(vpro_cmd_z_end_len_c - 1 downto 0));
                        end if;
                    end if;

                    if param_mask_imm_v(flags) = '1' then
                        assert increment = '0' report "[VPRO.LI] flags modified. Increment cannot be applied!" severity failure;
                        vpro_command_wr.is_chain <= std_ulogic_vector(value_imm_v(2 downto 2));
                        vpro_command_wr.blocking <= std_ulogic_vector(value_imm_v(1 downto 1));
                        vpro_command_wr.f_update <= std_ulogic_vector(value_imm_v(0 downto 0));
                    end if;

                when VPRO_LW =>
                    -- trigger
                    ex_vpro_trigger <= ex_vpro_bundle_i.imm_s_type(0);
                    ex_vpro_wr      <= '1';

                    -- src1 target
                    case (to_integer(unsigned(ex_vpro_bundle_i.imm_s_type(8 downto 5)))) is
                        when id =>
                            vpro_command_wr.id <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.id'range);
                        when func =>
                            vpro_command_wr.func   <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.func'range);
                            vpro_command_wr.fu_sel <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.fu_sel'length - 1 + vpro_command_wr.func'length downto vpro_command_wr.func'length);
                        when dst_offset =>
                            vpro_command_wr.dst_offset <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.dst_offset'range);
                        when dst_all =>
                            vpro_command_wr.dst_sel    <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_dst_sel_len_c + vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_offset <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_alpha  <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_beta   <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_gamma  <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_dst_gamma_len_c - 1 downto 0);
                        when src1_flag =>
                            vpro_command_wr.src1_sel <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.src1_sel'range);
                        when src1_offset =>
                            vpro_command_wr.src1_offset <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.src1_offset'range);
                        when src1_all =>
                            vpro_command_wr.src1_sel    <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src1_sel_len_c + vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_offset <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_alpha  <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_beta   <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_gamma  <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src1_gamma_len_c - 1 downto 0);
                        when src2_flag =>
                            vpro_command_wr.src2_sel <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.src2_sel'range);
                        when src2_offset =>
                            vpro_command_wr.src2_offset <= ex_vpro_bundle_i.regfile_op_b(vpro_command_wr.src2_offset'range);
                        when src2_all =>
                            vpro_command_wr.src2_sel    <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src2_sel_len_c + vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_offset <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_alpha  <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_beta   <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_gamma  <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src2_gamma_len_c - 1 downto 0);
                        when src2_imm =>
                            imm_tmp                     := vpro_src2_imm2cmd(vpro_command_rd, ex_vpro_bundle_i.regfile_op_b(vpro_cmd_src2_imm_len_c - 1 downto 0));
                            vpro_command_wr.src2_offset <= imm_tmp.src2_offset;
                            vpro_command_wr.src2_alpha  <= imm_tmp.src2_alpha;
                            vpro_command_wr.src2_beta   <= imm_tmp.src2_beta;
                            vpro_command_wr.src2_gamma  <= imm_tmp.src2_gamma;
                            vpro_command_wr.src2_sel    <= srcsel_imm_c;
                        when ends =>
                            vpro_command_wr.x_end <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c + vpro_cmd_x_end_len_c - 1 downto vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c);
                            vpro_command_wr.y_end <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c - 1 downto vpro_cmd_z_end_len_c);
                            vpro_command_wr.z_end <= ex_vpro_bundle_i.regfile_op_b(vpro_cmd_z_end_len_c - 1 downto 0);
                        when flags =>
                            vpro_command_wr.is_chain <= ex_vpro_bundle_i.regfile_op_b(2 downto 2);
                            vpro_command_wr.blocking <= ex_vpro_bundle_i.regfile_op_b(1 downto 1);
                            vpro_command_wr.f_update <= ex_vpro_bundle_i.regfile_op_b(0 downto 0);
                        when nowhere => null;
                        when others  => null;
                    end case;

                    -- src2 target 
                    case (to_integer(unsigned(ex_vpro_bundle_i.imm_s_type(4 downto 1)))) is
                        when id =>
                            vpro_command_wr.id <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.id'range);
                        when func =>
                            vpro_command_wr.func   <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.func'range);
                            vpro_command_wr.fu_sel <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.fu_sel'length - 1 + vpro_command_wr.func'length downto vpro_command_wr.func'length);
                        when dst_offset =>
                            vpro_command_wr.dst_offset <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.dst_offset'range);
                        when dst_all =>
                            vpro_command_wr.dst_sel    <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_dst_sel_len_c + vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_offset <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_alpha  <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_beta   <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c - 1 downto vpro_cmd_dst_gamma_len_c);
                            vpro_command_wr.dst_gamma  <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_dst_gamma_len_c - 1 downto 0);
                        when src1_flag =>
                            vpro_command_wr.src1_sel <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.src1_sel'range);
                        when src1_offset =>
                            vpro_command_wr.src1_offset <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.src1_offset'range);
                        when src1_all =>
                            vpro_command_wr.src1_sel    <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src1_sel_len_c + vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_offset <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_alpha  <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_beta   <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_gamma_len_c);
                            vpro_command_wr.src1_gamma  <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src1_gamma_len_c - 1 downto 0);
                        when src2_flag =>
                            vpro_command_wr.src2_sel <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.src2_sel'range);
                        when src2_offset =>
                            vpro_command_wr.src2_offset <= ex_vpro_bundle_i.regfile_op_a(vpro_command_wr.src2_offset'range);
                        when src2_all =>
                            vpro_command_wr.src2_sel    <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src2_sel_len_c + vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_offset <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_alpha  <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_beta   <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_gamma_len_c);
                            vpro_command_wr.src2_gamma  <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src2_gamma_len_c - 1 downto 0);
                        when src2_imm =>
                            imm_tmp                     := vpro_src2_imm2cmd(vpro_command_rd, ex_vpro_bundle_i.regfile_op_a(vpro_cmd_src2_imm_len_c - 1 downto 0));
                            vpro_command_wr.src2_offset <= imm_tmp.src2_offset;
                            vpro_command_wr.src2_alpha  <= imm_tmp.src2_alpha;
                            vpro_command_wr.src2_beta   <= imm_tmp.src2_beta;
                            vpro_command_wr.src2_gamma  <= imm_tmp.src2_gamma;
                            vpro_command_wr.src2_sel    <= srcsel_imm_c;
                        when ends =>
                            vpro_command_wr.x_end <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c + vpro_cmd_x_end_len_c - 1 downto vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c);
                            vpro_command_wr.y_end <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_z_end_len_c + vpro_cmd_y_end_len_c - 1 downto vpro_cmd_z_end_len_c);
                            vpro_command_wr.z_end <= ex_vpro_bundle_i.regfile_op_a(vpro_cmd_z_end_len_c - 1 downto 0);
                        when flags =>
                            vpro_command_wr.is_chain <= ex_vpro_bundle_i.regfile_op_a(2 downto 2);
                            vpro_command_wr.blocking <= ex_vpro_bundle_i.regfile_op_a(1 downto 1);
                            vpro_command_wr.f_update <= ex_vpro_bundle_i.regfile_op_a(0 downto 0);
                        when nowhere => null;
                        when others  => null;
                    end case;

                when others =>
            end case;
        end if;
    end process;

    vpro_write_rf : process(clk)
    begin
        if rising_edge(clk) then
            if ex_vpro_wr = '1' then
                vpro_rf_mem(vpro_rf_index) <= vpro_cmd2vec(vpro_command_wr);
            end if;
        end if;
    end process;

    output_reg : process(clk)
    begin
        if rising_edge(clk) then
            mem_vpro_trigger_ff <= ex_vpro_trigger;
            wb_vpro_trigger_ff  <= mem_vpro_trigger_ff;

            if ex_vpro_trigger = '1' then
                mem_vpro_cmd_o <= vpro_command_wr;
            end if;
            mem_vpro_we_o <= ex_vpro_trigger;
        end if;
    end process;
end architecture RTL;
