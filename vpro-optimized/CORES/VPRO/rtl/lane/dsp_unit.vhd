--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System Arithmetic/Logic Core                      #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

entity dsp_unit is
    generic(
        DATA_INOUT_WIDTH_g : natural := rf_data_width_c;
        MUL_OPB_WIDTH_g    : natural := opb_mul_data_width_c;
        STATIC_SHIFT_g     : natural := 0 -- @suppress "Unused generic: STATIC_SHIFT_g is not used in core_v2pro.dsp_unit(dsp_unit_rtl)"
    );
    port(
        -- global control --
        ce_i              : in  std_ulogic;
        clk_i             : in  std_ulogic;
        enable_i          : in  std_ulogic;
        function_i        : in  std_ulogic_vector(03 downto 0);
        mul_shift_i       : in  std_ulogic_vector(04 downto 0);
        mac_shift_i       : in  std_ulogic_vector(04 downto 0);
        mac_init_source_i : in  MAC_INIT_SOURCE_t;
        reset_accu_i      : in  std_ulogic;
        first_iteration_i : in  std_ulogic;
        -- operands --
        opa_i             : in  std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
        opb_i             : in  std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
        opc_i             : in  std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
        -- results --
        is_zero_o         : out std_ulogic;
        data_o            : out std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0)
    );
end entity dsp_unit;

