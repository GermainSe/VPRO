--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2023, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
--! @file dma_command_gen.vhd
--! @brief DCache Block to be interpreted as DMA Command is used here to e.g. Loop (Generate) DMA Commands
-- #############################################################################
-- coverage off

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;                  -- multi_cmd_t

--! Use Vectorprocessor libray
library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

entity dma_command_gen is
    port(
        vpro_clk_i           : in  std_ulogic; -- global clock signal, rising-edge
        vpro_rst_i           : in  std_ulogic; -- global reset, async, polarity: see package
        idma_cmd_full_i      : in  std_ulogic;
        idma_dcache_cmd_i    : in  multi_cmd_t;
        idma_dcache_cmd_we_i : in  std_ulogic;
        dma_cmd_gen_cmd_o    : out dma_command_t;
        dma_cmd_we_o         : out std_ulogic;
        waiting_for_dma_o    : out std_ulogic;
        busy_o               : out std_ulogic
    );
end entity dma_command_gen;

architecture RTL of dma_command_gen is

    -- internal command, send to output
    signal dma_cmd_int : dma_command_t;

    -- base DMA command
    signal base_dma_cmd_ff, base_dma_cmd_nxt : dma_command_t;

    -- modified DMA command
    signal generated_dma_cmd_ff, generated_dma_cmd_nxt             : dma_command_t;
    signal generated_dma_cmd_issue_nxt, generated_dma_cmd_issue_ff : std_ulogic;

    -- loop parameter registers
    type loop_parameter_t is record
        cluster_loop_len        : unsigned(7 downto 0); -- 0 - 'clusters (8bit => max 255 Clusters)
        cluster_loop_shift_incr : signed(7 downto 0);
        unit_loop_len           : unsigned(7 downto 0); -- 0 - 'units    (8bit => max 255 Units)
        unit_loop_shift_incr    : signed(7 downto 0);
        inter_unit_loop_len     : unsigned(7 downto 0); -- 8bit => max 255 CMDs/Unit -> 'lane count
        lm_incr                 : signed(12 downto 0); -- 0 - 8192 (LM addr): -8192 -- +8191
        mm_incr                 : signed(31 downto 0); --
        dma_cmd_count           : unsigned(15 downto 0); -- Total number of generating commands. Debug / fsm logic uses this
    end record;
    signal loop_parameter_ff, loop_parameter_nxt : loop_parameter_t;

    -- loop counter
    signal cluster_loop_cnt_ff, cluster_loop_cnt_nxt       : unsigned(7 downto 0);
    signal unit_loop_cnt_ff, unit_loop_cnt_nxt             : unsigned(7 downto 0);
    signal inter_unit_loop_cnt_ff, inter_unit_loop_cnt_nxt : unsigned(7 downto 0);
    signal dma_cmd_count_ff, dma_cmd_count_nxt             : unsigned(15 downto 0); -- total command count

    -- control fsm to start looping
    type fsm_t is (IDLE, WAIT_FOR_START, LOOPING, ISSUE_LAST);
    signal loop_fsm_ff, loop_fsm_nxt : fsm_t;

    procedure dcache_multiword_to_dma_loop_parameters(
        signal dcache_instr_i  : in multi_cmd_t;
        signal dma_parameter_o : out loop_parameter_t
    ) is
    begin
        dma_parameter_o.cluster_loop_len        <= unsigned(dcache_instr_i(0)(15 downto 8));
        dma_parameter_o.cluster_loop_shift_incr <= signed(dcache_instr_i(0)(23 downto 16));
        dma_parameter_o.unit_loop_len           <= unsigned(dcache_instr_i(0)(31 downto 24));
        dma_parameter_o.unit_loop_shift_incr    <= signed(dcache_instr_i(1)(7 downto 0));
        dma_parameter_o.inter_unit_loop_len     <= unsigned(dcache_instr_i(1)(15 downto 8));
        dma_parameter_o.lm_incr                 <= signed(dcache_instr_i(2)(12 downto 0));
        dma_parameter_o.mm_incr                 <= signed(dcache_instr_i(3)(31 downto 0));
        dma_parameter_o.dma_cmd_count           <= unsigned(dcache_instr_i(4)(15 downto 0));
    end procedure;

    -- cmd parameters to modify by loop
    signal param_cluster_ff, param_cluster_nxt     : std_ulogic_vector(dma_cmd_cluster_len_c - 1 downto 0);
    signal param_unit_mask_ff, param_unit_mask_nxt : std_ulogic_vector(dma_cmd_unit_mask_len_c - 1 downto 0);
    signal param_ext_base_ff, param_ext_base_nxt   : std_ulogic_vector(dma_cmd_ext_base_len_c - 1 downto 0);
    signal param_loc_base_ff, param_loc_base_nxt   : std_ulogic_vector(dma_cmd_loc_base_len_c - 1 downto 0);
