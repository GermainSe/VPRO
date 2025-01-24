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

package v2pro_package is

    --- 
    --   VPRO Instruction Word Layout
    ---
    constant vpro_cmd_id_len_c          : natural := 3;
    constant vpro_cmd_blocking_len_c    : natural := 1;
    constant vpro_cmd_is_chain_len_c    : natural := 1;
    constant vpro_cmd_fu_sel_len_c      : natural := 2;
    constant vpro_cmd_func_len_c        : natural := 4;
    constant vpro_cmd_f_update_len_c    : natural := 1;
    constant vpro_cmd_dst_sel_len_c     : natural := 3;
    constant vpro_cmd_dst_offset_len_c  : natural := 10;
    constant vpro_cmd_dst_alpha_len_c   : natural := 6;
    constant vpro_cmd_dst_beta_len_c    : natural := 6;
    constant vpro_cmd_dst_gamma_len_c   : natural := 6;
    constant vpro_cmd_src1_sel_len_c    : natural := 3;
    constant vpro_cmd_src1_offset_len_c : natural := 10;
    constant vpro_cmd_src1_alpha_len_c  : natural := 6;
    constant vpro_cmd_src1_beta_len_c   : natural := 6;
    constant vpro_cmd_src1_gamma_len_c  : natural := 6;
    constant vpro_cmd_src2_sel_len_c    : natural := 3;
    constant vpro_cmd_src2_offset_len_c : natural := 10;
    constant vpro_cmd_src2_alpha_len_c  : natural := 6;
    constant vpro_cmd_src2_beta_len_c   : natural := 6;
    constant vpro_cmd_src2_gamma_len_c  : natural := 6;
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
    constant dma_cmd_x_size_len_c    : natural := 13;
    constant dma_cmd_y_size_len_c    : natural := 13;
    constant dma_cmd_x_stride_len_c  : natural := 13;
    constant dma_cmd_dir_len_c       : natural := 1;
    constant dma_cmd_pad_len_c       : natural := 4;

    constant dma_cmd_len_c : natural := dma_cmd_cluster_len_c + dma_cmd_unit_mask_len_c + --
                                        dma_cmd_ext_base_len_c + dma_cmd_loc_base_len_c + --
                                        dma_cmd_x_size_len_c + dma_cmd_y_size_len_c + dma_cmd_x_stride_len_c + --
                                        dma_cmd_dir_len_c + dma_cmd_pad_len_c;

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

    -- io addresses
    -- dma fsm
    constant io_addr_dma_ext_base_e2l_c  : std_ulogic_vector(7 downto 2) := "110010"; -- C8 -- trigger
    constant io_addr_dma_ext_base_l2e_c  : std_ulogic_vector(7 downto 2) := "110011"; -- CC -- trigger    
    -- io fabric
    constant io_addr_sync_dma_c     : std_ulogic_vector(7 downto 2) := "000110"; -- 0x--18  -- read for mask sync return for DMA (bool)
    constant io_addr_sync_vpro_c    : std_ulogic_vector(7 downto 2) := "000111"; -- 0x--1C  -- read for mask sync return for VPRO System (bool)
    constant io_addr_cluster_busy_c      : std_ulogic_vector(7 downto 2) := "000010"; -- 0x--08  -- read for return of bitmask (unit busy) in this cluster?
    constant io_addr_sync_cl_mask_c : std_ulogic_vector(7 downto 2) := "000100"; -- 0x--10  -- write to set cluster mask for mask sync
    constant io_addr_dma_busy_addr_c     : std_ulogic_vector(7 downto 2) := "101111"; -- is zero when DMA is idle, queue_full & busy_sync2

    -- record to vector 
    function dma_cmd2vec(cmd : dma_command_t) return std_ulogic_vector;
    -- vector to record
    function dma_vec2cmd(vec : std_ulogic_vector) return dma_command_t;

    function index_size(input : natural) return natural;

    function int_match(l : std_ulogic_vector; r : std_ulogic_vector) return boolean;
        
end v2pro_package;

-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------
-- -------------------------------------------------------------------------------------------

package body v2pro_package is

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
    
    
    function int_match(l : std_ulogic_vector; r : std_ulogic_vector) return boolean is
        variable flag : boolean;
    begin
        flag := true;
        for i in l'range loop
            flag := flag and ((r(i) = '-') or (r(i) = '1' and l(i) = '1') or (r(i) = '0' and l(i) = '0'));
        end loop;
        return flag;
    end int_match;

end v2pro_package;

