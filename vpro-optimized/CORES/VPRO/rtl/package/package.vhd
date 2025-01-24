--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- # VPRO - Vector Processor System VHDL Package File                          #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library eisv;
use eisv.eisV_pkg.all;

library core_v2pro;
use core_v2pro.package_datawidths.all;

package v2pro_package is

    -- Configuration -----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- general hardware configuration --
    constant active_reset_c : std_ulogic := '0'; -- default: low-active

    constant rf_generate_write_traces_c : boolean := true; -- whether to generate c0u0l0rf.trace files in simulation dir with all write data traces

    -- specific hardware configuration --
    constant use_lut_cmd_fifo_c      : boolean := true; -- build CMD FIFO from BRAM or LUTs (distr. RAM)?
    constant num_idma_fifo_entries_c : natural := 64; -- number of entries/descriptors in iDMA queue
    constant num_idma_sync_ff_c      : natural := 2; -- number of CDC sync FFs -- 2

    -- the functionality of the lanes can be configured --
    constant instanciate_instruction_bit_reversal_c   : boolean := false; -- logic for bit reversal instructions
    constant instanciate_instruction_min_max_vector_c : boolean := false; -- logic for min max (value & index) vector instructions
    constant instanciate_instruction_load_shift_c     : boolean := false; -- logic (barrel shifter) for load instructions

    -- Vector unit CMD FIFO configuration (only for distributed RAM-based FIFO) --
    constant dram_cmd_fifo_num_entries_top_c : natural := 64; -- number of CMD entries, should be a power of 2. 
    constant dram_cmd_fifo_num_sync_ff_c     : natural := 2; -- number of CDC sync FFs
    constant dram_cmd_fifo_num_entries_c     : natural := 16; -- number of CMD entries, should be a power of 2. 

    -- Additional automatic configuration - no touchy! --
    constant dram_cmd_fifo_num_sfull_c : natural := 5; -- number of of remaining free entries when sfull signal is set

    -- DMA access counter
    constant instantiate_idma_access_counter_c : boolean := true; -- idma_access_counter in top of V2PRO

    --- 
    --   VPRO Instruction Word Layout
    ---
    constant vpro_cmd_offset_len_c : natural := 10;
    constant vpro_cmd_alpha_len_c  : natural := 6;
    constant vpro_cmd_beta_len_c   : natural := 6;
    constant vpro_cmd_gamma_len_c  : natural := 6;

    constant vpro_cmd_id_len_c          : natural := 3;
    constant vpro_cmd_blocking_len_c    : natural := 1;
    constant vpro_cmd_is_chain_len_c    : natural := 1;
    constant vpro_cmd_fu_sel_len_c      : natural := 2;
    constant vpro_cmd_func_len_c        : natural := 4;
    constant vpro_cmd_f_update_len_c    : natural := 1;
    constant vpro_cmd_dst_sel_len_c     : natural := 3;
    constant vpro_cmd_dst_offset_len_c  : natural := vpro_cmd_offset_len_c;
    constant vpro_cmd_dst_alpha_len_c   : natural := vpro_cmd_alpha_len_c;
    constant vpro_cmd_dst_beta_len_c    : natural := vpro_cmd_beta_len_c;
    constant vpro_cmd_dst_gamma_len_c   : natural := vpro_cmd_gamma_len_c;
    constant vpro_cmd_src1_sel_len_c    : natural := 3;
    constant vpro_cmd_src1_offset_len_c : natural := vpro_cmd_offset_len_c;
    constant vpro_cmd_src1_alpha_len_c  : natural := vpro_cmd_alpha_len_c;
    constant vpro_cmd_src1_beta_len_c   : natural := vpro_cmd_beta_len_c;
    constant vpro_cmd_src1_gamma_len_c  : natural := vpro_cmd_gamma_len_c;
    constant vpro_cmd_src2_sel_len_c    : natural := 3;
    constant vpro_cmd_src2_offset_len_c : natural := vpro_cmd_offset_len_c;
    constant vpro_cmd_src2_alpha_len_c  : natural := vpro_cmd_alpha_len_c;
    constant vpro_cmd_src2_beta_len_c   : natural := vpro_cmd_beta_len_c;
    constant vpro_cmd_src2_gamma_len_c  : natural := vpro_cmd_gamma_len_c;
    constant vpro_cmd_x_end_len_c       : natural := 6;
    constant vpro_cmd_y_end_len_c       : natural := 6;
    constant vpro_cmd_z_end_len_c       : natural := 10;

    -- total length 
    -- using imm instead offset + alpha + beta + gamma
    constant vpro_cmd_len_c : natural := vpro_cmd_id_len_c + vpro_cmd_blocking_len_c + vpro_cmd_is_chain_len_c + --
                                         vpro_cmd_fu_sel_len_c + vpro_cmd_func_len_c + vpro_cmd_f_update_len_c + --
                                         vpro_cmd_dst_sel_len_c + vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c + --
                                         vpro_cmd_src1_sel_len_c + vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c + --
                                         vpro_cmd_src2_sel_len_c + vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c + --
                                         vpro_cmd_x_end_len_c + vpro_cmd_y_end_len_c + vpro_cmd_z_end_len_c;

    constant vpro_cmd_dst_imm_len_c  : natural := vpro_cmd_dst_offset_len_c + vpro_cmd_dst_alpha_len_c + vpro_cmd_dst_beta_len_c + vpro_cmd_dst_gamma_len_c;
    constant vpro_cmd_src1_imm_len_c : natural := vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c;
    constant vpro_cmd_src2_imm_len_c : natural := vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c;

    -- record (internal)
    type vpro_command_t is record
        id          : std_ulogic_vector(vpro_cmd_id_len_c - 1 downto 0);
        blocking    : std_ulogic_vector(vpro_cmd_blocking_len_c - 1 downto 0);
        is_chain    : std_ulogic_vector(vpro_cmd_is_chain_len_c - 1 downto 0);
        fu_sel      : std_ulogic_vector(vpro_cmd_fu_sel_len_c - 1 downto 0);
        func        : std_ulogic_vector(vpro_cmd_func_len_c - 1 downto 0);
        f_update    : std_ulogic_vector(vpro_cmd_f_update_len_c - 1 downto 0);
        dst_sel     : std_ulogic_vector(vpro_cmd_dst_sel_len_c - 1 downto 0);
        dst_offset  : std_ulogic_vector(vpro_cmd_dst_offset_len_c - 1 downto 0);
        dst_alpha   : std_ulogic_vector(vpro_cmd_dst_alpha_len_c - 1 downto 0);
        dst_beta    : std_ulogic_vector(vpro_cmd_dst_beta_len_c - 1 downto 0);
        dst_gamma   : std_ulogic_vector(vpro_cmd_dst_gamma_len_c - 1 downto 0);
        src1_sel    : std_ulogic_vector(vpro_cmd_src1_sel_len_c - 1 downto 0);
        src1_offset : std_ulogic_vector(vpro_cmd_src1_offset_len_c - 1 downto 0);
        src1_alpha  : std_ulogic_vector(vpro_cmd_src1_alpha_len_c - 1 downto 0);
        src1_beta   : std_ulogic_vector(vpro_cmd_src1_beta_len_c - 1 downto 0);
        src1_gamma  : std_ulogic_vector(vpro_cmd_src1_gamma_len_c - 1 downto 0);
        src2_sel    : std_ulogic_vector(vpro_cmd_src2_sel_len_c - 1 downto 0);
        src2_offset : std_ulogic_vector(vpro_cmd_src2_offset_len_c - 1 downto 0);
        src2_alpha  : std_ulogic_vector(vpro_cmd_src2_alpha_len_c - 1 downto 0);
        src2_beta   : std_ulogic_vector(vpro_cmd_src2_beta_len_c - 1 downto 0);
        src2_gamma  : std_ulogic_vector(vpro_cmd_src2_gamma_len_c - 1 downto 0);
        x_end       : std_ulogic_vector(vpro_cmd_x_end_len_c - 1 downto 0);
        y_end       : std_ulogic_vector(vpro_cmd_y_end_len_c - 1 downto 0);
        z_end       : std_ulogic_vector(vpro_cmd_z_end_len_c - 1 downto 0);
    end record;

    -- record to vector 
    function vpro_cmd2vec(cmd : vpro_command_t) return std_ulogic_vector;
    -- vector to record
    function vpro_vec2cmd(vec : std_ulogic_vector) return vpro_command_t;

    function vpro_cmd2src1_imm(cmd : vpro_command_t) return std_ulogic_vector;
    function vpro_cmd2src2_imm(cmd : vpro_command_t) return std_ulogic_vector;
    function vpro_cmd2dst_imm(cmd : vpro_command_t) return std_ulogic_vector;

    function vpro_src1_imm2cmd(cmd : vpro_command_t; imm : std_ulogic_vector) return vpro_command_t;
    function vpro_src2_imm2cmd(cmd : vpro_command_t; imm : std_ulogic_vector) return vpro_command_t;

    constant vpro_cmd_zero_vec_c : std_ulogic_vector(vpro_cmd_len_c - 1 downto 0) := (others => '0');
    constant vpro_cmd_zero_c     : vpro_command_t;

    --- 
    --   DMA Instruction Word Layout
    ---
    constant dma_cmd_cluster_len_c   : natural := 8;
    constant dma_cmd_unit_mask_len_c : natural := 8; --32;
    constant dma_cmd_ext_base_len_c  : natural := 32;
    constant dma_cmd_loc_base_len_c  : natural := 13; --32;
    constant dma_cmd_x_size_len_c    : natural := 14;
    constant dma_cmd_y_size_len_c    : natural := 14;
    constant dma_cmd_x_stride_len_c  : natural := 13;
    constant dma_cmd_dir_len_c       : natural := 1;
    constant dma_cmd_pad_len_c       : natural := 4;

    constant dma_cmd_len_c : natural := dma_cmd_cluster_len_c + dma_cmd_unit_mask_len_c + --
                                        dma_cmd_ext_base_len_c + dma_cmd_loc_base_len_c + --
                                        dma_cmd_x_size_len_c + dma_cmd_y_size_len_c + dma_cmd_x_stride_len_c + --
                                        dma_cmd_dir_len_c + dma_cmd_pad_len_c;

    -- input to top
    alias dma_command_dcache_t is multi_cmd_t;

    type dma_command_t is record
        cluster   : std_ulogic_vector(dma_cmd_cluster_len_c - 1 downto 0);
        unit_mask : std_ulogic_vector(dma_cmd_unit_mask_len_c - 1 downto 0);
        ext_base  : std_ulogic_vector(dma_cmd_ext_base_len_c - 1 downto 0);
        loc_base  : std_ulogic_vector(dma_cmd_loc_base_len_c - 1 downto 0);
        x_size    : std_ulogic_vector(dma_cmd_x_size_len_c - 1 downto 0);
        y_size    : std_ulogic_vector(dma_cmd_y_size_len_c - 1 downto 0);
        x_stride  : std_ulogic_vector(dma_cmd_x_stride_len_c - 1 downto 0);
        dir       : std_ulogic_vector(dma_cmd_dir_len_c - 1 downto 0);
        pad       : std_ulogic_vector(dma_cmd_pad_len_c - 1 downto 0);
    end record;
    --
    -- Helper for translation of receive dcache multiword into DMA command
    --    matches the software fields (struct) of the command
    --
    procedure dcache_multiword_to_dma(
        signal dcache_instr_i : in multi_cmd_t;
        signal dma_cmd_o      : out dma_command_t
    );

    -- record to vector 
    function dma_cmd2vec(cmd : dma_command_t) return std_ulogic_vector;
    -- vector to record
    function dma_vec2cmd(vec : std_ulogic_vector) return dma_command_t;

    -- -------------------------------------------------------------------------------------------
    -- Source Selection --------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    constant srcsel_addr_c                    : std_ulogic_vector(2 downto 0) := "000"; -- register / complex addr inm src
    constant srcsel_imm_c                     : std_ulogic_vector(2 downto 0) := "001"; -- immediate
    constant srcsel_ls_c                      : std_ulogic_vector(2 downto 0) := "010"; -- chain source: LS	
    constant srcsel_chain_neighbor_c          : std_ulogic_vector(2 downto 0) := "011"; -- chain source: Processing Lane Neighbor
    constant srcsel_indirect_chain_ls_c       : std_ulogic_vector(2 downto 0) := "100"; -- chain source offset (indirect addr): LS
    constant srcsel_indirect_chain_neighbor_c : std_ulogic_vector(2 downto 0) := "101"; -- chain source offset (indirect addr): Processing Lane Neighbor
    constant srcsel_indirect_chain_l0_c       : std_ulogic_vector(2 downto 0) := "110"; -- chain source offset (indirect addr): in LS: L0 usage
    constant srcsel_indirect_chain_l1_c       : std_ulogic_vector(2 downto 0) := "111"; -- chain source offset (indirect addr): in LS: L1 usage

    -- -------------------------------------------------------------------------------------------
    -- Instruction Class: Functional Unit Selection ----------------------------------------------
    -- -------------------------------------------------------------------------------------------
    constant fu_memory_c             : std_ulogic_vector(vpro_cmd_fu_sel_len_c - 1 downto 0) := "00"; -- local memory access
    --load	-- bit '3
    constant func_load_c             : std_ulogic_vector(3 downto 0)                         := "0000";
    constant func_loadb_c            : std_ulogic_vector(3 downto 0)                         := "0001";
    constant func_loads_c            : std_ulogic_vector(3 downto 0)                         := "0010";
    constant func_loadbs_c           : std_ulogic_vector(3 downto 0)                         := "0011";
    -- specials
    constant func_load_shift_left_c  : std_ulogic_vector(3 downto 0)                         := "0110";
    constant func_load_shift_right_c : std_ulogic_vector(3 downto 0)                         := "0111";
    constant func_load_reverse_c     : std_ulogic_vector(3 downto 0)                         := "0101"; -- TODO not implemented

    -- store -- bit '3
    constant func_store_c             : std_ulogic_vector(3 downto 0) := "1000";
    -- specials 
    constant func_store_shift_left_c  : std_ulogic_vector(3 downto 0) := "1001"; -- TODO not implemented
    constant func_store_shift_right_c : std_ulogic_vector(3 downto 0) := "1010"; -- TODO not implemented
    constant func_store_reverse_c     : std_ulogic_vector(3 downto 0) := "1011"; -- TODO not implemented
    -- unused
    -- constant func_    : std_ulogic_vector(3 downto 0) := "0100"; -- 
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1100"; --
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1101"; --
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1110"; --
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1111"; --

    -- -------------------------------------------------------------------------------------------
    constant fu_aludsp_c : std_ulogic_vector(vpro_cmd_fu_sel_len_c - 1 downto 0) := "01"; -- alu processing
    -- arithmetic --
    constant func_add_c  : std_ulogic_vector(3 downto 0)                         := "0000"; -- D <= A + B
    constant func_sub_c  : std_ulogic_vector(3 downto 0)                         := "0001"; -- D <= B - A (reversed)

    constant func_macl_pre_c : std_ulogic_vector(3 downto 0) := "0010"; -- ACCU=0; D <= low(A*B)
    constant func_mach_pre_c : std_ulogic_vector(3 downto 0) := "0011"; -- ACCU=0; D <= high(A*B)
    constant func_mull_c     : std_ulogic_vector(3 downto 0) := "0100"; -- D <= low(A*B)
    constant func_macl_c     : std_ulogic_vector(3 downto 0) := "0101"; -- ACCU+=A*B; D <= low(ACCU)
    constant func_mulh_c     : std_ulogic_vector(3 downto 0) := "0110"; -- D <= high(A*B)
    constant func_mach_c     : std_ulogic_vector(3 downto 0) := "0111"; -- ACCU+=A*B; D <= high(ACCU)
    -- logic --
    constant func_xor_c      : std_ulogic_vector(3 downto 0) := "1000"; -- D <= A xor B
    constant func_xnor_c     : std_ulogic_vector(3 downto 0) := "1001"; -- D <= A xnor B
    constant func_and_c      : std_ulogic_vector(3 downto 0) := "1010"; -- D <= A and B
    --    constant func_andn_c     : std_ulogic_vector(3 downto 0) := "1011"; -- D <= A and (not B)
    constant func_nand_c     : std_ulogic_vector(3 downto 0) := "1100"; -- D <= A nand B
    constant func_or_c       : std_ulogic_vector(3 downto 0) := "1101"; -- D <= A or B
    --    constant func_orn_c      : std_ulogic_vector(3 downto 0) := "1110"; -- D <= A or (not B)
    constant func_nor_c      : std_ulogic_vector(3 downto 0) := "1111"; -- D <= A nor B

    -- -------------------------------------------------------------------------------------------
    constant fu_special_c        : std_ulogic_vector(vpro_cmd_fu_sel_len_c - 1 downto 0) := "10"; -- special operation
    -- shifter --
    -- '1 -> logic/arithmetic, '0 -> left/right
    constant func_shift_ll_c     : std_ulogic_vector(3 downto 0)                         := "0000"; -- D <= A << B (logical) / MULL	-- TODO not implemented (replace by MULL!)
    constant func_shift_lr_c     : std_ulogic_vector(3 downto 0)                         := "0001"; -- D <= A >> B (logical)
    constant func_shift_ar_c     : std_ulogic_vector(3 downto 0)                         := "0011"; -- D <= A >> B (arithmetical)
    -- arithmetic --
    constant func_abs_c          : std_ulogic_vector(3 downto 0)                         := "0100"; -- D <= abs(A)
    constant func_min_c          : std_ulogic_vector(3 downto 0)                         := "0110"; -- D <= min(A,B) (signed)
    constant func_max_c          : std_ulogic_vector(3 downto 0)                         := "0111"; -- D <= max(A,B) (signed)
    -- unused:
    --    constant func_    : std_ulogic_vector(3 downto 0) := "1000";
    --    constant func_    : std_ulogic_vector(3 downto 0) := "1001";
    --    constant func_    : std_ulogic_vector(3 downto 0) := "1100";
    constant func_max_vector_c   : std_ulogic_vector(3 downto 0)                         := "1101"; -- D <= max(vector(A)) => (SRC2Offset == 0b1)? index : value 
    constant func_min_vector_c   : std_ulogic_vector(3 downto 0)                         := "1110"; -- D <= min(vector(A)) => (SRC2Offset == 0b1)? index : value 
    constant func_bit_reversal_c : std_ulogic_vector(3 downto 0)                         := "1111"; -- D <= reversed_bit_order(A)

    -- -------------------------------------------------------------------------------------------
    constant fu_condmove_c       : std_ulogic_vector(vpro_cmd_fu_sel_len_c - 1 downto 0) := "11"; -- conditional move
    -- conditional moves
    constant func_mv_ze_c        : std_ulogic_vector(3 downto 0)                         := "0000"; -- D <= A (zero!)
    constant func_mv_nz_c        : std_ulogic_vector(3 downto 0)                         := "0001"; -- D <= A (non zero!)
    constant func_mv_mi_c        : std_ulogic_vector(3 downto 0)                         := "0010"; -- D <= A (negative!)
    constant func_mv_pl_c        : std_ulogic_vector(3 downto 0)                         := "0011"; -- D <= A (positive!)
    -- conditional mul
    constant func_mull_neg_c     : std_ulogic_vector(3 downto 0)                         := "0100"; -- D <= A*B (if neg) A (else)
    constant func_mull_pos_c     : std_ulogic_vector(3 downto 0)                         := "0101"; -- 
    constant func_mulh_neg_c     : std_ulogic_vector(3 downto 0)                         := "0110"; -- 
    constant func_mulh_pos_c     : std_ulogic_vector(3 downto 0)                         := "0111"; -- 
    -- additions/specials
    constant func_shift_ar_neg_c : std_ulogic_vector(3 downto 0)                         := "1010"; -- D <= A >> B (arithmetical, only negative As)
    constant func_shift_ar_pos_c : std_ulogic_vector(3 downto 0)                         := "1011"; -- D <= A >> B (arithmetical, only positive As)
    -- NOP (pipeline fill)
    constant func_nop_c          : std_ulogic_vector(3 downto 0)                         := "1000";
    -- unused
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1001"; --
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1100"; --
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1101"; --
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1110"; --
    -- constant func_    : std_ulogic_vector(3 downto 0) := "1111"; --

    -- -------------------------------------------------------------------------------------------
    -- Status Flags ------------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    constant z_fbus_c : natural := 0;   -- ZERO flag position in the flag bus
    constant n_fbus_c : natural := 1;   -- NEGATIVE flag position in the flag bus
    constant z_rf_c   : natural := rf_data_width_c; -- ZERO flag position in the register file
    constant n_rf_c   : natural := rf_data_width_c + 1; -- NEGATIVE flag position in the register file

    -- -------------------------------------------------------------------------------------------
    -- Condition Codes ---------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    constant cond_ze_c : std_ulogic_vector(1 downto 0) := "00"; -- if zero
    constant cond_nz_c : std_ulogic_vector(1 downto 0) := "01"; -- if not zero
    constant cond_mi_c : std_ulogic_vector(1 downto 0) := "10"; -- if minus
    constant cond_pl_c : std_ulogic_vector(1 downto 0) := "11"; -- if plus

    -- -------------------------------------------------------------------------------------------
    -- IO Addresses to listen to in VPRO ---------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- '-' dont care
    -- in top, 16-bit address (LSB), MSB: 0xFFFE
    constant io_addr_cluster_mask_c : std_ulogic_vector(7 downto 2) := "000000"; -- 0x--00 , Cluster ID is 15 downto 8
    --    constant io_addr_cluster_c      : std_ulogic_vector(15 downto 8) := "XXXXXXXX"; -- cluster ID, enables we/rd access -- this constant unused [just for docu]
    -- in cluster, 16-bit address (LSB), MSB: 0xFFFE
    constant io_addr_unit_mask_c    : std_ulogic_vector(7 downto 2) := "000001"; -- 0x--04  -- write broadcast unit mask for cmd issue
    constant io_addr_cluster_busy_c : std_ulogic_vector(7 downto 2) := "000010"; -- 0x--08  -- read for return of bitmask (unit busy) in this cluster?

    constant io_addr_sync_cl_mask_c    : std_ulogic_vector(7 downto 2) := "000100"; -- 0x--10  -- write to set cluster mask for mask sync
    --    constant io_addr_sync_un_mask_c : std_ulogic_vector(7 downto 0) := "000101"; -- 0x--14  -- write to set unit    mask for mask sync -> needs wide (<unit>-bit busy forward to cluster)
    constant io_addr_sync_dma_c        : std_ulogic_vector(7 downto 2) := "000110"; -- 0x--18  -- read for mask sync return for DMA (bool)
    constant io_addr_sync_vpro_c       : std_ulogic_vector(7 downto 2) := "000111"; -- 0x--1C  -- read for mask sync return for VPRO System (bool)
    constant io_addr_sync_vpro_block_c : std_ulogic_vector(7 downto 2) := "001010"; -- 0x--28  -- read for mask sync return for VPRO System (bool)
    constant io_addr_sync_dma_block_c  : std_ulogic_vector(7 downto 2) := "001011"; -- 0x--2C  -- read for mask sync return for VPRO System (bool)
    constant io_addr_sync_block_c      : std_ulogic_vector(7 downto 2) := "001100"; -- 0x--30  -- read for mask sync return for VPRO System (bool)

    constant io_addr_global_MUL_shift_c       : std_ulogic_vector(7 downto 2) := "010000"; -- 0x--40 TODO: placement in top/cluster/unit/lane? currently in lane
    constant io_addr_global_MAC_shift_c       : std_ulogic_vector(7 downto 2) := "010001"; -- 0x--44
    constant io_addr_global_MAC_init_source_c : std_ulogic_vector(7 downto 2) := "010010"; -- 0x--48
    constant io_addr_global_MAC_reset_mode_c  : std_ulogic_vector(7 downto 2) := "010011"; -- 0x--4c

    type MAC_INIT_SOURCE_t is (NONE, IMM, ADDR, ZERO);
    attribute enum_encoding : string;
    attribute enum_encoding of MAC_INIT_SOURCE_t : type is "000 001 011 101";

    type MAC_RESET_MODE_t is (NEVER, ONCE, Z_INCREMENT, Y_INCREMENT, X_INCREMENT);
    attribute enum_encoding of MAC_RESET_MODE_t : type is "000 001 011 101 110";

    --	constant io_addr_unit_access_c       : std_ulogic_vector(15 downto 0) := "--------0-------"; -- enables access to unit -> busy -- if no dma it is vcp access

    constant io_addr_dma_access_c : std_ulogic_vector(7 downto 7) := "1"; -- 0x--8- enables access to dma

    -- DMA description register access addresses (relative) --
    -- IO Addressed Deprecated!
    --    constant io_addr_ext_base_addr_e2l_c : std_ulogic_vector(15 downto 0) := "----------0000--"; -- external memory base address (for EXT->LOC) + TRIGGER
    --    constant io_addr_ext_base_addr_l2e_c : std_ulogic_vector(15 downto 0) := "----------0001--"; -- external memory base address (for LOC->EXT) + TRIGGER
    --    constant io_addr_loc_base_addr_c     : std_ulogic_vector(15 downto 0) := "----------0010--"; -- local memory base address
    --    constant io_addr_block_x_addr_c      : std_ulogic_vector(15 downto 0) := "----------0100--";
    --    constant io_addr_block_y_addr_c      : std_ulogic_vector(15 downto 0) := "----------0101--";
    --    constant io_addr_block_stride_addr_c : std_ulogic_vector(15 downto 0) := "----------0110--";

    -- NEW IO DMA: in top separated (case struct -> all need same range)
    constant io_addr_dma_unit_mask_c         : std_ulogic_vector(7 downto 2) := "110000"; -- C0 -- "--------110000--"
    constant io_addr_dma_cluster_mask_c      : std_ulogic_vector(7 downto 2) := "110001"; -- C4
    constant io_addr_dma_ext_base_e2l_c      : std_ulogic_vector(7 downto 2) := "110010"; -- C8 -- trigger
    constant io_addr_dma_ext_base_l2e_c      : std_ulogic_vector(7 downto 2) := "110011"; -- CC -- trigger     
    constant io_addr_dma_loc_base_c          : std_ulogic_vector(7 downto 2) := "110100"; -- D0
    constant io_addr_dma_x_size_c            : std_ulogic_vector(7 downto 2) := "110101"; -- D4
    constant io_addr_dma_y_size_c            : std_ulogic_vector(7 downto 2) := "110110"; -- D8
    constant io_addr_dma_x_stride_c          : std_ulogic_vector(7 downto 2) := "110111"; -- DC
    constant io_addr_dma_pad_active_c        : std_ulogic_vector(7 downto 2) := "111000"; -- E0
    constant io_addr_dma_read_hit_cycles_c   : std_ulogic_vector(7 downto 2) := "111001"; -- E4
    constant io_addr_dma_read_miss_cycles_c  : std_ulogic_vector(7 downto 2) := "111010"; -- E8
    constant io_addr_dma_write_hit_cycles_c  : std_ulogic_vector(7 downto 2) := "111011"; -- EC
    constant io_addr_dma_write_miss_cycles_c : std_ulogic_vector(7 downto 2) := "111100"; -- F0

    constant io_addr_dma_pad_top_c    : std_ulogic_vector(7 downto 2) := "101000"; -- pad
    constant io_addr_dma_pad_bottom_c : std_ulogic_vector(7 downto 2) := "101001";
    constant io_addr_dma_pad_left_c   : std_ulogic_vector(7 downto 2) := "101010";
    constant io_addr_dma_pad_right_c  : std_ulogic_vector(7 downto 2) := "101011";
    constant io_addr_dma_pad_value_c  : std_ulogic_vector(7 downto 2) := "101100";
    constant io_addr_dma_busy_addr_c  : std_ulogic_vector(7 downto 2) := "101111"; -- is zero when DMA is idle, queue_full & busy_sync2

    -- -------------------------------------------------------------------------------------------
    -- External Types ----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------

    type sync_request_t is (NONE, SYNC_REQUEST_DMA, SYNC_REQUEST_VPRO, SYNC_REQUEST_BOTH);

    type main_memory_single_out_t is record -- DMA => MAIN MEMORY SYSTEM (single)
        base_adr : std_ulogic_vector(31 downto 0); -- base address, byte-indexed
        size     : std_ulogic_vector(19 downto 0); -- quantity in bytes
        wdat     : std_ulogic_vector(mm_data_width_c - 1 downto 0); -- write data
        req      : std_ulogic;          -- memory request
        rw       : std_ulogic;          -- read/write a block from/to memory
        rden     : std_ulogic;          -- FIFO read enable
        wren     : std_ulogic;          -- FIFO write enable
        wr_last  : std_ulogic;          -- last word of write-block
    end record;

    type main_memory_single_in_t is record -- MAIN MEMORY SYSTEM => DMA (single)
        rdat : std_ulogic_vector(mm_data_width_c - 1 downto 0); -- read data
        busy : std_ulogic;              -- no request possible right now
        wrdy : std_ulogic;              -- data can be written, bus master can accept AT LEAST 8 more data words!!!
        rrdy : std_ulogic;              -- read data ready
    end record;

    -- vector system <=> main memory system (several instance / bundles)
    type main_memory_bundle_out_t is array (natural range <>) of main_memory_single_out_t;
    type main_memory_bundle_in_t is array (natural range <>) of main_memory_single_in_t;

    -- types for dma read/write hit/miss cycle counters
    type dma_access_counter_t is array (natural range <>) of std_ulogic_vector(31 downto 0);

    -- -------------------------------------------------------------------------------------------
    -- Internal Types ----------------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    -- in cluster: DMA <-> local memories interface
    --type lm_32b_t is array (natural range <>) of std_ulogic_vector(31 downto 0);
    type lm_20b_t is array (natural range <>) of std_ulogic_vector(19 downto 0);
    type lm_addr_t is array (natural range <>) of std_ulogic_vector(lm_addr_width_c - 1 downto 0);
    type lm_dma_word_t is array (natural range <>) of std_ulogic_vector(mm_data_width_c - 1 downto 0);
    type lm_vpro_word_t is array (natural range <>) of std_ulogic_vector(vpro_data_width_c - 1 downto 0);
    type lm_1b_t is array (natural range <>) of std_ulogic;
    type lm_wren_t is array (natural range <>) of std_ulogic_vector(mm_data_width_c / vpro_data_width_c - 1 downto 0);

    type chain_data_t is record
        data      : std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- flags & data
        data_avai : std_ulogic;
    end record;

    type lane_chain_data_input_t is array (0 to 2) of chain_data_t; -- left and right and ls
    type lane_chain_data_input_array_t is array (natural range <>) of lane_chain_data_input_t; -- for each alu lane
    type lane_chain_data_input_read_t is array (0 to 2) of std_ulogic; -- left and right and ls
    type lane_chain_data_input_read_array_t is array (natural range <>) of lane_chain_data_input_read_t;
    alias lane_chain_data_output_t is chain_data_t; -- left and right and ls
    type lane_chain_data_output_array_t is array (natural range <>) of lane_chain_data_output_t; -- for each alu lane

    type ls_chain_data_input_t is array (natural range <>) of chain_data_t; -- all alu lanes
    alias ls_chain_data_output_t is chain_data_t; -- ls out
    type ls_chain_data_input_read_t is array (natural range <>) of std_ulogic; -- all alu lanes

    type chain_data_array_t is array (natural range <>) of std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- for all lanes
    type chain_re_array_t is array (natural range <>) of std_ulogic; -- for all lanes
    type chain_emtpy_array_t is array (natural range <>) of std_ulogic; -- for all lanes

    -- -------------------------------------------------------------------------------------------
    -- Lane Pipeline Definitions -----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    constant num_pstages_c : natural := 12; -- number of pipeline stages - do not change!

    -- pipeline register types --
    -- mostly: 0 to num_pstages_c - 1
    type pipe1_t is array (natural range <>) of std_ulogic;
    type pipe10_t is array (natural range <>) of std_ulogic_vector(09 downto 0);
    type pipeCmd_t is array (natural range <>) of vpro_command_t;

    type operand_src_t is (CHAIN_LANE, CHAIN_LS, IMMEDIATE, REG);

    -- -------------------------------------------------------------------------------------------
    -- Internal Functions ---------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------

    --    function bit_reverse_vector(a : in std_ulogic_vector) return std_ulogic_vector;
    --    function bit_repeat(N : natural; B : std_ulogic) return std_ulogic_vector;

    function index_size(input : natural) return natural;
    function bit_reversal(input : std_ulogic_vector) return std_ulogic_vector;
    function set_bits(input : std_ulogic_vector) return natural;
    function leading_zeros(input : std_ulogic_vector) return natural;
    function cond_sel_natural(cond : boolean; val_t : natural; val_f : natural) return natural;
    function cond_sel_stdulogicvector(cond : boolean; val_t : std_ulogic_vector; val_f : std_ulogic_vector) return std_ulogic_vector;
    function bool_to_ulogic(cond : boolean) return std_ulogic;
    function bin_to_gray(input : std_ulogic_vector) return std_ulogic_vector;
    function gray_to_bin(input : std_ulogic_vector) return std_ulogic_vector;
    function int_match(l : std_ulogic_vector; r : std_ulogic_vector) return boolean;
    function count_ones(s : std_ulogic_vector) return integer;
    function count_zeros(s : std_ulogic_vector) return integer;

    -- -------------------------------------------------------------------------------------------
    -- Component: Vector System Top Entity ----------------------------------------------------
    -- -------------------------------------------------------------------------------------------

    component top
        generic(
            num_clusters          : natural := 1;
            num_units_per_cluster : natural := 1;
            num_lanes_per_unit    : natural := 2
        );
        port(
            -- vector system (clock domain 1) --
            vpro_clk_i            : in  std_ulogic; -- global clock signal, rising-edge
            vpro_rst_i            : in  std_ulogic_vector(num_clusters - 1 downto 0); -- global reset, async, polarity: see package
            -- host command interface (clock domain 2) --
            cmd_clk_i             : in  std_ulogic; -- CMD fifo access clock
            cmd_i                 : in  vpro_command_t; -- instruction word
            cmd_we_i              : in  std_ulogic; -- cmd write enable, high-active
            cmd_full_o            : out std_ulogic; -- accessed CMD FIFO is full
            idma_dcache_cmd_i     : in  multi_cmd_t;
            idma_dcache_cmd_we_i  : in  std_ulogic;
            idma_cmd_full_o       : out std_ulogic;
            dcache_dma_fsm_busy_i : in  std_ulogic;
            sync_request_i        : in  sync_request_t;
            sync_pending_o        : out std_ulogic;
            -- io interface (clock domain 2), 16-bit address space --
            io_clk_i              : in  std_ulogic; -- global clock signal, rising-edge
            io_rst_i              : in  std_ulogic; -- global reset, async, polarity: see package
            io_ren_i              : in  std_ulogic; -- read enable
            io_wen_i              : in  std_ulogic; -- write enable (full word)
            io_adr_i              : in  std_ulogic_vector(15 downto 0); -- data address
            io_data_i             : in  std_ulogic_vector(31 downto 0); -- data output
            io_data_o             : out std_ulogic_vector(31 downto 0); -- data input
            -- external memory system interface (clock domain 2) --
            mem_clk_i             : in  std_ulogic; -- global clock signal, rising-edge
            mem_rst_i             : in  std_ulogic_vector(num_clusters downto 0); -- global reset, async, polarity: see package
            mem_bundle_o          : out main_memory_bundle_out_t;
            mem_bundle_i          : in  main_memory_bundle_in_t;
            -- debug (cnt)
            vcp_lane_busy_o       : out std_ulogic;
            vcp_dma_busy_o        : out std_ulogic
        );
    end component;

    component dma_command_gen is
        port(
            vpro_clk_i           : in  std_ulogic; -- global clock signal, rising-edge
            vpro_rst_i           : in  std_ulogic; -- global reset, async, polarity: see package
            idma_cmd_full_i      : in  std_ulogic;
            idma_dcache_cmd_i    : in  multi_cmd_t;
            idma_dcache_cmd_we_i : in  std_ulogic;
            dma_cmd_gen_cmd_o    : out dma_command_t;
            dma_cmd_we_o         : out std_ulogic;
            waiting_for_dma_o    : out std_ulogic;
            busy_o               : out std_ulogic
        );
    end component;

    component idma_access_counter
        generic(
            num_clusters : natural := 8
        );
        port(
            dma_clk_i            : in  std_ulogic;
            dma_rst_i            : in  std_ulogic;
            mem_bundle_dma2mem_i : in  main_memory_bundle_out_t(0 to num_clusters - 1);
            mem_bundle_mem2dma_i : in  main_memory_bundle_in_t(0 to num_clusters - 1);
            read_hit_cycles_o    : out dma_access_counter_t(0 to num_clusters - 1);
            read_miss_cycles_o   : out dma_access_counter_t(0 to num_clusters - 1);
            write_hit_cycles_o   : out dma_access_counter_t(0 to num_clusters - 1);
            write_miss_cycles_o  : out dma_access_counter_t(0 to num_clusters - 1);
            reset_counters_i     : in  std_ulogic
        );
    end component idma_access_counter;

    -- Component: Single Vector Cluster Top Entity --------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component cluster_top
        generic(
            CLUSTER_ID         : natural := 0; -- absolute ID of this cluster
            num_vu_per_cluster : natural := 1;
            num_lanes_per_unit : natural := 2
        );
        port(
            -- vector system (clock domain 1) --
            vcp_clk_i       : in  std_ulogic; -- global clock signal, rising-edge
            vcp_rst_i       : in  std_ulogic; -- global reset, async, polarity: see package
            -- internal command interface (clock domain 4) --
            cmd_clk_i       : in  std_ulogic; -- CMD fifo access clock
            cmd_i           : in  vpro_command_t; -- instruction word
            cmd_we_i        : in  std_ulogic; -- cmd write enable, high-active
            cmd_full_o      : out std_ulogic; -- accessed CMD FIFO is full
            idma_cmd_i      : in  dma_command_t;
            idma_cmd_we_i   : in  std_ulogic;
            idma_cmd_full_o : out std_ulogic;
            -- io interface (clock domain 2), 16-bit address space --
            io_clk_i        : in  std_ulogic; -- global clock signal, rising-edge
            io_rst_i        : in  std_ulogic; -- global reset, async, polarity: see package
            io_ren_i        : in  std_ulogic; -- read enable
            io_wen_i        : in  std_ulogic; -- write enable (full word)
            io_adr_i        : in  std_ulogic_vector(15 downto 0); -- data address, word-indexed!
            io_data_i       : in  std_ulogic_vector(31 downto 0); -- data output
            io_data_o       : out std_ulogic_vector(31 downto 0); -- data input
            -- external memory system interface (clock domain 3) --
            mem_clk_i       : in  std_ulogic; -- global clock signal, rising-edge
            mem_rst_i       : in  std_ulogic; -- global reset, async, polarity: see package
            mem_o           : out main_memory_single_out_t;
            mem_i           : in  main_memory_single_in_t;
            -- debug (cnt)
            lane_busy_o     : out std_ulogic;
            dma_busy_o      : out std_ulogic
        );
    end component;

    component idma_fifo IS
        GENERIC(
            DWIDTH_WR         : integer := 32; -- data width at write port
            DWIDTH_RD         : integer := 32; -- data width at read port
            DEPTH_WR          : integer := 2; -- fifo depth (number of words with write data width), must be a power of 2
            AWIDTH_WR         : integer := 1; -- address width of memory write port, set to log2(DEPTH_WR)
            AWIDTH_RD         : integer := 1; -- address width of memory read port,  set to log2(DEPTH_WR*DWIDTH_WR/DWIDTH_RD)
            ASYNC             : integer := 0; -- 0: sync fifo, 1: async fifo
            ADD_READ_SYNC_REG : integer := 0; -- 0: 2 sync regs for async fifo on read side, 1: 1 cycle additional delay for rd_count+rd_empty
            SYNC_OUTREG       : integer := 1; -- 0: no read data output register if sync fifo, 1: always generate output register
            BIG_ENDIAN        : integer := 1 -- 0: big endian conversion if DWIDTH_WR /= DWIDTH_RD
            -- 1: little endian conversion if DWIDTH_WR /= DWIDTH_RD
        );

        PORT(
            -- *** write port ***
            clk_wr     : IN  std_ulogic;
            reset_n_wr : IN  std_ulogic;
            clken_wr   : IN  std_ulogic;
            flush_wr   : IN  std_ulogic;
            wr_free    : OUT std_ulogic_vector(AWIDTH_WR DOWNTO 0); -- number of free fifo entries
            wr_full    : OUT std_ulogic;
            wr_en      : IN  std_ulogic;
            wdata      : IN  std_ulogic_vector(DWIDTH_WR - 1 DOWNTO 0);
            -- *** read port ***
            clk_rd     : IN  std_ulogic;
            reset_n_rd : IN  std_ulogic;
            clken_rd   : IN  std_ulogic;
            flush_rd   : IN  std_ulogic;
            rd_count   : OUT std_ulogic_vector(AWIDTH_RD DOWNTO 0); -- number of valid fifo entries
            rd_empty   : OUT std_ulogic;
            rd_en      : IN  std_ulogic;
            rdata      : OUT std_ulogic_vector(DWIDTH_RD - 1 DOWNTO 0)
        );
    END component;

    component idma_shift_reg IS
        generic(
            DATA_WIDTH      : integer := 64; -- data width at write port
            SUBDATA_WIDTH   : integer := 16; -- data width at write port
            DATA_DEPTH_LOG2 : integer := 2 -- fifo depth (number of words with data width), log2
        );

        port(
            clk      : in  std_ulogic;
            reset_n  : in  std_ulogic;
            -- *** write port ***
            wr_full  : out std_ulogic;  -- can new data be written?
            wr_en    : in  std_ulogic_vector(integer(ceil(log2(real(DATA_WIDTH / SUBDATA_WIDTH)))) DOWNTO 0); -- how many subwords are written
            wdata    : in  std_ulogic_vector(DATA_WIDTH - 1 DOWNTO 0);
            -- *** read port ***
            rd_count : out std_ulogic_vector(integer(ceil(log2(real(DATA_WIDTH / SUBDATA_WIDTH)))) DOWNTO 0); -- number of valid fifo entries up to DATA_WIDTH / SUBDATA_WIDTH
            rd_en    : in  std_ulogic_vector(integer(ceil(log2(real(DATA_WIDTH / SUBDATA_WIDTH)))) DOWNTO 0); -- how many subwords are read
            rdata    : out std_ulogic_vector(DATA_WIDTH - 1 DOWNTO 0)
        );
    end component;

    component parallel_protocol_master is
        generic(
            PAR_DATA_WIDTH            : integer := 64; -- or 32
            FIFO_DEPTH                : integer := 2;
            EISV_CACHE_ENDIANESS_SWAP : boolean := false; -- this will swap endianess and the word order. to change back word order use WORD_SWAP
            EISV_CACHE_WORD_SWAP      : boolean := true;
            PROC_DATA_WIDTH           : integer := 32;
            EISV_CACHE_DATA_WIDTH     : integer := 128;
            DCMA_DATA_WIDTH           : integer := 512
        );
        port(
            -- Command Interface --
            icache_clk            : in  std_ulogic;
            icache_rstn           : in  std_ulogic;
            icache_req_i          : in  std_ulogic; -- data request
            icache_busy_o         : out std_ulogic; -- memory command buffer full
            icache_read_length_i  : in  std_ulogic_vector(19 downto 0); --length of that block in bytes
            icache_base_adr_i     : in  std_ulogic_vector(31 downto 0); -- data address, word-indexed
            icache_fifo_rden_i    : in  std_ulogic; -- FIFO read enable
            icache_fifo_data_o    : out std_ulogic_vector(EISV_CACHE_DATA_WIDTH - 1 downto 0); -- data output
            icache_fifo_rrdy_o    : out std_ulogic; -- read-data ready

            dcache_clk            : in  std_ulogic;
            dcache_rstn           : in  std_ulogic;
            dcache_req_i          : in  std_ulogic; -- data request
            dcache_busy_o         : out std_ulogic; -- memory command buffer full
            dcache_rw_i           : in  std_ulogic; -- read/write a block from/to memory
            dcache_read_length_i  : in  std_ulogic_vector(19 downto 0); --length of that block in bytes
            dcache_base_adr_i     : in  std_ulogic_vector(31 downto 0); -- data address, word-indexed
            dcache_fifo_rden_i    : in  std_ulogic; -- FIFO read enable
            dcache_fifo_wren_i    : in  std_ulogic; -- FIFO write enable
            dcache_fifo_wr_last_i : in  std_ulogic; -- last word of write-block
            dcache_fifo_data_o    : out std_ulogic_vector(EISV_CACHE_DATA_WIDTH - 1 downto 0); -- data output
            dcache_fifo_wrdy_o    : out std_ulogic; -- write fifo is ready
            dcache_fifo_rrdy_o    : out std_ulogic; -- read-data ready
            dcache_fifo_data_i    : in  std_ulogic_vector(EISV_CACHE_DATA_WIDTH - 1 downto 0); -- data input

            dcma_clk              : in  std_ulogic;
            dcma_rstn             : in  std_ulogic;
            dcma_req_i            : in  std_ulogic; -- data request
            dcma_busy_o           : out std_ulogic; -- memory command buffer full
            dcma_rw_i             : in  std_ulogic; -- read/write a block from/to memory
            dcma_read_length_i    : in  std_ulogic_vector(19 downto 0); --length of that block in bytes
            dcma_base_adr_i       : in  std_ulogic_vector(31 downto 0); -- data address, word-indexed
            dcma_fifo_rden_i      : in  std_ulogic; -- FIFO read enable
            dcma_fifo_wren_i      : in  std_ulogic; -- FIFO write enable
            dcma_fifo_wr_last_i   : in  std_ulogic; -- last word of write-block
            dcma_fifo_data_o      : out std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- data output
            dcma_fifo_wrdy_o      : out std_ulogic; -- write fifo is ready
            dcma_fifo_rrdy_o      : out std_ulogic; -- read-data ready
            dcma_fifo_data_i      : in  std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- data input

            -- Ports of Parallel Interface
            par_clk_i             : in  std_ulogic;
            par_rstn              : in  std_ulogic;
            par_busy_i            : in  std_ulogic;
            par_valid_o           : out std_ulogic;
            par_wdata_o           : out std_ulogic_vector(PAR_DATA_WIDTH - 1 downto 0);
            par_rdata_i           : in  std_ulogic_vector(PAR_DATA_WIDTH - 1 downto 0);
            par_direction_o       : out std_ulogic -- 1 = reading data from ext to asic, 0 = writing data from asic to ext
        );
    end component parallel_protocol_master;

    component cmd_fifo_wrapper
        generic(
            DATA_WIDTH  : natural := vpro_cmd_len_c; -- data width of FIFO entries
            NUM_ENTRIES : natural := 32; -- number of FIFO entries, should be a power of 2!
            NUM_SYNC_FF : natural := 2; -- number of synchronization FF stages
            NUM_SFULL   : natural := 1  -- offset between RD and WR for issueing 'special full' signal
        );
        port(
            -- write port (master clock domain) --
            m_clk_i    : in  std_ulogic;
            m_rst_i    : in  std_ulogic; -- polarity: see package
            m_cmd_i    : in  vpro_command_t;
            m_cmd_we_i : in  std_ulogic;
            m_full_o   : out std_ulogic;
            -- read port (slave clock domain) --
            s_clk_i    : in  std_ulogic;
            s_rst_i    : in  std_ulogic; -- polarity: see package
            s_cmd_o    : out vpro_command_t;
            s_cmd_re_i : in  std_ulogic;
            s_empty_o  : out std_ulogic
        );
    end component;

    -- Component: Command FIFO (based on DRAM, sync clocks) --------------------------------------
    -- -------------------------------------------------------------------------------------------
    component sync_fifo
        generic(
            DATA_WIDTH     : natural := rf_data_width_c; -- data width of FIFO entries
            NUM_ENTRIES    : natural := 8; -- number of FIFO entries, should be a power of 2!
            NUM_SFULL      : natural := 2; -- offset between RD and WR for issueing 'special full' signal
            DIRECT_OUT     : boolean := false; -- direct output of first data when true
            DIRECT_OUT_REG : boolean := false -- direct output (one cycle delay) when true (e.g. write & read not in same cycle!)
        );
        port(
            -- globals --
            clk_i    : in  std_ulogic;
            rst_i    : in  std_ulogic;  -- polarity: see package
            -- write port --
            wdata_i  : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            we_i     : in  std_ulogic;
            wfull_o  : out std_ulogic;
            wsfull_o : out std_ulogic;  -- almost full signal
            -- read port (slave clock domain) --
            rdata_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            re_i     : in  std_ulogic;
            rempty_o : out std_ulogic
        );
    end component;

    component sync_fifo_register is
        generic(
            DATA_WIDTH  : natural := rf_data_width_c + 2; -- data width of FIFO entries
            NUM_ENTRIES : natural := 2  -- number of FIFO entries, should be a power of 2!
        );
        port(
            -- globals --
            clk_i    : in  std_ulogic;
            rst_i    : in  std_ulogic;  -- polarity: see package
            -- write port --
            wdata_i  : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            we_i     : in  std_ulogic;
            wfull_o  : out std_ulogic;
            wsfull_o : out std_ulogic;  -- almost full signal
            -- read port (slave clock domain) --
            rdata_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            re_i     : in  std_ulogic;
            rempty_o : out std_ulogic
        );
    end component;

    -- Component: Command FIFO (based on distributed RAM) ----------------------------------------
    -- -------------------------------------------------------------------------------------------
    component cdc_fifo
        generic(
            DATA_WIDTH  : natural := vpro_cmd_len_c; -- data width of FIFO entries
            NUM_ENTRIES : natural := 32; -- number of FIFO entries, should be a power of 2!
            NUM_SYNC_FF : natural := 2; -- number of synchronization FF stages
            NUM_SFULL   : natural := 1; -- offset between RD and WR for issueing 'special full' signal
            ASYNC       : boolean := false
        );
        port(
            -- write port (master clock domain) --
            m_clk_i   : in  std_ulogic;
            m_rst_i   : in  std_ulogic; -- async, polarity: see package
            m_data_i  : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            m_we_i    : in  std_ulogic;
            m_full_o  : out std_ulogic;
            m_sfull_o : out std_ulogic; -- 'special' full signal
            -- read port (slave clock domain) --
            s_clk_i   : in  std_ulogic;
            s_rst_i   : in  std_ulogic; -- async, polarity: see package
            s_data_o  : out std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            s_re_i    : in  std_ulogic;
            s_empty_o : out std_ulogic
        );
    end component;

    -- Component: Command Arbiter -------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component cmd_ctrl
        generic(
            num_lanes_per_unit : natural := 3 -- number of lanes in this unit
        );
        port(
            -- global control --
            clk_i           : in  std_ulogic;
            rst_i           : in  std_ulogic; -- polarity: see package
            -- status --
            idle_o          : out std_ulogic;
            -- cmd fifo interface --
            cmd_i           : in  vpro_command_t;
            cmd_avail_i     : in  std_ulogic;
            cmd_re_o        : out std_ulogic;
            -- lane interface --
            lane_cmd_o      : out vpro_command_t;
            lane_cmd_we_o   : out std_ulogic_vector(num_lanes_per_unit - 1 downto 0);
            lane_cmd_req_i  : in  std_ulogic_vector(num_lanes_per_unit - 1 downto 0);
            lane_blocking_i : in  std_ulogic_vector(num_lanes_per_unit - 1 downto 0)
        );
    end component;

    -- Component: Local Memory ----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component local_mem
        generic(
            ADDR_WIDTH_g : natural := 13; -- must be 11..15
            DATA_WIDTH_g : natural := 16
        );
        port(
            -- port A --
            a_clk_i  : in  std_ulogic;
            a_addr_i : in  std_ulogic_vector(19 downto 0);
            a_di_i   : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            a_we_i   : in  std_ulogic_vector(DATA_WIDTH_g / 8 - 1 downto 0);
            a_re_i   : in  std_ulogic;
            a_do_o   : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            -- port B --
            b_clk_i  : in  std_ulogic;
            b_addr_i : in  std_ulogic_vector(19 downto 0);
            b_di_i   : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            b_we_i   : in  std_ulogic_vector(DATA_WIDTH_g / 8 - 1 downto 0);
            b_re_i   : in  std_ulogic;  -- @suppress "Unused port: b_re_i is not used in core_v2pro.local_mem(local_mem_rtl)"
            b_do_o   : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0)
        );
    end component;

    -- Component: Single Lane Top Entity ------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component lane_top
        generic(
            minmax_instance_g       : boolean;
            bit_reversal_instance_g : boolean;
            LANE_LABLE_g            : string := "unknown"
        );
        port(
            clk_i                     : in  std_ulogic;
            rst_i                     : in  std_ulogic;
            cmd_i                     : in  vpro_command_t;
            cmd_we_i                  : in  std_ulogic;
            cmd_busy_o                : out std_ulogic;
            cmd_req_o                 : out std_ulogic;
            cmd_isblocking_o          : out std_ulogic;
            mul_shift_i               : in  std_ulogic_vector(04 downto 0);
            mac_shift_i               : in  std_ulogic_vector(04 downto 0);
            mac_init_source_i         : in  MAC_INIT_SOURCE_t;
            mac_reset_mode_i          : in  MAC_RESET_MODE_t;
            lane_chain_input_i        : in  lane_chain_data_input_t;
            lane_chain_input_read_o   : out lane_chain_data_input_read_t;
            lane_chain_output_o       : out lane_chain_data_output_t;
            lane_chain_output_stall_i : in  std_ulogic
        );
    end component lane_top;

    component ls_lane_top
        generic(
            load_shift_instance_g : boolean;
            num_lanes_per_unit    : natural
        );
        port(
            -- global control --
            clk_i                   : in  std_ulogic; -- global clock, rising edge
            rst_i                   : in  std_ulogic; -- global reset, async, polarity: see package
            -- instruction interface --
            cmd_i                   : in  vpro_command_t;
            cmd_we_i                : in  std_ulogic;
            cmd_busy_o              : out std_ulogic;
            cmd_req_o               : out std_ulogic;
            cmd_isblocking_o        : out std_ulogic;
            -- chaining (data + flags) --
            ls_chain_input_data_i   : in  ls_chain_data_input_t; -- alu lanes
            ls_chain_input_read_o   : out ls_chain_data_input_read_t;
            ls_chain_output_data_o  : out ls_chain_data_output_t; -- ls output
            ls_chain_output_stall_i : in  std_ulogic; -- ls output
            -- local memory interface --
            lm_we_o                 : out std_ulogic;
            lm_re_o                 : out std_ulogic;
            lm_addr_o               : out std_ulogic_vector(19 downto 0);
            lm_wdata_o              : out std_ulogic_vector(vpro_data_width_c - 1 downto 0);
            lm_rdata_i              : in  std_ulogic_vector(vpro_data_width_c - 1 downto 0)
        );
    end component;

    component operand_mux_chain is
        port(
            vcmd_i             : in  vpro_command_t;
            lane_chain_input_i : in  lane_chain_data_input_t;
            src1_src_i         : in  operand_src_t;
            src2_src_i         : in  operand_src_t;
            src1_buf_o         : out std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- includes flag data
            src1_addr_sel_o    : out std_ulogic;
            src2_buf_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0); -- without flag
            src2_addr_sel_o    : out std_ulogic
        );
    end component operand_mux_chain;

    component operand_mux_buf_rf is
        port(
            vcmd_i            : in  vpro_command_t; -- immediate
            src1_addr_sel_i   : in  std_ulogic;
            src2_addr_sel_i   : in  std_ulogic;
            src1_buf_i        : in  std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- with flag data
            src2_buf_i        : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
            src1_rdata_i      : in  std_ulogic_vector(rf_data_width_c + 2 - 1 downto 0); -- with flag data
            src2_rdata_i      : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
            mac_init_source_i :     MAC_INIT_SOURCE_t;
            alu_opa_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0);
            alu_opb_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0);
            alu_opc_o         : out std_ulogic_vector(rf_data_width_c - 1 downto 0);
            old_flags_o       : out std_ulogic_vector(01 downto 0)
        );
    end component operand_mux_buf_rf;

    component register_file is
        generic(
            FLAG_WIDTH_g  : natural := 2;
            DATA_WIDTH_g  : natural := rf_data_width_c;
            NUM_ENTRIES_g : natural := 1024;
            RF_LABLE_g    : string  := "unknown"
        );
        port(
            -- global control --
            rd_ce_i    : in  std_ulogic;
            wr_ce_i    : in  std_ulogic;
            clk_i      : in  std_ulogic;
            -- write port --
            waddr_i    : in  std_ulogic_vector(09 downto 0);
            wdata_i    : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            wflag_i    : in  std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
            wdata_we_i : in  std_ulogic; -- data write enable
            wflag_we_i : in  std_ulogic; -- flags write enable
            -- read port --
            raddr_a_i  : in  std_ulogic_vector(09 downto 0);
            rdata_a_o  : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            rflag_a_o  : out std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
            -- read port --
            raddr_b_i  : in  std_ulogic_vector(09 downto 0);
            rdata_b_o  : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            rflag_b_o  : out std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0)
        );
    end component register_file;

    -- Component: 1024x24+2 DP-RAM ------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component dpram_1024x26
        generic(
            FLAG_WIDTH_g  : natural := 2;
            DATA_WIDTH_g  : natural := rf_data_width_c;
            NUM_ENTRIES_g : natural := 1024;
            RF_LABLE_g    : string  := "unknown"
        );
        port(
            -- global control --
            rd_ce_i : in  std_ulogic;
            wr_ce_i : in  std_ulogic;
            clk_i   : in  std_ulogic;
            -- write port --
            waddr_i : in  std_ulogic_vector(09 downto 0);
            data_i  : in  std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            flag_i  : in  std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0);
            dwe_i   : in  std_ulogic;   -- data write enable
            fwe_i   : in  std_ulogic;   -- flags write enable
            -- read port --
            raddr_i : in  std_ulogic_vector(09 downto 0);
            data_o  : out std_ulogic_vector(DATA_WIDTH_g - 1 downto 0);
            flag_o  : out std_ulogic_vector(FLAG_WIDTH_g - 1 downto 0)
        );
    end component;

    component addressing_offset_mux is
        generic(
            OFFSET_WIDTH_g : natural := 10
        );
        port(
            cmd_src_sel_i : in  std_ulogic_vector(2 downto 0);
            cmd_offset_i  : in  std_ulogic_vector(OFFSET_WIDTH_g - 1 downto 0);
            chain_input_i : in  lane_chain_data_input_t;
            offset_o      : out std_ulogic_vector(OFFSET_WIDTH_g - 1 downto 0)
        );
    end component addressing_offset_mux;

    -- Component: Artihmetic/Logic Unit -------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component alu
        generic(
            minmax_instance_g       : boolean;
            bit_reversal_instance_g : boolean
        );
        port(
            ce_i              : in  std_ulogic;
            clk_i             : in  std_ulogic;
            en_i              : in  std_ulogic;
            fusel_i           : in  std_ulogic_vector(01 downto 0);
            func_i            : in  std_ulogic_vector(03 downto 0);
            mul_shift_i       : in  std_ulogic_vector(04 downto 0);
            mac_shift_i       : in  std_ulogic_vector(04 downto 0);
            mac_init_source_i : in  MAC_INIT_SOURCE_t;
            reset_accu_i      : in  std_ulogic;
            first_iteration_i : in  std_ulogic;
            conditional_i     : in  std_ulogic;
            opa_i             : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
            opb_i             : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
            opc_i             : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
            result_o          : out std_ulogic_vector(rf_data_width_c - 1 downto 0);
            flags_o           : out std_ulogic_vector(01 downto 0)
        );
    end component alu;

    -- Component: DSP Unit --------------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component dsp_unit
        generic(
            DATA_INOUT_WIDTH_g : natural := rf_data_width_c;
            MUL_OPB_WIDTH_g    : natural := opb_mul_data_width_c;
            STATIC_SHIFT_g     : natural := 0
        );
        port(
            -- global control --
            ce_i              : in  std_ulogic;
            clk_i             : in  std_ulogic;
            enable_i          : in  std_ulogic;
            function_i        : in  std_ulogic_vector(03 downto 0);
            mul_shift_i       : in  std_ulogic_vector(04 downto 0);
            mac_shift_i       : in  std_ulogic_vector(04 downto 0);
            mac_init_source_i : in  MAC_INIT_SOURCE_t;
            reset_accu_i      : in  std_ulogic;
            first_iteration_i : in  std_ulogic;
            -- operands --
            opa_i             : in  std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
            opb_i             : in  std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
            opc_i             : in  std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0);
            -- results --
            is_zero_o         : out std_ulogic;
            data_o            : out std_ulogic_vector(DATA_INOUT_WIDTH_g - 1 downto 0)
        );
    end component;

    -- Component: Barrelshifter ---------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    component bs_unit
        generic(
            only_right_shift : boolean := true -- whether to implement the tree for shift in left direction
        );
        port(
            -- global control --
            ce_i       : in  std_ulogic;
            clk_i      : in  std_ulogic;
            function_i : in  std_ulogic_vector(03 downto 0);
            -- operands --
            opa_i      : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
            opb_i      : in  std_ulogic_vector(rf_data_width_c - 1 downto 0);
            -- result --
            data_o     : out std_ulogic_vector(rf_data_width_c - 1 downto 0)
        );
    end component;

    component dma_crossbar_dma_module is
        generic(
            NUM_RAMS                  : integer := 32;
            ASSOCIATIVITY_LOG2        : integer := 2;
            RAM_ADDR_WIDTH            : integer := 12;
            DCMA_ADDR_WIDTH           : integer := 32; -- Address Width
            DCMA_DATA_WIDTH           : integer := 64; -- Data Width
            VPRO_DATA_WIDTH           : integer := 16;
            ADDR_WORD_BITWIDTH        : integer;
            ADDR_WORD_SELECT_BITWIDTH : integer;
            ADDR_SET_BITWIDTH         : integer;
            RAM_LOG2                  : integer
        );
        port(
            clk_i                    : in  std_ulogic; -- Clock 
            areset_n_i               : in  std_ulogic;
            -- dma interface --
            dma_base_adr_i           : in  std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0); -- addressing words (only on boundaries!)
            dma_size_i               : in  std_ulogic_vector(20 - 1 downto 0); -- quantity
            dma_dat_o                : out std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- data from main memory
            dma_dat_i                : in  std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- data to main memory
            dma_req_i                : in  std_ulogic; -- memory request
            dma_busy_o               : out std_ulogic; -- no request possible right now
            dma_rw_i                 : in  std_ulogic; -- read/write a block from/to memory
            dma_rden_i               : in  std_ulogic; -- FIFO read enable
            dma_wren_i               : in  std_ulogic; -- FIFO write enable
            dma_wrdy_o               : out std_ulogic; -- data can be written
            dma_wr_last_i            : in  std_ulogic; -- last word of write-block
            dma_rrdy_o               : out std_ulogic; -- read data ready
            is_dma_access_allowed_i  : in  std_ulogic;
            -- ram interface --
            access_ram_idx_o         : out std_ulogic_vector(RAM_LOG2 - 1 downto 0);
            access_ram_addr_o        : out std_ulogic_vector(RAM_ADDR_WIDTH - 1 downto 0);
            access_ram_is_read_o     : out std_ulogic;
            access_ram_wdata_valid_o : out std_ulogic_vector(DCMA_DATA_WIDTH / VPRO_DATA_WIDTH - 1 downto 0);
            access_ram_rdata_valid_i : in  std_ulogic;
            access_ram_rrdy_o        : out std_ulogic;
            access_ram_wdata_o       : out std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- Data Input  
            access_ram_rdata_i       : in  std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0); -- Data Output
            -- controller interface --
            ctrl_addr_o              : out std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
            ctrl_is_read_o           : out std_ulogic;
            ctrl_valid_o             : out std_ulogic;
            ctrl_is_hit_i            : in  std_ulogic;
            ctrl_line_offset_i       : in  std_ulogic_vector(ASSOCIATIVITY_LOG2 - 1 downto 0)
        );
    end component;

