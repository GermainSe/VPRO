--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # Instanziates either CDC Fifos based on BRAM Cells (Xilinx primitives) or  #
-- # DRAM (parameter for distributed Ram + Logic)                              #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

entity cmd_fifo_wrapper is
    generic(
        DATA_WIDTH  : natural := vpro_cmd_len_c; -- data width of FIFO entries
        NUM_ENTRIES : natural := 32;    -- number of FIFO entries, should be a power of 2!
        NUM_SYNC_FF : natural := 2;     -- number of synchronization FF stages
        NUM_SFULL   : natural := 1      -- offset between RD and WR for issueing 'special full' signal
    );
    port(
        -- write port (master clock domain) --
        m_clk_i    : in  std_ulogic;
        m_rst_i    : in  std_ulogic;    -- polarity: see package
        m_cmd_i    : in  vpro_command_t;
        m_cmd_we_i : in  std_ulogic;
        m_full_o   : out std_ulogic;
        -- read port (slave clock domain) --
        s_clk_i    : in  std_ulogic;
        s_rst_i    : in  std_ulogic;    -- polarity: see package
        s_cmd_o    : out vpro_command_t;
        s_cmd_re_i : in  std_ulogic;
        s_empty_o  : out std_ulogic
    );
end entity cmd_fifo_wrapper;

architecture RTL of cmd_fifo_wrapper is

    signal m_cmd_int : std_ulogic_vector(vpro_cmd_len_c - 1 downto 0);
    signal s_cmd_int : std_ulogic_vector(vpro_cmd_len_c - 1 downto 0);

begin

    --- ASYNC FIFOs ----

    -- construct CMD FIFO from LUTs (distributed RAM)
    generate_dram_cmd_fifo : if (NUM_SYNC_FF > 0) generate
        assert (vpro_cmd_len_c = DATA_WIDTH) report "CMD FIFO WRAPPER only designed for length of vpro cmds!" severity error;

        m_cmd_int <= vpro_cmd2vec(m_cmd_i);
        s_cmd_o   <= vpro_vec2cmd(s_cmd_int);
        cmd_fifo_inst : cdc_fifo
            generic map(
                DATA_WIDTH  => DATA_WIDTH,
                NUM_ENTRIES => NUM_ENTRIES,
                NUM_SYNC_FF => NUM_SYNC_FF,
                NUM_SFULL   => NUM_SFULL
            )
            port map(
                -- write port (master clock domain) --
                m_clk_i   => m_clk_i,
                m_rst_i   => m_rst_i,
                m_data_i  => m_cmd_int,
                m_we_i    => m_cmd_we_i,
                m_full_o  => open,
                m_sfull_o => m_full_o,
                -- read port (slave clock domain) --
                s_clk_i   => s_clk_i,
                s_rst_i   => s_rst_i,
                s_data_o  => s_cmd_int,
                s_re_i    => s_cmd_re_i,
                s_empty_o => s_empty_o
            );
    end generate;

    --- SYNC FIFOs ----

    -- construct CMD FIFO from LUTs (distributed RAM)
    generate_sync_cmd_fifo : if (NUM_SYNC_FF = 0) generate
        assert (vpro_cmd_len_c = DATA_WIDTH) report "CMD FIFO WRAPPER only designed for length of vpro cmds!" severity error;

        m_cmd_int <= vpro_cmd2vec(m_cmd_i);
        s_cmd_o   <= vpro_vec2cmd(s_cmd_int);
        cmd_fifo_inst : sync_fifo
            generic map(
                DATA_WIDTH     => DATA_WIDTH,
                NUM_ENTRIES    => NUM_ENTRIES,
                NUM_SFULL      => NUM_SFULL,
                DIRECT_OUT     => false,
                DIRECT_OUT_REG => true
            )
            port map(
                clk_i    => m_clk_i,
                rst_i    => m_rst_i,
                wdata_i  => m_cmd_int,
                we_i     => m_cmd_we_i,
                wfull_o  => open,
                wsfull_o => m_full_o,
                rdata_o  => s_cmd_int,
                re_i     => s_cmd_re_i,
                rempty_o => s_empty_o
            );

    end generate;
end architecture RTL;

