--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Instruction fetch unit: Selection of the next PC, and      --
--                 buffering (sampling) of the read instruction               --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_if_stage is
    port(
        clk_i                         : in  std_ulogic;
        rst_ni                        : in  std_ulogic;
        -- instruction bus
        if_instr_req_o                : out std_ulogic; -- external instruction bus
        if_instr_addr_o               : out std_ulogic_vector(31 downto 0); -- external instruction bus
        if_instr_gnt_i                : in  std_ulogic; -- external instruction bus
        id_instr_rvalid_i             : in  std_ulogic; -- external instruction bus
        id_instr_rdata_i              : in  std_ulogic_vector(31 downto 0); -- external instruction bus
        -- ID if request?
        if_req_i                      : in  std_ulogic; -- input to prefetch buffer
        -- the fetched instruction 
        id_aligned_instr_valid_o      : out std_ulogic;
        id_decompressed_instr_o       : out std_ulogic_vector(31 downto 0);
        id_is_compressed_instr_o      : out std_ulogic;
        id_illegal_compressed_instr_o : out std_ulogic;
        -- control signals, PC modifications
        id_pc_set_i                   : in  std_ulogic; -- set the program counter to a new value
        if_pc_mux_i                   : in  pc_mux_sel_t; -- sel for pc multiplexer
        if_mepc_i                     : in  std_ulogic_vector(31 downto 0); -- address used to restore PC when the interrupt/exception is served
        if_m_trap_base_addr_i         : in  std_ulogic_vector(23 downto 0); -- possible branch address, Trap Base address, machine mode
        if_boot_addr_i                : in  std_ulogic_vector(31 downto 0); -- possible branch address, Boot address
        if_m_exc_vec_pc_mux_i         : in  std_ulogic_vector(4 downto 0); -- selects ISR address for vectorized interrupt lines
        if_csr_mtvec_init_o           : out std_ulogic; -- tell CS regfile to init mtvec
        if_jump_target_id_i           : in  std_ulogic_vector(31 downto 0); -- jump target address
        if_jump_target_ex_i           : in  std_ulogic_vector(31 downto 0); -- branch target address
        id_pc_i                       : in  std_ulogic_vector(31 downto 0); -- address used used for fencei instructions -- @suppress "Unused port: id_pc_i is not used in eisv.eisV_if_stage(RTL)"
        -- current pcs
        id_pc_o                       : out std_ulogic_vector(31 downto 0);
        if_pc_o                       : out std_ulogic_vector(31 downto 0);
        -- pipeline stall
        if_ready_o                    : out std_ulogic;
        id_ready_i                    : in  std_ulogic;
        -- misc signals
        if_busy_o                     : out std_ulogic; -- is the IF stage busy fetching instructions?
        if_perf_imiss_o               : out std_ulogic -- Instruction Fetch Miss
    );
end entity eisV_if_stage;

architecture RTL of eisV_if_stage is
    signal if_fetch_req                : std_ulogic;
    signal if_fetch_addr               : std_ulogic_vector(31 downto 0);
    signal id_fetch_valid              : std_ulogic;
    signal id_fetch_rdata              : std_ulogic_vector(31 downto 0);
    signal id_fetch_buffered_valid     : std_ulogic;
    signal id_fetch_buffered_data      : std_ulogic_vector(31 downto 0);
    signal if_clear_buffer             : std_ulogic;
    signal if_fetcher_ready            : std_ulogic;
    signal id_aligner_halt             : std_ulogic;
    signal id_aligned_instr            : std_ulogic_vector(31 downto 0);
    signal id_fetch_addr_last          : std_ulogic_vector(31 downto 0);
    signal id_fetch_buffered_addr_last : std_ulogic_vector(31 downto 0);
    signal id_pc_int                   : std_ulogic_vector(31 downto 0);
    signal if_perf_imiss_int           : std_ulogic;
    signal id_buffer_halt_fetch        : std_ulogic;

    signal id_pc_set_ff    : std_ulogic;
    signal id_valid_buffer : std_ulogic;
