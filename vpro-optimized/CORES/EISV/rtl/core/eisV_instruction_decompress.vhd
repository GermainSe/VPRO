--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Decodes RISC-V compressed instructions into their RV32     --
--                 equivalent. This module is fully combinatorial.            --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_instruction_decompress is
    port(
        id_instr_i         : in  std_ulogic_vector(31 downto 0);
        id_instr_o         : out std_ulogic_vector(31 downto 0);
        id_is_compressed_o : out std_ulogic;
        id_illegal_instr_o : out std_ulogic
    );
end entity eisV_instruction_decompress;

architecture RTL of eisV_instruction_decompress is

begin
    NO_C_ALIGN_BUFFER_g : if not C_EXTENSION generate
        id_is_compressed_o <= '0';
        id_illegal_instr_o <= '1' when id_instr_i(1 downto 0) /= "11" else '0'; -- C = illegal
        id_instr_o         <= id_instr_i;
    end generate;

    C_ALIGN_BUFFER_g : if C_EXTENSION generate
        ---------------------------------------------
        -- Compressed Instructions Decode
        ---------------------------------------------

        process(id_instr_i)
            variable instr_v : std_ulogic_vector(2 downto 0);
        begin
            instr_v := (id_instr_i(12) & id_instr_i(6 downto 5));
            
            id_illegal_instr_o <= '0';
            id_instr_o         <= (others => '0');

            case (id_instr_i(1 downto 0)) is
                -- C0
                when "00" =>
                    case (id_instr_i(15 downto 13)) is
                        when "000" =>
                            -- c.addi4spn -> addi rd', x2, imm
                            id_instr_o <= "00" & id_instr_i(10 downto 7) & id_instr_i(12 downto 11) & id_instr_i(5) & id_instr_i(6) & "00" & "00010" & "000" & "01" & id_instr_i(4 downto 2) & OPCODE_OPIMM;
                            if (id_instr_i(12 downto 5) = "00000000") then
                                id_illegal_instr_o <= '1';
                            end if;

                        when "001" =>
                            -- c.fld -> fld rd', imm(rs1')
                            id_illegal_instr_o <= '1';

                        when "010" =>
                            -- c.lw -> lw rd', imm(rs1')
                            id_instr_o <= "00000" & id_instr_i(5) & id_instr_i(12 downto 10) & id_instr_i(6) & "00" & "01" & id_instr_i(9 downto 7) & "010" & "01" & id_instr_i(4 downto 2) & OPCODE_LOAD;

                        when "011" =>
                            -- c.flw -> flw rd', imm(rs1')
                            id_illegal_instr_o <= '1';
                        when "101" =>
                            -- c.fsd -> fsd rs2', imm(rs1')
                            id_illegal_instr_o <= '1';

                        when "110" =>
                            -- c.sw -> sw rs2', imm(rs1')
                            id_instr_o <= "00000" & id_instr_i(5) & id_instr_i(12) & "01" & id_instr_i(4 downto 2) & "01" & id_instr_i(9 downto 7) & "010" & id_instr_i(11 downto 10) & id_instr_i(6) & "00" & OPCODE_STORE;

                        when "111" =>
                            -- c.fsw -> fsw rs2', imm(rs1')
                            id_illegal_instr_o <= '1';
                        when others =>
                            id_illegal_instr_o <= '1';
                    end case;

                -- C1
                when "01" =>
                    case (id_instr_i(15 downto 13)) is
                        when "000" =>
                            -- c.addi -> addi rd, rd, nzimm
                            -- c.nop
                            id_instr_o <= bit_repeat(6, id_instr_i(12)) & id_instr_i(12) & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & "000" & id_instr_i(11 downto 7) & OPCODE_OPIMM;

                        when "001" | "101" =>
                            -- 001: c.jal -> jal x1, imm
                            -- 101: c.j   -> jal x0, imm
                            id_instr_o <= id_instr_i(12) & id_instr_i(8) & id_instr_i(10 downto 9) & id_instr_i(6) & id_instr_i(7) & id_instr_i(2) & id_instr_i(11) & id_instr_i(5 downto 3) & bit_repeat(9, id_instr_i(12)) & "0000" & not id_instr_i(15) & OPCODE_JAL;

                        when "010" =>
                            if (id_instr_i(11 downto 7) = "00000") then
                                -- Hint -> addi x0, x0, nzimm
                                id_instr_o <= bit_repeat(6, id_instr_i(12)) & id_instr_i(12) & id_instr_i(6 downto 2) & "00000000" & id_instr_i(11 downto 7) & OPCODE_OPIMM;
                            else
                                -- c.li -> addi rd, x0, nzimm
                                id_instr_o <= bit_repeat(6, id_instr_i(12)) & id_instr_i(12) & id_instr_i(6 downto 2) & "00000000" & id_instr_i(11 downto 7) & OPCODE_OPIMM;
                            end if;

                        when "011" =>
                            if (id_instr_i(12) & id_instr_i(6 downto 2) = "000000") then
                                id_illegal_instr_o <= '1';
                            else
                                if (id_instr_i(11 downto 7) = "00010") then
                                    -- c.addi16sp -> addi x2, x2, nzimm
                                    id_instr_o <= bit_repeat(3, id_instr_i(12)) & id_instr_i(4 downto 3) & id_instr_i(5) & id_instr_i(2) & id_instr_i(6) & "0000" & "00010" & "000" & "00010" & OPCODE_OPIMM;
                                elsif (id_instr_i(11 downto 7) = "00000") then
                                    -- Hint -> lui x0, imm
                                    id_instr_o <= bit_repeat(15, id_instr_i(12)) & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & OPCODE_LUI;
                                else
                                    -- c.lui -> lui rd, imm
                                    id_instr_o <= bit_repeat(15, id_instr_i(12)) & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & OPCODE_LUI;
                                end if;
                            end if;

                        when "100" =>
                            case (id_instr_i(11 downto 10)) is
                                when "00" | "01" =>
                                    -- 00: c.srli -> srli rd, rd, shamt
                                    -- 01: c.srai -> srai rd, rd, shamt
                                    if (id_instr_i(12) = '1') then
                                        -- Reserved for future custom extensions (instr_o don't care)
                                        id_instr_o         <= '0' & id_instr_i(10) & "00000" & id_instr_i(6 downto 2) & "01" & id_instr_i(9 downto 7) & "101" & "01" & id_instr_i(9 downto 7) & OPCODE_OPIMM;
                                        id_illegal_instr_o <= '1';
                                    else
                                        if (id_instr_i(6 downto 2) = "00000") then
                                            -- Hint
                                            id_instr_o <= '0' & id_instr_i(10) & "00000" & id_instr_i(6 downto 2) & "01" & id_instr_i(9 downto 7) & "101" & "01" & id_instr_i(9 downto 7) & OPCODE_OPIMM;
                                        else
                                            id_instr_o <= '0' & id_instr_i(10) & "00000" & id_instr_i(6 downto 2) & "01" & id_instr_i(9 downto 7) & "101" & "01" & id_instr_i(9 downto 7) & OPCODE_OPIMM;
                                        end if;
                                    end if;

                                when "10" =>
                                    -- c.andi -> andi rd, rd, imm
                                    id_instr_o <= bit_repeat(6, id_instr_i(12)) & id_instr_i(12) & id_instr_i(6 downto 2) & "01" & id_instr_i(9 downto 7) & "111" & "01" & id_instr_i(9 downto 7) & OPCODE_OPIMM;

                                when "11" =>
                                    case instr_v is
                                        when "000" =>
                                            -- c.sub -> sub rd', rd', rs2'
                                            id_instr_o <= "01" & "00000" & "01" & id_instr_i(4 downto 2) & "01" & id_instr_i(9 downto 7) & "000" & "01" & id_instr_i(9 downto 7) & OPCODE_OP;

                                        when "001" =>
                                            -- c.xor -> xor rd', rd', rs2'
                                            id_instr_o <= "0000000" & "01" & id_instr_i(4 downto 2) & "01" & id_instr_i(9 downto 7) & "100" & "01" & id_instr_i(9 downto 7) & OPCODE_OP;

                                        when "010" =>
                                            -- c.or  -> or  rd', rd', rs2'
                                            id_instr_o <= "0000000" & "01" & id_instr_i(4 downto 2) & "01" & id_instr_i(9 downto 7) & "110" & "01" & id_instr_i(9 downto 7) & OPCODE_OP;

                                        when "011" =>
                                            -- c.and -> and rd', rd', rs2'
                                            id_instr_o <= "0000000" & "01" & id_instr_i(4 downto 2) & "01" & id_instr_i(9 downto 7) & "111" & "01" & id_instr_i(9 downto 7) & OPCODE_OP;

                                        when "100"| "101"| "110"| "111" =>
                                            -- 100: c.subw
                                            -- 101: c.addw
                                            id_illegal_instr_o <= '1';
                                        when others =>
                                            id_illegal_instr_o <= '1';
                                    end case;
                                when others =>
                                    id_illegal_instr_o <= '1';
                            end case;

                        when "110"| "111" =>
                            -- 0: c.beqz -> beq rs1', x0, imm
                            -- 1: c.bnez -> bne rs1', x0, imm
                            id_instr_o <= bit_repeat(4, id_instr_i(12)) & id_instr_i(6 downto 5) & id_instr_i(2) & "00000" & "01" & id_instr_i(9 downto 7) & "00" & id_instr_i(13) & id_instr_i(11 downto 10) & id_instr_i(4 downto 3) & id_instr_i(12) & OPCODE_BRANCH;
                        when others =>
                            id_illegal_instr_o <= '1';
                    end case;

                -- C2
                when "10" =>
                    case (id_instr_i(15 downto 13)) is
                        when "000" =>
                            if (id_instr_i(12) = '1') then
                                -- Reserved for future extensions (instr_o don't care)
                                id_instr_o         <= "0000000" & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & "001" & id_instr_i(11 downto 7) & OPCODE_OPIMM;
                                id_illegal_instr_o <= '1';
                            else
                                if ((id_instr_i(6 downto 2) = "00000") or (id_instr_i(11 downto 7) = "00000")) then
                                    -- Hint -> slli rd, rd, shamt 
                                    id_instr_o <= "0000000" & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & "001" & id_instr_i(11 downto 7) & OPCODE_OPIMM;
                                else
                                    -- c.slli -> slli rd, rd, shamt
                                    id_instr_o <= "0000000" & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & "001" & id_instr_i(11 downto 7) & OPCODE_OPIMM;
                                end if;
                            end if;

                        when "001" =>
                            -- c.fldsp -> fld rd, imm(x2)
                            id_illegal_instr_o <= '1';

                        when "010" =>
                            -- c.lwsp -> lw rd, imm(x2)
                            id_instr_o <= "0000" & id_instr_i(3 downto 2) & id_instr_i(12) & id_instr_i(6 downto 4) & "00" & "00010" & "010" & id_instr_i(11 downto 7) & OPCODE_LOAD;
                            if (id_instr_i(11 downto 7) = "00000") then
                                id_illegal_instr_o <= '1';
                            end if;

                        when "011" =>
                            -- c.flwsp -> flw rd, imm(x2)
                            id_illegal_instr_o <= '1';

                        when "100" =>
                            if (id_instr_i(12) = '0') then
                                if (id_instr_i(6 downto 2) = "00000") then
                                    -- c.jr -> jalr x0, rd/rs1, 0
                                    id_instr_o <= "000000000000" & id_instr_i(11 downto 7) & "00000000" & OPCODE_JALR;
                                    -- c.jr with rs1 = 0 is reserved
                                    if (id_instr_i(11 downto 7) = "00000") then
                                        id_illegal_instr_o <= '1';
                                    end if;
                                else
                                    if (id_instr_i(11 downto 7) = "00000") then
                                        -- Hint -> add x0, x0, rs2
                                        id_instr_o <= "0000000" & id_instr_i(6 downto 2) & "00000000" & id_instr_i(11 downto 7) & OPCODE_OP;
                                    else
                                        -- c.mv -> add rd, x0, rs2
                                        id_instr_o <= "0000000" & id_instr_i(6 downto 2) & "00000000" & id_instr_i(11 downto 7) & OPCODE_OP;
                                    end if;
                                end if;
                            else
                                if (id_instr_i(6 downto 2) = "00000") then
                                    if (id_instr_i(11 downto 7) = "00000") then
                                        -- c.ebreak -> ebreak
                                        id_instr_o <= x"00100073";
                                    else
                                        -- c.jalr -> jalr x1, rs1, 0
                                        id_instr_o <= "000000000000" & id_instr_i(11 downto 7) & "000" & "00001" & OPCODE_JALR;
                                    end if;
                                else
                                    if (id_instr_i(11 downto 7) = "00000") then
                                        -- Hint -> add x0, x0, rs2
                                        id_instr_o <= "0000000" & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & "000" & id_instr_i(11 downto 7) & OPCODE_OP;
                                    else
                                        -- c.add -> add rd, rd, rs2
                                        id_instr_o <= "0000000" & id_instr_i(6 downto 2) & id_instr_i(11 downto 7) & "000" & id_instr_i(11 downto 7) & OPCODE_OP;
                                    end if;
                                end if;
                            end if;

                        when "101" =>
                            -- c.fsdsp -> fsd rs2, imm(x2)
                            id_illegal_instr_o <= '1';

                        when "110" =>
                            -- c.swsp -> sw rs2, imm(x2)
                            id_instr_o <= "0000" & id_instr_i(8 downto 7) & id_instr_i(12) & id_instr_i(6 downto 2) & "00010" & "010" & id_instr_i(11 downto 9) & "00" & OPCODE_STORE;

                        when "111" =>
                            -- c.fswsp -> fsw rs2, imm(x2)
                            id_illegal_instr_o <= '1';
                        when others =>
                            id_illegal_instr_o <= '1';
                    end case;

                when others =>
                    -- 32 bit (or more) instruction
                    id_instr_o <= id_instr_i;
            end case;
        end process;

        id_is_compressed_o <= '1' when (id_instr_i(1 downto 0) /= "11") else '0';

    end generate;
end architecture RTL;
