--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Control and Status Registers (CSRs) loosely following the  --
--                 RiscV draft priviledged instruction set spec (v1.9)        --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_cs_register is
    generic(
        IMPLEMENTED_COUNTERS_G : natural := 32
    );
    port(
        -- Clock and Reset
        clk_i                      : in  std_ulogic;
        rst_ni                     : in  std_ulogic;
        -- Hart ID
        hart_id_i                  : in  std_ulogic_vector(31 downto 0);
        if_mtvec_o                 : out std_ulogic_vector(23 downto 0);
        mtvec_mode_o               : out std_ulogic_vector(1 downto 0);
        -- Used for mtvec address
        mtvec_addr_i               : in  std_ulogic_vector(31 downto 0);
        if_csr_mtvec_init_i        : in  std_ulogic;
        -- Interface to registers (SRAM like)    
        ex_csr_addr_i              : in  std_ulogic_vector(11 downto 0);
        ex_csr_wdata_i             : in  std_ulogic_vector(31 downto 0);
        ex_csr_op_i                : in  std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0);
        ex_csr_rdata_o             : out std_ulogic_vector(31 downto 0);
        -- Interrupts
        mie_bypass_o               : out std_ulogic_vector(31 downto 0);
        mip_i                      : in  std_ulogic_vector(31 downto 0);
        m_irq_enable_o             : out std_ulogic;
        if_mepc_o                  : out std_ulogic_vector(31 downto 0);
        if_pc_i                    : in  std_ulogic_vector(31 downto 0);
        id_pc_i                    : in  std_ulogic_vector(31 downto 0);
        ex_pc_i                    : in  std_ulogic_vector(31 downto 0);
        csr_save_if_i              : in  std_ulogic;
        csr_save_id_i              : in  std_ulogic;
        csr_save_ex_i              : in  std_ulogic;
        csr_restore_mret_i         : in  std_ulogic;
        --coming from controller
        csr_cause_i                : in  std_ulogic_vector(5 downto 0);
        --coming from controller
        csr_save_cause_i           : in  std_ulogic;
        -- Performance Counters
        mhpmevent_minstret_i       : in  std_ulogic;
        mhpmevent_load_i           : in  std_ulogic;
        mhpmevent_store_i          : in  std_ulogic;
        mhpmevent_jump_i           : in  std_ulogic; -- Jump instruction retired (j, jr, jal, jalr)
        mhpmevent_branch_i         : in  std_ulogic; -- Branch instruction retired (beq, bne, etc.)
        mhpmevent_branch_taken_i   : in  std_ulogic; -- Branch instruction taken
        mhpmevent_compressed_i     : in  std_ulogic;
        mhpmevent_jr_stall_i       : in  std_ulogic;
        mhpmevent_imiss_i          : in  std_ulogic;
        mhpmevent_dmiss_i          : in  std_ulogic;
        mhpmevent_ld_stall_i       : in  std_ulogic;
        mhpmevent_mul_stall_i      : in  std_ulogic;
        mhpmevent_csr_instr_i      : in  std_ulogic;
        mhpmevent_div_multicycle_i : in  std_ulogic
    );
end entity eisV_cs_register;

