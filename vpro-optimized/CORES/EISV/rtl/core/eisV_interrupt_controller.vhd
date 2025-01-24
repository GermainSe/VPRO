--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Interrupt Controller of the pipelined processor            --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_interrupt_controller is
    port(
        clk_i          : in  std_ulogic;
        rst_ni         : in  std_ulogic;
        -- External interrupt lines
        irq_i          : in  std_ulogic_vector(31 downto 0); -- Level-triggered interrupt inputs
        -- To controller
        irq_req_ctrl_o : out std_ulogic;
        --        irq_sec_ctrl_o     : out std_ulogic;
        irq_id_ctrl_o  : out std_ulogic_vector(4 downto 0);
        irq_wu_ctrl_o  : out std_ulogic;
        -- To/from cs_registers
        mie_bypass_i   : in  std_ulogic_vector(31 downto 0); -- MIE CSR (bypass)
        mip_o          : out std_ulogic_vector(31 downto 0); -- MIP CSR
        m_ie_i         : in  std_ulogic -- Interrupt enable bit from CSR (M mode)
    );
end entity eisV_interrupt_controller;

architecture RTL of eisV_interrupt_controller is

    signal global_irq_enable : std_ulogic;
    signal irq_local_qual    : std_ulogic_vector(31 downto 0);
    signal irq_ff            : std_ulogic_vector(31 downto 0);
    --    signal irq_sec_q         : std_ulogic;
