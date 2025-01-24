--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
-- Description:    Arithmetic logic unit of the pipelined processor      --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_alu is
    port(
        clk_i                  : in  std_ulogic;
        rst_ni                 : in  std_ulogic;
        ex_enable_i            : in  std_ulogic;
        ex_operator_i          : in  alu_op_t; --std_ulogic_vector(ALU_OP_WIDTH - 1 downto 0);
        ex_operand_a_i         : in  std_ulogic_vector(31 downto 0);
        ex_operand_b_i         : in  std_ulogic_vector(31 downto 0);
        ex_result_o            : out std_ulogic_vector(31 downto 0);
        ex_comparison_result_o : out std_ulogic;
        ex_alu_multicycle_o    : out std_ulogic;
        ex_alu_ready_o         : out std_ulogic;
        mem_ready_i            : in  std_ulogic
    );
end entity eisV_alu;

architecture RTL of eisV_alu is

    signal ex_operand_a_rev     : std_ulogic_vector(31 downto 0);
    signal ex_operand_a_neg     : std_ulogic_vector(31 downto 0);
    signal ex_operand_a_neg_rev : std_ulogic_vector(31 downto 0); -- @suppress "signal ex_operand_a_neg_rev is never read"
    signal ex_operand_b_neg     : std_ulogic_vector(31 downto 0); -- @suppress "signal ex_operand_b_neg is never read"

    -- adder
    signal ex_adder_in_a, ex_adder_in_b : signed(31 downto 0);
    signal ex_adder_result              : std_ulogic_vector(31 downto 0);

    -- shift
    signal ex_shift_left_flag  : std_ulogic; -- should we shift left
    signal ex_shift_arithmetic : std_ulogic;

    signal ex_shift_amt          : std_ulogic_vector(31 downto 0); -- amount of shift, to the right
    signal ex_shift_op_a         : std_ulogic_vector(31 downto 0); -- input of the shifter
    signal ex_shift_result       : std_ulogic_vector(31 downto 0);
    signal ex_shift_right_result : std_ulogic_vector(31 downto 0);
    signal ex_shift_left_result  : std_ulogic_vector(31 downto 0);
    signal ex_shift_op_a_32      : std_ulogic_vector(63 downto 0); -- right shifts, we let the synthesizer optimize this

    -- compare
    signal ex_is_equal   : std_ulogic_vector(3 downto 0);
    signal ex_is_greater : std_ulogic_vector(3 downto 0); -- handles both signed and unsigned forms

    -- 8-bit vector comparisons, basic building blocks
    signal ex_cmp_signed : std_ulogic_vector(3 downto 0);
    -- generate comparison result
    signal ex_cmp_result : std_ulogic_vector(3 downto 0);

    -- div
    signal ex_div_valid                                  : std_ulogic;
    signal ex_result_div                                 : std_ulogic_vector(31 downto 0);
    signal ex_div_ready                                  : std_ulogic;
    --    signal ex_div_a_is_zero                              : std_ulogic;
    signal ex_div_b_is_zero                              : std_ulogic;
    signal ex_div_start_div                              : std_ulogic;
    signal ex_div_start_divu                             : std_ulogic;
    signal ex_div_quotient                               : std_ulogic_vector(31 downto 0);
    signal ex_div_remainder                              : std_ulogic_vector(31 downto 0);
    signal ex_div_busy                                   : std_ulogic;
    type div_control_fsm_t is (IDLE, DIVIDE);
    signal ex_div_control_fsm_nxt, ex_div_control_fsm_ff : div_control_fsm_t;

    signal ex_comparison_result_int : std_ulogic;

    signal ex_alu_multicycle_int : std_ulogic;