architecture RTL of eisV_cs_register is

    constant NUM_HPM_EVENTS : natural := 16;

    constant MSTATUS_UIE_BIT      : natural := 0;
    constant MSTATUS_SIE_BIT      : natural := 1; -- @suppress "Unused declaration"
    constant MSTATUS_MIE_BIT      : natural := 3;
    constant MSTATUS_UPIE_BIT     : natural := 4;
    constant MSTATUS_SPIE_BIT     : natural := 5; -- @suppress "Unused declaration"
    constant MSTATUS_MPIE_BIT     : natural := 7;
    constant MSTATUS_SPP_BIT      : natural := 8; -- @suppress "Unused declaration"
    constant MSTATUS_MPP_BIT_HIGH : natural := 12; -- @suppress "Unused declaration"
    constant MSTATUS_MPP_BIT_LOW  : natural := 11; -- @suppress "Unused declaration"
    constant MSTATUS_MPRV_BIT     : natural := 17;

    -- misa
    constant MXL        : std_ulogic_vector(1 downto 0)  := "01"; -- M-XLEN: XLEN in M-Mode for RV32
    constant MX         : std_ulogic_vector(0 downto 0)  := "0"; -- X: Trap Handling supported? CSR to enable/disable exteranl interript? meie-meip
    constant MM         : std_ulogic_vector(0 downto 0)  := "1"; -- M: M Extension
    constant MC         : std_ulogic_vector(0 downto 0)  := "1"; -- C: C Extension
    constant MA         : std_ulogic_vector(0 downto 0)  := "0"; -- A: A Extension
    constant MISA_VALUE : std_ulogic_vector(31 downto 0) := MXL & (29 downto 24 => '0') & MX & (22 downto 13 => '0') & MM & "000" & "1" & "00" & "000" & MC & "0" & MA;

    --  (A_EXTENSION << 0)  -- A - Atomic Instructions extension
    --  | (1 << 2)  -- C - Compressed extension
    --  | (0 << 3)  -- D - Double precision floating-point extension
    --  | (0 << 4)  -- E - RV32E base ISA
    --  | (0 << 5)                     -- F - Single precision floating-point extension
    --  | (1 << 8)                            -- I - RV32I/64I/128I base ISA
    --  | (1 << 12)                           -- M - Integer Multiply/Divide extension
    --  | (0 << 13)                           -- N - User level interrupts supported
    --  | (0 << 18)                           -- S - Supervisor mode implemented
    --  | (0 << 20)            -- U - User mode implemented
    --  | (0 << 23) -- X - Non-standard extensions present
    --  | (MXL << 30);                   -- M-XLEN

    constant MHPMCOUNTER_WIDTH : natural := 64;

    type status_t is record
        uie  : std_ulogic;
        mie  : std_ulogic;
        upie : std_ulogic;
        mpie : std_ulogic;
        mprv : std_ulogic;
    end record;

    -- CSR update logic
    signal csr_wdata_int : std_ulogic_vector(31 downto 0);
    signal csr_rdata_int : std_ulogic_vector(31 downto 0);
    signal csr_we_int    : std_ulogic;

    -- Interrupt control signals
    signal mepc_ff, mepc_nxt : std_ulogic_vector(31 downto 0);

    signal exception_pc                  : std_ulogic_vector(31 downto 0);
    signal mstatus_ff, mstatus_nxt       : status_t;
    signal mcause_ff, mcause_nxt         : std_ulogic_vector(5 downto 0);
    --not implemented yet
    signal mtvec_nxt, mtvec_ff           : std_ulogic_vector(23 downto 0);
    signal mtvec_mode_nxt, mtvec_mode_ff : std_ulogic_vector(1 downto 0);

    signal mip             : std_ulogic_vector(31 downto 0); -- Bits are masked according to IRQ_MASK
    signal mie_ff, mie_nxt : std_ulogic_vector(31 downto 0); -- Bits are masked according to IRQ_MASK

    signal csr_mie_wdata : std_ulogic_vector(31 downto 0);
    signal csr_mie_we    : std_ulogic;

    -- Performance Counter Signals
    type mhpmcounter_t is array (0 to 31) of std_ulogic_vector(MHPMCOUNTER_WIDTH - 1 downto 0);
    signal mhpmcounter_ff, mhpmcounter_nxt : mhpmcounter_t; -- performance counters
    type mhpmevent_en_t is array (0 to 31) of std_ulogic_vector(31 downto 0);
    signal mhpmevent_ff, mhpmevent_nxt     : mhpmevent_en_t; -- event enable
    signal mcounteren_ff, mcounteren_nxt   : std_ulogic_vector(31 downto 0); -- user mode counter enable
    signal hpm_events                      : std_ulogic_vector(NUM_HPM_EVENTS - 1 downto 0); -- events for performance counters
    signal mhpmcounter_increment           : mhpmcounter_t; -- increment of mhpmcounter_ff
    signal mhpmcounter_write_lower         : std_ulogic_vector(31 downto 0); -- write 32 lower bits of mhpmcounter_ff
    signal mhpmcounter_write_upper         : std_ulogic_vector(31 downto 0); -- write 32 upper bits mhpmcounter_ff
    signal mhpmcounter_write_increment     : std_ulogic_vector(31 downto 0); -- write increment of mhpmcounter_ff

    -- address decoder for performance counter registers
    signal mcounteren_we             : std_ulogic;
    signal mhpmevent_we              : std_ulogic;
    signal mscratch_nxt, mscratch_ff : std_ulogic_vector(31 downto 0);

