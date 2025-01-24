--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System - Command Scheduler (for one unit)         #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity cmd_ctrl is
    generic(
        num_lanes_per_unit : natural := 3 -- number of processing lanes in this unit
    );
    port(
        -- global control --
        clk_i           : in  std_ulogic;
        rst_i           : in  std_ulogic; -- polarity: see package
        -- status --
        idle_o          : out std_ulogic;
        -- cmd fifo interface --
        cmd_i           : in  vpro_command_t;
        cmd_avail_i     : in  std_ulogic;
        cmd_re_o        : out std_ulogic;
        -- lane interface --
        lane_cmd_o      : out vpro_command_t;
        lane_cmd_we_o   : out std_ulogic_vector(num_lanes_per_unit - 1 downto 0);
        lane_cmd_req_i  : in  std_ulogic_vector(num_lanes_per_unit - 1 downto 0);
        lane_blocking_i : in  std_ulogic_vector(num_lanes_per_unit - 1 downto 0)
    );
end entity cmd_ctrl;

architecture rtl of cmd_ctrl is

    -- cycles until the blocking signal inside the lane's cmd fsm has savely propagated to the register in here
    constant LANE_BLOCK_STATIC_CYCLES : natural := 2;
    -- 0 -> cmd was placed to buffer_ff in lane. blocking = 1 gets in here
    -- 1 -> blocking register in here has saved this value
    -- 2 -> better save than sorry

    -- control arbiter --
    type arbiter_t is (S_IDLE, S_CHECK, S_WAIT_UNBLOCK);
    signal arbiter, arbiter_nxt : arbiter_t := S_IDLE;

    signal lane_block_ff, lane_block_nxt : std_ulogic := '0';

    signal block_wait_shift_ff, block_wait_shift_nxt : std_ulogic_vector(LANE_BLOCK_STATIC_CYCLES - 1 downto 0) := (others => '0');

begin
    -- global command signal --
    lane_cmd_o <= cmd_i;

    -- Arbiter -----------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    arbiter_comb : process(arbiter, cmd_avail_i, lane_block_ff, lane_cmd_req_i, cmd_i, block_wait_shift_ff)
        variable rdy_concat : std_ulogic;
    begin
        -- defaults --
        arbiter_nxt   <= arbiter;
        cmd_re_o      <= '0';
        lane_cmd_we_o <= (others => '0');
        idle_o        <= '0';

        block_wait_shift_nxt(0)                                  <= '0';
        block_wait_shift_nxt(block_wait_shift_nxt'left downto 1) <= block_wait_shift_ff(block_wait_shift_nxt'left - 1 downto 0);

        -- state machine --
        case arbiter is

            when S_IDLE =>              -- wait for instructions...
                idle_o <= '1';
                if (cmd_avail_i = '1') then -- new command available?
                    idle_o      <= '0';
                    cmd_re_o    <= '1'; -- fetch next command
                    arbiter_nxt <= S_CHECK;
                end if;

            when S_CHECK =>
                if (lane_block_ff = '0') then -- wait until no lane is blocking

                    rdy_concat := '1';  -- all of selected rdy ?
                    for i in 0 to num_lanes_per_unit - 1 loop
                        if (cmd_i.id(i) = '1') and (lane_cmd_req_i(i) = '0') then
                            rdy_concat := '0';
                        end if;
                    end loop;

                    if (rdy_concat = '1') then
                        for i in 0 to num_lanes_per_unit - 1 loop
                            if (cmd_i.id(i) = '1') then
                                lane_cmd_we_o(i) <= '1';
                            end if;
                        end loop;
                        arbiter_nxt <= S_IDLE;

                        -- shortcut for next cmd
                        if cmd_i.blocking(0) = '0' then
                            if (cmd_avail_i = '1') then -- new command available?
                                idle_o      <= '0';
                                cmd_re_o    <= '1'; -- fetch next command
                                arbiter_nxt <= S_CHECK;
                            end if;
                        else
                            block_wait_shift_nxt(0) <= cmd_i.blocking(0);
                            arbiter_nxt             <= S_WAIT_UNBLOCK;
                        end if;
                    end if;
                end if;

            when S_WAIT_UNBLOCK =>
                if (unsigned(block_wait_shift_ff) = 0) then -- wait after each
                    arbiter_nxt <= S_IDLE;
                end if;

        end case;
    end process arbiter_comb;

    lane_block_nxt <= '0' when unsigned(lane_blocking_i) = 0 else
                      '1';

    -- Registers ---------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    arbiter_sync : process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then
            arbiter             <= S_IDLE;
            lane_block_ff       <= '0';
            block_wait_shift_ff <= (others => '0');
        elsif rising_edge(clk_i) then
            arbiter             <= arbiter_nxt;
            lane_block_ff       <= lane_block_nxt;
            block_wait_shift_ff <= block_wait_shift_nxt;
        end if;
    end process arbiter_sync;

end architecture;
