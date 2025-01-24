--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
-- Design Name:    multiplier                                                 --
-- Description:    
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_mult is
    port(
        clk_i                : in  std_ulogic;
        rst_ni               : in  std_ulogic;
        ex_enable_i          : in  std_ulogic;
        ex_operator_i        : in  mult_operator_t;
        ex_signed_i          : in  std_ulogic_vector(1 downto 0);
        ex_op_a_i            : in  std_ulogic_vector(31 downto 0);
        ex_op_b_i            : in  std_ulogic_vector(31 downto 0);
        mem_result_o         : out std_ulogic_vector(31 downto 0);
        ex_mult_multicycle_o : out std_ulogic;
        ex_mult_ready_o      : out std_ulogic;
        mem_ready_i          : in  std_ulogic
    );
end entity eisV_mult;

architecture RTL of eisV_mult is

    -- if VHDL98, max needs to be defined...
    function MAX(LEFT, RIGHT : INTEGER) return INTEGER is
    begin
        --coverage off
        if LEFT > RIGHT then
            return LEFT;
        else
            return RIGHT;
        end if;
        --coverage on
    end;

    constant MUL_MAX_CYCLES : natural := MAX(2, MAX(MUL_CYCLES_H, MUL_CYCLES_L));

    type mul_pipeline_t is array (0 to MUL_MAX_CYCLES - 1) of std_ulogic_vector(63 downto 0);
    signal ex_mul_pipeline_ff : mul_pipeline_t;

    -- read mult result from mul pipeline in mem stage
    signal mem_mul_h_result : std_ulogic_vector(31 downto 0);
    signal mem_mul_l_result : std_ulogic_vector(31 downto 0);
    signal mem_operator_ff  : mult_operator_t;
    signal mem_enable_ff    : std_ulogic;

begin

    assert (MUL_CYCLES_H >= MUL_CYCLES_L) report "(MUL_CYCLES_H < MUL_CYCLES_L   !!!!!!!) Mul OP for high part faster than low part (seems impoossible!) :-D - check package configuration " severity failure;

    --------------------------------------------------------------
    -- Integer Mult
    --------------------------------------------------------------    

    ex_mul_pipeline_ff(0) <= std_ulogic_vector(signed(ex_op_a_i) * signed(ex_op_b_i)) when ex_signed_i = "11" else
                             std_ulogic_vector(resize(signed(ex_op_a_i) * signed(resize(unsigned(ex_op_b_i), ex_op_b_i'length + 1)), ex_mul_pipeline_ff(0)'length)) when ex_signed_i = "01" else -- mulhsu
                             std_ulogic_vector(unsigned(ex_op_a_i) * unsigned(ex_op_b_i));

    mem_mul_l_result <= ex_mul_pipeline_ff(MUL_CYCLES_L - 1)(31 downto 0);
    mem_mul_h_result <= ex_mul_pipeline_ff(MUL_CYCLES_H - 1)(63 downto 32);

    --------------------------------------------------------------
    -- Integer Pipeline Registers
    --------------------------------------------------------------
    mul_register_process : process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            ex_mul_pipeline_ff(1 to MUL_MAX_CYCLES - 1) <= (others => (others => '0'));
            mem_operator_ff                             <= MUL_L;
            mem_enable_ff                               <= '0';
        elsif rising_edge(clk_i) then
            if mem_ready_i = '1' then
                ex_mul_pipeline_ff(1 to MUL_MAX_CYCLES - 1) <= ex_mul_pipeline_ff(0 to MUL_MAX_CYCLES - 2);
                mem_operator_ff                             <= ex_operator_i;
                mem_enable_ff                               <= ex_enable_i;
            end if;
        end if;
    end process;

    --------------------------------------------------------
    -- Result Multiplex
    --------------------------------------------------------
    process(mem_operator_ff, mem_mul_l_result, mem_enable_ff, mem_mul_h_result)
    begin
        mem_result_o <= (others => '0');

        if mem_enable_ff = '1' then
            case (mem_operator_ff) is
                when MUL_L =>
                    mem_result_o <= mem_mul_l_result;

                when MUL_H =>
                    mem_result_o <= mem_mul_h_result;

            end case;
        end if;
    end process;

    -- MUL_IN_TWO_STAGES_EX_AND_MEM - TODO
    -- if > 2 cycles -> multicycle out
    --   if ((ex_operator_i = MUL_H) and (ex_enable_i = '1') and MUL_CYCLE_H > 1 AND (MUL_CYCLE_H > 2 AND NOT MUL_IN_TWO_STAGES_EX_AND_MEM) then multicycle_o <= '1'
    ex_mult_multicycle_o <= '0';        -- never multicycle. output in mem stage always valid   - modify if pipeline increases and result not yet available in mem stage (ex + 1)
    ex_mult_ready_o      <= '1';        -- always ready for new input

    -- ready <= not multicycle ?!   - TODO
    assert (MUL_IN_TWO_STAGES_EX_AND_MEM) report "[MUL_IN_TWO_STAGES_EX_AND_MEM needs to be true!] MUL only in EX removed. PKG enhancement on TODO" severity failure;
    assert (MUL_CYCLES_L = 2) report "[MUL_CYCLES_L needs to be 2!] MUL parametrization, PKG enhancement on TODO" severity failure;
    assert (MUL_CYCLES_H = 2) report "[MUL_CYCLES_L needs to be 2!] MUL parametrization, PKG enhancement on TODO" severity failure;

end architecture RTL;