begin
    -- coverage off

    -- mip CSR
    mip <= mip_i;

    -- mie_nxt is used instead of mie_ff such that a CSR write to the MIE register can
    -- affect the instruction immediately following it.

    -- MIE CSR operation logic
    process(ex_csr_op_i, ex_csr_wdata_i, mie_ff)
    begin
        csr_mie_wdata <= ex_csr_wdata_i;
        csr_mie_we    <= '1';

        case (ex_csr_op_i) is
            when CSR_OP_WRITE =>
                csr_mie_wdata <= ex_csr_wdata_i;
            when CSR_OP_SET =>
                csr_mie_wdata <= ex_csr_wdata_i or mie_ff;
            when CSR_OP_CLEAR =>
                csr_mie_wdata <= (not ex_csr_wdata_i) and mie_ff;
            when CSR_OP_READ =>
                csr_mie_wdata <= ex_csr_wdata_i;
                csr_mie_we    <= '0';
            when others => csr_mie_wdata <= ex_csr_wdata_i;
        end case;
    end process;

    mie_bypass_o <= csr_mie_wdata and IRQ_MASK when ((ex_csr_addr_i = CSR_MIE) and csr_mie_we = '1') else mie_ff;

    --------------------------------------------
    -- CSR Read
    --------------------------------------------
    -- NOTE!!!: Any new CSR register added in this file must also be added to the valid CSR register list in the ID Stage's decoder
    process(ex_csr_addr_i, mstatus_ff, hart_id_i, mcause_ff, mepc_ff, mhpmcounter_ff, mhpmevent_ff, mie_ff, mip, mtvec_mode_ff, mtvec_ff, mcounteren_ff, mscratch_ff)
    begin
        case (ex_csr_addr_i) is
            -- mstatus: always M-mode, contains IE bit
            when CSR_MSTATUS =>
                csr_rdata_int <= "00" & x"000" & mstatus_ff.mprv & "000011000" & mstatus_ff.mpie & "00" & mstatus_ff.upie & mstatus_ff.mie & "00" & mstatus_ff.uie;

            -- misa: machine isa register
            when CSR_MISA =>
                csr_rdata_int <= MISA_VALUE;

            -- mie: machine interrupt enable
            when CSR_MIE =>
                csr_rdata_int <= mie_ff;

            -- mtvec: machine trap-handler base address
            when CSR_MTVEC =>
                csr_rdata_int <= mtvec_ff & "000000" & mtvec_mode_ff;

            -- mscratch: machine scratch
            when CSR_MSCRATCH =>
                csr_rdata_int <= mscratch_ff;

            -- mepc: exception program counter
            when CSR_MEPC =>
                csr_rdata_int <= mepc_ff;

            -- mcause: exception cause
            when CSR_MCAUSE =>

                csr_rdata_int <= mcause_ff(5) & x"000000" & "00" & mcause_ff(4 downto 0);
            -- mip: interrupt pending
            when CSR_MIP =>
                csr_rdata_int <= mip;

            -- mhartid: unique hardware thread id
            when CSR_MHARTID =>
                csr_rdata_int <= hart_id_i;

            -- mvendorid: Machine Vendor ID
            when CSR_MVENDORID =>
                csr_rdata_int <= MVENDORID;

            -- marchid: Machine Architecture ID
            when CSR_MARCHID =>
                csr_rdata_int <= MARCHID;

            -- unimplemented, read 0 CSRs
            when CSR_MIMPID|  CSR_MTVAL =>
                csr_rdata_int <= (others => '0');

            -- Hardware Performance Monitor
            when CSR_MCYCLE|
      CSR_MINSTRET|
      CSR_MHPMCOUNTER3|
      CSR_MHPMCOUNTER4|  CSR_MHPMCOUNTER5|  CSR_MHPMCOUNTER6|  CSR_MHPMCOUNTER7|
      CSR_MHPMCOUNTER8|  CSR_MHPMCOUNTER9|  CSR_MHPMCOUNTER10| CSR_MHPMCOUNTER11|
      CSR_MHPMCOUNTER12| CSR_MHPMCOUNTER13| CSR_MHPMCOUNTER14| CSR_MHPMCOUNTER15|
      CSR_MHPMCOUNTER16| CSR_MHPMCOUNTER17| CSR_MHPMCOUNTER18| CSR_MHPMCOUNTER19|
      CSR_MHPMCOUNTER20| CSR_MHPMCOUNTER21| CSR_MHPMCOUNTER22| CSR_MHPMCOUNTER23|
      CSR_MHPMCOUNTER24| CSR_MHPMCOUNTER25| CSR_MHPMCOUNTER26| CSR_MHPMCOUNTER27|
      CSR_MHPMCOUNTER28| CSR_MHPMCOUNTER29| CSR_MHPMCOUNTER30| CSR_MHPMCOUNTER31|
      CSR_CYCLE|      CSR_INSTRET|
      CSR_HPMCOUNTER3|
      CSR_HPMCOUNTER4|  CSR_HPMCOUNTER5|  CSR_HPMCOUNTER6|  CSR_HPMCOUNTER7|
      CSR_HPMCOUNTER8|  CSR_HPMCOUNTER9|  CSR_HPMCOUNTER10| CSR_HPMCOUNTER11|
      CSR_HPMCOUNTER12| CSR_HPMCOUNTER13| CSR_HPMCOUNTER14| CSR_HPMCOUNTER15|
      CSR_HPMCOUNTER16| CSR_HPMCOUNTER17| CSR_HPMCOUNTER18| CSR_HPMCOUNTER19|
      CSR_HPMCOUNTER20| CSR_HPMCOUNTER21| CSR_HPMCOUNTER22| CSR_HPMCOUNTER23|
      CSR_HPMCOUNTER24| CSR_HPMCOUNTER25| CSR_HPMCOUNTER26| CSR_HPMCOUNTER27|
      CSR_HPMCOUNTER28| CSR_HPMCOUNTER29| CSR_HPMCOUNTER30| CSR_HPMCOUNTER31 =>
                csr_rdata_int <= mhpmcounter_ff(to_integer(unsigned(ex_csr_addr_i(4 downto 0))))(31 downto 0);

            when CSR_MCYCLEH|
      CSR_MINSTRETH|
      CSR_MHPMCOUNTER3H|
      CSR_MHPMCOUNTER4H|  CSR_MHPMCOUNTER5H|  CSR_MHPMCOUNTER6H|  CSR_MHPMCOUNTER7H|
      CSR_MHPMCOUNTER8H|  CSR_MHPMCOUNTER9H|  CSR_MHPMCOUNTER10H| CSR_MHPMCOUNTER11H|
      CSR_MHPMCOUNTER12H| CSR_MHPMCOUNTER13H| CSR_MHPMCOUNTER14H| CSR_MHPMCOUNTER15H|
      CSR_MHPMCOUNTER16H| CSR_MHPMCOUNTER17H| CSR_MHPMCOUNTER18H| CSR_MHPMCOUNTER19H|
      CSR_MHPMCOUNTER20H| CSR_MHPMCOUNTER21H| CSR_MHPMCOUNTER22H| CSR_MHPMCOUNTER23H|
      CSR_MHPMCOUNTER24H| CSR_MHPMCOUNTER25H| CSR_MHPMCOUNTER26H| CSR_MHPMCOUNTER27H|
      CSR_MHPMCOUNTER28H| CSR_MHPMCOUNTER29H| CSR_MHPMCOUNTER30H| CSR_MHPMCOUNTER31H|
      CSR_CYCLEH|
      CSR_INSTRETH|
      CSR_HPMCOUNTER3H|
      CSR_HPMCOUNTER4H|  CSR_HPMCOUNTER5H|  CSR_HPMCOUNTER6H|  CSR_HPMCOUNTER7H|
      CSR_HPMCOUNTER8H|  CSR_HPMCOUNTER9H|  CSR_HPMCOUNTER10H| CSR_HPMCOUNTER11H|
      CSR_HPMCOUNTER12H| CSR_HPMCOUNTER13H| CSR_HPMCOUNTER14H| CSR_HPMCOUNTER15H|
      CSR_HPMCOUNTER16H| CSR_HPMCOUNTER17H| CSR_HPMCOUNTER18H| CSR_HPMCOUNTER19H|
      CSR_HPMCOUNTER20H| CSR_HPMCOUNTER21H| CSR_HPMCOUNTER22H| CSR_HPMCOUNTER23H|
      CSR_HPMCOUNTER24H| CSR_HPMCOUNTER25H| CSR_HPMCOUNTER26H| CSR_HPMCOUNTER27H|
      CSR_HPMCOUNTER28H| CSR_HPMCOUNTER29H| CSR_HPMCOUNTER30H| CSR_HPMCOUNTER31H =>
                if (MHPMCOUNTER_WIDTH = 64) then
                    csr_rdata_int <= mhpmcounter_ff(to_integer(unsigned(ex_csr_addr_i(4 downto 0))))(63 downto 32);
                else                    -- @suppress "Dead code"
                    csr_rdata_int <= (others => '0');
                end if;

            when CSR_MCOUNTINHIBIT =>
                csr_rdata_int <= not mcounteren_ff;

            when CSR_MCOUNTEREN =>
                csr_rdata_int <= mcounteren_ff;

            when CSR_MHPMEVENT3|
      CSR_MHPMEVENT4|  CSR_MHPMEVENT5|  CSR_MHPMEVENT6|  CSR_MHPMEVENT7|
      CSR_MHPMEVENT8|  CSR_MHPMEVENT9|  CSR_MHPMEVENT10| CSR_MHPMEVENT11|
      CSR_MHPMEVENT12| CSR_MHPMEVENT13| CSR_MHPMEVENT14| CSR_MHPMEVENT15|
      CSR_MHPMEVENT16| CSR_MHPMEVENT17| CSR_MHPMEVENT18| CSR_MHPMEVENT19|
      CSR_MHPMEVENT20| CSR_MHPMEVENT21| CSR_MHPMEVENT22| CSR_MHPMEVENT23|
      CSR_MHPMEVENT24| CSR_MHPMEVENT25| CSR_MHPMEVENT26| CSR_MHPMEVENT27|
      CSR_MHPMEVENT28| CSR_MHPMEVENT29| CSR_MHPMEVENT30| CSR_MHPMEVENT31 =>
                csr_rdata_int <= mhpmevent_ff(to_integer(unsigned(ex_csr_addr_i(4 downto 0))));

            --USER CSR 
            -- dublicated mhartid: unique hardware thread id (not official)
            when CSR_UHARTID =>
                csr_rdata_int <= hart_id_i;
            when others => csr_rdata_int <= (others => '0');
        end case;
    end process;                        -- write logic

    -----------------
    -- CSR Write
    -----------------
    process(ex_csr_addr_i, csr_cause_i, if_csr_mtvec_init_i, csr_restore_mret_i, csr_save_cause_i, csr_save_ex_i, csr_save_id_i, csr_save_if_i, csr_wdata_int, csr_we_int, exception_pc, mcause_ff, mepc_ff, mie_ff, mstatus_ff, mstatus_ff.mie, mstatus_ff.mpie, mtvec_addr_i(31 downto 8), mtvec_mode_ff, mtvec_ff, ex_pc_i, id_pc_i, if_pc_i, mscratch_ff)
    begin
        --        mscratch_nxt  <= mscratch_ff;
        mepc_nxt     <= mepc_ff;
        mstatus_nxt  <= mstatus_ff;
        mcause_nxt   <= mcause_ff;
        exception_pc <= id_pc_i;
        if if_csr_mtvec_init_i = '1' then
            mtvec_nxt <= mtvec_addr_i(31 downto 8);
        else
            mtvec_nxt <= mtvec_ff;
        end if;

        mie_nxt        <= mie_ff;
        mtvec_mode_nxt <= mtvec_mode_ff;
        mscratch_nxt   <= mscratch_ff;

        if (csr_we_int = '1') then
            case (ex_csr_addr_i) is
                -- mstatus: IE bit
                when CSR_MSTATUS =>
                    mstatus_nxt.uie  <= csr_wdata_int(MSTATUS_UIE_BIT);
                    mstatus_nxt.mie  <= csr_wdata_int(MSTATUS_MIE_BIT);
                    mstatus_nxt.upie <= csr_wdata_int(MSTATUS_UPIE_BIT);
                    mstatus_nxt.mpie <= csr_wdata_int(MSTATUS_MPIE_BIT);
                    mstatus_nxt.mprv <= csr_wdata_int(MSTATUS_MPRV_BIT);
                -- mie: machine interrupt enable
                when CSR_MIE =>
                    mie_nxt <= csr_wdata_int and IRQ_MASK;
                -- mtvec: machine trap-handler base address
                when CSR_MTVEC =>
                    mtvec_nxt      <= csr_wdata_int(31 downto 8);
                    mtvec_mode_nxt <= "0" & csr_wdata_int(0); -- Only direct and vectored mode are supported

                -- mscratch: machine scratch
                when CSR_MSCRATCH =>
                    mscratch_nxt <= csr_wdata_int;

                -- mepc: exception program counter
                when CSR_MEPC =>
                    mepc_nxt <= csr_wdata_int and not x"00000001"; -- force 16-bit alignment

                -- mcause
                when CSR_MCAUSE =>
                    mcause_nxt <= csr_wdata_int(31) & csr_wdata_int(4 downto 0);

                when others =>
            end case;
        end if;                         -- csr_we_int

        -- exception controller gets priority over other writes
        if (csr_save_cause_i = '1') then
            if (csr_save_if_i = '1') then
                exception_pc <= if_pc_i;
            elsif (csr_save_id_i = '1') then
                exception_pc <= id_pc_i;
            elsif (csr_save_ex_i = '1') then
                exception_pc <= ex_pc_i;
            else
                exception_pc <= (others => '0');
            end if;
            mstatus_nxt.mpie <= mstatus_ff.mie;
            mstatus_nxt.mie  <= '0';
            mepc_nxt         <= exception_pc;
            mcause_nxt       <= csr_cause_i;
        elsif (csr_restore_mret_i = '1') then --MRET
            mstatus_nxt.mie  <= mstatus_ff.mpie;
            mstatus_nxt.mpie <= '1';
        end if;
    end process;

    -- CSR operation logic
    process(ex_csr_op_i, csr_rdata_int, ex_csr_wdata_i)
    begin
        csr_wdata_int <= ex_csr_wdata_i;
        csr_we_int    <= '1';

        case (ex_csr_op_i) is
            when CSR_OP_WRITE => csr_wdata_int <= ex_csr_wdata_i;
            when CSR_OP_SET   => csr_wdata_int <= ex_csr_wdata_i or csr_rdata_int;
            when CSR_OP_CLEAR => csr_wdata_int <= (not ex_csr_wdata_i) and csr_rdata_int;

            when CSR_OP_READ =>
                csr_wdata_int <= ex_csr_wdata_i;
                csr_we_int    <= '0';
            when others => csr_wdata_int <= ex_csr_wdata_i;
        end case;
    end process;

    ex_csr_rdata_o <= csr_rdata_int;

    -- directly output some registers
    m_irq_enable_o <= mstatus_ff.mie;
    if_mtvec_o     <= mtvec_ff;
    mtvec_mode_o   <= mtvec_mode_ff;
    if_mepc_o      <= mepc_ff;

    -- actual registers
    process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            mstatus_ff.uie  <= '0';
            mstatus_ff.mie  <= '0';
            mstatus_ff.upie <= '0';
            mstatus_ff.mpie <= '0';
            mstatus_ff.mprv <= '0';
            mepc_ff         <= (others => '0');
            mcause_ff       <= (others => '0');
            mie_ff          <= (others => '0');
            mtvec_ff        <= (others => '0');
            mtvec_mode_ff   <= "01";
            mscratch_ff     <= (others => '0');
        elsif rising_edge(clk_i) then
            -- update CSRs
            mstatus_ff.uie  <= '0';
            mstatus_ff.mie  <= mstatus_nxt.mie;
            mstatus_ff.upie <= '0';
            mstatus_ff.mpie <= mstatus_nxt.mpie;
            mstatus_ff.mprv <= '0';
            mepc_ff         <= mepc_nxt;
            mcause_ff       <= mcause_nxt;
            mie_ff          <= mie_nxt;
            mtvec_ff        <= mtvec_nxt;
            mtvec_mode_ff   <= mtvec_mode_nxt;
            mscratch_ff     <= mscratch_nxt;
        end if;
    end process;

    ----------------------------------------------------------------
    -- Counters:
    -- ------------------------
    -- read / write (reset) counter data with:
    -- ---
    -- fix counters:
    -- 0.: data_low @ CSR_MCYCLE + 0 | x"B00", data_high @ CSR_MCYCLEH + 0 | x"B80"
    -- 1.: data_low @ CSR_MCYCLE + 1 | x"B01", data_high @ CSR_MCYCLEH + 1 | x"B81" -- FIXME unused?! -> equal to 2
    -- 2.: data_low @ CSR_MCYCLE + 2 | x"B02", data_high @ CSR_MCYCLEH + 2 | x"B82"
    -- programmierbare counter:
    -- 3.: data_low @ CSR_MCYCLE + 3 | x"B03", data_high @ CSR_MCYCLEH + 3 | x"B83"
    -- 4.: data_low @ CSR_MCYCLE + 4 | x"B04", data_high @ CSR_MCYCLEH + 4 | x"B84"
    -- ...
    -- 31.: data_low @ CSR_MCYCLE + 31 | x"B1F", data_high @ CSR_MCYCLEH + 31 | x"B9F"
    -- ------------------------
    -- Enable Counters (default: '0 & '2 enabled, '3-31 disabled)
    -- csr address: CSR_MCOUNTINHIBIT | x"320" (32-bit mask)                        -- DONE: rename to _en (merge)
    -- csr address: CSR_MCOUNTEREN    | x"306"
    -- ------------------------
    -- Counter Event selection (programming)
    -- 3.:  @ CSR_MHPMEVENT3  | x"323" 
    -- 31.: @ CSR_MHPMEVENT31 | x"33F" 
    -- event data [16-bit mask/immediate]: (any selected criteria of following will increment the counter)
    -- '0: each cycle
    -- '1: instruction
    -- '2: load hazard
    -- '3: jump reg hazard
    -- '4: instr, miss
    -- '5: nr. of loads
    -- '6: nr. of stores
    -- '7: nr. of jumps (unconditional)
    -- '8: nr. of branches (conditional)
    -- '9: nr. of branches taken
    -- '10: nr. of compressed instr.
    -- '11: unused
    -- '12: unused
    -- '13: unused
    -- '14: unused
    -- '15: unused
    -- ------------------------

    -- Events to count
    hpm_events(0)  <= '1';              -- cycle counter
    hpm_events(1)  <= '0';              -- unused
    hpm_events(2)  <= mhpmevent_minstret_i; -- instruction counter
    hpm_events(3)  <= mhpmevent_dmiss_i; -- wb not ready (no gnt / miss)
    hpm_events(4)  <= mhpmevent_imiss_i; -- cycles waiting for instruction fetches, excluding jumps and branches
    hpm_events(5)  <= mhpmevent_load_i; -- nr of loads
    hpm_events(6)  <= mhpmevent_store_i; -- nr of stores
    hpm_events(7)  <= mhpmevent_jump_i; -- nr of jumps (unconditional)
    hpm_events(8)  <= mhpmevent_branch_i; -- nr of branches (conditional)
    hpm_events(9)  <= mhpmevent_branch_taken_i; -- nr of taken branches (conditional)
    hpm_events(10) <= mhpmevent_compressed_i; -- compressed instruction counter
    hpm_events(11) <= mhpmevent_div_multicycle_i; -- cycles of multicycle instructions (DIV)
    hpm_events(12) <= mhpmevent_mul_stall_i; -- nr of multiply use hazards
    hpm_events(13) <= mhpmevent_ld_stall_i; -- nr of load use hazards
    hpm_events(14) <= mhpmevent_jr_stall_i; -- nr of jump register hazards
    hpm_events(15) <= mhpmevent_csr_instr_i; -- nr of csr instructions (access)
    -- ------------------------

    --    mcountinhibit_we <= '1' when csr_we_int = '1' and (csr_addr_i = CSR_MCOUNTINHIBIT) else '0';
    mcounteren_we <= '1' when csr_we_int = '1' and ((ex_csr_addr_i = CSR_MCOUNTEREN) or (ex_csr_addr_i = CSR_MCOUNTINHIBIT)) else '0';
    mhpmevent_we  <= '1' when csr_we_int = '1' and ((ex_csr_addr_i = CSR_MHPMEVENT3) or (ex_csr_addr_i = CSR_MHPMEVENT4) or (ex_csr_addr_i = CSR_MHPMEVENT5) or (ex_csr_addr_i = CSR_MHPMEVENT6) or (ex_csr_addr_i = CSR_MHPMEVENT7) or (ex_csr_addr_i = CSR_MHPMEVENT8) or (ex_csr_addr_i = CSR_MHPMEVENT9) or (ex_csr_addr_i = CSR_MHPMEVENT10) or (ex_csr_addr_i = CSR_MHPMEVENT11) or (ex_csr_addr_i = CSR_MHPMEVENT12) or (ex_csr_addr_i = CSR_MHPMEVENT13) or (ex_csr_addr_i = CSR_MHPMEVENT14) or (ex_csr_addr_i = CSR_MHPMEVENT15) or (ex_csr_addr_i = CSR_MHPMEVENT16) or (ex_csr_addr_i = CSR_MHPMEVENT17) or (ex_csr_addr_i = CSR_MHPMEVENT18) or (ex_csr_addr_i = CSR_MHPMEVENT19) or (ex_csr_addr_i = CSR_MHPMEVENT20) or (ex_csr_addr_i = CSR_MHPMEVENT21) or (ex_csr_addr_i = CSR_MHPMEVENT22) or (ex_csr_addr_i = CSR_MHPMEVENT23) or (ex_csr_addr_i = CSR_MHPMEVENT24) or (ex_csr_addr_i = CSR_MHPMEVENT25) or (ex_csr_addr_i = CSR_MHPMEVENT26) or (ex_csr_addr_i = CSR_MHPMEVENT27) or (ex_csr_addr_i = CSR_MHPMEVENT28) or (ex_csr_addr_i = CSR_MHPMEVENT29) or (ex_csr_addr_i = CSR_MHPMEVENT30) or (ex_csr_addr_i = CSR_MHPMEVENT31)) else
                     '0';

    -- Increment performance counters
    counter_increment_enable : process(mhpmcounter_ff, hpm_events, mcounteren_ff, mhpmevent_ff)
        variable event_active : std_ulogic;
    begin
        mhpmcounter_increment       <= (others => (others => '0'));
        mhpmcounter_write_increment <= (others => '0');

        for c in 0 to 31 loop
            -- implement counter number, set by generic configuration
            if c < IMPLEMENTED_COUNTERS_G or c < 3 then
                mhpmcounter_increment(c) <= std_ulogic_vector(unsigned(mhpmcounter_ff(c)) + 1);

                -- count enabled?
                if (c = 0) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c);
                elsif (c = 1) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(1);
                elsif (c = 2) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(2);
                elsif (c = 3) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(3);
                elsif (c = 4) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(4);
                elsif (c = 5) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(5);
                elsif (c = 6) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(6);
                elsif (c = 7) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(7);
                elsif (c = 8) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(8);
                elsif (c = 9) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(9);
                elsif (c = 10) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(10);
                elsif (c = 11) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(11);
                elsif (c = 12) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(12);
                elsif (c = 13) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(13);
                elsif (c = 14) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(14);
                elsif (c = 15) then
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and hpm_events(15);
                else
                    -- any event active of selected event types
                    event_active                   := or_reduce(hpm_events and mhpmevent_ff(c)(hpm_events'range));
                    mhpmcounter_write_increment(c) <= mcounteren_ff(c) and event_active;
                end if;
            end if;
        end loop;
    end process;

    -- CSR Write Controls Counters (enable, event type, data)
    counter_csr_control : process(csr_wdata_int, mhpmevent_ff, mhpmevent_we, ex_csr_addr_i, csr_we_int, mcounteren_ff, mcounteren_we)
    begin
        mhpmevent_nxt           <= mhpmevent_ff;
        mcounteren_nxt          <= mcounteren_ff;
        mhpmcounter_write_lower <= (others => '0');
        mhpmcounter_write_upper <= (others => '0');

        -- Counter Enable   / Inhibit?
        if (mcounteren_we = '1') then
            mcounteren_nxt <= csr_wdata_int;
            if (ex_csr_addr_i = CSR_MCOUNTINHIBIT) then
                mcounteren_nxt <= not csr_wdata_int;
            end if;
        end if;

        -- Counter Event
        if (mhpmevent_we = '1') then
            mhpmevent_nxt(to_integer(unsigned(ex_csr_addr_i(4 downto 0)))) <= csr_wdata_int;
        end if;

        -- Counter Data
        for c in 0 to 31 loop
            -- implement counter number, set by generic configuration
            if c < IMPLEMENTED_COUNTERS_G or c < 3 then
                if csr_we_int = '1' and (unsigned(ex_csr_addr_i) = (unsigned(CSR_MCYCLE) + c)) then
                    -- write low part
                    mhpmcounter_write_lower(c) <= '1';
                elsif (csr_we_int = '1' and (to_integer(unsigned(ex_csr_addr_i)) = (to_integer(unsigned(CSR_MCYCLEH)) + c)) and (MHPMCOUNTER_WIDTH = 64)) then
                    -- write high part
                    mhpmcounter_write_upper(c) <= '1';
                end if;
            end if;
        end loop;
    end process;

    mhpmcounter_nxt <= mhpmcounter_ff;
    gen_counter_registers : for c in 0 to 31 generate
        process(clk_i, rst_ni)
        begin
            if (c >= IMPLEMENTED_COUNTERS_G and c >= 3) then --: not implemented counters
                mcounteren_ff(c)                             <= '0';
                mhpmcounter_ff(c)                            <= (others => '0');
                mhpmevent_ff(c)                              <= (others => '0');
                mhpmevent_ff(c)(NUM_HPM_EVENTS - 1 downto 0) <= (others => '0');
            else                        -- : implemented counters
                if (rst_ni = '0') then
                    mhpmcounter_ff(c)  <= (others => '0');
                    mhpmevent_ff(c)    <= (others => '0');
                    mhpmevent_ff(c)(c) <= '1';
                    if (c = 0) then
                        mcounteren_ff(c) <= '1';
                    elsif (c = 1) then
                        mcounteren_ff(c) <= '0';
                    elsif (c = 2) then
                        mcounteren_ff(c) <= '1';
                    else
                        mcounteren_ff(c) <= '1'; -- default enable
                    end if;
                elsif rising_edge(clk_i) then
                    mcounteren_ff(c)                             <= mcounteren_nxt(c);
                    mhpmevent_ff(c)                              <= (others => '0');
                    mhpmevent_ff(c)(NUM_HPM_EVENTS - 1 downto 0) <= mhpmevent_nxt(c)(NUM_HPM_EVENTS - 1 downto 0);
                    mhpmcounter_ff(c)                            <= mhpmcounter_nxt(c);

                    -- counter value increment or write
                    if (mhpmcounter_write_lower(c) = '1') then
                        mhpmcounter_ff(c)(31 downto 0) <= csr_wdata_int;
                    elsif ((mhpmcounter_write_upper(c) = '1') and (MHPMCOUNTER_WIDTH = 64)) then
                        mhpmcounter_ff(c)(63 downto 32) <= csr_wdata_int;
                    elsif (mhpmcounter_write_increment(c) = '1') then -- @suppress "Dead code"
                        mhpmcounter_ff(c) <= mhpmcounter_increment(c);
                    end if;
                end if;
            end if;
        end process;
    end generate;

    -- coverage on
end architecture RTL;
