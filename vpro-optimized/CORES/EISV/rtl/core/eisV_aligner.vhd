--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Design Name:    Instruction Aligner                                        --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
--use eisv.eisV_pkg.log2_bitwidth;

entity eisV_aligner is
    port(
        clk_i                    : in  std_ulogic;
        rst_ni                   : in  std_ulogic;
        id_fetched_instr_i       : in  std_ulogic_vector(31 downto 0);
        id_fetched_instr_valid_i : in  std_ulogic;
        id_fetched_addr_i        : in  std_ulogic_vector(31 downto 0); -- @suppress "Unused port: id_fetched_addr_i is not used in eisv.eisV_aligner(RTL)"
        id_fetch_hold_o          : out std_ulogic;
        id_branch_addr_i         : in  std_ulogic_vector(31 downto 0); -- branch target
        id_branch_i              : in  std_ulogic; -- Asserted if we are branching/jumping now
        id_ready_i               : in  std_ulogic;
        id_aligned_instr_o       : out std_ulogic_vector(31 downto 0);
        id_aligned_instr_valid_o : out std_ulogic;
        id_aligned_addr_o        : out std_ulogic_vector(31 downto 0) -- this is the next needed addr (regular flow + branches)
    );
end entity eisV_aligner;

architecture RTL of eisV_aligner is

    -- coverage off
    type state_t is (
        ALIGNED32,
        MISALIGNED32,
        MISALIGNED16,
        BRANCH_MISALIGNED);

    signal id_state, id_state_nxt    : state_t;
    signal id_instr_ff, id_instr_nxt : std_ulogic_vector(31 downto 0);
    signal id_pc_plus4, id_pc_plus2  : unsigned(31 downto 0);

    signal id_aligned_addr_nxt        : std_ulogic_vector(31 downto 0);
    signal id_pc_aligned              : std_ulogic_vector(31 downto 0);
    signal id_update_state            : std_ulogic;
    signal id_aligned_instr_valid_int : std_ulogic;
    signal id_aligned_instr_int       : std_ulogic_vector(31 downto 0);
    -- coverage on

    signal id_branch_ff              : std_ulogic;
    signal id_aligned_instr_valid_ff : std_ulogic;
    signal id_aligned_instr_ff       : std_ulogic_vector(31 downto 0);
    signal id_pc_aligned_ff          : std_ulogic_vector(31 downto 0);