architecture dsp_unit_rtl of dsp_unit is

    -- dsp operands --
    signal opa_int, opa_int_ff                       : std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
    signal opb_int, opb_int_ff                       : std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
    signal opc_int, opc_int_ff                       : std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
    signal dsp_result, dsp_result_ff2                : std_ulogic_vector(DATA_INOUT_WIDTH_g * 2 - 1 downto 0);
    signal dsp_result_post_processed, dsp_result_ff3 : std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
    signal reset_accu_ff1                            : std_ulogic; -- reset accu (mac)?
    signal first_iteration_ff1                       : std_ulogic; -- first operation cycle?
    signal accu, accu_nxt                            : signed(DATA_INOUT_WIDTH_g * 2 - 1 downto 0);
    -- misc --
    signal pdetect_ff1, pdetect_ff2, pdetect_ff3     : std_ulogic;
    signal enable_ff1, enable_ff2                    : std_ulogic;
    signal function_ff1, function_ff2                : std_ulogic_vector(function_i'length - 1 downto 0);

begin
    -- Pipeline Registers ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    pipe_regs : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (ce_i = '1') then
                enable_ff1 <= enable_i;
                enable_ff2 <= enable_ff1;

                if (enable_i = '1') then
                    function_ff1        <= function_i;
                    opa_int_ff          <= opa_int;
                    opb_int_ff          <= opb_int;
                    opc_int_ff          <= opc_int;
                    reset_accu_ff1      <= reset_accu_i;
                    first_iteration_ff1 <= first_iteration_i;
                end if;
                if (enable_ff1 = '1') then
                    accu           <= accu_nxt;
                    dsp_result_ff2 <= dsp_result;
                    pdetect_ff2    <= pdetect_ff1;
                    function_ff2   <= function_ff1;
                end if;
                if (enable_ff2 = '1') then
                    dsp_result_ff3 <= dsp_result_post_processed;
                    pdetect_ff3    <= pdetect_ff2;
                end if;
            end if;
        end if;
    end process pipe_regs;

    -- Operation Selection --------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    op_decode : process(opa_i, opb_i, mac_init_source_i, opc_i, function_i)
    begin
        opa_int                                  <= (others => opa_i(DATA_INOUT_WIDTH_g - 1)); -- sign extension
        opa_int(DATA_INOUT_WIDTH_g - 1 downto 0) <= opa_i(DATA_INOUT_WIDTH_g - 1 downto 0);
        opb_int                                  <= (others => opb_i(DATA_INOUT_WIDTH_g - 1)); -- sign extension
        opb_int(DATA_INOUT_WIDTH_g - 1 downto 0) <= opb_i(DATA_INOUT_WIDTH_g - 1 downto 0);
        if (mac_init_source_i = ZERO) or (function_i = func_mach_pre_c) then
            opc_int <= (others => '0'); -- sign extension
        else                            -- IMM or ADDR
            opc_int                                  <= (others => opc_i(DATA_INOUT_WIDTH_g - 1)); -- sign extension
            opc_int(DATA_INOUT_WIDTH_g - 1 downto 0) <= opc_i(DATA_INOUT_WIDTH_g - 1 downto 0);
        end if;
    end process op_decode;

    dsp_function : process(function_ff1, opa_int_ff, opb_int_ff, opc_int_ff, accu, reset_accu_ff1, mac_init_source_i, first_iteration_ff1, mac_shift_i)
        variable mul_tmp          : signed(accu'length - 1 downto 0);
        variable mul_add_accu_tmp : signed(accu'length - 1 downto 0);
        variable mul_add_c_tmp    : signed(accu'length - 1 downto 0);
        variable opc_v            : signed(accu'length - 1 downto 0);
        variable opc_shifted      : signed(accu'length - 1 downto 0);
        variable shift_amount     : integer range 0 to 24;
    begin
        opc_v := resize(signed(opc_int_ff), accu'length);
        if function_ff1 = func_mach_c then
            -- shift of OPC (init of Mac)
            -- TODO:
            --    24-bit shift enaugh! -> here 32-bit possible / 5-bit mac_shift_i
            --    shift split in two stages? (one stage during mul is registered here -> used for complete shift)
            --        use of input stage (RF read) for first level shift
            shift_amount := to_integer(unsigned(mac_shift_i));
            opc_shifted  := shift_left(signed(opc_v), shift_amount);
        else
            opc_shifted := signed(opc_v);
        end if;

        accu_nxt         <= accu;
        dsp_result       <= (others => '-');
        mul_tmp          := resize(signed(opa_int_ff) * signed(opb_int_ff(MUL_OPB_WIDTH_g - 1 downto 0)), mul_tmp'length);
        mul_add_accu_tmp := mul_tmp + accu;
        mul_add_c_tmp    := mul_tmp + opc_shifted;

        case function_ff1 is
            when func_add_c =>          -- ADD: D <= A + B
                dsp_result(opa_int_ff'length - 1 downto 0) <= std_ulogic_vector(unsigned(opa_int_ff) + unsigned(opb_int_ff));
            when func_sub_c =>          -- SUB: D <= B - A
                dsp_result(opa_int_ff'length - 1 downto 0) <= std_ulogic_vector(unsigned(opb_int_ff) - unsigned(opa_int_ff));
            when func_mull_c =>         -- MULL: D <= low(A*B)
                dsp_result <= std_ulogic_vector(mul_tmp);
            when func_mulh_c =>         -- MULH: D <= high(A*B)
                dsp_result <= std_ulogic_vector(mul_tmp);
            when func_macl_c =>         -- MACL: ACCU+=A*B; D <= low(A*B)
                if (reset_accu_ff1 = '1') then
                    accu_nxt   <= mul_add_c_tmp;
                    dsp_result <= std_ulogic_vector(mul_add_c_tmp);
                else
                    accu_nxt   <= mul_add_accu_tmp;
                    dsp_result <= std_ulogic_vector(mul_add_accu_tmp);
                end if;
            when func_mach_c =>         -- MACH: ACCU+=A*B; D <= high(A*B)
                if (reset_accu_ff1 = '1') then
                    accu_nxt   <= mul_add_c_tmp;
                    dsp_result <= std_ulogic_vector(mul_add_c_tmp);
                else
                    accu_nxt   <= mul_add_accu_tmp;
                    dsp_result <= std_ulogic_vector(mul_add_accu_tmp);
                end if;
            when func_macl_pre_c =>     -- MACL_PRE: ACCU=0; D <= low(A*B)
                if (first_iteration_ff1 = '1') then
                    accu_nxt   <= mul_tmp;
                    dsp_result <= std_ulogic_vector(mul_tmp);
                else
                    accu_nxt   <= mul_add_accu_tmp;
                    dsp_result <= std_ulogic_vector(mul_add_accu_tmp);
                end if;
            when func_mach_pre_c =>     -- MACH_PRE: ACCU=0; D <= high(A*B)
                if (first_iteration_ff1 = '1') then
                    accu_nxt   <= mul_tmp;
                    dsp_result <= std_ulogic_vector(mul_tmp);
                else
                    accu_nxt   <= mul_add_accu_tmp;
                    dsp_result <= std_ulogic_vector(mul_add_accu_tmp);
                end if;
            when func_xor_c =>          -- XOR: D <= A xor B
                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff xor opb_int_ff);
            when func_xnor_c =>         -- XNOR: D <= A xnor B
                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff xnor opb_int_ff);
            when func_and_c =>          -- AND: D <= A and B
                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff and opb_int_ff);
            --            when func_andn_c =>         -- ANDN: D <= A and !B
            --                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff and not opb_int_ff);
            when func_nand_c =>         -- NAND: D <= A nand B
                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff nand opb_int_ff);
            when func_or_c =>           -- OR: D <= A or B
                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff or opb_int_ff);
            --            when func_orn_c =>          -- ORN: D <= A or !B
            --                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff or not opb_int_ff);
            when func_nor_c =>          -- NOR: D <= A nor B
                dsp_result(opa_int_ff'length - 1 downto 0) <= (opa_int_ff nor opb_int_ff);
            when others =>              -- read accumulator, actual operation is irrelevant
                NULL;                   -- use defaults
        end case;
    end process dsp_function;

    p_detect : process(opa_int_ff)
    begin
        pdetect_ff1 <= '0';
        if (to_integer(unsigned(opa_int_ff)) = 0) then
            pdetect_ff1 <= '1';
        end if;
    end process p_detect;

    -- Data Output ----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    output_logic : process(function_ff2, dsp_result_ff2, mac_shift_i, mul_shift_i)
    begin
        case function_ff2 is
            when func_mulh_c =>
                dsp_result_post_processed <= dsp_result_ff2(to_integer(unsigned(mul_shift_i)) + DATA_INOUT_WIDTH_g - 1 downto to_integer(unsigned(mul_shift_i)));
            when func_mach_c | func_mach_pre_c =>
                dsp_result_post_processed <= dsp_result_ff2(to_integer(unsigned(mac_shift_i)) + DATA_INOUT_WIDTH_g - 1 downto to_integer(unsigned(mac_shift_i)));
            when others =>
                dsp_result_post_processed <= dsp_result_ff2(dsp_result_post_processed'length - 1 downto 0);
        end case;
    end process;

    -- actual output --
    data_o    <= dsp_result_ff3;        -- @suppress "Incorrect array size in assignment: expected (<24>) but was (<DATA_INOUT_WIDTH_g>)"
    is_zero_o <= pdetect_ff3;

end architecture dsp_unit_rtl;