begin             
--coverage off

    --    Parameters Loop command: cluster_loop_len, cluster_loop_shift, unit_loop_len, unit_loop_shift,
    --                                                                   lm addr incr (+/-)
    --                                                                   mm_addr incr (+/-)
    --
    --    Base command: DIR | Cluster_Mask | Unit_Mask | MM_Addr | LM_Addr | x | stride | y | 4xpad
    --
    --    unmodified (original) base command will not get executed
    --    
    --    per cluster: base mask shift left (e.g. 00010001 | 00000001 | 01010101 | 00000011 )
    --      loop count cluster  4 / 8   + 1 / 2
    --    per unit: base mask shift left  (e.g. 00000001 | 11111111)
    --      loop count units    0 / 1 / 2 + 0 / 1
    --    inter unit loop:
    --      loop count block -> lm_addr    base, incr 
    --                          mm_addr    base, incr
    --    
    --    -> only if unit mask 00000001 (kernel/bias/store), 11111111 (input)
    --    -> only if cluster mask 00000001, 00010001, 01010101, 00000011, 00110011, 00000111, 01110111, 11111111 + shifted variants
    --    -> only if lm add in every cluster's unit loop identic
    --  
    --    debug     -> total count of dma cmds (for check ? )
    --    example   -> kernel/bias loads / data store / input load: 
    --
    --
    --  1. Loop command? (busy -> true / latenz ausgleich? cache miss? -> false!)
    --      2. Base command
    --      3. Loop

    dcache_multiword_to_dma(idma_dcache_cmd_i, dma_cmd_int);

    fsm_p : process(vpro_clk_i, loop_fsm_ff, dma_cmd_int, idma_dcache_cmd_i, idma_dcache_cmd_we_i, base_dma_cmd_ff, generated_dma_cmd_ff, loop_parameter_ff, cluster_loop_cnt_ff, inter_unit_loop_cnt_ff, unit_loop_cnt_ff, dma_cmd_count_ff, param_cluster_ff, param_ext_base_ff, param_loc_base_ff, param_unit_mask_ff, generated_dma_cmd_issue_ff, idma_cmd_full_i)
        --alias cmd_type is idma_dcache_cmd_i(0)(7 downto 0); -- the bit position in the multiword dcache array which represents the DMA_DIRECTION/DMA Command Type (see bif.h)
    begin
        loop_fsm_nxt <= loop_fsm_ff;

        busy_o            <= '0';
        dma_cmd_we_o      <= '0';
        dma_cmd_gen_cmd_o <= dma_cmd_int;
        waiting_for_dma_o <= '0';

        loop_parameter_nxt    <= loop_parameter_ff;
        generated_dma_cmd_nxt <= generated_dma_cmd_ff;
        base_dma_cmd_nxt      <= base_dma_cmd_ff;

        cluster_loop_cnt_nxt    <= cluster_loop_cnt_ff;
        unit_loop_cnt_nxt       <= unit_loop_cnt_ff;
        inter_unit_loop_cnt_nxt <= inter_unit_loop_cnt_ff;

        param_cluster_nxt   <= param_cluster_ff;
        param_unit_mask_nxt <= param_unit_mask_ff;
        param_ext_base_nxt  <= param_ext_base_ff;
        param_loc_base_nxt  <= param_loc_base_ff;

        dma_cmd_count_nxt <= dma_cmd_count_ff;

        generated_dma_cmd_issue_nxt <= '0';

        case (loop_fsm_ff) is
            when IDLE =>
                if (idma_dcache_cmd_we_i = '1') then
                    if (idma_dcache_cmd_i(0)(2) = '0') then
                        -- pass dma commands
                        dma_cmd_we_o <= idma_dcache_cmd_we_i;
                    else
                        loop_fsm_nxt      <= WAIT_FOR_START;
                        waiting_for_dma_o <= '1';
                        dcache_multiword_to_dma_loop_parameters(idma_dcache_cmd_i, loop_parameter_nxt);
                    end if;
                end if;

            when WAIT_FOR_START =>
                waiting_for_dma_o <= '1';
                if (idma_dcache_cmd_we_i = '1') then
                    if falling_edge(vpro_clk_i) then -- assert on falling edge
                        assert idma_dcache_cmd_i(0)(2) = '0' report "[DMA CMD GEN] ERROR! LOOP FSM waiting for base command. got another loop!?" severity failure;
                    end if;
                    base_dma_cmd_nxt        <= dma_cmd_int;
                    generated_dma_cmd_nxt   <= dma_cmd_int;
                    loop_fsm_nxt            <= LOOPING;
                    dma_cmd_count_nxt       <= (others => '0');
                    inter_unit_loop_cnt_nxt <= (others => '0');
                    unit_loop_cnt_nxt       <= (others => '0');
                    cluster_loop_cnt_nxt    <= (others => '0');

                    param_cluster_nxt   <= dma_cmd_int.cluster; -- TODO: check if dma_cmd_int. only remains the other registers in synthesis
                    param_unit_mask_nxt <= dma_cmd_int.unit_mask;
                    param_ext_base_nxt  <= dma_cmd_int.ext_base;
                    param_loc_base_nxt  <= dma_cmd_int.loc_base;
                end if;

            when LOOPING =>
                busy_o <= '1';

                -- assert not working as dma fsm has cycle delay (crit path cut)
                --  assert idma_dcache_cmd_we_i = '0' report "[DMA CMD GEN] ERROR! LOOP FSM busy. Got another dma cmd from dcache (fsm)." severity failure;
                -- added in fsm/instanciation in top: after dma cmd gen command -> fake fifo full to stall one cycle
                if falling_edge(vpro_clk_i) then -- assert on falling edge    -- another command coming in?
                    assert idma_dcache_cmd_we_i = '0' report "[DMA CMD GEN] ERROR! LOOP FSM busy. Got another dma cmd from dcache (fsm)." severity failure;
                end if;

                --    def start gen loop:
                --      mm = mm_base 
                --      cluster_mask = cluster_base_mask
                --      for (int c = 0; c <= cluster_loop_len; c += 1)
                --          unit_mask = unit_base_mask
                --          for (int u = 0; u <= unit_loop_len; u += 1)
                --              lm = lm_base
                --              for (int l = 0; l <= inter_unit_loop_len; l += 1)
                --                  lm += lm_incr
                --                  mm += mm_incr
                --                      -> start command
                --              unit_mask <<= unit_loop_shift;
                --          cluster_mask <<= cluster_loop_shift;
                if idma_cmd_full_i = '0' then
                    if cluster_loop_cnt_ff <= loop_parameter_ff.cluster_loop_len then
                        if unit_loop_cnt_ff < loop_parameter_ff.unit_loop_len then
                            -- next unit loop will happen next cycle
                            if inter_unit_loop_cnt_ff < loop_parameter_ff.inter_unit_loop_len then
                                -- next inter loop will happen next cycle
                                inter_unit_loop_cnt_nxt <= inter_unit_loop_cnt_ff + 1;
                                param_loc_base_nxt      <= std_ulogic_vector(resize(signed(param_loc_base_ff) + loop_parameter_ff.lm_incr, param_loc_base_nxt'length));
                            else
                                -- this is the last inter loop -> next cycle, unit increase
                                unit_loop_cnt_nxt       <= unit_loop_cnt_ff + 1;
                                param_loc_base_nxt      <= base_dma_cmd_ff.loc_base; -- start with base lm addr again 
                                inter_unit_loop_cnt_nxt <= (others => '0');
                                if (loop_parameter_ff.unit_loop_shift_incr(loop_parameter_ff.unit_loop_shift_incr'left) = '1') then -- negative shift
                                    param_unit_mask_nxt <= std_ulogic_vector(shift_right(unsigned(param_unit_mask_ff), to_integer(-loop_parameter_ff.unit_loop_shift_incr)));
                                else
                                    param_unit_mask_nxt <= std_ulogic_vector(shift_left(unsigned(param_unit_mask_ff), to_integer(loop_parameter_ff.unit_loop_shift_incr)));
                                end if;
                            end if;
                        else
                            -- this is the last unit loop -> next cycle, cluster increase
                            if inter_unit_loop_cnt_ff < loop_parameter_ff.inter_unit_loop_len then
                                -- next inter loop will happen next cycle
                                inter_unit_loop_cnt_nxt <= inter_unit_loop_cnt_ff + 1;
                                param_loc_base_nxt      <= std_ulogic_vector(resize(signed(param_loc_base_ff) + loop_parameter_ff.lm_incr, param_loc_base_nxt'length));
                            else
                                -- this is the last unit loop -> next cycle, cluster increase
                                cluster_loop_cnt_nxt    <= cluster_loop_cnt_ff + 1;
                                param_unit_mask_nxt     <= base_dma_cmd_ff.unit_mask; -- start with base lm mask again
                                param_loc_base_nxt      <= base_dma_cmd_ff.loc_base; -- start with base lm addr again 
                                inter_unit_loop_cnt_nxt <= (others => '0');
                                unit_loop_cnt_nxt       <= (others => '0');
                                if (loop_parameter_ff.cluster_loop_shift_incr(loop_parameter_ff.cluster_loop_shift_incr'left) = '1') then -- negative shift
                                    param_cluster_nxt <= std_ulogic_vector(shift_right(unsigned(param_cluster_ff), to_integer(-loop_parameter_ff.cluster_loop_shift_incr)));
                                else
                                    param_cluster_nxt <= std_ulogic_vector(shift_left(unsigned(param_cluster_ff), to_integer(loop_parameter_ff.cluster_loop_shift_incr)));
                                end if;
                            end if;
                        end if;
                    else
                        assert (dma_cmd_count_ff = loop_parameter_ff.dma_cmd_count) report "[DMA CMD GEN] Error! loop iterations done but not yet enaugh -> fsm error!" severity failure;
                    end if;

                    param_ext_base_nxt <= std_ulogic_vector(resize(signed(param_ext_base_ff) + loop_parameter_ff.mm_incr, param_ext_base_nxt'length));
                    dma_cmd_count_nxt  <= dma_cmd_count_ff + 1;

                    generated_dma_cmd_nxt.cluster   <= param_cluster_ff;
                    generated_dma_cmd_nxt.unit_mask <= param_unit_mask_ff;
                    generated_dma_cmd_nxt.ext_base  <= param_ext_base_ff;
                    generated_dma_cmd_nxt.loc_base  <= param_loc_base_ff;

                    generated_dma_cmd_issue_nxt <= '1'; -- send out next cycle

                    if (dma_cmd_count_ff = loop_parameter_ff.dma_cmd_count - 1) then -- -1 due to registered content, start @0 when first is triggered
                        loop_fsm_nxt <= ISSUE_LAST;
                    end if;
                end if;

                if generated_dma_cmd_issue_ff = '1' then
                    dma_cmd_we_o      <= '1';
                    dma_cmd_gen_cmd_o <= generated_dma_cmd_ff;
                end if;

            when ISSUE_LAST =>
                -- BUSY required?
                busy_o <= '1';
                if falling_edge(vpro_clk_i) then -- assert on falling edge 
                    assert (generated_dma_cmd_issue_ff = '1') report "[DMA CMD GEN] Error! Last Issue without issue trigger set!" severity failure;
                end if;
                dma_cmd_we_o      <= '1';
                dma_cmd_gen_cmd_o <= generated_dma_cmd_ff;
                loop_fsm_nxt      <= IDLE;

        end case;
    end process;                        -- fsm logic

    sync_p : process(vpro_clk_i, vpro_rst_i)
    begin
        if vpro_rst_i = active_reset_c then
            loop_fsm_ff <= IDLE;

            cluster_loop_cnt_ff    <= (others => '0');
            unit_loop_cnt_ff       <= (others => '0');
            inter_unit_loop_cnt_ff <= (others => '0');

            generated_dma_cmd_issue_ff <= '0';
        elsif rising_edge(vpro_clk_i) then
            loop_parameter_ff    <= loop_parameter_nxt;
            generated_dma_cmd_ff <= generated_dma_cmd_nxt;
            base_dma_cmd_ff      <= base_dma_cmd_nxt;
            dma_cmd_count_ff     <= dma_cmd_count_nxt;

            param_cluster_ff   <= param_cluster_nxt;
            param_unit_mask_ff <= param_unit_mask_nxt;
            param_ext_base_ff  <= param_ext_base_nxt;
            param_loc_base_ff  <= param_loc_base_nxt;

            loop_fsm_ff <= loop_fsm_nxt;

            cluster_loop_cnt_ff    <= cluster_loop_cnt_nxt;
            unit_loop_cnt_ff       <= unit_loop_cnt_nxt;
            inter_unit_loop_cnt_ff <= inter_unit_loop_cnt_nxt;

            generated_dma_cmd_issue_ff <= generated_dma_cmd_issue_nxt;
        end if;
    end process;             
--coverage on
end architecture RTL;
-- coverage on