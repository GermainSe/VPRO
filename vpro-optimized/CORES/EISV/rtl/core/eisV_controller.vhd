--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
-- Description:    Main CPU controller of the processor                       --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_controller is
    port(
        clk_i                          : in  std_ulogic; -- Gated clock
        rst_ni                         : in  std_ulogic;
        fetch_enable_i                 : in  std_ulogic; -- Start the decoding (external processor input)
        -- to IF
        if_instr_req_o                 : out std_ulogic; -- Start fetching instructions
        pc_set_o                       : out std_ulogic; -- jump to address set by pc_mux
        pc_mux_o                       : out pc_mux_sel_t; -- Selector in the Fetch stage to select the rigth PC (normal, jump ...)
        exc_cause_o                    : out std_ulogic_vector(4 downto 0);
        -- from IF/ID pipeline
        id_instr_valid_i               : in  std_ulogic; -- instruction coming from IF/ID pipeline is valid
        -- to CSR
        csr_save_if_o                  : out std_ulogic;
        csr_save_id_o                  : out std_ulogic;
        csr_save_ex_o                  : out std_ulogic;
        csr_cause_o                    : out std_ulogic_vector(5 downto 0);
        csr_restore_mret_id_o          : out std_ulogic;
        csr_save_cause_o               : out std_ulogic;
        -- decoder related signals
        id_deassert_we_o               : out std_ulogic; -- deassert write enable for next instruction
        id_instruction_type_i          : in  instr_type_t;
        id_ctrl_transfer_insn_in_dec_i : in  branch_t;
        -- jump/branch signals
        ex_branch_taken_i              : in  std_ulogic; -- branch taken signal from EX ALU
        -- Interrupt Controller Signals
        irq_req_ctrl_i                 : in  std_ulogic; -- interrupt was triggered
        irq_id_ctrl_i                  : in  std_ulogic_vector(4 downto 0); -- which interrupt was triggered
        irq_wu_ctrl_i                  : in  std_ulogic; -- interrupt wake up
        irq_ack_o                      : out std_ulogic;
        irq_id_o                       : out std_ulogic_vector(4 downto 0);
        -- Hazard detecting singals
        id_jt_hazard_i                 : in  std_ulogic;
        id_load_hazard_i               : in  std_ulogic;
        id_mul_hazard_i                : in  std_ulogic;
        -- Stall signals
        id_jr_stall_o                  : out std_ulogic; -- force next input to be the same (decoded instr)  -- forces this instruction to be kept in id (not using new from IF)
        id_ld_stall_o                  : out std_ulogic;
        id_mul_stall_o                 : out std_ulogic;
        -- Wakeup Signal
        wake_from_sleep_o              : out std_ulogic;
        id_control_ready_ff_o          : out std_ulogic; -- ID stage is ready to decode another instruction
        ex_valid_i                     : in  std_ulogic; -- EX stage is done
        ex_ready_i                     : in  std_ulogic; -- EX stage is rdy (e.g. for calc of JALR addr)
        -- Performance Counters
        id_is_decoding_o               : out std_ulogic
    );
end entity eisV_controller;

architecture RTL of eisV_controller is

    -- FSM state encoding
    signal ctrl_fsm_ff, ctrl_fsm_nxt : ctrl_state_t;

    signal id_control_ready_nxt : std_ulogic;

    type nop_insertion_cause_t is (UNKNOWN, ILLEGAL_INSTR, FENCEI, MRET, ECALL, WFI, CSR_STATUS);
    signal nop_insertion_cause_ff, nop_insertion_cause_nxt : nop_insertion_cause_t;

    signal id_jalr_jump_nxt, id_jalr_jump_ff                               : std_ulogic;
    signal delay_jalr_in_ex_nxt, delay_jalr_in_ex_ff, delay_jalr_in_ex_ff2 : std_ulogic;

