--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System - dual-port RAM                            #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use STD.textio.all;
use ieee.std_logic_textio.all;

library utils;
use utils.txt_util.all;
use utils.binaryio.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

entity dpram_1024x26 is
    generic(
        FLAG_WIDTH_g  : natural := 2;
        DATA_WIDTH_g  : natural := rf_data_width_c;
        NUM_ENTRIES_g : natural := 1024;
        RF_LABLE_g    : string  := "unknown"
    );
    port(
        -- global control --
        rd_ce_i : in  std_ulogic;
        wr_ce_i : in  std_ulogic;
        clk_i   : in  std_ulogic;
        -- write port --
        waddr_i : in  std_ulogic_vector(09 downto 0);
        data_i  : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        flag_i  : in  std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
        dwe_i   : in  std_ulogic;       -- data write enable
        fwe_i   : in  std_ulogic;       -- flags write enable
        -- read port --
        raddr_i : in  std_ulogic_vector(09 downto 0);
        data_o  : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
        flag_o  : out std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0)
    );
end entity dpram_1024x26;

architecture dpram_1024x26_rtl of dpram_1024x26 is

    signal ram_do : std_ulogic_vector(DATA_WIDTH_g + FLAG_WIDTH_g - 1 downto 0);

    type data_mem_t is array (0 to NUM_ENTRIES_g - 1) of std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
    signal data_mem : data_mem_t := (others=>(others=>'0'));
    type flag_mem_t is array (0 to NUM_ENTRIES_g - 1) of std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
    signal flag_mem : flag_mem_t := (others=>(others=>'0'));

    -- registered ce and rd data
    signal last_rd_ce, last_rd_ce_nxt   : std_ulogic;
    signal next_ram_do, next_ram_do_nxt : std_ulogic_vector(DATA_WIDTH_g + FLAG_WIDTH_g - 1 downto 0);

    signal data_o_nxt : std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
    signal flag_o_nxt : std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
begin

    last_rd_ce_nxt  <= rd_ce_i;
    next_ram_do_nxt <= std_ulogic_vector(ram_do);

    register_clk : process(clk_i)
    begin
        if rising_edge(clk_i) then
            last_rd_ce <= last_rd_ce_nxt;
            if (rd_ce_i = '0' and last_rd_ce = '1') then -- valid ram_do @ stall start
                next_ram_do <= next_ram_do_nxt;
            end if;
        end if;
    end process;

    data_o_process : process(ram_do, next_ram_do, rd_ce_i)
    begin
        if (rd_ce_i = '1') then
            data_o_nxt(DATA_WIDTH_g - 1 downto 0) <= std_ulogic_vector(ram_do(DATA_WIDTH_g - 1 downto 0));
            flag_o_nxt(FLAG_WIDTH_g - 1 downto 0) <= std_ulogic_vector(ram_do(DATA_WIDTH_g + FLAG_WIDTH_g - 1 downto DATA_WIDTH_g));
        else
            data_o_nxt(DATA_WIDTH_g - 1 downto 0) <= next_ram_do(DATA_WIDTH_g - 1 downto 0);
            flag_o_nxt(FLAG_WIDTH_g - 1 downto 0) <= next_ram_do(DATA_WIDTH_g + FLAG_WIDTH_g - 1 downto DATA_WIDTH_g);
        end if;
    end process;

    -- additional output register (begind mux, to match BRAM instanciation)
    output_seq : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rd_ce_i = '1') then
                flag_o <= flag_o_nxt;
                data_o <= data_o_nxt;
            end if;
        end if;
    end process output_seq;

    mem_sync_rd : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rd_ce_i = '1') then     -- TODO: remove?
                ram_do <= flag_mem(to_integer(unsigned(raddr_i))) & data_mem(to_integer(unsigned(raddr_i)));
            end if;
        end if;
    end process mem_sync_rd;

    mem_sync_wr : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (wr_ce_i = '1') then     -- TODO: remove?
                if (dwe_i = '1') then
                    data_mem(to_integer(unsigned(waddr_i))) <= data_i(DATA_WIDTH_g - 1 downto 0);
                end if;
                if (fwe_i = '1') then
                    flag_mem(to_integer(unsigned(waddr_i))) <= flag_i(FLAG_WIDTH_g - 1 downto 0);
                end if;
            end if;
        end if;
    end process mem_sync_wr;
    
    
    
    -- trace generation
    --pragma translate_off
    trace_p : if RF_LABLE_g /= "unknown" and rf_generate_write_traces_c generate
        file_output : process
            file rf_trace      : text;
            variable line_out  : line;
            variable start     : boolean   := true;
        begin
            if start then
                file_open(rf_trace, RF_LABLE_g & ".trace", write_mode);
                start := false;
            end if;
            wait on clk_i until clk_i = '1' and clk_i'last_value = '0' and wr_ce_i = '1';
           
            if (dwe_i = '1') then
                write(line_out, 'R');
                write(line_out, 'F');
                write(line_out, '[');
                write(line_out, str(to_integer(unsigned(waddr_i))));
                write(line_out, ']');
                write(line_out, ' ');
                write(line_out, hstr(std_logic_vector(data_mem(to_integer(unsigned(waddr_i))))));
                write(line_out, ' ');
                write(line_out, '>');
                write(line_out, ' ');
                write(line_out, hstr(std_logic_vector(data_i(DATA_WIDTH_g - 1 downto 0))));
                writeline(rf_trace, line_out);
            end if;
            
        end process file_output;
    end generate;
    --pragma translate_on

end architecture dpram_1024x26_rtl;

