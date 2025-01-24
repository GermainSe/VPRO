--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;
use core_v2pro.package_specializations.all;

entity sync_fifo_register is
    generic(
        DATA_WIDTH  : natural := rf_data_width_c + 2; -- data width of FIFO entries
        NUM_ENTRIES : natural := 2      -- number of FIFO entries, should be a power of 2!
    );
    port(
        -- globals --
        clk_i    : in  std_ulogic;
        rst_i    : in  std_ulogic;      -- polarity: see package
        -- write port --
        wdata_i  : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        we_i     : in  std_ulogic;
        wfull_o  : out std_ulogic;
        wsfull_o : out std_ulogic;      -- almost full signal
        -- read port (slave clock domain) --
        rdata_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
        re_i     : in  std_ulogic;
        rempty_o : out std_ulogic
    );
end entity sync_fifo_register;

architecture RTL of sync_fifo_register is
    constant num_entries_log2_c : natural := index_size(NUM_ENTRIES);

    type reg_t is array (NUM_ENTRIES - 1 downto 0) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal reg_nxt, reg_ff : reg_t := (others => (others => '0'));

    signal reg_valid, reg_valid_nxt : std_ulogic_vector(NUM_ENTRIES - 1 downto 0) := (others => '0');

    signal wr_index, wr_index_nxt : unsigned(num_entries_log2_c - 1 downto 0) := (others => '0');
    signal rd_index, rd_index_nxt : unsigned(num_entries_log2_c - 1 downto 0) := (others => '0');

    -- data out buffer (same as fifo logic in sync_fifo) 
    --  -> matches logic in lane (rd expects data in next cycle)
    signal data_o_nxt, data_o : std_ulogic_vector(DATA_WIDTH - 1 downto 0) := (others => '0');
begin

    assert (NUM_ENTRIES = 2) or (NUM_ENTRIES = 4) report "Sync Fifo of Registers need to have 2/4 entries -> else use sync_fifo (no register)!" severity failure;

    wsfull_2 : if NUM_ENTRIES = 2 generate
        wsfull_o <= or_reduce(reg_valid); -- near full if one has data
    end generate;

    wsfull_4 : if NUM_ENTRIES = 4 generate  -- 3 or 4 entries valid
        wsfull_o <= '0' when reg_valid = "0001" or --
                    reg_valid = "0010" or --
                    reg_valid = "0100" or --
                    reg_valid = "1000" or --
                    reg_valid = "0011" or --
--                    reg_valid = "0101" or -- dc
                    reg_valid = "1001" or --
                    reg_valid = "0110" or --
--                    reg_valid = "1010" or -- dc
                    reg_valid = "1100" else
                    or_reduce(reg_valid);
    end generate;

    wfull_o <= and_reduce(reg_valid);   -- full if both have data

    --        rempty_o   <= and_reduce(not reg_valid); -- none has data
    rempty_o <= and_reduce(not reg_valid_nxt); -- none will have data nxt cycle

    process(data_o, reg_ff, reg_valid, wr_index, rd_index, re_i, we_i, wdata_i)
    begin
        reg_nxt       <= reg_ff;
        reg_valid_nxt <= reg_valid;
        wr_index_nxt  <= wr_index;
        rd_index_nxt  <= rd_index;

        rdata_o    <= data_o;
        data_o_nxt <= data_o;

        if we_i = '1' then
            reg_valid_nxt(to_integer(wr_index)) <= '1';
            reg_nxt(to_integer(wr_index))       <= wdata_i;
            wr_index_nxt                        <= wr_index + 1;
        end if;
        if re_i = '1' then              -- any needs to contain data
            reg_valid_nxt(to_integer(rd_index)) <= '0';
            data_o_nxt                          <= reg_ff(to_integer(rd_index));
            rd_index_nxt                        <= rd_index + 1;
        end if;
    end process;

    process(clk_i, rst_i)
    begin
        -- turn off condition coverage for following line, first item (see _user.pdf, p.985)
        -- coverage off -item c 1
        if (IMPLEMENT_RESET_C and rst_i = active_reset_c) then
            reg_ff    <= (others => (others => '0')); -- TODO: needed?
            wr_index  <= (others => '0');
            rd_index  <= (others => '0');
            reg_valid <= (others => '0');
            data_o    <= (others => '0');
        elsif rising_edge(clk_i) then
            data_o    <= data_o_nxt;
            reg_ff    <= reg_nxt;
            wr_index  <= wr_index_nxt;
            rd_index  <= rd_index_nxt;
            reg_valid <= reg_valid_nxt;
        end if;
    end process;

    process(clk_i)
    begin
        if falling_edge(clk_i) then
            if we_i = '1' then
                assert and_reduce(reg_valid) = '0' report "Writing Chain FIFO which is full!!!" severity failure;
            end if;
            if re_i = '1' then          -- any needs to contain data
                assert and_reduce(not reg_valid) = '0' report "Reading Chain FIFO which does not contain any data!!!" severity failure;
            end if;
        end if;
    end process;

end architecture RTL;
