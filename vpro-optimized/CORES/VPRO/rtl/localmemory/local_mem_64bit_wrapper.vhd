--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System Local Memory 64 bit wrapper                #
-- #############################################################################
-- coverage off

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_specializations.all;
use core_v2pro.package_datawidths.all;

entity local_mem_64bit_wrapper is
    generic(
        ADDR_WIDTH_g      : natural := 13; -- must be 11..15;  13 => 8192x16bit
        LM_DATA_WIDTH_g   : natural := 16;
        VPRO_DATA_WIDTH_g : natural := 16; -- should not be changed
        DCMA_DATA_WIDTH_g : natural := 64 -- should not be changed
    );
    port(
        -- port A: VPRO Lane--
        a_clk_i  : in  std_ulogic;
        a_addr_i : in  std_ulogic_vector(19 downto 0); -- TODO make this ADDR_WIDTH ?!
        a_di_i   : in  std_ulogic_vector(VPRO_DATA_WIDTH_g - 1 downto 0);
        a_we_i   : in  std_ulogic;
        a_re_i   : in  std_ulogic;
        a_do_o   : out std_ulogic_vector(VPRO_DATA_WIDTH_g - 1 downto 0);
        -- port B: VPRO DMA --
        b_clk_i  : in  std_ulogic;
        b_addr_i : in  std_ulogic_vector(19 downto 0);
        b_di_i   : in  std_ulogic_vector(DCMA_DATA_WIDTH_g - 1 downto 0);
        b_we_i   : in  std_ulogic_vector(DCMA_DATA_WIDTH_g / VPRO_DATA_WIDTH_g - 1 downto 0); -- 16bit word write enable
        b_re_i   : in  std_ulogic;
        b_do_o   : out std_ulogic_vector(DCMA_DATA_WIDTH_g - 1 downto 0)
    );
end local_mem_64bit_wrapper;

architecture rtl of local_mem_64bit_wrapper is
    -- functions    
--coverage off
    impure function get_vpro_words_per_lm_log2(number_vpro_words_per_lm : natural) return natural is
        variable num_v : natural;
    begin
        if number_vpro_words_per_lm = 1 then
            -- correct result would be zero, but vector with zero length not possible
            num_v := 1;
        else
            num_v := integer(ceil(log2(real(number_vpro_words_per_lm))));
        end if;
        return num_v;
    end function get_vpro_words_per_lm_log2;