begin
    --------------------------------------------------------------------------------------------
    --  Core Controller
    --------------------------------------------------------------------------------------------

    UPDATE_REGS : process(clk_i, rst_ni)
    begin
        if (rst_ni = '0') then
            ctrl_fsm_ff            <= RESET;
            id_control_ready_ff_o  <= '0';
            nop_insertion_cause_ff <= UNKNOWN;
            id_jalr_jump_ff        <= '0';
            delay_jalr_in_ex_ff    <= '0';
            delay_jalr_in_ex_ff2   <= '0';
        elsif rising_edge(clk_i) then
            ctrl_fsm_ff            <= ctrl_fsm_nxt;
            id_control_ready_ff_o  <= id_control_ready_nxt;
            nop_insertion_cause_ff <= nop_insertion_cause_nxt;
            id_jalr_jump_ff        <= id_jalr_jump_nxt;
            delay_jalr_in_ex_ff    <= delay_jalr_in_ex_nxt;
            delay_jalr_in_ex_ff2   <= delay_jalr_in_ex_ff;
        end if;
    end process;

    process(ctrl_fsm_ff, ex_branch_taken_i, ex_valid_i, fetch_enable_i, id_ctrl_transfer_insn_in_dec_i, id_instr_valid_i, id_jt_hazard_i, id_load_hazard_i, irq_id_ctrl_i, irq_req_ctrl_i, irq_wu_ctrl_i, nop_insertion_cause_ff, id_instruction_type_i, id_jalr_jump_ff, id_mul_hazard_i, delay_jalr_in_ex_ff, ex_ready_i, delay_jalr_in_ex_ff2)
    begin
        -- Default values
        ctrl_fsm_nxt         <= ctrl_fsm_ff;
        id_control_ready_nxt <= '1';    -- no stall in next cycle (IF will continue)?

        nop_insertion_cause_nxt <= nop_insertion_cause_ff;

        id_is_decoding_o <= '0';

        csr_save_if_o         <= '0';   -- unused for now
        csr_save_id_o         <= '0';
        csr_save_ex_o         <= '0';   -- unused for now
        csr_restore_mret_id_o <= '0';
        csr_save_cause_o      <= '0';
        csr_cause_o           <= (others => '0');

        if_instr_req_o <= '1';
        id_jr_stall_o  <= '0';
        id_ld_stall_o  <= '0';
        id_mul_stall_o <= '0';

        pc_mux_o    <= PC_BOOT;
        pc_set_o    <= '0';
        exc_cause_o <= (others => '0');

        irq_ack_o <= '0';
        irq_id_o  <= "00000";

        id_deassert_we_o     <= '1';
        id_jalr_jump_nxt     <= '0';
        delay_jalr_in_ex_nxt <= delay_jalr_in_ex_ff;

        case (ctrl_fsm_ff) is
            when RESET =>               -- We were just reset, wait for fetch_enable
                if_instr_req_o       <= '0';
                id_control_ready_nxt <= '0';
                if (fetch_enable_i = '1') then
                    ctrl_fsm_nxt <= BOOT_SET; -- copy boot address to instr fetch address
                end if;

            when BOOT_SET =>
                if_instr_req_o       <= '1';
                pc_mux_o             <= PC_BOOT;
                pc_set_o             <= '1';
                ctrl_fsm_nxt         <= DECODE;
                id_control_ready_nxt <= '1';

            -- coverage off
            when SLEEP =>               -- we begin execution when an interrupt has arrived                
                if_instr_req_o       <= '0';
                id_control_ready_nxt <= '0'; -- instruction in if_stage should be already valid but is not used yet
                if (irq_wu_ctrl_i = '1') then -- interrupt wake up signal
                    ctrl_fsm_nxt         <= DECODE;
                    id_control_ready_nxt <= '1';
                end if;
            -- coverage on

            when DECODE =>
                if (ex_branch_taken_i = '1' and ex_valid_i = '1') then -- there is a branch in the EX stage that is taken                    
                    pc_mux_o             <= PC_BRANCH;
                    pc_set_o             <= '1';
                    id_control_ready_nxt <= '1'; -- will stay in decode and wait for branch'd nxt instruction
                elsif                   --
                    -- coverage off
                    not JALR_TARGET_ADDER_IN_ID and (id_jalr_jump_ff = '1') then -- @suppress "Dead code"
                    pc_mux_o             <= PC_BRANCH; -- even if this is a jump, the address comes from ex stage (like the branch address)
                    pc_set_o             <= '1';
                    id_control_ready_nxt <= '1'; -- will stay in decode and wait for branch'd nxt instruction
                --                    id_deassert_we_o     <= '0';
                -- coverage on

                elsif (id_instr_valid_i = '1') then -- valid instruction from IF
                    id_is_decoding_o <= '1';
                    -- coverage off
                    if (irq_req_ctrl_i = '1') then -- Taken IRQ
                        id_control_ready_nxt <= '1';
                        pc_set_o             <= '1';
                        pc_mux_o             <= PC_IRQ;
                        exc_cause_o          <= irq_id_ctrl_i;

                        -- IRQ interface
                        irq_ack_o <= '1';
                        irq_id_o  <= irq_id_ctrl_i;

                        csr_save_cause_o <= '1';
                        csr_cause_o      <= "1" & irq_id_ctrl_i;
                        csr_save_id_o    <= '1';
                        id_deassert_we_o <= '0';
                    -- coverage on
                    --
                    -- TODO: handle other exception possibilities?
                    --
                    -- else if exception -> csr_save_if_o
                    -- else ex exception -> csr_save_ex_o
                    else                -- no irq
                        case (id_instruction_type_i) is
                            -- coverage off
                            when WFI =>
                                id_control_ready_nxt    <= '0';
                                nop_insertion_cause_nxt <= WFI;
                                ctrl_fsm_nxt            <= NOP_INSERT_FIRST;

                            when ILLEGAL =>
                                -- invalid instruction decoded but signalled as "valid" by IF
                                id_control_ready_nxt    <= '0';
                                nop_insertion_cause_nxt <= ILLEGAL_INSTR;
                                ctrl_fsm_nxt            <= NOP_INSERT_FIRST;
                                csr_save_id_o           <= '1';
                                csr_save_cause_o        <= '1';
                                csr_cause_o             <= "0" & EXC_CAUSE_ILLEGAL_INSN;
                                id_deassert_we_o        <= '0';
                            -- else -> no illegal instruction, no irq, valid

                            when ECALL =>
                                id_control_ready_nxt    <= '0';
                                nop_insertion_cause_nxt <= ECALL;
                                ctrl_fsm_nxt            <= NOP_INSERT_FIRST;
                                csr_save_id_o           <= '1';
                                csr_save_cause_o        <= '1';
                                csr_cause_o             <= "0" & EXC_CAUSE_ECALL_MMODE;
                                id_deassert_we_o        <= '0';
                            -- coverage on

                            when FENCEI =>
                                id_control_ready_nxt    <= '0';
                                nop_insertion_cause_nxt <= FENCEI;
                                ctrl_fsm_nxt            <= NOP_INSERT_FIRST;

                            when MRET =>
                                id_control_ready_nxt    <= '0';
                                nop_insertion_cause_nxt <= MRET;
                                ctrl_fsm_nxt            <= NOP_INSERT_FIRST;

                            when BRANCH =>
                                -- unconditional jumps
                                -- jump directly since we know the address already (ID read from RF)
                                -- if there is a jr stall, wait for it to be gone
                                -----------------------------------------------------------------------------------------
                                -- Jump Return Hazard
                                -----------------------------------------------------------------------------------------
                                if (id_ctrl_transfer_insn_in_dec_i = BRANCH_JALR) and (id_jt_hazard_i = '1') then
                                    id_jr_stall_o        <= '1';
                                    id_control_ready_nxt <= '0';
                                else
                                    id_control_ready_nxt <= '1';
                                    if (id_ctrl_transfer_insn_in_dec_i = BRANCH_JALR) and (id_jalr_jump_ff = '0') then
                                        -- coverage off
                                        if JALR_TARGET_ADDER_IN_ID then
                                            pc_mux_o <= PC_JUMP; -- @suppress "Dead code"
                                            pc_set_o <= '1';
                                        else -- @suppress "Dead code"
                                            -- coverage on
                                            if ex_ready_i = '1' and delay_jalr_in_ex_ff = '0' then
                                                pc_mux_o         <= PC_JUMP; -- still needed to save addr
                                                id_jalr_jump_nxt <= '1';
                                            else
                                                -- delay jalr instr one cycle to be executed when ex becomes rdy
                                                delay_jalr_in_ex_nxt <= not ex_ready_i;
                                                id_control_ready_nxt <= '0';
                                            end if;
                                        end if;
                                    else
                                        pc_mux_o <= PC_JUMP; -- @suppress "Dead code"
                                        pc_set_o <= '1';
                                    end if;

                                    id_deassert_we_o <= '0';
                                end if;

                            when LOAD => -- TODO: merge with NORMAL
                                id_control_ready_nxt <= '1';
                                id_deassert_we_o     <= '0';
                                if (id_load_hazard_i = '1') then
                                    -----------------------------------------------------------------------------------------
                                    -- Load Hazard
                                    -----------------------------------------------------------------------------------------
                                    id_ld_stall_o        <= '1';
                                    id_control_ready_nxt <= '0';
                                    id_deassert_we_o     <= '1';
                                end if;

                            when CSR =>
                                if (id_load_hazard_i = '0' and id_mul_hazard_i = '0') then
		                                id_control_ready_nxt    <= '0';
		                                nop_insertion_cause_nxt <= CSR_STATUS;
		                                ctrl_fsm_nxt            <= NOP_INSERT_FIRST;
		                                id_deassert_we_o        <= '0';
		                        end if;
		                
                                if (id_load_hazard_i = '1') then
                                    -----------------------------------------------------------------------------------------
                                    -- Load Hazard
                                    -----------------------------------------------------------------------------------------
                                    id_ld_stall_o        <= '1';
                                    id_control_ready_nxt <= '0';
                                    id_deassert_we_o     <= '1';
                                end if;
                                if (id_mul_hazard_i = '1') then
                                    id_mul_stall_o       <= '1';
                                    id_control_ready_nxt <= '0';
                                    id_deassert_we_o     <= '1';
                                end if;

                            when NORMAL =>
                                -- valid decoded regualr instruction
                                -- no hazard 
                                id_control_ready_nxt <= '1';
                                id_deassert_we_o     <= '0';
                                if (id_load_hazard_i = '1') then
                                    -----------------------------------------------------------------------------------------
                                    -- Load Hazard
                                    -----------------------------------------------------------------------------------------
                                    id_ld_stall_o        <= '1';
                                    id_control_ready_nxt <= '0';
                                    id_deassert_we_o     <= '1';
                                end if;
                                if (id_mul_hazard_i = '1') then
                                    id_mul_stall_o       <= '1';
                                    id_control_ready_nxt <= '0';
                                    id_deassert_we_o     <= '1';
                                end if;
                        end case;
                    end if;             -- irq?
                else                    -- valid instr in?
                end if;

            -- flush the pipeline, insert NOP into EX stage
            when NOP_INSERT_FIRST =>
                id_control_ready_nxt <= '0';
                -- coverage off
                if (ex_valid_i = '1') then
                    --check done to prevent data harzard in the CSR registers
                    ctrl_fsm_nxt <= NOP_INSERT_SECOND;

                    --                    if (nop_insertion_cause_ff = ILLEGAL_INSTR) then
                    --                        csr_save_id_o    <= '1';
                    --                        csr_save_cause_o <= '1';
                    --                        csr_cause_o      <= "0" & EXC_CAUSE_ILLEGAL_INSN;
                    --                    end if;
                end if;
            -- coverage on

            -- flush the pipeline, insert NOP into EX and WB stage
            when NOP_INSERT_SECOND =>
                -- ex will be valid - only path to this state goes through NOP_INSERT_FIRST (which checks ex, not inserting any new instr. there) 
                id_control_ready_nxt <= '1';
                ctrl_fsm_nxt         <= DECODE;

                case nop_insertion_cause_ff is
                    -- coverage off
                    when ILLEGAL_INSTR =>
                        pc_mux_o                <= PC_EXCEPTION;
                        pc_set_o                <= '1';
                        nop_insertion_cause_nxt <= UNKNOWN;

                    when ECALL =>
                        nop_insertion_cause_nxt <= UNKNOWN;
                        pc_mux_o                <= PC_EXCEPTION;
                        pc_set_o                <= '1';
                    -- coverage on

                    when MRET =>
                        csr_restore_mret_id_o   <= '1';
                        nop_insertion_cause_nxt <= UNKNOWN;
                        pc_mux_o                <= PC_MRET;
                        pc_set_o                <= '1';

                    -- coverage off
                    when WFI =>
                        id_control_ready_nxt <= '0';
                        ctrl_fsm_nxt         <= SLEEP;
                    -- coverage on

                    when FENCEI =>
                        -- we just jump to instruction after the fence.i since that forces the instruction buffer to refetch
                        nop_insertion_cause_nxt <= UNKNOWN;
                        pc_mux_o                <= PC_FENCEI;
                        pc_set_o                <= '1';

                    when CSR_STATUS =>
                        nop_insertion_cause_nxt <= UNKNOWN;

                    -- coverage off
                    when UNKNOWN =>
                        report "[Error] ID-Controller Flushing Pipeline with NOPs but reason is unknown/invalid!" severity error;
                        -- coverage on
                end case;
        end case;
    end process;

    -- wakeup from sleep conditions
    wake_from_sleep_o <= irq_wu_ctrl_i;

end architecture RTL;
