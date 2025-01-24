--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eisV_bus_fetcher is
    port(
        clk_i                          : in  std_ulogic;
        rst_ni                         : in  std_ulogic;
        -- Bus
        if_bus_gnt_i                   : in  std_ulogic;
        if_bus_req_o                   : out std_ulogic;
        if_bus_addr_o                  : out std_ulogic_vector(31 downto 0);
        id_bus_rdata_i                 : in  std_ulogic_vector(31 downto 0);
        id_bus_rvalid_i                : in  std_ulogic;
        -- to pc control
        if_fetch_ready_o               : out std_ulogic;
        -- from pc control
        if_fetch_req_i                 : in  std_ulogic;
        if_fetch_addr_i                : in  std_ulogic_vector(31 downto 0);
        id_fetch_invalidate_last_req_i : in  std_ulogic;
        -- to buffer
        id_fetch_valid_o               : out std_ulogic;
        id_fetch_rdata_o               : out std_ulogic_vector(31 downto 0);
        -- status (miss/waiting)
        if_fetcher_miss_o              : out std_ulogic;
        id_fetch_addr_o                : out std_ulogic_vector(31 downto 0) -- last fetched addr
    );
end entity eisV_bus_fetcher;

architecture RTL of eisV_bus_fetcher is

    type fetch_fsm_t is (IDLE, RDATA);

    signal if_state_ff, if_state_nxt : fetch_fsm_t;

    signal if_fetched_addr_nxt, if_fetched_addr_ff : std_ulogic_vector(31 downto 0);

begin

    id_fetch_addr_o <= if_fetched_addr_ff;

    fsm : process(if_state_ff, if_bus_gnt_i, id_bus_rdata_i, id_bus_rvalid_i, if_fetch_addr_i, if_fetch_req_i, if_fetched_addr_ff, id_fetch_invalidate_last_req_i)
    begin
        if_state_nxt        <= if_state_ff;
        if_bus_req_o        <= '0';
        if_bus_addr_o       <= if_fetched_addr_ff;
        if_fetch_ready_o    <= if_bus_gnt_i;
        id_fetch_valid_o    <= '0';
        id_fetch_rdata_o    <= (others => '0');
        if_fetcher_miss_o   <= '0';
        if_fetched_addr_nxt <= if_fetched_addr_ff;

        case if_state_ff is
            when IDLE =>
                if (if_fetch_req_i = '1' and if_bus_gnt_i = '1') then
                    if_bus_req_o        <= if_fetch_req_i;
                    if_bus_addr_o       <= if_fetch_addr_i;
                    if_fetched_addr_nxt <= if_fetch_addr_i;
                    if_state_nxt        <= RDATA;
                end if;

            when RDATA =>
                if_bus_req_o  <= '1';   -- keep request registered until rvalid  is received
                if_bus_addr_o <= if_fetched_addr_ff;
                if (id_bus_rvalid_i = '1') then -- receiving data
                    id_fetch_valid_o <= '1';
                    if_bus_req_o     <= '0';
                    id_fetch_rdata_o <= id_bus_rdata_i;
                    if_state_nxt     <= IDLE;
                    if (if_fetch_req_i = '1') then -- new request immediately
                        if_bus_req_o        <= if_fetch_req_i;
                        if_fetched_addr_nxt <= if_fetch_addr_i;
                        if_bus_addr_o       <= if_fetch_addr_i;
                        if_state_nxt        <= RDATA;
                    end if;
                else
                    if_fetcher_miss_o <= '1';
                    if_fetch_ready_o  <= '0'; -- still waiting for data, not yet ready for new req
                end if;

                -- if pc_set was called (e.g. after a branch), but the fetch is waiting for new data on dcachemiss (gnt_i = '0')
                -- the fetch_buffer will just invalidate current data (gnt_i = '1' / rvalid = '1'). 
                -- the fetch buffer needs the NEW pc data next, no old requested data, so perform the new request now, invalidating old addr
                if id_fetch_invalidate_last_req_i = '1' and if_bus_gnt_i = '0' then -- FIXME: check if removeable "and bus_gnt_i = '0'" -> if gnt, buffer will drop this
                    if_state_nxt      <= IDLE;
                    if_bus_req_o      <= '0';
                    id_fetch_valid_o  <= '0';
                    if_fetcher_miss_o <= '0';
                    if_fetch_ready_o  <= if_bus_gnt_i;
                end if;
        end case;
    end process;

    process(clk_i, rst_ni) is
    begin
        if rst_ni = '0' then
            if_state_ff        <= IDLE;
            if_fetched_addr_ff <= (others => '0');
        elsif rising_edge(clk_i) then
            if_state_ff        <= if_state_nxt;
            if_fetched_addr_ff <= if_fetched_addr_nxt;
        end if;
    end process;

end architecture RTL;
