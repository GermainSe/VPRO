--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--  SPDX-FileContributor: Stephan Nolting <IMS, Uni Hannover, 2015>
--
-- ----------------------------------------------------------------------------
-- Scalar / vector instruction streamer
-- ----------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity instruction_streamer is
    generic(
        LOG2_NUM_LINES : natural := 4;  -- log2 of number of cache lines
        LOG2_LINE_SIZE : natural := 3   -- log2 of size of cache line (size in 32-bit words)
    );
    port(
        -- global control --
        clk_i           : in  std_ulogic; -- global clock line, rising-edge
        rst_i           : in  std_ulogic; -- global reset line, high-active, sync
        ce_i            : in  std_ulogic; -- global clock enable, high-active
        stall_i         : in  std_ulogic; -- freeze output if any stall
        clear_i         : in  std_ulogic; -- force reload of cache
        -- CPU instruction interface --
        cpu_oe_i        : in  std_ulogic; -- "IR" update enable
        cpu_instr_adr_i : in  std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
        cpu_instr_req_i : in  std_ulogic; -- this is a valid read request
        cpu_instr_dat_o : out std_ulogic_vector(31 downto 0); -- the instruction word
        cpu_stall_o     : out std_ulogic; -- stall CPU (miss)
        -- Vector CP instruction interface --
        vcp_instr_array : out multi_cmd_t; -- the instruction word
        -- memory system interface --
        mem_base_adr_o  : out std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
        mem_dat_i       : in  std_ulogic_vector(ic_cache_word_width_c - 1 downto 0);
        mem_req_o       : out std_ulogic; -- request data from memory
        mem_wait_i      : in  std_ulogic; -- memory command buffer full
        mem_ren_o       : out std_ulogic; -- read enable
        mem_rdy_i       : in  std_ulogic; -- applied data is valid
        -- access statistics --
        hit_o           : out std_ulogic; -- valid hit access
        miss_o          : out std_ulogic -- valid miss access
    );
end instruction_streamer;

architecture instruction_streamer_rtl of instruction_streamer is

    signal instr      : std_ulogic_vector(31 downto 0);
    signal cache_addr : std_ulogic_vector(31 downto 0);

begin

    -- Quad-Instruction Cache ------------------------------------------------------------------------------
    -- --------------------------------------------------------------------------------------------------------
    i_cache_inst : i_cache
        generic map(
            LOG2_NUM_LINES    => LOG2_NUM_LINES, -- log2 of number of cache lines
            LOG2_LINE_SIZE    => LOG2_LINE_SIZE, -- log2 of size of cache line (size in 32b words)
            INSTR_WORD_COUNT  => ic_cache_word_width_c / cpu_instr_dat_o'length, -- number of output instruction words
            WORD_WIDTH        => 32,    -- width of one instruction word
            ADDR_WIDTH        => 32,    -- width of address
            MEMORY_WORD_WIDTH => ic_cache_word_width_c -- width of one instruction word
        )
        port map(
            -- global control --
            clk_i           => clk_i,   -- global clock line, rising-edge
            rst_i           => rst_i,   -- global reset line, high-active, sync
            ce_i            => '1',     -- global clock enable, high-active
            stall_i         => stall_i, -- freeze output if any stall
            clear_i         => clear_i, -- force reload of cache
            -- CPU instruction interface --
            cpu_oe_i        => cpu_oe_i, -- "IR" update enable
            cpu_instr_adr_i => cache_addr, -- addressing words (only on boundaries!)
            cpu_instr_req_i => cpu_instr_req_i, -- this is a valid read request
            cpu_stall_o     => cpu_stall_o, -- stall CPU (miss)
            -- Quad instruction word --
            instr_o         => instr,   -- 4x cmds
            -- memory system interface --
            mem_base_adr_o  => mem_base_adr_o, -- addressing words (only on boundaries!)
            mem_dat_i       => mem_dat_i,
            mem_req_o       => mem_req_o, -- request data from memory
            mem_wait_i      => mem_wait_i, -- memory command buffer full
            mem_ren_o       => mem_ren_o, -- read enable
            mem_rdy_i       => mem_rdy_i, -- applied data is valid
            hit_o           => hit_o,
            miss_o          => miss_o
        );

    -- cache access address --
    cache_addr <= cpu_instr_adr_i(31 downto 2) & "00";

    -- scalar instruction stream --
    cpu_instr_dat_o <= instr;           -- remaining from to cache_addr subword downto 32-bit aligned
    vcp_instr_array <= (others => (others => '-'));

end instruction_streamer_rtl;