begin
    -- coverage off

    -- Register all interrupt inputs (on gated clock). The wake-up logic will
    -- observe irq_i as well, but in all other places irq_q will be used to 
    -- avoid timing paths from irq_i to instr_*_o

    process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            irq_ff <= (others => '0');
        elsif rising_edge(clk_i) then
            irq_ff <= irq_i and IRQ_MASK;
        end if;
    end process;

    -- MIP CSR
    mip_o <= irq_ff;

    -- Qualify registered IRQ with MIE CSR to compute locally enabled IRQs
    irq_local_qual <= irq_ff and mie_bypass_i;

    -- Wake-up signal based on unregistered IRQ such that wake-up can be caused if no clock is present
    irq_wu_ctrl_o <= or_reduce(irq_i and mie_bypass_i);

    -- Global interrupt enable
    global_irq_enable <= m_ie_i;

    -- Request to take interrupt if there is a locally enabled interrupt while interrupts are also enabled globally
    irq_req_ctrl_o <= (or_reduce(irq_local_qual)) and global_irq_enable;

    -- Interrupt Encoder
    --
    -- - sets correct id to request to ID
    -- - encodes priority order

    process(irq_local_qual)
    begin
        if (irq_local_qual(31) = '1') then
            irq_id_ctrl_o <= "11111";   -- 31;     -- Custom irq_i(31)
        elsif (irq_local_qual(30) = '1') then
            irq_id_ctrl_o <= "11110";   -- 30;                -- Custom irq_i(30)
        elsif (irq_local_qual(29) = '1') then
            irq_id_ctrl_o <= "11101";   --29;                -- Custom irq_i(29)
        elsif (irq_local_qual(28) = '1') then
            irq_id_ctrl_o <= "11100";   --28;                -- Custom irq_i(28)
        elsif (irq_local_qual(27) = '1') then
            irq_id_ctrl_o <= "11011";   --27;                -- Custom irq_i(27)
        elsif (irq_local_qual(26) = '1') then
            irq_id_ctrl_o <= "11010";   --26;                -- Custom irq_i(26)
        elsif (irq_local_qual(25) = '1') then
            irq_id_ctrl_o <= "11001";   --25;                -- Custom irq_i(25)
        elsif (irq_local_qual(24) = '1') then
            irq_id_ctrl_o <= "11000";   --24;                -- Custom irq_i(24)
        elsif (irq_local_qual(23) = '1') then
            irq_id_ctrl_o <= "10111";   --23;                -- Custom irq_i(23)
        elsif (irq_local_qual(22) = '1') then
            irq_id_ctrl_o <= "10110";   --22;                -- Custom irq_i(22)
        elsif (irq_local_qual(21) = '1') then
            irq_id_ctrl_o <= "10101";   --21;                -- Custom irq_i(21)
        elsif (irq_local_qual(20) = '1') then
            irq_id_ctrl_o <= "10100";   --20;                -- Custom irq_i(20)
        elsif (irq_local_qual(19) = '1') then
            irq_id_ctrl_o <= "10011";   --19;                -- Custom irq_i(19)
        elsif (irq_local_qual(18) = '1') then
            irq_id_ctrl_o <= "10010";   --18;                -- Custom irq_i(18)
        elsif (irq_local_qual(17) = '1') then
            irq_id_ctrl_o <= "10001";   --17;                -- Custom irq_i(17)
        elsif (irq_local_qual(16) = '1') then
            irq_id_ctrl_o <= "10000";   --16;                -- Custom irq_i(16)

        elsif (irq_local_qual(15) = '1') then
            irq_id_ctrl_o <= "01111";   --15;           -- Reserved  (default masked out with IRQ_MASK)
        elsif (irq_local_qual(14) = '1') then
            irq_id_ctrl_o <= "01110";   --14;           -- Reserved  (default masked out with IRQ_MASK)
        elsif (irq_local_qual(13) = '1') then
            irq_id_ctrl_o <= "01101";   --13;           -- Reserved  (default masked out with IRQ_MASK)
        elsif (irq_local_qual(12) = '1') then
            irq_id_ctrl_o <= "01100";   --12;           -- Reserved  (default masked out with IRQ_MASK)

        elsif (irq_local_qual(CSR_MEIX_BIT) = '1') then
            irq_id_ctrl_o <= std_ulogic_vector(to_unsigned(CSR_MEIX_BIT, 5)); -- MEI, irq_i(11)
        elsif (irq_local_qual(CSR_MSIX_BIT) = '1') then
            irq_id_ctrl_o <= std_ulogic_vector(to_unsigned(CSR_MSIX_BIT, 5)); -- MSI, irq_i(3)
        elsif (irq_local_qual(CSR_MTIX_BIT) = '1') then
            irq_id_ctrl_o <= std_ulogic_vector(to_unsigned(CSR_MTIX_BIT, 5)); -- MTI, irq_i(7)

        elsif (irq_local_qual(10) = '1') then
            irq_id_ctrl_o <= "01010";   --10;           -- Reserved (for now assuming EI, SI, TI priority) (default masked out with IRQ_MASK)
        elsif (irq_local_qual(2) = '1') then
            irq_id_ctrl_o <= "00010";   --2;            -- Reserved (for now assuming EI, SI, TI priority) (default masked out with IRQ_MASK)
        elsif (irq_local_qual(6) = '1') then
            irq_id_ctrl_o <= "00110";   --6;            -- Reserved (for now assuming EI, SI, TI priority) (default masked out with IRQ_MASK)

        elsif (irq_local_qual(9) = '1') then
            irq_id_ctrl_o <= "01001";   --9;            -- Reserved: SEI (default masked out with IRQ_MASK)
        elsif (irq_local_qual(1) = '1') then
            irq_id_ctrl_o <= "00001";   --1;            -- Reserved: SSI (default masked out with IRQ_MASK)
        elsif (irq_local_qual(5) = '1') then
            irq_id_ctrl_o <= "00101";   --5;            -- Reserved: STI (default masked out with IRQ_MASK)

        elsif (irq_local_qual(8) = '1') then
            irq_id_ctrl_o <= "01000";   --8;            -- Reserved: UEI (default masked out with IRQ_MASK)
        elsif (irq_local_qual(0) = '1') then
            irq_id_ctrl_o <= "00000";   --0;            -- Reserved: USI (default masked out with IRQ_MASK)
        elsif (irq_local_qual(4) = '1') then
            irq_id_ctrl_o <= "00100";   --4;            -- Reserved: UTI (default masked out with IRQ_MASK)

        else
            irq_id_ctrl_o <= std_ulogic_vector(to_unsigned(CSR_MTIX_BIT, 5)); -- Value not relevant
        end if;
    end process;

    -- coverage on
end architecture RTL;

