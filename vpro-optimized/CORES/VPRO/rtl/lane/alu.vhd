--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System Data Processing Unit                       #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

entity alu is
    generic(
        minmax_instance_g       : boolean := true;
        bit_reversal_instance_g : boolean := true
    );
    port(
        -- global control --
        ce_i              : in  std_ulogic;
        clk_i             : in  std_ulogic;
        -- function --
        en_i              : in  std_ulogic; -- alu enable
        fusel_i           : in  std_ulogic_vector(01 downto 0); -- function unit select
        func_i            : in  std_ulogic_vector(03 downto 0); -- function select
        mul_shift_i       : in  std_ulogic_vector(04 downto 0);
        mac_shift_i       : in  std_ulogic_vector(04 downto 0);
        mac_init_source_i : in  MAC_INIT_SOURCE_t;
        reset_accu_i      : in  std_ulogic;
        first_iteration_i : in  std_ulogic;
        conditional_i     : in  std_ulogic;
        -- operands --
        opa_i             : in  std_ulogic_vector(rf_data_width_c - 1 downto 0); -- operand A
        opb_i             : in  std_ulogic_vector(rf_data_width_c - 1 downto 0); -- operand B
        opc_i             : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
        -- results --
        result_o          : out std_ulogic_vector(rf_data_width_c - 1 downto 0); -- computation result
        flags_o           : out std_ulogic_vector(01 downto 0) -- new status flags
    );
    --    attribute keep_hierarchy : string;
    --    attribute keep_hierarchy of alu : entity is "true";
end entity alu;

architecture alu_rtl of alu is

    -- pipeline register --
    signal opa_ff0   : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal opb_ff0   : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal opa_ff1   : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal opb_ff1   : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal fusel_ff0 : std_ulogic_vector(01 downto 0);
    signal fusel_ff1 : std_ulogic_vector(01 downto 0);
    signal fusel_ff2 : std_ulogic_vector(01 downto 0); -- @suppress "signal fusel_ff2 is never read"
    signal func_ff0  : std_ulogic_vector(03 downto 0);
    signal func_ff1  : std_ulogic_vector(03 downto 0);
    signal en_ff0    : std_ulogic;
    signal en_ff1    : std_ulogic;

    --    type result_src_t is (OPA, OPB, DSP, MIN_MAX, ABS_UNIT, BARREL_SHIFTER, BIT_REVERSAL);
    type result_src_t is (DSP, BARREL_SHIFTER, BIT_REVERSAL, PRE_RESULT_MUX);
    signal result_src, result_src_nxt : result_src_t;

    -- dsp unit --
    signal dsp_en   : std_ulogic;       -- allow update of internal registers (ACC)
    signal dsp_func : std_ulogic_vector(03 downto 0);
    signal dsp_res  : std_ulogic_vector(rf_data_width_c - 1 downto 0); -- processing result

    -- max/min unit --
    signal cmp_res_ff1  : std_ulogic_vector(rf_data_width_c - 1 downto 0);

    -- abs unit --
    signal abs_res_ff1 : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal abs_en_wide : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal abs_en_add  : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    signal abs_en      : std_ulogic;

    -- barrelshifter --
    signal bs_res : std_ulogic_vector(rf_data_width_c - 1 downto 0);

    -- bit reversal --
    signal bit_reversal_res_ff2 : std_ulogic_vector(rf_data_width_c - 1 downto 0);

    -- misc --
    signal result : std_ulogic_vector(rf_data_width_c - 1 downto 0);

    signal pre_result_ff, pre_result_nxt : std_ulogic_vector(rf_data_width_c - 1 downto 0);

