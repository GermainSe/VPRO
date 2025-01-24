--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2023, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - RegisterFile (Wrapper) with 2 read, 1 write port                   #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity register_file is
    generic(
        FLAG_WIDTH_g  : natural := 2;
        DATA_WIDTH_g  : natural := rf_data_width_c;
        NUM_ENTRIES_g : natural := 1024;
        RF_LABLE_g    : string  := "unknown"
    );
    port(
        -- global control --
        rd_ce_i    : in  std_ulogic;
        wr_ce_i    : in  std_ulogic;
        clk_i      : in  std_ulogic;
        -- write port --
        waddr_i    : in  std_ulogic_vector(09 downto 0);
        wdata_i    : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        wflag_i    : in  std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
        wdata_we_i : in  std_ulogic;    -- data write enable
        wflag_we_i : in  std_ulogic;    -- flags write enable
        -- read port --
        raddr_a_i  : in  std_ulogic_vector(09 downto 0);
        rdata_a_o  : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        rflag_a_o  : out std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
        -- read port --
        raddr_b_i  : in  std_ulogic_vector(09 downto 0);
        rdata_b_o  : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        rflag_b_o  : out std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0)
    );
end entity register_file;

architecture RTL of register_file is

begin

    -- Port A / Src1 --
    reg_file_porta_inst : dpram_1024x26
        generic map(
            FLAG_WIDTH_g => FLAG_WIDTH_g,
            DATA_WIDTH_g => DATA_WIDTH_g,
            NUM_ENTRIES_g => NUM_ENTRIES_g,
            RF_LABLE_g => RF_LABLE_g
        )
        port map(
            -- global control --
            rd_ce_i => rd_ce_i,
            wr_ce_i => wr_ce_i,
            clk_i   => clk_i,
            -- write port --
            waddr_i => waddr_i,
            data_i  => wdata_i,
            flag_i  => wflag_i,
            dwe_i   => wdata_we_i,
            fwe_i   => wflag_we_i,
            -- read port --
            raddr_i => raddr_a_i,
            data_o  => rdata_a_o,
            flag_o  => rflag_a_o
        );

    -- Port B / Src2 --
    reg_file_portb_inst : dpram_1024x26 -- no label -> no dump in simulation (debug)
        generic map(
            FLAG_WIDTH_g => FLAG_WIDTH_g,
            DATA_WIDTH_g => DATA_WIDTH_g,
            NUM_ENTRIES_g => NUM_ENTRIES_g
        )
        port map(
            -- global control --
            rd_ce_i => rd_ce_i,
            wr_ce_i => wr_ce_i,
            clk_i   => clk_i,
            -- write port --
            waddr_i => waddr_i,
            data_i  => wdata_i,
            flag_i  => wflag_i,
            dwe_i   => wdata_we_i,
            fwe_i   => wflag_we_i,
            -- read port --
            raddr_i => raddr_b_i,
            data_o  => rdata_b_o,
            flag_o  => rflag_b_o
        );

end architecture RTL;