begin

    NO_C_ALIGN_BUFFER_g : if not C_EXTENSION generate
        process(clk_i, rst_ni)
        begin
            if (rst_ni = '0') then
                id_aligned_instr_ff       <= (others => '0');
                id_aligned_instr_valid_ff <= '0';
                id_pc_aligned_ff          <= (others => '0');
                id_branch_ff              <= '0';
            elsif rising_edge(clk_i) then
                id_branch_ff <= id_branch_i;
                if (id_ready_i = '1') then
                    id_aligned_instr_ff       <= id_fetched_instr_i;
                    id_aligned_instr_valid_ff <= id_fetched_instr_valid_i;
                    id_pc_aligned_ff          <= id_fetched_addr_i;
                end if;
                if (id_branch_i = '1') then
                    id_pc_aligned_ff          <= id_branch_addr_i;
                    id_aligned_instr_valid_ff <= '0';
                end if;
            end if;
        end process;

        hold : process(id_ready_i, id_branch_i, id_branch_ff, id_fetched_instr_valid_i, id_aligned_instr_ff, id_aligned_instr_valid_ff, id_fetched_addr_i, id_fetched_instr_i, id_pc_aligned_ff)
        begin
            if (id_ready_i = '1') then
                -- output will get internals
                id_aligned_instr_valid_o <= id_fetched_instr_valid_i;
                id_aligned_instr_o       <= id_fetched_instr_i;
                id_aligned_addr_o        <= id_fetched_addr_i;
            else
                -- else buffered? / 0? -- TODO check
                id_aligned_instr_valid_o <= id_aligned_instr_valid_ff;
                id_aligned_instr_o       <= id_aligned_instr_ff;
                id_aligned_addr_o        <= id_pc_aligned_ff;
            end if;

            id_fetch_hold_o <= '0';
            if (id_ready_i = '0') then
                id_fetch_hold_o <= '1';
            elsif (id_branch_i = '1') then
                -- in case of branch, force continue of fetch (JUMP, BRANCH, SPECIAL JUMP), pc req_nxt will be set
                id_fetch_hold_o <= '0';
            end if;
            if (id_branch_ff = '1') then -- this is the branch
                id_fetch_hold_o          <= '0';
                id_aligned_instr_valid_o <= '0';
            end if;
        end process;
    end generate;

    C_ALIGN_BUFFER_g : if C_EXTENSION generate

        id_pc_plus2 <= unsigned(id_pc_aligned) + 2;
        id_pc_plus4 <= unsigned(id_pc_aligned) + 4;

        process(clk_i, rst_ni)
        begin
            if (rst_ni = '0') then
                id_state                  <= ALIGNED32;
                id_instr_ff               <= (others => '0');
                id_branch_ff              <= '0';
                id_pc_aligned_ff          <= (others => '0');
                id_pc_aligned             <= (others => '0');
                id_aligned_instr_ff       <= (others => '0');
                id_aligned_instr_valid_ff <= '0';
            elsif rising_edge(clk_i) then
                id_branch_ff <= id_branch_i;
                if (id_update_state = '1') then
                    id_aligned_instr_valid_ff <= id_aligned_instr_valid_int;
                    id_aligned_instr_ff       <= id_aligned_instr_int;
                    id_pc_aligned_ff          <= id_pc_aligned;
                    id_state                  <= id_state_nxt;
                    id_instr_ff               <= id_instr_nxt;
                    id_pc_aligned             <= id_aligned_addr_nxt;
                    -- else keep registered
                end if;
                if (id_branch_i = '1') then
                    id_aligned_instr_valid_ff <= '0';
                end if;
            end if;
        end process;

        process(id_branch_addr_i, id_branch_i, id_fetched_instr_i, id_fetched_instr_valid_i, id_instr_ff, id_state, id_branch_ff, id_pc_aligned, id_pc_plus2, id_pc_plus4, id_ready_i, id_aligned_instr_int, id_aligned_instr_valid_int, id_aligned_instr_ff, id_aligned_instr_valid_ff, id_pc_aligned_ff)
        begin
            id_instr_nxt               <= id_instr_ff(31 downto 00);
            if (id_fetched_instr_valid_i = '1') then
                id_instr_nxt <= id_fetched_instr_i(31 downto 00);
            end if;
            id_state_nxt               <= id_state;
            id_aligned_instr_valid_int <= '0';
            id_aligned_instr_int       <= id_fetched_instr_i;
            id_aligned_addr_nxt        <= id_pc_aligned;

            case (id_state) is
                when ALIGNED32 =>       -- before we were aligned to 32-bit boundary
                    if (id_fetched_instr_valid_i = '1') then
                        if (id_fetched_instr_i(1 downto 0) = "11") then -- 32bit instruction
                            id_state_nxt               <= ALIGNED32;
                            id_aligned_addr_nxt        <= std_ulogic_vector(id_pc_plus4);
                            id_aligned_instr_valid_int <= id_fetched_instr_valid_i;
                            id_aligned_instr_int       <= id_fetched_instr_i; -- complete 32-bit Instruction

                        else            -- 16bit instruction
                            id_state_nxt               <= MISALIGNED32;
                            id_aligned_addr_nxt        <= std_ulogic_vector(id_pc_plus2);
                            id_aligned_instr_valid_int <= id_fetched_instr_valid_i;
                            id_aligned_instr_int       <= id_fetched_instr_i; --only the first 16b are used
                        end if;
                    end if;

                when MISALIGNED32 =>    -- before we were NOT aligned to 32-bit boundary -> misaligned
                    -- The beginning of this instruction is the stored one
                    if (id_fetched_instr_valid_i = '1') then
                        if (id_instr_ff(17 downto 16) = "11") then -- 32bit instruction
                            id_state_nxt               <= MISALIGNED32;
                            id_aligned_addr_nxt        <= std_ulogic_vector(id_pc_plus4);
                            id_aligned_instr_valid_int <= id_fetched_instr_valid_i;
                            id_aligned_instr_int       <= id_fetched_instr_i(15 downto 0) & id_instr_ff(31 downto 16); -- complete 32-bit Instruction
                        else            -- 16bit instruction. The beginning of the next instruction will be the stored one (new instruction needed for the stored one to be valid)
                            id_state_nxt               <= MISALIGNED16;
                            id_aligned_addr_nxt        <= std_ulogic_vector(id_pc_plus2);
                            id_aligned_instr_valid_int <= '1';
                            id_aligned_instr_int       <= (31 downto 16 => '0') & id_instr_ff(31 downto 16); --only the first 16b are used
                        end if;
                    end if;

                when MISALIGNED16 =>
                    -- TODO: if id_vald_i
                    -- The beginning of this instruction is the stored one by previous MISALIGNED32 state + 16-bit instr (stored)
                    if (id_instr_ff(1 downto 0) = "11") then -- 32bit instruction, aligned
                        -- Before we fetched a 16bit misaligned instruction. The beginning of the next instruction is the new one
                        id_state_nxt               <= ALIGNED32;
                        id_aligned_addr_nxt        <= std_ulogic_vector(id_pc_plus4);
                        id_aligned_instr_valid_int <= '1';
                        id_aligned_instr_int       <= id_instr_ff; -- complete 32-bit Instruction
                    else                -- 16bit instruction
                        -- Before we fetched a 16bit misaligned  instruction. The beginning of the next instruction is the new one
                        -- The istruction is 16bit aligned
                        id_state_nxt               <= MISALIGNED32;
                        id_aligned_addr_nxt        <= std_ulogic_vector(id_pc_plus2);
                        id_aligned_instr_valid_int <= '1';
                        id_instr_nxt               <= id_instr_ff(31 downto 16) & (15 downto 00 => '0');
                        id_aligned_instr_int       <= id_instr_ff; --only the first 16b are used
                    end if;

                when BRANCH_MISALIGNED =>
                    if (id_fetched_instr_valid_i = '1') then
                        --we jumped to a misaligned location, so now we received {TARGET, XXXX}
                        if (id_fetched_instr_i(17 downto 16) = "11") then -- 32bit instruction
                            --  We jumped to a misaligned location that contains 32bits instruction
                            id_state_nxt               <= MISALIGNED32;
                            id_aligned_instr_valid_int <= '0';
                        else            -- 16bit instruction. We consumed the whole word and start again with ALIGNED32
                            id_state_nxt               <= ALIGNED32;
                            id_aligned_addr_nxt        <= std_ulogic_vector(id_pc_plus2);
                            id_aligned_instr_valid_int <= id_fetched_instr_valid_i;
                            id_aligned_instr_int       <= (31 downto 16 => '-') & id_fetched_instr_i(31 downto 16); --only the first 16b are used
                        end if;
                    end if;
            end case;                   -- state

            id_update_state <= '0';
            -- if instruction is not parsed -> e.g. id stalled / not ready due to hazzards or csr instr
            if id_ready_i = '1' then
                id_update_state <= '1';
            else
                id_update_state <= '0';
            end if;

            if (id_ready_i = '1') then
                -- output will get internals
                id_aligned_instr_valid_o <= id_aligned_instr_valid_int;
                id_aligned_instr_o       <= id_aligned_instr_int;
                id_aligned_addr_o        <= id_pc_aligned;
            else
                -- else buffered? / 0? -- TODO check
                id_aligned_instr_valid_o <= id_aligned_instr_valid_ff;
                id_aligned_instr_o       <= id_aligned_instr_ff;
                id_aligned_addr_o        <= id_pc_aligned_ff;
            end if;

            -- if aligner not updated, keep input buffered
            -- or if state = MISALIGNED16 ~ instr still buffered in aligner register
            -- only needed if buffer has a valid instr. 
            id_fetch_hold_o <= '0';
            if (id_ready_i = '0') then
                id_fetch_hold_o <= '1';
            elsif (id_state /= MISALIGNED16) then
                -- current need of valid_instr_i, continue fetch until instr_valid_i
                if (id_fetched_instr_valid_i = '1') then
                    if (id_ready_i = '0') then
                        id_fetch_hold_o <= '1';
                    else
                        id_fetch_hold_o <= '0';
                    end if;
                end if;
            else                        -- MISALIGNED16
                id_fetch_hold_o <= '1';
            end if;

            -- in case of branch, force continue of fetch (JUMP, BRANCH, SPECIAL JUMP), pc req_nxt will be set
            if (id_branch_i = '1' and id_ready_i = '1') then
                id_fetch_hold_o <= '0';
            end if;

            -- new branch addr received in aligner
            if (id_branch_ff = '1') then -- this is the branch
                id_aligned_instr_valid_int <= '0';
                id_aligned_addr_nxt        <= id_branch_addr_i;
                id_aligned_instr_valid_o   <= '0';
                id_update_state            <= '1';
                id_fetch_hold_o            <= '0'; -- TODO: needed?
                if (id_branch_addr_i(1) = '1') then
                    id_state_nxt <= BRANCH_MISALIGNED;
                else
                    id_state_nxt <= ALIGNED32;
                end if;
            end if;

        end process;

    end generate;                       -- C_EXT
end architecture RTL;
