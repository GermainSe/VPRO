--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;

library core_v2pro;
use core_v2pro.v2pro_package.vpro_command_t;
use core_v2pro.v2pro_package.dma_command_t;

package eisV_pkg_units is

    component eisV_wb_stage is
        port(
            clk_i            : in  std_logic;
            rst_ni           : in  std_logic;
            -- stall signales
            wb_ready_o       : out std_ulogic; -- to MEM
            -- pipeline signals
            wb_pipeline_i    : in  wb_pipeline_t; -- input from MEM/WB pipeline register
            -- forward signals (or result)
            wb_fwd_data_o    : out fwd_t;
            -- Data memory signals (extern memory)
            wb_data_rdata_i  : in  std_ulogic_vector(31 downto 0);
            wb_data_rvalid_i : in  std_ulogic
        );
    end component eisV_wb_stage;

    component eisV_mem_stage is
        port(
            clk_i            : in  std_logic;
            rst_ni           : in  std_logic;
            -- stall signales
            mem_ready_o      : out std_ulogic; -- to EX
            --            mem_valid_o      : out std_ulogic; -- to WB
            wb_ready_i       : in  std_ulogic; -- from WB
            -- pipeline signals
            mem_pipeline_i   : in  mem_pipeline_t; -- input from EX/MEM pipeline register
            wb_pipeline_o    : out wb_pipeline_t; -- output from MEM/WB pipeline register
            -- forward signals
            mem_fwd_data_o   : out fwd_bundle_t(MEM_DELAY - 1 downto 0); -- relevant forward signals from each MEM stage
            -- status
            mem_busy_o       : out std_ulogic;
            -- Data memory signals (extern memory)
            mem_data_req_o   : out std_ulogic;
            mem_data_gnt_i   : in  std_ulogic;
            mem_data_addr_o  : out std_ulogic_vector(31 downto 0);
            mem_data_we_o    : out std_ulogic;
            mem_data_be_o    : out std_ulogic_vector(3 downto 0);
            mem_data_wdata_o : out std_ulogic_vector(31 downto 0)
        );
    end component eisV_mem_stage;

    component eisV_mult is
        port(
            clk_i                : in  std_ulogic;
            rst_ni               : in  std_ulogic;
            ex_enable_i          : in  std_ulogic;
            ex_operator_i        : in  mult_operator_t;
            ex_signed_i          : in  std_ulogic_vector(1 downto 0);
            ex_op_a_i            : in  std_ulogic_vector(31 downto 0);
            ex_op_b_i            : in  std_ulogic_vector(31 downto 0);
            mem_result_o         : out std_ulogic_vector(31 downto 0);
            ex_mult_multicycle_o : out std_ulogic;
            ex_mult_ready_o      : out std_ulogic;
            mem_ready_i          : in  std_ulogic
        );
    end component eisV_mult;

    component eisV_alu is
        port(
            clk_i                  : in  std_ulogic;
            rst_ni                 : in  std_ulogic;
            ex_enable_i            : in  std_ulogic;
            ex_operator_i          : in  alu_op_t; --std_ulogic_vector(ALU_OP_WIDTH - 1 downto 0);
            ex_operand_a_i         : in  std_ulogic_vector(31 downto 0);
            ex_operand_b_i         : in  std_ulogic_vector(31 downto 0);
            ex_result_o            : out std_ulogic_vector(31 downto 0);
            ex_comparison_result_o : out std_ulogic;
            ex_alu_multicycle_o    : out std_ulogic;
            ex_alu_ready_o         : out std_ulogic;
            mem_ready_i            : in  std_ulogic
        );
    end component eisV_alu;

    component eisV_if_stage is
        port(
            clk_i                         : in  std_ulogic;
            rst_ni                        : in  std_ulogic;
            -- instruction bus
            if_instr_req_o                : out std_ulogic; -- external instruction bus
            if_instr_addr_o               : out std_ulogic_vector(31 downto 0); -- external instruction bus
            if_instr_gnt_i                : in  std_ulogic; -- external instruction bus
            id_instr_rvalid_i             : in  std_ulogic; -- external instruction bus
            id_instr_rdata_i              : in  std_ulogic_vector(31 downto 0); -- external instruction bus
            -- ID if request?
            if_req_i                      : in  std_ulogic; -- input to prefetch buffer
            -- the fetched instruction 
            id_aligned_instr_valid_o      : out std_ulogic;
            id_decompressed_instr_o       : out std_ulogic_vector(31 downto 0);
            id_is_compressed_instr_o      : out std_ulogic;
            id_illegal_compressed_instr_o : out std_ulogic;
            -- control signals, PC modifications
            id_pc_set_i                   : in  std_ulogic; -- set the program counter to a new value
            if_pc_mux_i                   : in  pc_mux_sel_t; -- sel for pc multiplexer
            if_mepc_i                     : in  std_ulogic_vector(31 downto 0); -- address used to restore PC when the interrupt/exception is served
            if_m_trap_base_addr_i         : in  std_ulogic_vector(23 downto 0); -- possible branch address, Trap Base address, machine mode
            if_boot_addr_i                : in  std_ulogic_vector(31 downto 0); -- possible branch address, Boot address
            if_m_exc_vec_pc_mux_i         : in  std_ulogic_vector(4 downto 0); -- selects ISR address for vectorized interrupt lines
            if_csr_mtvec_init_o           : out std_ulogic; -- tell CS regfile to init mtvec
            if_jump_target_id_i           : in  std_ulogic_vector(31 downto 0); -- jump target address
            if_jump_target_ex_i           : in  std_ulogic_vector(31 downto 0); -- branch target address
            id_pc_i                       : in  std_ulogic_vector(31 downto 0); -- address used used for fencei instructions -- @suppress "Unused port: id_pc_i is not used in eisv.eisV_if_stage(RTL)"
            -- current pcs
            id_pc_o                       : out std_ulogic_vector(31 downto 0);
            if_pc_o                       : out std_ulogic_vector(31 downto 0);
            -- pipeline stall
            if_ready_o                    : out std_ulogic;
            id_ready_i                    : in  std_ulogic;
            -- misc signals
            if_busy_o                     : out std_ulogic; -- is the IF stage busy fetching instructions?
            if_perf_imiss_o               : out std_ulogic -- Instruction Fetch Miss
        );
    end component eisV_if_stage;

    component eisV_id_stage is
        port(
            clk_i                            : in  std_ulogic;
            rst_ni                           : in  std_ulogic;
            -- Processor Enable
            fetch_enable_i                   : in  std_ulogic; -- Delayed version so that clock can remain gated until fetch enabled
            wake_from_sleep_o                : out std_ulogic;
            -- Interrupt signals
            irq_i                            : in  std_ulogic_vector(31 downto 0);
            mie_bypass_i                     : in  std_ulogic_vector(31 downto 0); -- MIE CSR (bypass)
            mip_o                            : out std_ulogic_vector(31 downto 0); -- MIP CSR
            m_irq_enable_i                   : in  std_ulogic;
            irq_ack_o                        : out std_ulogic;
            irq_id_o                         : out std_ulogic_vector(4 downto 0);
            exc_cause_o                      : out std_ulogic_vector(4 downto 0);
            -- Status
            ctrl_busy_o                      : out std_ulogic;
            id_is_decoding_o                 : out std_ulogic;
            -- IF Interface
            if_instr_req_o                   : out std_ulogic;
            id_instr_valid_i                 : in  std_ulogic;
            id_instr_i                       : in  std_ulogic_vector(31 downto 0);
            id_is_compressed_instr_i         : in  std_ulogic;
            id_illegal_compressed_instr_i    : in  std_ulogic;
            if_pc_i                          : in  std_ulogic_vector(31 downto 0); -- @suppress "Unused port: if_pc_i is not used in eisv.eisV_id_stage(RTL)"
            id_pc_i                          : in  std_ulogic_vector(31 downto 0);
            pc_set_o                         : out std_ulogic;
            pc_mux_o                         : out pc_mux_sel_t;
            id_jump_target_o                 : out std_ulogic_vector(31 downto 0); -- jump and branch targets
            ex_jump_target_o                 : out std_ulogic_vector(31 downto 0);
            -- WB Data to RF and used for FW
            wb_regfile_waddr_i               : in  std_ulogic_vector(4 downto 0);
            wb_regfile_we_i                  : in  std_ulogic;
            wb_regfile_wdata_i               : in  std_ulogic_vector(31 downto 0);
            -- Stalls
            id_ready_o                       : out std_ulogic; -- ID stage is ready for the next instruction
            ex_ready_i                       : in  std_ulogic; -- EX stage is ready for the next instruction
            ex_valid_i                       : in  std_ulogic; -- EX stage is done
            -- Forwared Control 
            ex_fwd_i                         : in  fwd_t;
            mem_fwd_i                        : in  fwd_bundle_t(MEM_DELAY - 1 downto 0);
            wb_fwd_i                         : in  fwd_t;
            wb_ready_i                       : in  std_ulogic;
            -- From the Pipeline ID/EX
            ex_pipeline_o                    : out ex_pipeline_t;
            ex_vpro_op_o                     : out vpro_op_t;
            -- from ALU
            ex_branch_decision_i             : in  std_ulogic;
            ex_multicycle_i                  : in  std_ulogic;
            ex_regfile_data_a_after_fwd_i    : in  std_ulogic_vector(31 downto 0);
            -- CSR ID/EX
            ex_csr_access_o                  : out std_ulogic;
            ex_csr_op_o                      : out std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0);
            csr_cause_o                      : out std_ulogic_vector(5 downto 0);
            csr_save_if_o                    : out std_ulogic; -- control signal to save pc
            csr_save_id_o                    : out std_ulogic;
            csr_save_ex_o                    : out std_ulogic;
            csr_restore_mret_id_o            : out std_ulogic; -- control signal to restore pc
            csr_save_cause_o                 : out std_ulogic;
            ex_pc_o                          : out std_ulogic_vector(31 downto 0);
            -- Performance Counters
            id_mhpmevent_minstret_ff_o       : out std_ulogic;
            id_mhpmevent_load_ff_o           : out std_ulogic;
            id_mhpmevent_store_ff_o          : out std_ulogic;
            id_mhpmevent_jump_ff_o           : out std_ulogic;
            id_mhpmevent_branch_o            : out std_ulogic;
            id_mhpmevent_branch_taken_ff_o   : out std_ulogic;
            id_mhpmevent_compressed_ff_o     : out std_ulogic;
            id_mhpmevent_jr_stall_ff_o       : out std_ulogic;
            id_mhpmevent_imiss_ff_o          : out std_ulogic;
            id_mhpmevent_ld_stall_ff_o       : out std_ulogic;
            id_mhpmevent_mul_stall_ff_o      : out std_ulogic;
            id_mhpmevent_dmiss_ff_o          : out std_ulogic;
            id_mhpmevent_csr_instr_ff_o      : out std_ulogic;
            id_mhpmevent_div_multicycle_ff_o : out std_ulogic;
            id_perf_imiss_i                  : in  std_ulogic;
            id_perf_dmiss_i                  : in  std_ulogic
        );
    end component eisV_id_stage;
    component eisV_ex_stage is
        port(
            clk_i                : in  std_ulogic;
            rst_ni               : in  std_ulogic;
            -- stall signales
            ex_ready_o           : out std_ulogic; -- to ID
            ex_valid_o           : out std_ulogic; -- to MEM
            mem_ready_i          : in  std_ulogic; -- from MEM
            -- pipeline signals
            ex_pipeline_i        : in  ex_pipeline_t; -- input from ID/EX pipeline register
            mem_pipeline_o       : out mem_pipeline_t; -- output from EX/MEM pipeline register
            -- forward signals
            ex_fwd_o             : out fwd_t;
            mem_fwd_i            : in  fwd_bundle_t(MEM_DELAY - 1 downto 0);
            wb_fwd_i             : in  fwd_t;
            -- special outputs
            ex_csr_wdata_o       : out std_ulogic_vector(31 downto 0);
            ex_csr_addr_o        : out std_ulogic_vector(11 downto 0);
            ex_branch_decision_o : out std_ulogic;
            ex_multicycle_o      : out std_ulogic; -- indicates still runnning div for counters/events
            -- post fwd mux (hazards resolved if data is used)
            ex_operand_a_o       : out std_ulogic_vector(31 downto 0);
            ex_operand_b_o       : out std_ulogic_vector(31 downto 0)
        );
    end component eisV_ex_stage;

    component eisV_register_file_ff is
        generic(
            ADDR_WIDTH : natural := 5;
            DATA_WIDTH : natural := 32
        );
        port(
            -- Clock and Reset
            clk_i        : in  std_ulogic;
            rst_ni       : in  std_ulogic;
            --Read port R1
            id_raddr_a_i : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            id_rdata_a_o : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            --Read port R2
            id_raddr_b_i : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            id_rdata_b_o : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            -- Write port W
            wb_waddr_i   : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            wb_wdata_i   : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            wb_we_i      : in  std_ulogic
        );
    end component eisV_register_file_ff;

    component eisV_decoder is
        port(
            -- singals running to/from controller
            id_deassert_we_i                  : in  std_ulogic; -- deassert we, we are stalled or not active
            id_instruction_type_o             : out instr_type_t;
            id_rega_used_o                    : out std_ulogic; -- rs1 is used by current instruction
            id_regb_used_o                    : out std_ulogic; -- rs2 is used by current instruction
            -- from IF/ID pipeline
            id_instr_rdata_i                  : in  std_ulogic_vector(31 downto 0); -- instruction read from instr memory/cache
            id_illegal_c_insn_i               : in  std_ulogic; -- compressed instruction decode failed
            -- ALU signals
            id_alu_en_o                       : out std_ulogic; -- ALU enable
            id_alu_operator_o                 : out alu_op_t; --std_ulogic_vector(ALU_OP_WIDTH - 1 downto 0); -- ALU operation selection
            id_alu_op_a_mux_sel_o             : out op_a_sel_t; -- operand a selection: reg value, PC, immediate or zero
            id_alu_op_b_mux_sel_o             : out op_b_sel_t; -- operand b selection: reg value or immediate
            id_imm_a_mux_sel_o                : out op_a_immediate_sel_t; -- immediate selection for operand a
            id_imm_b_mux_sel_o                : out op_b_immediate_sel_t; -- immediate selection for operand b
            -- MUL related control signals
            id_mult_operator_o                : out mult_operator_t; -- Multiplication operation selection
            id_mult_int_en_o                  : out std_ulogic; -- perform integer multiplication
            id_mult_signed_mode_o             : out std_ulogic_vector(1 downto 0); -- Multiplication in signed mode
            -- register file related signals
            id_regfile_mem_we_o               : out std_ulogic; -- write enable for regfile
            id_regfile_alu_we_o               : out std_ulogic; -- write enable for 2nd regfile port
            -- CSR manipulation
            id_csr_access_o                   : out std_ulogic; -- access to CSR
            id_csr_op_o                       : out std_ulogic_vector(CSR_OP_WIDTH - 1 downto 0); -- operation to perform on CSR
            -- LD/ST unit signals
            id_data_req_o                     : out std_ulogic; -- start transaction to data memory
            id_data_we_o                      : out lsu_op_t; -- data memory write enable
            id_data_type_o                    : out memory_data_type_t; --std_ulogic_vector(1 downto 0); -- data type on data memory: byte, half word or word
            id_data_sign_extension_o          : out std_ulogic; -- sign extension on read data from data memory / NaN boxing
            -- jump/branches
            id_ctrl_transfer_insn_in_dec_o    : out branch_t; -- control transfer instruction without deassert
            id_ctrl_transfer_insn_in_o        : out branch_t; -- control transfer instructio is decoded
            id_ctrl_transfer_target_mux_sel_o : out jump_target_mux_sel_t; -- jump target selection
            -- vpro custom extension
            id_vpro_op_o                      : out vpro_op_t
        );
    end component eisV_decoder;

    component eisV_controller is
        port(
            clk_i                          : in  std_ulogic;
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
    end component eisV_controller;

    component eisV_interrupt_controller is
        port(
            clk_i          : in  std_ulogic;
            rst_ni         : in  std_ulogic;
            -- External interrupt lines
            irq_i          : in  std_ulogic_vector(31 downto 0); -- Level-triggered interrupt inputs
            -- To controller
            irq_req_ctrl_o : out std_ulogic;
            --            irq_sec_ctrl_o     : out std_ulogic;
            irq_id_ctrl_o  : out std_ulogic_vector(4 downto 0);
            irq_wu_ctrl_o  : out std_ulogic;
            -- To/from cs_registers
            mie_bypass_i   : in  std_ulogic_vector(31 downto 0); -- MIE CSR (bypass)
            mip_o          : out std_ulogic_vector(31 downto 0); -- MIP CSR
            m_ie_i         : in  std_ulogic -- Interrupt enable bit from CSR (M mode)
        );
    end component eisV_interrupt_controller;

    component eisV_pc_controller is
        port(
            clk_i                 : in  std_ulogic;
            rst_ni                : in  std_ulogic;
            if_req_i              : in  std_ulogic; -- id requests new instruction from IF
            -- halt control:
            if_fetcher_ready_i    : in  std_ulogic; -- fetcher could not be ready / halt fetch (pc not incrementing, no request)
            -- PC control:
            id_pc_set_i           : in  std_ulogic; -- set the program counter to a new value
            id_pc_mux_i           : in  pc_mux_sel_t; -- sel for pc multiplexer 
            id_mepc_i             : in  std_ulogic_vector(31 downto 0); -- address used to restore PC when the interrupt/exception is served
            id_pc_i               : in  std_ulogic_vector(31 downto 0); -- for fencei
            if_m_trap_base_addr_i : in  std_ulogic_vector(23 downto 0); -- possible branch address, Trap Base address, machine mode
            if_boot_addr_i        : in  std_ulogic_vector(31 downto 0); -- possible branch address, Boot address
            if_m_exc_vec_pc_mux_i : in  std_ulogic_vector(4 downto 0); -- selects ISR address for vectorized interrupt lines
            if_csr_mtvec_init_o   : out std_ulogic; -- tell CS regfile to init mtvec
            if_jump_target_id_i   : in  std_ulogic_vector(31 downto 0); -- jump target address
            if_jump_target_ex_i   : in  std_ulogic_vector(31 downto 0); -- branch target address
            -- from buffer (instr already buffered after halt?)
            id_buffer_halt_i      : in  std_ulogic;
            -- to bus fetcher
            if_fetch_req_o        : out std_ulogic;
            if_fetch_addr_o       : out std_ulogic_vector(31 downto 0)
        );
    end component eisV_pc_controller;

    component eisV_bus_fetcher is
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
            -- to align
            id_fetch_valid_o               : out std_ulogic;
            id_fetch_rdata_o               : out std_ulogic_vector(31 downto 0);
            -- status (miss/waiting)
            if_fetcher_miss_o              : out std_ulogic;
            id_fetch_addr_o                : out std_ulogic_vector(31 downto 0) -- last fetched addr
        );
    end component eisV_bus_fetcher;

    component eisV_instruction_buffer is
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
    end component eisV_instruction_buffer;

    component eisV_bus_registered_interface is
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
            -- BUS interface
            mem_bus_req_o     : out std_ulogic;
            mem_bus_gnt_i     : in  std_ulogic;
            mem_bus_addr_o    : out std_ulogic_vector(31 downto 0);
            mem_bus_we_o      : out std_ulogic;
            mem_bus_be_o      : out std_ulogic_vector(3 downto 0);
            mem_bus_wdata_o   : out std_ulogic_vector(31 downto 0);
            wb_bus_rdata_i    : in  std_ulogic_vector(31 downto 0);
            wb_bus_rvalid_i   : in  std_ulogic
        );
    end component eisV_bus_registered_interface;

    component eisV_aligner is
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
    end component eisV_aligner;

    component eisV_instruction_decompress is
        port(
            id_instr_i         : in  std_ulogic_vector(31 downto 0);
            id_instr_o         : out std_ulogic_vector(31 downto 0);
            id_is_compressed_o : out std_ulogic;
            id_illegal_instr_o : out std_ulogic
        );
    end component eisV_instruction_decompress;

    component eisV_cs_register is
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
    end component eisV_cs_register;

    component eisV_core is
        generic(
            NUM_MHPMCOUNTERS : natural := 1
        );
        port(
            clk_i             : in  std_ulogic;
            rst_ni            : in  std_ulogic;
            -- Core ID, Cluster ID, debug mode halt address and boot address are considered more or less static
            if_boot_addr_i    : in  std_ulogic_vector(31 downto 0);
            mtvec_addr_i      : in  std_ulogic_vector(31 downto 0);
            hart_id_i         : in  std_ulogic_vector(31 downto 0);
            -- Instruction memory interface
            if_instr_req_o    : out std_ulogic;
            if_instr_gnt_i    : in  std_ulogic;
            id_instr_rvalid_i : in  std_ulogic;
            if_instr_addr_o   : out std_ulogic_vector(31 downto 0);
            id_instr_rdata_i  : in  std_ulogic_vector(31 downto 0);
            -- Data memory interface
            mem_data_req_o    : out std_ulogic;
            mem_data_gnt_i    : in  std_ulogic;
            wb_data_rvalid_i  : in  std_ulogic;
            mem_data_we_o     : out std_ulogic;
            mem_data_be_o     : out std_ulogic_vector(3 downto 0);
            mem_data_addr_o   : out std_ulogic_vector(31 downto 0);
            mem_data_wdata_o  : out std_ulogic_vector(31 downto 0);
            wb_data_rdata_i   : in  std_ulogic_vector(31 downto 0);
            -- Interrupt s
            irq_i             : in  std_ulogic_vector(31 downto 0); -- CLINT interrupts + CLINT extension interrupts
            irq_ack_o         : out std_ulogic;
            irq_id_o          : out std_ulogic_vector(4 downto 0);
            -- CPU Control Signals
            fetch_enable_i    : in  std_ulogic;
            -- VPRO custom extension
            ex_vpro_bundle_o  : out vpro_bundle_t;
            ex_vpro_rdy_i     : in  std_ulogic
        );
    end component eisV_core;

    component eisV_alu_divide is
        port(
            clk_i                : in  std_ulogic;
            rst_ni               : in  std_ulogic; -- high-active, sync
            ex_clk_en_i          : in  std_ulogic; -- clock enable
            ex_op_div_i          : in  std_ulogic; -- True to initiate a signed divide
            ex_op_divu_i         : in  std_ulogic; -- True to initiate an unsigned divide
            ex_dividend_i        : in  std_ulogic_vector(31 downto 0);
            ex_divisor_is_zero_i : in  std_ulogic;
            ex_divisor_i         : in  std_ulogic_vector(31 downto 0);
            ex_quotient_o        : out std_ulogic_vector(31 downto 0);
            ex_remainder_o       : out std_ulogic_vector(31 downto 0);
            ex_stall_o           : out std_ulogic -- True while calculating
        );
    end component;

    component dcache_ram_wrapper is
        generic(
            ADDR_WIDTH : integer := 12;
            DATA_WIDTH : integer := 64
        );
        port(
            clk         : in  std_ulogic; -- Clock 
            areset_n    : in  std_ulogic;
            -- CPU Port
            cpu_rd_en   : in  std_ulogic; -- Memory Enable
            cpu_rd_addr : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- Address Input
            cpu_rdata   : out std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Data Output
            -- External Mem Port
            mem_rd_en   : in  std_ulogic; -- Memory Enable
            mem_rd_addr : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- Address Input
            mem_rdata   : out std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Data Output
            mem_wr_en   : in  std_ulogic_vector(DATA_WIDTH / 8 - 1 downto 0); -- Write Enable
            mem_wdata   : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Data Input  
            mem_wr_addr : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0) -- Address Input
        );
    end component dcache_ram_wrapper;

    component icache_ram_wrapper
        generic(
            ADDR_WIDTH                  : integer := 12;
            DATA_WIDTH                  : integer := 64;
            USE_DUAL_PORT               : boolean := false;
            SINGLE_PORT_PRIORITY_PORT_A : boolean := false
        );
        port(
            clk     : in  std_ulogic;
            wr_en_a : in  std_ulogic;
            rd_en_a : in  std_ulogic;
            wdata_a : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            addr_a  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            rdata_a : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            wr_en_b : in  std_ulogic;
            rd_en_b : in  std_ulogic;
            wdata_b : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            addr_b  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            rdata_b : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component icache_ram_wrapper;

    component i_cache is
        generic(
            LOG2_NUM_LINES       : natural := 3; -- log2 of number of cache lines
            LOG2_LINE_SIZE       : natural := 6; -- log2 of size of cache line (size in MEMORY_WORD_WIDTH-bit words)
            log2_associativity_g : natural := 2; -- 1 ~ 2-block, 2 ~ 4-block
            INSTR_WORD_COUNT     : natural := 16; -- number of output instruction words
            WORD_WIDTH           : natural := 32; -- width of one instruction word
            MEMORY_WORD_WIDTH    : natural := 512; -- width of one instruction word
            ADDR_WIDTH           : natural := 32 -- width of address
        );
        port(
            -- global control --
            clk_i           : in  std_ulogic; -- global clock line, rising-edge
            rst_i           : in  std_ulogic; -- global reset line, high-active, sync
            ce_i            : in  std_ulogic; -- global clock enable, high-active
            stall_i         : in  std_ulogic; -- freeze output if any stall
            clear_i         : in  std_ulogic; -- force reload of cache
            -- CPU instruction interface --
            cpu_oe_i        : in  std_ulogic; -- "IR" update enable
            cpu_instr_adr_i : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
            cpu_instr_req_i : in  std_ulogic; -- this is a valid read request
            cpu_stall_o     : out std_ulogic; -- stall CPU (miss)
            -- Quad instruction word --
            instr_o         : out std_ulogic_vector(WORD_WIDTH - 1 downto 0);
            -- memory system interface --
            mem_base_adr_o  : out std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
            mem_dat_i       : in  std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
            mem_req_o       : out std_ulogic; -- request data from memory
            mem_wait_i      : in  std_ulogic; -- memory command buffer full
            mem_ren_o       : out std_ulogic; -- read enable
            mem_rdy_i       : in  std_ulogic; -- applied data is valid
            -- access statistics --
            hit_o           : out std_ulogic; -- valid hit access
            miss_o          : out std_ulogic -- valid miss access
        );
    end component;

    component d_cache_multiword is
        generic(
            LOG2_NUM_LINES       : natural := 5; -- log2 of number of cache lines
            LOG2_LINE_SIZE       : natural := 6; -- log2 of size of cache line (size in 128-bit words)
            log2_associativity_g : natural := 1; -- 1 ~ 2-block, 2 ~ 4-block
            INSTR_WORD_COUNT     : natural := 8; -- number of output instruction words
            WORD_WIDTH           : natural := 32; -- width of one instruction word
            MEMORY_WORD_WIDTH    : natural := 128; -- width of one instruction word
            ADDR_WIDTH           : natural := 32 -- width of address
        );
        port(
            -- global control --
            clk_i                  : in  std_ulogic; -- global clock line, rising-edge
            rst_i                  : in  std_ulogic; -- global reset line, high-active, sync
            ce_i                   : in  std_ulogic; -- global clock enable, high-active
            stall_i                : in  std_ulogic; -- freeze output if any stall
            clear_i                : in  std_ulogic; -- force reload of cache
            flush_i                : in  std_ulogic; -- force flush of cache
            -- CPU instruction interface --
            cpu_oe_i               : in  std_ulogic; -- "IR" update enable
            cpu_req_i              : in  std_ulogic;
            cpu_adr_i              : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
            cpu_rden_i             : in  std_ulogic; -- this is a valid read request -- read enable
            cpu_wren_i             : in  std_ulogic_vector(03 downto 0); -- write enable
            cpu_stall_o            : out std_ulogic; -- stall CPU (miss)
            cpu_data_i             : in  std_ulogic_vector(WORD_WIDTH - 1 downto 0); -- write-data word
            -- Quad instruction word --
            data_o                 : out multi_cmd_t; -- multiple cmds starting at addr!
            -- 
            dcache_prefetch_i      : in  std_ulogic;
            dcache_prefetch_addr_i : in  std_ulogic_vector(31 downto 0);
            -- memory system interface --
            mem_base_adr_o         : out std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
            mem_dat_i              : in  std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
            mem_req_o              : out std_ulogic; -- request data from memory
            mem_wait_i             : in  std_ulogic; -- memory command buffer full
            mem_ren_o              : out std_ulogic; -- read enable
            mem_rdy_i              : in  std_ulogic; -- applied data is valid
            mem_dat_o              : out std_ulogic_vector(MEMORY_WORD_WIDTH - 1 downto 0);
            mem_wrdy_i             : in  std_ulogic; -- write fifo is ready
            mem_rw_o               : out std_ulogic; -- read/write a block from/to memory
            mem_wren_o             : out std_ulogic; -- FIFO write enable
            mem_wr_last_o          : out std_ulogic; -- last word of write-block
            mem_wr_done_i          : in  std_ulogic_vector(1 downto 0); -- '00' not done, '01' done, '10' data error, '11' req error
            mem_busy_o             : out std_ulogic; -- busy signal forces MUX (DCache/DMA -> AXI) to choose DCache
            -- access statistics --
            hit_o                  : out std_ulogic; -- valid hit access
            miss_o                 : out std_ulogic -- valid miss access
        );
    end component;

    component instruction_streamer is
        generic(
            LOG2_NUM_LINES : natural := 4; -- log2 of number of cache lines
            LOG2_LINE_SIZE : natural := 3 -- log2 of size of cache line (size in 32-bit words)
        );
        port(
            -- global control --
            clk_i           : in  std_ulogic; -- global clock line, rising-edge
            rst_i           : in  std_ulogic; -- global reset line, high-active, sync
            ce_i            : in  std_ulogic; -- global clock enable, high-active
            stall_i         : in  std_ulogic; -- freeze output if any stall
            clear_i         : in  std_ulogic; -- force reload of cache
            -- CPU instruction interface --
            cpu_oe_i        : in  std_ulogic; -- "IR" update enable
            cpu_instr_adr_i : in  std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
            cpu_instr_req_i : in  std_ulogic; -- this is a valid read request
            cpu_instr_dat_o : out std_ulogic_vector(31 downto 0); -- the instruction word
            cpu_stall_o     : out std_ulogic; -- stall CPU (miss)
            -- Vector CP instruction interface --
            vcp_instr_array : out multi_cmd_t; -- the instruction word
            -- memory system interface --
            mem_base_adr_o  : out std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
            mem_dat_i       : in  std_ulogic_vector(ic_cache_word_width_c - 1 downto 0);
            mem_req_o       : out std_ulogic; -- request data from memory
            mem_wait_i      : in  std_ulogic; -- memory command buffer full
            mem_ren_o       : out std_ulogic; -- read enable
            mem_rdy_i       : in  std_ulogic; -- applied data is valid
            -- access statistics --
            hit_o           : out std_ulogic; -- valid hit access
            miss_o          : out std_ulogic -- valid miss access
        );
    end component;

    component eisV_dma is
        port(
            -- global control --
            clk_i             : in  std_ulogic; -- global clock line, rising-edge
            rst_i             : in  std_ulogic; -- global reset line, high-active, sync
            ce_i              : in  std_ulogic; -- global clock enable, high-active
            stall_i           : in  std_ulogic; -- freeze output if any stall
            stall_o           : out std_ulogic; -- freeze output if any stall

            cpu_req_i         : in  std_ulogic; -- access to cached memory space
            cpu_adr_i         : in  std_ulogic_vector(31 downto 0);
            cpu_rden_i        : in  std_ulogic; -- read enable
            cpu_wren_i        : in  std_ulogic_vector(03 downto 0); -- write enable
            cpu_data_o        : out std_ulogic_vector(31 downto 0); -- read-data word
            cpu_data_i        : in  std_ulogic_vector(31 downto 0); -- write-data word

            -- memory system interface --
            mem_read_length_o : out std_ulogic_vector(19 downto 0); --length of that block in bytes
            mem_base_adr_o    : out std_ulogic_vector(31 downto 0); -- addressing words (only on boundaries!)
            mem_dat_i         : in  std_ulogic_vector(dc_cache_word_width_c - 1 downto 0);
            mem_dat_o         : out std_ulogic_vector(dc_cache_word_width_c - 1 downto 0);
            mem_req_o         : out std_ulogic; -- memory request
            mem_busy_i        : in  std_ulogic; -- memory command buffer full
            mem_wrdy_i        : in  std_ulogic; -- write fifo is ready
            mem_rw_o          : out std_ulogic; -- read/write a block from/to memory
            mem_rden_o        : out std_ulogic; -- FIFO read enable
            mem_wren_o        : out std_ulogic; -- FIFO write enable
            mem_wr_last_o     : out std_ulogic; -- last word of write-block
            mem_wr_done_i     : in  std_ulogic_vector(1 downto 0); -- '00' not done, '01' done, '10' data error, '11' req error
            mem_rrdy_i        : in  std_ulogic -- read data ready
        );
    end component;

    component eisV_data_distributor is
        generic(
            addr_width_g              : integer                        := 32;
            word_width_g              : integer                        := 32;
            dcache_area_begin_g       : std_ulogic_vector(31 downto 0) := x"00000000"; -- where does the dcache area start?
            dma_area_begin_g          : std_ulogic_vector(31 downto 0) := x"80000000"; -- where does the dma area start?
            io_area_begin_g           : std_ulogic_vector(31 downto 0) := x"C0000000"; -- where does the IO area start?
            FSM_SIZE                  : std_ulogic_vector(31 downto 0) := x"FFFFFE40"; -- DMA FSM
            FSM_START_ADDRESS_TRIGGER : std_ulogic_vector(31 downto 0) := x"FFFFFE44"; -- DMA FSM
            SINGLE_DMA_TRIGGER        : std_ulogic_vector(31 downto 0) := x"FFFFFE48" -- DMA FSM
        );
        port(
            -- global control --
            clk_i                        : in  std_ulogic; -- global clock line, rising-edge, CPU clock
            rst_i                        : in  std_ulogic; -- global reset line, high-active, sync

            -- EISV Data Access Interface --
            eisV_req_i                   : in  std_ulogic;
            eisV_gnt_o                   : out std_ulogic;
            eisV_rvalid_o                : out std_ulogic;
            eisV_we_i                    : in  std_ulogic;
            eisV_be_i                    : in  std_ulogic_vector(word_width_g / 8 - 1 downto 0);
            eisV_addr_i                  : in  std_ulogic_vector(addr_width_g - 1 downto 0);
            eisV_wdata_i                 : in  std_ulogic_vector(word_width_g - 1 downto 0);
            eisV_rdata_o                 : out std_ulogic_vector(word_width_g - 1 downto 0);
            -- DMA Interface --
            dma_req_o                    : out std_ulogic;
            dma_adr_o                    : out std_ulogic_vector(addr_width_g - 1 downto 0);
            dma_rden_o                   : out std_ulogic; -- read enable
            dma_wren_o                   : out std_ulogic_vector(word_width_g / 8 - 1 downto 0); -- write enable
            dma_rdata_i                  : in  std_ulogic_vector(word_width_g - 1 downto 0); -- read-data word
            dma_wdata_o                  : out std_ulogic_vector(word_width_g - 1 downto 0); -- write-data word
            dma_stall_i                  : in  std_ulogic; -- freeze output if any stall

            -- DMA FSM Interface --
            vpro_dma_fsm_busy_i          : in  std_ulogic;
            vpro_dma_fsm_stall_o         : out std_ulogic;
            vpro_dma_fsm_dcache_addr_i   : in  std_ulogic_vector(addr_width_g - 1 downto 0);
            vpro_dma_fsm_dcache_req_i    : in  std_ulogic;
            vpro_dma_fsm_dcache_rvalid_o : out std_ulogic;
            vpro_dma_fifo_full_i         : in  std_ulogic;
            -- DCache Interface --
            dcache_oe_o                  : out std_ulogic; -- "IR" update enable
            dcache_req_o                 : out std_ulogic;
            dcache_adr_o                 : out std_ulogic_vector(addr_width_g - 1 downto 0); -- addressing words (only on boundaries!)
            dcache_rden_o                : out std_ulogic; -- this is a valid read request -- read enable
            dcache_wren_o                : out std_ulogic_vector(word_width_g / 8 - 1 downto 0); -- write enable
            dcache_stall_i               : in  std_ulogic; -- stall CPU (miss)
            dcache_wdata_o               : out std_ulogic_vector(word_width_g - 1 downto 0); -- write-data word
            dcache_rdata_i               : in  std_ulogic_vector(word_width_g - 1 downto 0); -- read-data word

            -- IO Interface --
            io_rdata_i                   : in  std_ulogic_vector(word_width_g - 1 downto 0); -- data input
            io_ack_i                     : in  std_ulogic; -- ack transfer
            io_ren_o                     : out std_ulogic; -- read enable
            io_wen_o                     : out std_ulogic_vector(word_width_g / 8 - 1 downto 0); -- 4-bit write enable (for each byte)
            io_adr_o                     : out std_ulogic_vector(addr_width_g - 1 downto 0); -- data address, byte-indexed
            io_wdata_o                   : out std_ulogic_vector(word_width_g - 1 downto 0); -- data output

            -- MUX select signal for axi signals behind dcache/dma
            mux_sel_dma_o                : out std_ulogic -- '1' = dma, '0' = dcache
        );
    end component;

    component eisV_VPRO_ext_register_file is
        port(
            clk                   : in  std_ulogic;
            rst_n                 : in  std_ulogic;
            -- VPRO custom extension
            ex_vpro_bundle_i      : in  vpro_bundle_t;
            ex_ready_o            : out std_ulogic; -- depends on fifo state (if not ready, the current vpro_bundle_i needs to be kept as it is)
            -- VPRO current fifo states
            vpro_vpro_fifo_full_i : in  std_ulogic;
            -- generated VPRO Command (registered)
            mem_vpro_cmd_o        : out vpro_command_t;
            mem_vpro_we_o         : out std_ulogic
        );
    end component;

    component eisV_vpro_dma_fsm is
        generic(
            FSM_SIZE                  : std_ulogic_vector(31 downto 0) := x"FFFFFE40"; -- DMA FSM
            FSM_START_ADDRESS_TRIGGER : std_ulogic_vector(31 downto 0) := x"FFFFFE44"; -- DMA FSM
            SINGLE_DMA_TRIGGER        : std_ulogic_vector(31 downto 0) := x"FFFFFE48" -- DMA FSM
        );
        port(
            clk_i             : in  std_ulogic;
            rst_i             : in  std_ulogic;
            core_data_addr_i  : in  std_ulogic_vector(31 downto 0);
            core_data_req_i   : in  std_ulogic;
            core_data_we_i    : in  std_ulogic;
            core_data_be_i    : in  std_ulogic_vector(3 downto 0);
            core_data_wdata_i : in  std_ulogic_vector(31 downto 0);
            dcache_addr_o     : out std_ulogic_vector(31 downto 0);
            dcache_req_o      : out std_ulogic;
            dcache_instr_i    : in  multi_cmd_t;
            dcache_rvalid_i   : in  std_ulogic;
            dcache_stall_i    : in  std_ulogic;
            active_o          : out std_ulogic;
            vpro_fsm_stall_i  : in  std_ulogic;
            dma_cmd_full_i    : in  std_ulogic;
            dma_cmd_we_o      : out std_ulogic;
            dma_cmd_o         : out multi_cmd_t
        );
    end component;

    component dcache_line_replacer is
        generic(
            ASSOCIATIVITY_LOG2   : integer := 2;
            ADDR_WIDTH           : integer := 32; -- Address Width
            SET_ADDR_WIDTH       : integer;
            WORD_SEL_ADDR_WIDTH  : integer;
            WORD_OFFS_ADDR_WIDTH : integer
        );
        port(
            clk_i        : in  std_ulogic; -- Clock 
            areset_n_i   : in  std_ulogic;
            addr_i       : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- mem byte addr
            valid_i      : in  std_ulogic;
            cache_line_o : out std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0)
        );
    end component;

end package eisV_pkg_units;

package body eisV_pkg_units is

end package body eisV_pkg_units;