end v2pro_package;

-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------

package body v2pro_package is

    procedure dcache_multiword_to_dma(
        signal dcache_instr_i : in multi_cmd_t;
        signal dma_cmd_o      : out dma_command_t
    ) is
    begin
        assert (dma_cmd_unit_mask_len_c <= 32) report "[static ERROR] dcache broadcast is limited to 32-bit -> maximum of 32 broadcast selection possible!" severity failure;
        assert (dma_cmd_x_stride_len_c <= 16) report "DMA from Dcache decode: X Stride with maximum of 16-bit! (Software -> Hardware Interface!)" severity failure;
        assert (dma_cmd_x_size_len_c <= 16) report "DMA from Dcache decode: X Size with maximum of 16-bit! (Software -> Hardware Interface!)" severity failure;
        assert (dma_cmd_y_size_len_c <= 16) report "DMA from Dcache decode: Y Size with maximum of 16-bit! (Software -> Hardware Interface!)" severity failure;
        dma_cmd_o.dir(0)    <= dcache_instr_i(0)(01);
        dma_cmd_o.pad       <= dcache_instr_i(0)(27 downto 24);
        dma_cmd_o.cluster   <= dcache_instr_i(1)(dma_cmd_cluster_len_c - 1 downto 0); -- TODO: different bits to allow > 8 clusters. Use of dma_cmd_cluster_len_c to select bits!
        dma_cmd_o.unit_mask <= dcache_instr_i(2)(dma_cmd_unit_mask_len_c - 1 downto 0); -- TODO: adopt to acutal number of cl/vu! -> generic of VPRO sys
        dma_cmd_o.ext_base  <= dcache_instr_i(3)(31 downto 0);
        -- 4 reserved for ISS 64-bit mm addr
        dma_cmd_o.loc_base  <= dcache_instr_i(5)(dma_cmd_loc_base_len_c - 1 downto 0);
        dma_cmd_o.x_stride  <= dcache_instr_i(6)(15 - (16 - dma_cmd_x_stride_len_c) downto 00);
        dma_cmd_o.x_size    <= dcache_instr_i(6)(31 - (16 - dma_cmd_x_size_len_c) downto 16);
        dma_cmd_o.y_size    <= dcache_instr_i(7)(15 - (16 - dma_cmd_y_size_len_c) downto 00);
    end procedure;

    -- record to vector 
    function vpro_cmd2vec(cmd : vpro_command_t) return std_ulogic_vector is
        variable vec : std_ulogic_vector(vpro_cmd_len_c - 1 downto 0);
    begin
        vec := cmd.id & cmd.blocking & cmd.is_chain & cmd.fu_sel & cmd.func & cmd.f_update & --
               cmd.dst_sel & cmd.dst_offset & cmd.dst_alpha & cmd.dst_beta & cmd.dst_gamma & -- 
               cmd.src1_sel & cmd.src1_offset & cmd.src1_alpha & cmd.src1_beta & cmd.src1_gamma & --
               cmd.src2_sel & cmd.src2_offset & cmd.src2_alpha & cmd.src2_beta & cmd.src2_gamma & --
               cmd.x_end & cmd.y_end & cmd.z_end;
        return vec;
    end;

    -- vector to record
    function vpro_vec2cmd(vec : std_ulogic_vector) return vpro_command_t is
        variable index : natural;
        variable cmd   : vpro_command_t;
    begin
        assert (vec'length = vpro_cmd_len_c) report "VPRO_VEC2CMD called with vector of wrong length! Required: " & integer'image(vpro_cmd_len_c) & ", Given: " & integer'image(vec'length) severity failure;
        index           := vpro_cmd_len_c;
        cmd.id          := vec(index - 1 downto index - vpro_cmd_id_len_c);
        index           := index - vpro_cmd_id_len_c;
        cmd.blocking    := vec(index - 1 downto index - vpro_cmd_blocking_len_c);
        index           := index - vpro_cmd_blocking_len_c;
        cmd.is_chain    := vec(index - 1 downto index - vpro_cmd_is_chain_len_c);
        index           := index - vpro_cmd_is_chain_len_c;
        cmd.fu_sel      := vec(index - 1 downto index - vpro_cmd_fu_sel_len_c);
        index           := index - vpro_cmd_fu_sel_len_c;
        cmd.func        := vec(index - 1 downto index - vpro_cmd_func_len_c);
        index           := index - vpro_cmd_func_len_c;
        cmd.f_update    := vec(index - 1 downto index - vpro_cmd_f_update_len_c);
        index           := index - vpro_cmd_f_update_len_c;
        cmd.dst_sel     := vec(index - 1 downto index - vpro_cmd_dst_sel_len_c);
        index           := index - vpro_cmd_dst_sel_len_c;
        cmd.dst_offset  := vec(index - 1 downto index - vpro_cmd_dst_offset_len_c);
        index           := index - vpro_cmd_dst_offset_len_c;
        cmd.dst_alpha   := vec(index - 1 downto index - vpro_cmd_dst_alpha_len_c);
        index           := index - vpro_cmd_dst_alpha_len_c;
        cmd.dst_beta    := vec(index - 1 downto index - vpro_cmd_dst_beta_len_c);
        index           := index - vpro_cmd_dst_beta_len_c;
        cmd.dst_gamma   := vec(index - 1 downto index - vpro_cmd_dst_gamma_len_c);
        index           := index - vpro_cmd_dst_gamma_len_c;
        cmd.src1_sel    := vec(index - 1 downto index - vpro_cmd_src1_sel_len_c);
        index           := index - vpro_cmd_src1_sel_len_c;
        cmd.src1_offset := vec(index - 1 downto index - vpro_cmd_src1_offset_len_c);
        index           := index - vpro_cmd_src1_offset_len_c;
        cmd.src1_alpha  := vec(index - 1 downto index - vpro_cmd_src1_alpha_len_c);
        index           := index - vpro_cmd_src1_alpha_len_c;
        cmd.src1_beta   := vec(index - 1 downto index - vpro_cmd_src1_beta_len_c);
        index           := index - vpro_cmd_src1_beta_len_c;
        cmd.src1_gamma  := vec(index - 1 downto index - vpro_cmd_src1_gamma_len_c);
        index           := index - vpro_cmd_src1_gamma_len_c;
        cmd.src2_sel    := vec(index - 1 downto index - vpro_cmd_src2_sel_len_c);
        index           := index - vpro_cmd_src2_sel_len_c;
        cmd.src2_offset := vec(index - 1 downto index - vpro_cmd_src2_offset_len_c);
        index           := index - vpro_cmd_src2_offset_len_c;
        cmd.src2_alpha  := vec(index - 1 downto index - vpro_cmd_src2_alpha_len_c);
        index           := index - vpro_cmd_src2_alpha_len_c;
        cmd.src2_beta   := vec(index - 1 downto index - vpro_cmd_src2_beta_len_c);
        index           := index - vpro_cmd_src2_beta_len_c;
        cmd.src2_gamma  := vec(index - 1 downto index - vpro_cmd_src2_gamma_len_c);
        index           := index - vpro_cmd_src2_gamma_len_c;
        cmd.x_end       := vec(index - 1 downto index - vpro_cmd_x_end_len_c);
        index           := index - vpro_cmd_x_end_len_c;
        cmd.y_end       := vec(index - 1 downto index - vpro_cmd_y_end_len_c);
        index           := index - vpro_cmd_y_end_len_c;
        cmd.z_end       := vec(index - 1 downto index - vpro_cmd_z_end_len_c);
        index           := index - vpro_cmd_z_end_len_c;

        assert (index = 0) report "Convert of VEC to VPRO CMD not used all bits. Remaining: " & integer'image(index) severity failure;
        return cmd;
    end;

    constant vpro_cmd_zero_c : vpro_command_t := vpro_vec2cmd(vpro_cmd_zero_vec_c);

    -- record to vector 
    function dma_cmd2vec(cmd : dma_command_t) return std_ulogic_vector is
        variable vec : std_ulogic_vector(dma_cmd_len_c - 1 downto 0);
    begin
        vec := cmd.cluster & cmd.unit_mask & --
               cmd.ext_base & cmd.loc_base & --
               cmd.x_size & cmd.y_size & cmd.x_stride & --
               cmd.dir & cmd.pad;
        return vec;
    end;

    -- vector to record
    function dma_vec2cmd(vec : std_ulogic_vector) return dma_command_t is
        variable index : natural;
        variable cmd   : dma_command_t;
    begin
        assert (vec'length = dma_cmd_len_c) report "DMA_VEC2CMD called with vector of wrong length! Required: " & integer'image(dma_cmd_len_c) & ", Given: " & integer'image(vec'length) severity failure;

        index         := dma_cmd_len_c;
        cmd.cluster   := vec(index - 1 downto index - dma_cmd_cluster_len_c);
        index         := index - dma_cmd_cluster_len_c;
        cmd.unit_mask := vec(index - 1 downto index - dma_cmd_unit_mask_len_c);
        index         := index - dma_cmd_unit_mask_len_c;
        cmd.ext_base  := vec(index - 1 downto index - dma_cmd_ext_base_len_c);
        index         := index - dma_cmd_ext_base_len_c;
        cmd.loc_base  := vec(index - 1 downto index - dma_cmd_loc_base_len_c);
        index         := index - dma_cmd_loc_base_len_c;
        cmd.x_size    := vec(index - 1 downto index - dma_cmd_x_size_len_c);
        index         := index - dma_cmd_x_size_len_c;
        cmd.y_size    := vec(index - 1 downto index - dma_cmd_y_size_len_c);
        index         := index - dma_cmd_y_size_len_c;
        cmd.x_stride  := vec(index - 1 downto index - dma_cmd_x_stride_len_c);
        index         := index - dma_cmd_x_stride_len_c;
        cmd.dir       := vec(index - 1 downto index - dma_cmd_dir_len_c);
        index         := index - dma_cmd_dir_len_c;
        cmd.pad       := vec(index - 1 downto index - dma_cmd_pad_len_c);
        index         := index - dma_cmd_pad_len_c;

        assert (index = 0) report "Convert of VEC to DMA CMD not used all bits. Remaining: " & integer'image(index) severity failure;
        return cmd;
    end;

    -- sepcial modify functions

    function vpro_cmd2src1_imm(cmd : vpro_command_t) return std_ulogic_vector is
        variable vec : std_ulogic_vector(vpro_cmd_src1_imm_len_c - 1 downto 0);
    begin
        vec := cmd.src1_offset & cmd.src1_alpha & cmd.src1_beta & cmd.src1_gamma;
        return vec;
    end;

    function vpro_cmd2src2_imm(cmd : vpro_command_t) return std_ulogic_vector is
        variable vec : std_ulogic_vector(vpro_cmd_src2_imm_len_c - 1 downto 0);
    begin
        vec := cmd.src2_offset & cmd.src2_alpha & cmd.src2_beta & cmd.src2_gamma;
        return vec;
    end;

    function vpro_cmd2dst_imm(cmd : vpro_command_t) return std_ulogic_vector is
        variable vec : std_ulogic_vector(vpro_cmd_dst_imm_len_c - 1 downto 0);
    begin
        vec := cmd.dst_offset & cmd.dst_alpha & cmd.dst_beta & cmd.dst_gamma;
        return vec;
    end;

    function vpro_src1_imm2cmd(cmd : vpro_command_t; imm : std_ulogic_vector) return vpro_command_t is
        variable newcmd  : vpro_command_t := cmd;
        variable imm_ext : std_ulogic_vector(vpro_cmd_src1_imm_len_c - 1 downto 0);
    begin
        newcmd             := cmd;
        imm_ext            := (others => imm(imm'left));
        imm_ext(imm'range) := imm;
        newcmd.src1_offset := imm_ext(vpro_cmd_src1_offset_len_c + vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
        newcmd.src1_alpha  := imm_ext(vpro_cmd_src1_alpha_len_c + vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c);
        newcmd.src1_beta   := imm_ext(vpro_cmd_src1_beta_len_c + vpro_cmd_src1_gamma_len_c - 1 downto vpro_cmd_src1_gamma_len_c);
        newcmd.src1_gamma  := imm_ext(vpro_cmd_src1_gamma_len_c - 1 downto 0);
        return newcmd;
    end;

    function vpro_src2_imm2cmd(cmd : vpro_command_t; imm : std_ulogic_vector) return vpro_command_t is
        variable newcmd  : vpro_command_t := cmd;
        variable imm_ext : std_ulogic_vector(vpro_cmd_src2_imm_len_c - 1 downto 0);
    begin
        newcmd             := cmd;
        imm_ext            := (others => imm(imm'left));
        imm_ext(imm'range) := imm;
        newcmd.src2_offset := imm_ext(vpro_cmd_src2_offset_len_c + vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
        newcmd.src2_alpha  := imm_ext(vpro_cmd_src2_alpha_len_c + vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c);
        newcmd.src2_beta   := imm_ext(vpro_cmd_src2_beta_len_c + vpro_cmd_src2_gamma_len_c - 1 downto vpro_cmd_src2_gamma_len_c);
        newcmd.src2_gamma  := imm_ext(vpro_cmd_src2_gamma_len_c - 1 downto 0);
        return newcmd;
    end;

    -- Function: Minimum required bit width ---------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function index_size(input : natural) return natural is
    begin
        if (input = 0) then
            return 0;
        end if;
        for i in 0 to natural'high loop
            if (2 ** i >= input) then
                return i;
            end if;
        end loop;
        return 0;
    end function index_size;

    -- Function: Bit reversal -----------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function bit_reversal(input : std_ulogic_vector) return std_ulogic_vector is
        variable output_v : std_ulogic_vector(input'range);
    begin
        for i in 0 to input'length - 1 loop
            output_v(input'length - i - 1) := input(i);
        end loop;                       -- i
        return output_v;
    end function bit_reversal;

    -- Function: Count number of set bits (aka population count) ------------------------------
    -- -------------------------------------------------------------------------------------------
    function set_bits(input : std_ulogic_vector) return natural is
        variable cnt_v : natural range 0 to input'length - 1;
    begin
        cnt_v := 0;
        for i in input'length - 1 downto 0 loop
            if (input(i) = '1') then
                cnt_v := cnt_v + 1;
            end if;
        end loop;                       -- i
        return cnt_v;
    end function set_bits;

    -- Function: Count leading zeros ----------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function leading_zeros(input : std_ulogic_vector) return natural is
        variable cnt_v : natural range 0 to input'length;
    begin
        cnt_v := 0;
        for i in input'length - 1 downto 0 loop
            if (input(i) = '0') then
                cnt_v := cnt_v + 1;
            else
                exit;
            end if;
        end loop;                       -- i
        return cnt_v;
    end function leading_zeros;

    -- Function: Conditional select natural ---------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function cond_sel_natural(cond : boolean; val_t : natural; val_f : natural) return natural is
    begin
        if (cond) then
            return val_t;
        else
            return val_f;
        end if;
    end function cond_sel_natural;

    -- Function: Conditional select std_ulogic_vector -----------------------------------------
    -- -------------------------------------------------------------------------------------------
    function cond_sel_stdulogicvector(cond : boolean; val_t : std_ulogic_vector; val_f : std_ulogic_vector) return std_ulogic_vector is
    begin
        if (cond) then
            return val_t;
        else
            return val_f;
        end if;
    end function cond_sel_stdulogicvector;

    -- Function: Convert BOOL to STD_ULOGIC ---------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function bool_to_ulogic(cond : boolean) return std_ulogic is
    begin
        if (cond) then
            return '1';
        else
            return '0';
        end if;
    end function bool_to_ulogic;

    -- Function: Binary to Gray ---------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function bin_to_gray(input : std_ulogic_vector) return std_ulogic_vector is
        variable output_v : std_ulogic_vector(input'range);
    begin
        output_v(input'length - 1) := input(input'length - 1); -- keep MSB
        for i in input'length - 2 downto 0 loop
            output_v(i) := input(i) xor input(i + 1);
        end loop;                       -- i
        return output_v;
    end function bin_to_gray;

    -- Function: Gray to Binary ---------------------------------------------------------------
    -- -------------------------------------------------------------------------------------------
    function gray_to_bin(input : std_ulogic_vector) return std_ulogic_vector is
        variable output_v : std_ulogic_vector(input'range);
    begin
        output_v(input'length - 1) := input(input'length - 1); -- keep MSB
        for i in input'length - 2 downto 0 loop
            output_v(i) := output_v(i + 1) xor input(i);
        end loop;                       -- i
        return output_v;
    end function gray_to_bin;

    function int_match(l : std_ulogic_vector; r : std_ulogic_vector) return boolean is
        variable flag : boolean;
    begin
        flag := true;
        for i in l'range loop
            flag := flag and ((r(i) = '-') or (r(i) = '1' and l(i) = '1') or (r(i) = '0' and l(i) = '0'));
        end loop;
        return flag;
    end int_match;

    function count_ones(s : std_ulogic_vector) return integer is
        variable temp : natural := 0;
    begin
        for i in s'range loop
            if s(i) = '1' then
                temp := temp + 1;
            end if;
        end loop;
        return temp;
    end function count_ones;

    function count_zeros(s : std_ulogic_vector) return integer is
        variable temp : natural := 0;
    begin
        for i in s'range loop
            if s(i) = '0' then
                temp := temp + 1;
            end if;
        end loop;
        return temp;
    end function count_zeros;
end v2pro_package;