begin

    -- Pipeline Register ----------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    pipe_regs : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                -- stage 0 - input buffer --
                opa_ff0   <= opa_i;
                opb_ff0   <= opb_i;
                fusel_ff0 <= fusel_i;
                func_ff0  <= func_i;
                en_ff0    <= en_i;
                -- stage 1 --
                opa_ff1   <= opa_ff0;
                opb_ff1   <= opb_ff0;
                fusel_ff1 <= fusel_ff0;
                func_ff1  <= func_ff0;
                en_ff1    <= en_ff0;
                -- stage 2 --
                fusel_ff2 <= fusel_ff1;
            end if;
        end if;
    end process pipe_regs;

    -- DSP Processing Core --------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    dsp_unit_inst : dsp_unit
        generic map(
            DATA_INOUT_WIDTH_g => rf_data_width_c, -- using defaults (constant from package)
            MUL_OPB_WIDTH_g    => opb_mul_data_width_c,
            STATIC_SHIFT_g     => 0
        )
        port map(
            -- global control --
            ce_i              => ce_i,
            clk_i             => clk_i,
            enable_i          => dsp_en,
            function_i        => dsp_func,
            mul_shift_i       => mul_shift_i,
            mac_shift_i       => mac_shift_i,
            mac_init_source_i => mac_init_source_i,
            reset_accu_i      => reset_accu_i,
            first_iteration_i => first_iteration_i,
            -- operands --
            opa_i             => opa_i,
            opb_i             => opb_i,
            opc_i             => opc_i,
            -- results --
            is_zero_o         => open,
            data_o            => dsp_res
        );

    -- enable update of internal registers --
    dsp_en <= en_i when (fusel_i = fu_aludsp_c) or (fusel_i = fu_condmove_c) else '0'; -- dsp en for arithmetic and conditionals (due to conditional arithmetic)

    conditional_arithmetic : process(func_i, fusel_i)
    begin
        dsp_func <= func_i;
        if fusel_i = fu_condmove_c then
            dsp_func(0) <= '0';         -- difference on conditional neg or pos afterwards, opcode for mull and mulh matches!
        end if;
    end process;

    -- Bit Reversal ------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    --coverage off
    bit_reversal_process : if bit_reversal_instance_g generate
        bit_reversal_logic : process(clk_i)
        begin
            if rising_edge(clk_i) then
                if (ce_i = '1') then
                    --				bit_reversal_res_ff1  <= opa_ff0;
                    for i in 0 to opa_ff1'left loop
                        bit_reversal_res_ff2(opa_ff1'left - i) <= opa_ff1(i);
                    end loop;
                end if;
            end if;
        end process bit_reversal_logic;
    end generate bit_reversal_process;
    --coverage on

    -- Max/Min Unit ------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    max_min : process(clk_i)
        variable compare_flag          : std_ulogic;
        variable compare_value_special : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                -- changes by concat to xnor with instruction and save to reg:
                -- additional cost of a result register (24-bit instead 1-bit for flag) 
                -- result is directed to additional out port
                -- allows iterative use as input in next cycle e.g. for the min_vector instruction

                -- comparator --
                compare_value_special := opb_ff0;

                --coverage off
                if minmax_instance_g then
                    if (func_ff0(3) = '1') then -- min/max vector instruction, second value is registered min/max
                        if en_ff1 = '0' and en_ff0 = '1' then -- first cycle
                            compare_value_special := opa_ff0; -- init to first vaĺue of vector?
                        else
                            compare_value_special := cmp_res_ff1; -- last result
                        end if;
                    end if;
                end if;
                --coverage on

                if (signed(opa_ff0) < signed(compare_value_special)) then
                    compare_flag := '1';
                else
                    compare_flag := '0';
                end if;

                -- func_ff1(cmd_func0_c) = '0' => MIN, else MAX
                -- equal to: B is bigger and MAX or B is smaller and MIN
                if ((func_ff0(0) xnor compare_flag) = '1') then
                    cmp_res_ff1  <= compare_value_special;
                else
                    cmp_res_ff1  <= opa_ff0;
                end if;
            end if;
        end if;
    end process max_min;

    -- Absolute Unit -----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    abs_en                                   <= opa_ff0(rf_data_width_c - 1);
    abs_en_add(rf_data_width_c - 1 downto 1) <= (others => '0');
    abs_en_add(0)                            <= abs_en; -- 1 or 0
    abs_en_wide                              <= (others => abs_en);

    absolute : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                -- negate if negative
                -- 2-complement negation: invert all bits + '1'
                abs_res_ff1 <= std_ulogic_vector(unsigned(opa_ff0 xor abs_en_wide) + unsigned(abs_en_add));
            end if;
        end if;
    end process absolute;

    -- Barrelshifter -----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    bs_unit_inst : bs_unit
        generic map(
            only_right_shift => true
        )
        port map(
            -- global control --
            ce_i       => ce_i,
            clk_i      => clk_i,
            function_i => func_ff0,
            -- operands --
            opa_i      => opa_ff0,
            opb_i      => opb_ff0,
            -- result --
            data_o     => bs_res
        );

    -- Data Output Selector ---- STAGE 7/8_nxt ---------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    result_sel_logic : process(fusel_ff1, func_ff1, conditional_i, abs_res_ff1, cmp_res_ff1, opa_ff1, opb_ff1)
    begin
        result_src_nxt <= PRE_RESULT_MUX;
        pre_result_nxt <= (others => '-');

        case fusel_ff1 is
            when fu_aludsp_c =>         -- ARITH/LOGIC
                result_src_nxt <= DSP;
            when fu_special_c =>
                --coverage off
                if bit_reversal_instance_g then
                    case func_ff1 is
                        when func_shift_lr_c | func_shift_ar_c =>
                            result_src_nxt <= BARREL_SHIFTER;
                        when func_abs_c =>
                            pre_result_nxt <= abs_res_ff1;
                        when func_bit_reversal_c =>
                            result_src_nxt <= BIT_REVERSAL;
                        when others =>
                            pre_result_nxt <= cmp_res_ff1;
                    end case;
                else   
                --coverage on
                    case func_ff1 is
                        when func_shift_lr_c | func_shift_ar_c =>
                            result_src_nxt <= BARREL_SHIFTER;
                        when func_abs_c =>
                            pre_result_nxt <= abs_res_ff1;
                        when others =>
                            pre_result_nxt <= cmp_res_ff1;
                    end case;
                end if;
            when fu_memory_c =>
                pre_result_nxt <= opb_ff1;
            when fu_condmove_c =>       -- MOVE
                case func_ff1 is
                    when func_mull_neg_c | func_mulh_neg_c | func_mull_pos_c | func_mulh_pos_c =>
                        result_src_nxt <= DSP;
                    when func_shift_ar_neg_c | func_shift_ar_pos_c =>
                        result_src_nxt <= BARREL_SHIFTER;
                    when others =>
                        pre_result_nxt <= opb_ff1;
                end case;
            when OTHERS =>
        end case;

        -- always set OPA if conditional check fails
        if (conditional_i = '0') then
            result_src_nxt <= PRE_RESULT_MUX;
            pre_result_nxt <= opa_ff1;
        end if;
    end process;

    result_sel_buffer : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                pre_result_ff <= pre_result_nxt;
                result_src    <= result_src_nxt;
            end if;
        end if;
    end process;

    -- stage 8
    wb_mux : process(result_src, dsp_res, bs_res, bit_reversal_res_ff2, pre_result_ff)
        variable dsp_res_postprocessed : std_ulogic_vector(rf_data_width_c - 1 downto 0);
    begin
        dsp_res_postprocessed := dsp_res;
        result            <= (others => '-');

        case result_src is
            when DSP =>
                result            <= dsp_res_postprocessed;
            when BARREL_SHIFTER =>
                result            <= bs_res;
                --coverage off
            when BIT_REVERSAL =>        -- never occurs when _g disabled the bit reversal
                result            <= bit_reversal_res_ff2;
                --coverage on
            when PRE_RESULT_MUX =>
                result            <= pre_result_ff;
        end case;
    end process wb_mux;

    -- data output --
    result_o <= result;

    -- global negative flag --
    flags_o(n_fbus_c) <= result(result'left);
    flags_o(z_fbus_c) <= '1' when unsigned(result) = 0 else '0';

end architecture alu_rtl;