--coverage on

    -- constants
    constant number_local_mem_c              : integer := DCMA_DATA_WIDTH_g / LM_DATA_WIDTH_g;
    constant number_local_mem_log2_c         : integer := integer(ceil(log2(real(number_local_mem_c))));
    constant number_vpro_words_per_lm_c      : integer := LM_DATA_WIDTH_g / VPRO_DATA_WIDTH_g;
    constant number_vpro_words_per_lm_log2_c : integer := get_vpro_words_per_lm_log2(number_vpro_words_per_lm_c);

    -- types    
    type vpro_data_array_t is array (number_local_mem_c - 1 downto 0) of std_ulogic_vector(LM_DATA_WIDTH_g - 1 downto 0);
    type vpro_write_enable_array_t is array (number_local_mem_c - 1 downto 0) of std_ulogic_vector(LM_DATA_WIDTH_g / 8 - 1 downto 0);

    -- register
    --    signal vpro_last_read_ff, vpro_last_read_nxt : std_ulogic_vector(number_local_mem_log2_c - 1 downto 0);
    signal vpro_lm_sel_delay1_ff, vpro_lm_sel_delay2_ff     : std_ulogic_vector(number_local_mem_log2_c - 1 downto 0); -- data comes 2 cycles after read enable
    signal vpro_word_sel_delay1_ff, vpro_word_sel_delay2_ff : std_ulogic_vector(number_vpro_words_per_lm_log2_c - 1 downto 0); -- data comes 2 cycles after read enable
    signal last_vpro_re_ff, last_vpro_re_nxt                : std_ulogic;

    -- signals
    signal vpro_clk_i  : std_ulogic;
    signal dma_clk_i   : std_ulogic;
    signal vpro_addr_i : std_ulogic_vector(a_addr_i'range);
    signal vpro_di_i   : std_ulogic_vector(LM_DATA_WIDTH_g - 1 downto 0);
    signal vpro_we_i   : vpro_write_enable_array_t;
    signal vpro_re_i   : std_ulogic_vector(number_local_mem_c - 1 downto 0);
    signal vpro_do_o   : vpro_data_array_t;
    signal dma_addr_i  : std_ulogic_vector(b_addr_i'range);
    signal dma_di_i    : std_ulogic_vector(DCMA_DATA_WIDTH_g - 1 downto 0);
    signal dma_we_i    : vpro_write_enable_array_t;
    signal dma_re_i    : std_ulogic;
    signal dma_do_o    : std_ulogic_vector(DCMA_DATA_WIDTH_g - 1 downto 0);

    signal vpro_lm_sel   : std_ulogic_vector(number_local_mem_log2_c - 1 downto 0);
    signal vpro_word_sel : std_ulogic_vector(number_vpro_words_per_lm_log2_c - 1 downto 0);
begin
    lm_eq_vpro_width_gen : if LM_DATA_WIDTH_g = VPRO_DATA_WIDTH_g generate
        local_mem_gen : for I in 0 to number_local_mem_c - 1 generate
            local_mem_inst : local_mem
                generic map(
                    ADDR_WIDTH_g => ADDR_WIDTH_g - number_local_mem_log2_c,
                    DATA_WIDTH_g => LM_DATA_WIDTH_g
                )
                port map(
                    a_clk_i  => vpro_clk_i,
                    a_addr_i => vpro_addr_i,
                    a_di_i   => vpro_di_i,
                    a_we_i   => vpro_we_i(I),
                    a_re_i   => vpro_re_i(I),
                    a_do_o   => vpro_do_o(I),
                    b_clk_i  => dma_clk_i,
                    b_addr_i => dma_addr_i,
                    b_di_i   => dma_di_i((I + 1) * LM_DATA_WIDTH_g - 1 downto I * LM_DATA_WIDTH_g),
                    b_we_i   => dma_we_i(I),
                    b_re_i   => dma_re_i,
                    b_do_o   => dma_do_o((I + 1) * LM_DATA_WIDTH_g - 1 downto I * LM_DATA_WIDTH_g)
                );
        end generate;
    end generate;

    lm_uneq_vpro_width_gen : if LM_DATA_WIDTH_g /= VPRO_DATA_WIDTH_g generate
        local_mem_gen : for I in 0 to number_local_mem_c - 1 generate
            local_mem_inst : local_mem
                generic map(
                    ADDR_WIDTH_g => ADDR_WIDTH_g - number_local_mem_log2_c - number_vpro_words_per_lm_log2_c,
                    DATA_WIDTH_g => LM_DATA_WIDTH_g
                )
                port map(
                    a_clk_i  => vpro_clk_i,
                    a_addr_i => vpro_addr_i,
                    a_di_i   => vpro_di_i,
                    a_we_i   => vpro_we_i(I),
                    a_re_i   => vpro_re_i(I),
                    a_do_o   => vpro_do_o(I),
                    b_clk_i  => dma_clk_i,
                    b_addr_i => dma_addr_i,
                    b_di_i   => dma_di_i((I + 1) * LM_DATA_WIDTH_g - 1 downto I * LM_DATA_WIDTH_g),
                    b_we_i   => dma_we_i(I),
                    b_re_i   => dma_re_i,
                    b_do_o   => dma_do_o((I + 1) * LM_DATA_WIDTH_g - 1 downto I * LM_DATA_WIDTH_g)
                );
        end generate;
    end generate;

    -- vpro lane signals
    vpro_clk_i <= a_clk_i;

    vpro_sel_proc : process(a_addr_i)
    begin
        -- default
        vpro_lm_sel   <= a_addr_i(number_local_mem_log2_c + number_vpro_words_per_lm_log2_c - 1 downto number_vpro_words_per_lm_log2_c);
        vpro_word_sel <= a_addr_i(number_vpro_words_per_lm_log2_c - 1 downto 0);

        if LM_DATA_WIDTH_g = VPRO_DATA_WIDTH_g then
            vpro_lm_sel <= a_addr_i(number_local_mem_log2_c - 1 downto 0);
        end if;
    end process;

    data_mux_proc : process(a_di_i, vpro_do_o, last_vpro_re_ff, vpro_lm_sel_delay1_ff, vpro_lm_sel_delay2_ff, vpro_word_sel, vpro_word_sel_delay1_ff, vpro_word_sel_delay2_ff)
        variable vpro_word_sel_v        : natural;
        variable vpro_word_sel_delay1_v : natural;
        variable vpro_word_sel_delay2_v : natural;
    begin
        if LM_DATA_WIDTH_g /= VPRO_DATA_WIDTH_g then
            vpro_word_sel_v                                                                                     := to_integer(unsigned(vpro_word_sel));
            vpro_di_i                                                                                           <= (others => '0');
            vpro_di_i((vpro_word_sel_v + 1) * VPRO_DATA_WIDTH_g - 1 downto vpro_word_sel_v * VPRO_DATA_WIDTH_g) <= a_di_i;

            vpro_word_sel_delay1_v := to_integer(unsigned(vpro_word_sel_delay1_ff));
            vpro_word_sel_delay2_v := to_integer(unsigned(vpro_word_sel_delay2_ff));
            a_do_o                 <= vpro_do_o(to_integer(unsigned(vpro_lm_sel_delay1_ff)))((vpro_word_sel_delay1_v + 1) * VPRO_DATA_WIDTH_g - 1 downto vpro_word_sel_delay1_v * VPRO_DATA_WIDTH_g);
            if last_vpro_re_ff = '1' then
                a_do_o <= vpro_do_o(to_integer(unsigned(vpro_lm_sel_delay2_ff)))((vpro_word_sel_delay2_v + 1) * VPRO_DATA_WIDTH_g - 1 downto vpro_word_sel_delay2_v * VPRO_DATA_WIDTH_g);
            end if;
        end if;

        if LM_DATA_WIDTH_g = VPRO_DATA_WIDTH_g then
            vpro_di_i <= a_di_i;        -- @suppress "Incorrect array size in assignment: expected (<LM_DATA_WIDTH_g>) but was (<VPRO_DATA_WIDTH_g>)"

            a_do_o <= vpro_do_o(to_integer(unsigned(vpro_lm_sel_delay1_ff))); -- @suppress "Incorrect array size in assignment: expected (<VPRO_DATA_WIDTH_g>) but was (<LM_DATA_WIDTH_g>)"
            if last_vpro_re_ff = '1' then
                a_do_o <= vpro_do_o(to_integer(unsigned(vpro_lm_sel_delay2_ff))); -- @suppress "Incorrect array size in assignment: expected (<VPRO_DATA_WIDTH_g>) but was (<LM_DATA_WIDTH_g>)"
            end if;
        end if;
    end process;

    --    vpro_last_read_nxt <= vpro_lm_sel when a_re_i = '1' else vpro_last_read_ff;
    last_vpro_re_nxt <= '0' when unsigned(vpro_re_i) = 0 else '1';

    vpro_addr_and_enable_proc : process(a_addr_i, a_re_i, a_we_i, vpro_lm_sel)
    begin
        if LM_DATA_WIDTH_g = VPRO_DATA_WIDTH_g then
            vpro_addr_i                                                         <= (others => '0');
            vpro_addr_i(a_addr_i'length - number_local_mem_log2_c - 1 downto 0) <= a_addr_i(a_addr_i'length - 1 downto number_local_mem_log2_c);
        end if;

        if LM_DATA_WIDTH_g /= VPRO_DATA_WIDTH_g then
            vpro_addr_i                                                                                           <= (others => '0');
            vpro_addr_i(a_addr_i'length - number_local_mem_log2_c - number_vpro_words_per_lm_log2_c - 1 downto 0) <= a_addr_i(a_addr_i'length - 1 downto number_local_mem_log2_c + number_vpro_words_per_lm_log2_c);
        end if;

        vpro_re_i <= (others => '0');
        if a_re_i = '1' then
            vpro_re_i(to_integer(unsigned(vpro_lm_sel))) <= '1';
        end if;

        vpro_we_i <= (others => (others => '0'));
        if a_we_i = '1' then
            vpro_we_i(to_integer(unsigned(vpro_lm_sel))) <= (others => '1');
        end if;
    end process;

    vpro_seq : process(vpro_clk_i)
    begin
        if rising_edge(vpro_clk_i) then
            last_vpro_re_ff <= last_vpro_re_nxt;
            if unsigned(vpro_re_i) /= 0 then
                vpro_lm_sel_delay1_ff   <= vpro_lm_sel;
                vpro_lm_sel_delay2_ff   <= vpro_lm_sel_delay1_ff;
                vpro_word_sel_delay1_ff <= vpro_word_sel;
                vpro_word_sel_delay2_ff <= vpro_word_sel_delay1_ff;
            end if;
        end if;
    end process;

    -- vpro dma signals
    dma_clk_i <= b_clk_i;
    dma_di_i  <= b_di_i;
    dma_re_i  <= b_re_i;
    b_do_o    <= dma_do_o;

    process(b_we_i)
        constant const_ones_c : std_ulogic_vector(VPRO_DATA_WIDTH_g / 8 - 1 downto 0) := std_ulogic_vector(to_signed(-1, VPRO_DATA_WIDTH_g / 8));
    begin
        -- default
        dma_we_i <= (others => (others => '0'));

        for ram in 0 to number_local_mem_c - 1 loop
            for word in 0 to number_vpro_words_per_lm_c - 1 loop
                if b_we_i(ram * number_vpro_words_per_lm_c + word) = '1' then
                    dma_we_i(ram)((word + 1) * VPRO_DATA_WIDTH_g / 8 - 1 downto word * VPRO_DATA_WIDTH_g / 8) <= const_ones_c;
                end if;
            end loop;
        end loop;
    end process;

    dma_addr_proc : process(b_addr_i)
    begin
        dma_addr_i                                                         <= (others => '0');
        dma_addr_i(a_addr_i'length - number_local_mem_log2_c - 1 downto 0) <= b_addr_i(b_addr_i'length - 1 downto number_local_mem_log2_c);
    end process;

end rtl;
-- coverage on
