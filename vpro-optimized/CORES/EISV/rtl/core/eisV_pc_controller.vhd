--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Instruction fetch: pc register and branch mux              --
--                                    instr req register                      --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_pc_controller is
    port(
        clk_i                 : in  std_ulogic;
        rst_ni                : in  std_ulogic;
        if_req_i              : in  std_ulogic; -- id requests new instruction from IF
        -- halt control:
        if_fetcher_ready_i    : in  std_ulogic; -- fetcher could not be ready / halt fetch (pc not incrementing, no request)
        -- PC control:
        id_pc_set_i           : in  std_ulogic; -- set the program counter to a new value
        id_pc_mux_i           : in  pc_mux_sel_t; -- sel for pc multiplexer 
        id_mepc_i             : in  std_ulogic_vector(31 downto 0); -- address used to restore PC when the interrupt/exception is served
        id_pc_i               : in  std_ulogic_vector(31 downto 0); -- for fencei
        if_m_trap_base_addr_i : in  std_ulogic_vector(23 downto 0); -- possible branch address, Trap Base address, machine mode
        if_boot_addr_i        : in  std_ulogic_vector(31 downto 0); -- possible branch address, Boot address
        if_m_exc_vec_pc_mux_i : in  std_ulogic_vector(4 downto 0); -- selects ISR address for vectorized interrupt lines
        if_csr_mtvec_init_o   : out std_ulogic; -- tell CS regfile to init mtvec
        if_jump_target_id_i   : in  std_ulogic_vector(31 downto 0); -- jump target address
        if_jump_target_ex_i   : in  std_ulogic_vector(31 downto 0); -- branch target address
        -- from buffer (instr already buffered after halt?)
        id_buffer_halt_i      : in  std_ulogic;
        -- to bus fetcher
        if_fetch_req_o        : out std_ulogic;
        if_fetch_addr_o       : out std_ulogic_vector(31 downto 0)
    );
end entity eisV_pc_controller;

architecture RTL of eisV_pc_controller is

    -- branch address related signals
    signal id_branch_addr     : std_ulogic_vector(31 downto 0);
    signal id_branch_addr_int : std_ulogic_vector(31 downto 0);

    -- pc register
    signal if_pc_ff, if_pc_nxt         : std_ulogic_vector(31 downto 0);
    signal if_pc_req_ff, if_pc_req_nxt : std_ulogic;

begin

    process(if_boot_addr_i(31 downto 2), if_jump_target_ex_i, if_jump_target_id_i, id_mepc_i, id_pc_mux_i, id_pc_i, if_m_exc_vec_pc_mux_i, if_m_trap_base_addr_i)
    begin
        -- Default assign PC_BOOT (should be overwritten in below case)
        id_branch_addr <= if_boot_addr_i(31 downto 2) & "00";

        case (id_pc_mux_i) is
            when PC_BOOT      => id_branch_addr <= if_boot_addr_i(31 downto 2) & "00";
            when PC_JUMP      => id_branch_addr <= if_jump_target_id_i;
            when PC_BRANCH    => id_branch_addr <= if_jump_target_ex_i;
            -- coverage off
            when PC_EXCEPTION => id_branch_addr <= if_m_trap_base_addr_i & x"00"; --1.10 all the exceptions go to base address -- set PC to exception handler
            when PC_IRQ       => id_branch_addr <= if_m_trap_base_addr_i & "0" & if_m_exc_vec_pc_mux_i & "00"; -- interrupts are vectored -- set PC to interrupt handler
            -- coverage on
            when PC_MRET      => id_branch_addr <= id_mepc_i; -- PC is restored when returning from IRQ/exception
            when PC_FENCEI    => id_branch_addr <= std_ulogic_vector(unsigned(id_pc_i) + 4); -- jump to next instr forces prefetch buffer reload    -- TODO: +4? (from aligner, this is next needed one!)
        end case;
    end process;

    -- tell CS register file to initialize mtvec on boot
    if_csr_mtvec_init_o <= id_pc_set_i when (id_pc_mux_i = PC_BOOT) else '0';
    id_branch_addr_int  <= id_branch_addr(31 downto 1) & '0';

    pc_mux : process(if_pc_ff, id_branch_addr_int, id_pc_set_i, if_req_i, if_fetcher_ready_i, if_pc_req_ff, id_buffer_halt_i)
    begin
        if_pc_req_nxt <= if_pc_req_ff;
        if_pc_nxt     <= if_pc_ff;

        if (id_pc_set_i = '1') then     -- and if_req_i = '1' -- and id_ready_i = '1' and id_halt_i = '0') then
            if_pc_nxt     <= id_branch_addr_int;
            if_pc_req_nxt <= '1';       -- just set pc, fetch next cycle
        elsif (if_req_i = '1' and if_fetcher_ready_i = '1' and id_buffer_halt_i = '0') then -- and id_ready_i = '1' halt from id is unused here, wait until buffer signals "full" by its hold --  and aligner_halt_pc_i = '0'
            if_pc_nxt     <= std_ulogic_vector(unsigned(if_pc_ff) + 4);
            if_pc_req_nxt <= '1';
        elsif (if_req_i = '0' or id_buffer_halt_i = '1') and if_fetcher_ready_i = '1' then -- or id_ready_i = '0' aligner_halt_pc_i = '1' or 
            if_pc_req_nxt <= '0';
        end if;

    end process;

    pc_registers : process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            if_pc_ff     <= (others => '0');
            if_pc_req_ff <= '0';
        elsif rising_edge(clk_i) then
            if_pc_ff     <= if_pc_nxt;
            if_pc_req_ff <= if_pc_req_nxt;
        end if;
    end process;

    if_fetch_req_o  <= if_pc_req_ff;
    if_fetch_addr_o <= if_pc_ff;
end architecture;