begin

    ex_alu_multicycle_int <= '1' when ex_div_start_div = '1' or ex_div_busy = '1' else '0';
    ex_alu_multicycle_o   <= ex_alu_multicycle_int;

    ex_operand_a_neg     <= not ex_operand_a_i;
    -- bit reverse operand_a for left shifts and bit counting
    ex_operand_a_rev     <= bit_reverse_vector(ex_operand_a_i);
    -- bit reverse operand_a_neg for left shifts and bit counting
    ex_operand_a_neg_rev <= bit_reverse_vector(ex_operand_a_neg);
    ex_operand_b_neg     <= not ex_operand_b_i;

    ------------------------------------
    -- Adder
    ------------------------------------
    ex_adder_in_a   <= signed(ex_operand_a_i);
    ex_adder_in_b   <= -signed(ex_operand_b_i) when (ex_operator_i = ALU_SUB) else signed(ex_operand_b_i);
    ex_adder_result <= std_ulogic_vector(ex_adder_in_a + ex_adder_in_b);

    ----------------------------------------
    -- Shift
    ----------------------------------------
    ex_shift_amt          <= ex_operand_b_i;
    ex_shift_left_flag    <= '1' when (ex_operator_i = ALU_SLL) else
                             '0';
    ex_shift_arithmetic   <= '1' when (ex_operator_i = ALU_SRA) else
                             '0';
    -- choose the bit reversed or the normal input for shift operand a
    ex_shift_op_a         <= ex_operand_a_rev when ex_shift_left_flag = '1' else
                             ex_operand_a_i;
    ex_shift_op_a_32      <= bit_repeat(32, ex_shift_arithmetic and ex_shift_op_a(31)) & ex_shift_op_a;
    ex_shift_right_result <= std_ulogic_vector(resize(shift_right(unsigned(ex_shift_op_a_32), to_integer(unsigned(ex_shift_amt(4 downto 0)))), 32));

    -- bit reverse the shift_right_result for left shifts
    process(ex_shift_right_result)
    begin
        for j in 0 to 32 - 1 loop
            ex_shift_left_result(j) <= ex_shift_right_result(31 - j);
        end loop;
    end process;
    ex_shift_result <= ex_shift_left_result when ex_shift_left_flag = '1' else ex_shift_right_result;

    ------------------------------------------------------------------
    -- Compare
    ------------------------------------------------------------------
    process(ex_operator_i)
    begin
        ex_cmp_signed <= "0000";
        case (ex_operator_i) is
            when ALU_GES | ALU_LTS | ALU_SLTS =>
                ex_cmp_signed(3 downto 0) <= "1000";
            when others =>
        end case;
    end process;

    -- generate vector equal and greater than signals, cmp_signed decides if the
    -- comparison is done signed or unsigned

    -- generate the real equal and greater than signals that take the vector
    -- mode into account
    process(ex_cmp_signed, ex_operand_a_i, ex_operand_b_i)
        variable is_equal_vec   : std_ulogic_vector(3 downto 0);
        variable is_greater_vec : std_ulogic_vector(3 downto 0);
    begin
        for i in 0 to 3 loop
            is_equal_vec(i)   := '0';
            is_greater_vec(i) := '0';

            if (ex_operand_a_i(8 * i + 7 downto 8 * i) = ex_operand_b_i(8 * i + 7 downto i * 8)) then
                is_equal_vec(i) := '1';
            end if;

            if signed((ex_operand_a_i(8 * i + 7) and ex_cmp_signed(i)) & ex_operand_a_i(8 * i + 7 downto 8 * i)) > signed((ex_operand_b_i(8 * i + 7) and ex_cmp_signed(i)) & ex_operand_b_i(8 * i + 7 downto i * 8)) then
                is_greater_vec(i) := '1';
            end if;
        end loop;

        -- 32-bit mode
        ex_is_equal(3 downto 0)   <= (others => is_equal_vec(3) and is_equal_vec(2) and is_equal_vec(1) and is_equal_vec(0));
        ex_is_greater(3 downto 0) <= (others => is_greater_vec(3) or (is_equal_vec(3) and (is_greater_vec(2) or (is_equal_vec(2) and (is_greater_vec(1) or (is_equal_vec(1) and (is_greater_vec(0))))))));
    end process;

    process(ex_is_equal, ex_is_greater, ex_operator_i)
    begin
        ex_cmp_result <= ex_is_equal;
        case (ex_operator_i) is
            when ALU_EQ                               => ex_cmp_result <= ex_is_equal;
            when ALU_NE                               => ex_cmp_result <= not ex_is_equal;
            when ALU_GES| ALU_GEU                     => ex_cmp_result <= ex_is_greater or ex_is_equal;
            when ALU_LTS| ALU_SLTS| ALU_LTU| ALU_SLTU => ex_cmp_result <= not (ex_is_greater or ex_is_equal);
            when others =>
        end case;
    end process;

    ex_comparison_result_int <= ex_cmp_result(3);

    ----------------------------------------------------
    -- Divider / Remainder
    ----------------------------------------------------
    ex_div_valid     <= ex_enable_i when ((ex_operator_i = ALU_DIV) or (ex_operator_i = ALU_DIVU) or (ex_operator_i = ALU_REM) or (ex_operator_i = ALU_REMU)) else
                        '0';
    ex_div_b_is_zero <= '1' when (unsigned(ex_operand_b_i) = 0) else '0';

    div_control_fsm : process(ex_div_control_fsm_ff, ex_div_busy, ex_div_valid, ex_operator_i, mem_ready_i)
    begin
        ex_div_start_divu      <= '0';
        ex_div_start_div       <= '0';
        ex_div_control_fsm_nxt <= ex_div_control_fsm_ff;
        ex_div_ready           <= not ex_div_busy;

        case (ex_div_control_fsm_ff) is
            when IDLE =>
                if ex_div_valid = '1' then
                    if (ex_operator_i = ALU_REMU or ex_operator_i = ALU_DIVU) then
                        ex_div_start_divu <= '1';
                        ex_div_start_div  <= '0';
                    else
                        ex_div_start_divu <= '0';
                        ex_div_start_div  <= '1';
                    end if;
                    ex_div_control_fsm_nxt <= DIVIDE;
                    ex_div_ready           <= '0';
                end if;

            when DIVIDE =>
                if ex_div_busy = '0' and mem_ready_i = '1' then
                    ex_div_control_fsm_nxt <= IDLE;
                end if;

        end case;
    end process;

    process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            ex_div_control_fsm_ff <= IDLE;
        elsif (rising_edge(clk_i)) then

            ex_div_control_fsm_ff <= ex_div_control_fsm_nxt;
        end if;
    end process;

    alu_div_i : eisV_alu_divide
        port map(
            clk_i                => clk_i,
            rst_ni               => rst_ni,
            ex_clk_en_i          => ex_div_valid, -- clock enable
            ex_op_div_i          => ex_div_start_div, -- True to initiate a signed divide
            ex_op_divu_i         => ex_div_start_divu, -- True to initiate an unsigned divide
            ex_dividend_i        => ex_operand_a_i,
            ex_divisor_is_zero_i => ex_div_b_is_zero,
            ex_divisor_i         => ex_operand_b_i,
            ex_quotient_o        => ex_div_quotient,
            ex_remainder_o       => ex_div_remainder,
            ex_stall_o           => ex_div_busy -- True while calculating
        );

    ex_result_div <= ex_div_remainder when (ex_operator_i = ALU_REM or ex_operator_i = ALU_REMU) else ex_div_quotient;

    --------------------------------------------------------
    -- Result Multiplex
    --------------------------------------------------------

    process(ex_cmp_result, ex_comparison_result_int, ex_operand_a_i, ex_operand_b_i, ex_operator_i, ex_result_div, ex_shift_result, ex_adder_result)
    begin
        ex_result_o <= (others => '0');

        case (ex_operator_i) is
            -- Standard Operations
            when ALU_AND =>
                ex_result_o <= ex_operand_a_i and ex_operand_b_i;
            when ALU_OR =>
                ex_result_o <= ex_operand_a_i or ex_operand_b_i;
            when ALU_XOR =>
                ex_result_o <= ex_operand_a_i xor ex_operand_b_i;

            -- Shift Operations
            when ALU_SLL | ALU_SRL | ALU_SRA =>
                ex_result_o <= ex_shift_result;

            -- Comparison Operations
            when ALU_EQ | ALU_NE | ALU_GEU | ALU_LTU | ALU_GES | ALU_LTS =>
                ex_result_o(31 downto 24) <= bit_repeat(8, ex_cmp_result(3));
                ex_result_o(23 downto 16) <= bit_repeat(8, ex_cmp_result(2));
                ex_result_o(15 downto 8)  <= bit_repeat(8, ex_cmp_result(1));
                ex_result_o(7 downto 0)   <= bit_repeat(8, ex_cmp_result(0));

            -- Non-vector comparisons
            when ALU_SLTS | ALU_SLTU =>
                ex_result_o    <= (others => '0');
                ex_result_o(0) <= ex_comparison_result_int;

            when ALU_ADD | ALU_SUB =>
                ex_result_o <= ex_adder_result;

            -- Division Unit Commands
            when ALU_DIV | ALU_DIVU | ALU_REM | ALU_REMU =>
                ex_result_o <= ex_result_div;
        end case;
    end process;

    ex_comparison_result_o <= ex_comparison_result_int;
    ex_alu_ready_o         <= ex_div_ready;

end architecture RTL;
