--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity eisV_instruction_buffer is
    port(
        clk_i                  : in  std_ulogic;
        rst_ni                 : in  std_ulogic;
        -- from bus IF
        id_data_valid_i        : in  std_ulogic;
        id_data_i              : in  std_ulogic_vector(31 downto 0);
        id_addr_i              : in  std_ulogic_vector(31 downto 0);
        -- from ID
        id_id_valid_i          : in  std_ulogic;
        -- to aligner
        id_data_valid_o        : out std_ulogic;
        id_data_o              : out std_ulogic_vector(31 downto 0);
        id_addr_o              : out std_ulogic_vector(31 downto 0);
        -- control
        id_buffer_halt_fetch_o : out std_ulogic;
        if_clear_i             : in  std_ulogic
    );
end entity eisV_instruction_buffer;

architecture RTL of eisV_instruction_buffer is
    type buffer_fsm_t is (FALL_THROUGH, BUFFER_DATA, CLEAR_DATA);

    signal id_state_ff, id_state_nxt : buffer_fsm_t;

    constant BUFFER_SIZE_C : natural := 4; -- min is 2
    type buffer_data_t is array (0 to BUFFER_SIZE_C - 1) of std_ulogic_vector(31 downto 0);

    signal id_data_buffer_ff, id_data_buffer_nxt : buffer_data_t;
    signal id_addr_buffer_ff, id_addr_buffer_nxt : buffer_data_t;

    signal id_wcnt_ff, id_wcnt_nxt : integer range 0 to BUFFER_SIZE_C;

begin

    process(clk_i, rst_ni) is
    begin
        if rst_ni = '0' then
            id_state_ff       <= FALL_THROUGH;
            id_data_buffer_ff <= (others => (others => '0'));
            id_addr_buffer_ff <= (others => (others => '0'));
            id_wcnt_ff        <= 0;
        elsif rising_edge(clk_i) then
            id_state_ff       <= id_state_nxt;
            id_data_buffer_ff <= id_data_buffer_nxt;
            id_addr_buffer_ff <= id_addr_buffer_nxt;
            id_wcnt_ff        <= id_wcnt_nxt;
        end if;
    end process;

    process(id_state_ff, if_clear_i, id_data_i, id_data_valid_i, id_data_buffer_ff, id_wcnt_ff, id_addr_buffer_ff, id_addr_i, id_id_valid_i)
    begin
        id_buffer_halt_fetch_o <= '0';
        id_data_valid_o        <= '0';
        id_data_o              <= (others => '-');
        id_addr_o              <= (others => '-');
        id_state_nxt           <= id_state_ff;
        id_data_buffer_nxt     <= id_data_buffer_ff;
        id_addr_buffer_nxt     <= id_addr_buffer_ff;
        id_wcnt_nxt            <= id_wcnt_ff;

        case (id_state_ff) is
            when FALL_THROUGH =>
                -- receiving new data, old is interpreted already (falled through)
                if id_data_valid_i = '1' then -- no matter if halt (avoid comb. loop)
                    id_data_valid_o <= id_data_valid_i;
                    id_data_o       <= id_data_i;
                    id_addr_o       <= id_addr_i;
                end if;

                if id_id_valid_i = '0' then -- if id not ready/valid for new data, push to buffer (current instruction as well, not valid not from this current instr.)
                    id_state_nxt <= BUFFER_DATA;

                    if id_data_valid_i = '1' then
                        id_data_buffer_nxt(id_wcnt_ff) <= id_data_i;
                        id_addr_buffer_nxt(id_wcnt_ff) <= id_addr_i;
                        id_wcnt_nxt                    <= 1;
                    end if;
                end if;

                if if_clear_i = '1' then
                    id_state_nxt <= CLEAR_DATA;
                end if;

            when BUFFER_DATA =>
                if id_wcnt_ff = 0 then
                    if id_data_valid_i = '1' then -- halted state receiving initial data
                        id_data_valid_o <= id_data_valid_i;
                        id_data_o       <= id_data_i;
                        id_addr_o       <= id_addr_i;
                    end if;
                else                    -- halted state use buffer
                    id_data_valid_o        <= '1';
                    id_data_o              <= id_data_buffer_ff(0);
                    id_addr_o              <= id_addr_buffer_ff(0);
                    id_buffer_halt_fetch_o <= '1';
                end if;

                if id_id_valid_i = '0' then -- halt will read one more, valid immediately buffers
                    if id_data_valid_i = '1' then -- push to buffer
                        -- coverage off
                        if id_wcnt_ff = BUFFER_SIZE_C then
                            report "[Instruction] BUFFER OVERFLOW. New Fetched instruction received but buffer is full!" severity failure;
                        end if;
                        -- coverage on

                        id_data_buffer_nxt(id_wcnt_ff) <= id_data_i;
                        id_addr_buffer_nxt(id_wcnt_ff) <= id_addr_i;
                        id_wcnt_nxt                    <= id_wcnt_ff + 1;
                    end if;             -- data_valid_i = '0' then -- hold

                    id_buffer_halt_fetch_o <= '1';
                    if id_wcnt_ff <= 1 then
                        id_buffer_halt_fetch_o <= '0';
                        if id_wcnt_ff = 1 and id_data_valid_i = '1' then
                            id_buffer_halt_fetch_o <= '1';
                        end if;
                    end if;
                else                    -- halt_i = '0' then
                    -- read buffer (pop)
                    for i in 0 to BUFFER_SIZE_C - 2 loop
                        id_data_buffer_nxt(i) <= id_data_buffer_ff(i + 1);
                        id_addr_buffer_nxt(i) <= id_addr_buffer_ff(i + 1);
                    end loop;

                    if id_wcnt_ff = 0 then -- halted state end. buffer empty
                        id_state_nxt <= FALL_THROUGH;
                    else
                        id_wcnt_nxt <= id_wcnt_ff - 1;
                        if id_data_valid_i = '1' then
                            -- shift buffer; fill while reading it
                            id_data_buffer_nxt(id_wcnt_ff - 1) <= id_data_i;
                            id_addr_buffer_nxt(id_wcnt_ff - 1) <= id_addr_i;
                            id_wcnt_nxt                        <= id_wcnt_ff;
                            -- else, no new data, wcnt will decrease
                        end if;
                        if id_wcnt_ff <= 1 then
                            id_buffer_halt_fetch_o <= '0';
                        end if;
                    end if;
                end if;

                if if_clear_i = '1' then
                    id_state_nxt <= CLEAR_DATA;
                end if;

            when CLEAR_DATA =>
                id_wcnt_nxt  <= 0;
                id_state_nxt <= FALL_THROUGH;
        end case;

    end process;

end architecture RTL;