begin

    if_busy_o       <= (if_fetch_req or if_perf_imiss_int or id_aligner_halt);
    if_perf_imiss_o <= if_perf_imiss_int;
    if_pc_o         <= if_fetch_addr;
    if_ready_o      <= if_fetcher_ready;
    id_pc_o         <= id_pc_int;

    pc_control_i : eisV_pc_controller
        port map(
            clk_i                 => clk_i,
            rst_ni                => rst_ni,
            if_req_i              => if_req_i,
            if_fetcher_ready_i    => if_fetcher_ready,
            id_pc_set_i           => id_pc_set_i,
            id_pc_mux_i           => if_pc_mux_i,
            id_mepc_i             => if_mepc_i,
            id_pc_i               => id_pc_int,
            if_m_trap_base_addr_i => if_m_trap_base_addr_i,
            if_boot_addr_i        => if_boot_addr_i,
            if_m_exc_vec_pc_mux_i => if_m_exc_vec_pc_mux_i,
            if_csr_mtvec_init_o   => if_csr_mtvec_init_o,
            if_jump_target_id_i   => if_jump_target_id_i,
            if_jump_target_ex_i   => if_jump_target_ex_i,
            id_buffer_halt_i      => id_buffer_halt_fetch,
            if_fetch_req_o        => if_fetch_req,
            if_fetch_addr_o       => if_fetch_addr
        );

    process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            id_pc_set_ff <= '0';
        elsif rising_edge(clk_i) then
            id_pc_set_ff <= id_pc_set_i;
        end if;
    end process;

    bus_fetcher_i : eisV_bus_fetcher
        port map(
            clk_i                          => clk_i,
            rst_ni                         => rst_ni,
            if_bus_gnt_i                   => if_instr_gnt_i,
            if_bus_req_o                   => if_instr_req_o,
            if_bus_addr_o                  => if_instr_addr_o,
            id_bus_rdata_i                 => id_instr_rdata_i,
            id_bus_rvalid_i                => id_instr_rvalid_i,
            if_fetch_ready_o               => if_fetcher_ready,
            if_fetch_req_i                 => if_fetch_req,
            if_fetch_addr_i                => if_fetch_addr,
            id_fetch_invalidate_last_req_i => id_pc_set_ff,
            id_fetch_valid_o               => id_fetch_valid,
            id_fetch_rdata_o               => id_fetch_rdata,
            if_fetcher_miss_o              => if_perf_imiss_int,
            id_fetch_addr_o                => id_fetch_addr_last
        );

    if_clear_buffer <= id_pc_set_i;     -- and if_req_i;
    id_valid_buffer <= not id_aligner_halt;

    instruction_buffer_i : eisV_instruction_buffer
        port map(
            clk_i                  => clk_i,
            rst_ni                 => rst_ni,
            id_data_valid_i        => id_fetch_valid,
            id_data_i              => id_fetch_rdata,
            id_addr_i              => id_fetch_addr_last,
            id_id_valid_i          => id_valid_buffer,
            id_data_valid_o        => id_fetch_buffered_valid,
            id_data_o              => id_fetch_buffered_data,
            id_addr_o              => id_fetch_buffered_addr_last,
            id_buffer_halt_fetch_o => id_buffer_halt_fetch,
            if_clear_i             => if_clear_buffer
        );

    aligner_i : eisV_aligner
        port map(
            clk_i                    => clk_i,
            rst_ni                   => rst_ni,
            id_fetched_instr_i       => id_fetch_buffered_data,
            id_fetched_instr_valid_i => id_fetch_buffered_valid,
            id_fetched_addr_i        => id_fetch_buffered_addr_last,
            id_fetch_hold_o          => id_aligner_halt,
            id_branch_addr_i         => if_fetch_addr,
            id_branch_i              => id_pc_set_i,
            id_ready_i               => id_ready_i,
            id_aligned_instr_o       => id_aligned_instr,
            id_aligned_instr_valid_o => id_aligned_instr_valid_o,
            id_aligned_addr_o        => id_pc_int
        );

    decompressor_i : eisV_instruction_decompress
        port map(
            id_instr_i         => id_aligned_instr,
            id_instr_o         => id_decompressed_instr_o,
            id_is_compressed_o => id_is_compressed_instr_o,
            id_illegal_instr_o => id_illegal_compressed_instr_o
        );
end architecture RTL;

