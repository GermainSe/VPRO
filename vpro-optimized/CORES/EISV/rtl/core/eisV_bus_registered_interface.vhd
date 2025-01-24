--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Bus Interface to register outstanding transactions to the  --
--                 bus. gnt signal allows transactions, all transactions are  -- 
--                 ack'd by rvalid signal.                                    --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eisV_bus_registered_interface is
    port(
        clk_i             : in  std_ulogic;
        rst_ni            : in  std_ulogic;
        -- Transaction request interface
        mem_trans_valid_i : in  std_ulogic;
        mem_trans_ready_o : out std_ulogic;
        mem_trans_addr_i  : in  std_ulogic_vector(31 downto 0);
        mem_trans_we_i    : in  std_ulogic;
        mem_trans_be_i    : in  std_ulogic_vector(3 downto 0);
        mem_trans_wdata_i : in  std_ulogic_vector(31 downto 0);
        -- Transaction response interface
        wb_resp_valid_o   : out std_ulogic; -- Note: Consumer is assumed to be 'ready' whenever resp_valid_o = 1
        wb_resp_rdata_o   : out std_ulogic_vector(31 downto 0);
        -- Bus interface
        mem_bus_req_o     : out std_ulogic;
        mem_bus_gnt_i     : in  std_ulogic;
        mem_bus_addr_o    : out std_ulogic_vector(31 downto 0);
        mem_bus_we_o      : out std_ulogic;
        mem_bus_be_o      : out std_ulogic_vector(3 downto 0);
        mem_bus_wdata_o   : out std_ulogic_vector(31 downto 0);
        wb_bus_rdata_i    : in  std_ulogic_vector(31 downto 0);
        wb_bus_rvalid_i   : in  std_ulogic -- resp_valid, NOT READ_VALID
    );
end entity eisV_bus_registered_interface;

architecture RTL of eisV_bus_registered_interface is
    type bus_state_t is (TRANSPARENT, REGISTERED);
    signal state_ff, state_nxt : bus_state_t;

    signal bus_addr_nxt  : std_ulogic_vector(31 downto 0);
    signal bus_we_nxt    : std_ulogic;
    signal bus_be_nxt    : std_ulogic_vector(3 downto 0);
    signal bus_wdata_nxt : std_ulogic_vector(31 downto 0);

    signal bus_addr_ff  : std_ulogic_vector(31 downto 0);
    signal bus_we_ff    : std_ulogic;
    signal bus_be_ff    : std_ulogic_vector(3 downto 0);
    signal bus_wdata_ff : std_ulogic_vector(31 downto 0);
begin

    wb_resp_valid_o <= wb_bus_rvalid_i;
    wb_resp_rdata_o <= wb_bus_rdata_i;

    process(mem_bus_gnt_i, bus_addr_ff, bus_be_ff, bus_wdata_ff, bus_we_ff, state_ff, mem_trans_addr_i, mem_trans_be_i, mem_trans_valid_i, mem_trans_wdata_i, mem_trans_we_i)
    begin
        bus_addr_nxt  <= bus_addr_ff;
        bus_we_nxt    <= bus_we_ff;
        bus_be_nxt    <= bus_be_ff;
        bus_wdata_nxt <= bus_wdata_ff;

        mem_bus_addr_o  <= bus_addr_ff;
        mem_bus_we_o    <= bus_we_ff;
        mem_bus_be_o    <= bus_be_ff;
        mem_bus_wdata_o <= bus_wdata_ff;

        state_nxt <= state_ff;

        case (state_ff) is
            -- Default (transparent) state. Transaction requests are passed directly onto the Bus A channel.
            when TRANSPARENT =>
                mem_trans_ready_o <= '1';
                mem_bus_req_o     <= mem_trans_valid_i;
                mem_bus_addr_o    <= mem_trans_addr_i;
                mem_bus_we_o      <= mem_trans_we_i;
                mem_bus_be_o      <= mem_trans_be_i;
                mem_bus_wdata_o   <= mem_trans_wdata_i;

                bus_addr_nxt  <= mem_trans_addr_i;
                bus_we_nxt    <= mem_trans_we_i;
                bus_be_nxt    <= mem_trans_be_i;
                bus_wdata_nxt <= mem_trans_wdata_i;
                if (mem_trans_valid_i = '1' and mem_bus_gnt_i = '0') then
                    -- Bus request not immediately granted. Move to REGISTERED state such that Bus address phase
                    -- signals can be kept stable while the transaction request (trans_*) can possibly change.
                    state_nxt <= REGISTERED;
                end if;

            -- Registered state. Bus address phase signals are kept stable (driven from registers).
            when REGISTERED =>
                mem_bus_req_o     <= '1'; -- Never retract request
                mem_trans_ready_o <= '0';
                if (mem_bus_gnt_i = '1') then
                    -- Received grant. Move back to TRANSPARENT state such that next transaction request can be passed on.
                    state_nxt <= TRANSPARENT;
                end if;

        end case;
    end process;

    ------------------------------------------------------------------------------
    -- Registers
    ------------------------------------------------------------------------------
    process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            state_ff     <= TRANSPARENT;
            bus_addr_ff  <= (others => '0');
            bus_we_ff    <= '0';
            bus_be_ff    <= (others => '0');
            bus_wdata_ff <= (others => '0');
        elsif rising_edge(clk_i) then
            state_ff     <= state_nxt;
            bus_addr_ff  <= bus_addr_nxt;
            bus_we_ff    <= bus_we_nxt;
            bus_be_ff    <= bus_be_nxt;
            bus_wdata_ff <= bus_wdata_nxt;
        end if;
    end process;

end architecture RTL;
