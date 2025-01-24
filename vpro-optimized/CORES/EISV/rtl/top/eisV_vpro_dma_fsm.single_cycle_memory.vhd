--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
-- #############################################################################
-- #                                                                           #
-- # VPRO DMA Command FSM to fetch and trigger DMA commands from the DCache of #
-- #   the RISC-V (multi word read cache line)                                 #
-- #                                                                           #
-- #############################################################################

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
entity eisV_vpro_dma_fsm is
    port(
        clk_i              : in  std_ulogic;
        rst_i              : in  std_ulogic;
        core_data_addr_i   : in  std_ulogic_vector(31 downto 0);
        core_data_req_i    : in  std_ulogic;
        core_data_we_i     : in  std_ulogic;
        core_data_be_i     : in  std_ulogic_vector(3 downto 0);
        core_data_wdata_i  : in  std_ulogic_vector(31 downto 0);
        dcache_addr_o      : out std_ulogic_vector(31 downto 0);
        dcache_req_o       : out std_ulogic;
        dcache_instr_i     : in  multi_cmd_t;
        dcache_rvalid_i    : in  std_ulogic;
        active_o           : out std_ulogic;
        dma_cmd_full_i     : in  std_ulogic;
        dma_cmd_we_o       : out std_ulogic;
        dma_cmd_o          : out dma_command_t;
        vpro_ext_dma_cmd_i : in  dma_command_t;
        vpro_ext_dma_we_i  : in  std_ulogic
    );
end entity;

architecture RTL of eisV_vpro_dma_fsm is

    -- always generated:
    constant SINGLE_DMA_TRIGGER                                                  : std_ulogic_vector(31 downto 0) := x"FFFFFE48";
    constant SINGLE_DAM_TRIGGER_CLUSTER_IS_INT_INSTEAD_MASK_DOWNWARD_COMP_DEPREC : boolean                        := true; -- TODO ?

    -- FSM:
    constant DO_VPRO_DMA_FSM_gen       : boolean                        := true;
    constant FSM_SIZE                  : std_ulogic_vector(31 downto 0) := x"FFFFFE40";
    constant FSM_START_ADDRESS_TRIGGER : std_ulogic_vector(31 downto 0) := x"FFFFFE44";
    constant DMA_BYTE_OFFSET_IN_MEM    : integer                        := 32;

    type fsm_t is (IDLE, FETCH_DMA, FINAL_FETCH, FETCH_SINGLE_DMA);
    signal fsm_nxt, fsm_ff : fsm_t;

    signal base_addr_nxt, base_addr_ff : std_ulogic_vector(31 downto 0);
    signal size_reg_nxt, size_reg_ff   : std_ulogic_vector(31 downto 0); -- equals end_addr after trigger

    -- only required for dma io only:
    signal io_dma_issue, io_dma_issue_ff : std_ulogic;
begin

    VPRO_DMA_FSM_gen : if DO_VPRO_DMA_FSM_gen generate
        assert (DMA_BYTE_OFFSET_IN_MEM = 32) report "[DMA Command FSM] Address will always increment by 32-byte! Changes need vhdl modifications!" severity failure;

        snyc : process(clk_i, rst_i)
        begin
            if (rst_i = '1') then
                fsm_ff          <= IDLE;
                size_reg_ff     <= (others => '0');
                io_dma_issue_ff <= '0';
            elsif rising_edge(clk_i) then
                base_addr_ff    <= base_addr_nxt;
                fsm_ff          <= fsm_nxt;
                size_reg_ff     <= size_reg_nxt;
                io_dma_issue_ff <= io_dma_issue;
            end if;
        end process;

        fsm : process(fsm_ff, core_data_addr_i, core_data_be_i, core_data_req_i, core_data_we_i, base_addr_ff, core_data_wdata_i, size_reg_ff, dcache_instr_i, dcache_rvalid_i, vpro_ext_dma_cmd_i, vpro_ext_dma_we_i, dma_cmd_full_i, io_dma_issue_ff)
            variable nxt_addr : std_ulogic_vector(31 downto 0);
            variable pad_0    : std_ulogic_vector(7 downto 0);
            variable pad_1    : std_ulogic_vector(7 downto 0);
            variable pad_2    : std_ulogic_vector(7 downto 0);
            variable pad_3    : std_ulogic_vector(7 downto 0);
        begin
            fsm_nxt       <= fsm_ff;
            size_reg_nxt  <= size_reg_ff;
            base_addr_nxt <= base_addr_ff;
            io_dma_issue  <= io_dma_issue_ff;

            active_o      <= '0';
            dcache_req_o  <= '0';
            dcache_addr_o <= (others => '0');

            dma_cmd_we_o        <= '0';
            dma_cmd_o.cluster   <= (others => '0');
            dma_cmd_o.unit_mask <= (others => '0');
            dma_cmd_o.ext_base  <= (others => '0');
            dma_cmd_o.loc_base  <= (others => '0');
            dma_cmd_o.x_stride  <= (others => '0');
            dma_cmd_o.x_size    <= (others => '0');
            dma_cmd_o.y_size    <= (others => '0');
            dma_cmd_o.dir       <= "0"; -- e 2 l
            dma_cmd_o.pad       <= (others => '0');

            case (fsm_ff) is
                when IDLE =>
                    if vpro_ext_dma_we_i = '1' then
                        -- issue of dma command from Custom Risc-V VPRO Extension (VPRO/DMA Registerfile) 
                        dma_cmd_o    <= vpro_ext_dma_cmd_i;
                        dma_cmd_we_o <= '1';
                    end if;

                    if (core_data_we_i = '1') and (core_data_be_i = "1111") and (core_data_req_i = '1') then
                        if (core_data_addr_i = FSM_START_ADDRESS_TRIGGER) then
                            base_addr_nxt <= core_data_wdata_i;
                            -- store last valid addr: (size - 1) * 32 (5x'0') + start
                            -- multiply with 32 by using a shift by 5
                            size_reg_nxt  <= std_ulogic_vector(shift_left(unsigned(size_reg_ff), 5) + unsigned(core_data_wdata_i) - to_unsigned(32, 32));
                            if unsigned(size_reg_ff) = 1 then -- single fetch
                                fsm_nxt <= FINAL_FETCH;
                            else        -- fetch >= 2
                                fsm_nxt <= FETCH_DMA;
                            end if;
                            active_o      <= '1';
                            dcache_req_o  <= '1';
                            dcache_addr_o <= core_data_wdata_i;
                        elsif (core_data_addr_i = FSM_SIZE) then
                            size_reg_nxt <= core_data_wdata_i;
                            --                            assert (core_data_wdata_i /= x"00000000") report "DMA Command FSM got size of 0! Need to be larger/equal 1!" severity failure;
                            active_o     <= '1';
                        elsif (core_data_addr_i = SINGLE_DMA_TRIGGER) then
                            fsm_nxt       <= FETCH_SINGLE_DMA;
                            active_o      <= '1';
                            dcache_req_o  <= '1';
                            dcache_addr_o <= core_data_wdata_i;
                        end if;
                    end if;

                when FETCH_DMA =>
                    active_o <= '1';
                    -- wait for valid + trigger dma + fetch new if not yet done
                    if dcache_rvalid_i = '1' then
                        pad_0               := dcache_instr_i(5)(23 downto 16);
                        pad_1               := dcache_instr_i(5)(31 downto 24);
                        pad_2               := dcache_instr_i(6)(07 downto 00);
                        pad_3               := dcache_instr_i(6)(15 downto 08);
                        dma_cmd_o.cluster   <= dcache_instr_i(0)(31 downto 24);
                        dma_cmd_o.unit_mask <= dcache_instr_i(1)(31 downto 0);
                        dma_cmd_o.ext_base  <= dcache_instr_i(2)(31 downto 0);
                        dma_cmd_o.loc_base  <= dcache_instr_i(3)(31 downto 0);
                        dma_cmd_o.x_stride  <= dcache_instr_i(4)(15 - 3 downto 00);
                        dma_cmd_o.x_size    <= dcache_instr_i(4)(31 - 3 downto 16);
                        dma_cmd_o.y_size    <= dcache_instr_i(5)(15 - 3 downto 00);
                        dma_cmd_o.dir(0)    <= dcache_instr_i(0)(01);
                        dma_cmd_o.pad       <= pad_0(0) & pad_1(0) & pad_2(0) & pad_3(0);
                        -- TOP (0) , RIGHT (1) , BOTTOM (2) , LEFT (3) from SW / in DMA
                        --            dma_cmd_o.pad       <= pad_3(0) & pad_2(0) & pad_1(0) & pad_0(0); -- orig from mips
                        dma_cmd_we_o        <= '1';

                        if dma_cmd_full_i = '1' then
                            io_dma_issue <= '1';
                        else
                            io_dma_issue  <= '0';
                            dcache_req_o  <= '1';
                            nxt_addr      := std_ulogic_vector(unsigned(base_addr_ff) + to_unsigned(32, 32));
                            base_addr_nxt <= nxt_addr;
                            dcache_addr_o <= nxt_addr;
                            if nxt_addr = size_reg_ff then
                                fsm_nxt <= FINAL_FETCH;
                            end if;
                            io_dma_issue  <= '0';
                        end if;
                    end if;
                    if io_dma_issue_ff = '1' and dma_cmd_full_i = '0' then -- TODO: add buffer (one cycle earlier) -> TODO: 2 cycle latency adoption
                        dcache_req_o  <= '1';
                        nxt_addr      := std_ulogic_vector(unsigned(base_addr_ff) + to_unsigned(32, 32));
                        base_addr_nxt <= nxt_addr;
                        dcache_addr_o <= nxt_addr;
                        if nxt_addr = size_reg_ff then
                            fsm_nxt <= FINAL_FETCH;
                        end if;
                        io_dma_issue  <= '0';
                    end if;

                when FINAL_FETCH =>
                    active_o <= '1';
                    -- wait for valid + trigger dma
                    if dcache_rvalid_i = '1' then
                        pad_0               := dcache_instr_i(5)(23 downto 16);
                        pad_1               := dcache_instr_i(5)(31 downto 24);
                        pad_2               := dcache_instr_i(6)(07 downto 00);
                        pad_3               := dcache_instr_i(6)(15 downto 08);
                        dma_cmd_o.cluster   <= dcache_instr_i(0)(31 downto 24);
                        dma_cmd_o.unit_mask <= dcache_instr_i(1)(31 downto 0);
                        dma_cmd_o.ext_base  <= dcache_instr_i(2)(31 downto 0);
                        dma_cmd_o.loc_base  <= dcache_instr_i(3)(31 downto 0);
                        dma_cmd_o.x_stride  <= dcache_instr_i(4)(15 - 3 downto 00);
                        dma_cmd_o.x_size    <= dcache_instr_i(4)(31 - 3 downto 16);
                        dma_cmd_o.y_size    <= dcache_instr_i(5)(15 - 3 downto 00);
                        dma_cmd_o.dir(0)    <= dcache_instr_i(0)(01);
                        dma_cmd_o.pad       <= pad_0(0) & pad_1(0) & pad_2(0) & pad_3(0);
                        -- TOP (0) , RIGHT (1) , BOTTOM (2) , LEFT (3) from SW / in DMA
                        --            dma_cmd_o.pad       <= pad_3(0) & pad_2(0) & pad_1(0) & pad_0(0); -- orig from mips
                        dma_cmd_we_o        <= '1';
                        fsm_nxt             <= IDLE;
                    end if;

                when FETCH_SINGLE_DMA =>
                    active_o <= '1';
                    -- wait for valid + trigger dma
                    if dcache_rvalid_i = '1' then
                        pad_0 := dcache_instr_i(5)(23 downto 16);
                        pad_1 := dcache_instr_i(5)(31 downto 24);
                        pad_2 := dcache_instr_i(6)(07 downto 00);
                        pad_3 := dcache_instr_i(6)(15 downto 08);

                        if SINGLE_DAM_TRIGGER_CLUSTER_IS_INT_INSTEAD_MASK_DOWNWARD_COMP_DEPREC then
                            dma_cmd_o.cluster                                                        <= (others => '0');
                            dma_cmd_o.cluster(to_integer(unsigned(dcache_instr_i(0)(31 downto 24)))) <= '1';
                        else
                            dma_cmd_o.cluster <= dcache_instr_i(0)(31 downto 24);
                        end if;

                        dma_cmd_o.unit_mask <= dcache_instr_i(1)(31 downto 0);
                        dma_cmd_o.ext_base  <= dcache_instr_i(2)(31 downto 0);
                        dma_cmd_o.loc_base  <= dcache_instr_i(3)(31 downto 0);
                        dma_cmd_o.x_stride  <= dcache_instr_i(4)(15 - 3 downto 00);
                        dma_cmd_o.x_size    <= dcache_instr_i(4)(31 - 3 downto 16);
                        dma_cmd_o.y_size    <= dcache_instr_i(5)(15 - 3 downto 00);
                        dma_cmd_o.dir(0)    <= dcache_instr_i(0)(01);
                        dma_cmd_o.pad       <= pad_0(0) & pad_1(0) & pad_2(0) & pad_3(0);
                        -- TOP (0) , RIGHT (1) , BOTTOM (2) , LEFT (3) from SW / in DMA
                        --            dma_cmd_o.pad       <= pad_3(0) & pad_2(0) & pad_1(0) & pad_0(0); -- orig from mips
                        dma_cmd_we_o        <= '1';
                        fsm_nxt             <= IDLE;
                    end if;

            end case;
        end process;

    end generate;

    NO_VPRO_DMA_FSM_gen : if not DO_VPRO_DMA_FSM_gen generate
        -- standard behavior (only  => is the address to trigger a single DMA command)

        -- DMA IF (Shortcut via dcache (line-)aligned dma commands)
        -- triggererd upon write of base address to  => 
        -- special dma io issue
        io_dma_issue <= '1' when (core_data_addr_i = SINGLE_DMA_TRIGGER) and (core_data_we_i = '1') and (core_data_be_i = "1111") and (core_data_req_i = '1') else
                        '0';

        active_o <= io_dma_issue;

        dcache_req_o  <= core_data_req_i;
        dcache_addr_o <= core_data_wdata_i;

        -- register io_dma access
        io_dma_dcache_access_ff : process(clk_i, rst_i)
        begin
            if (rst_i = '1') then
                io_dma_issue_ff <= '0';
            elsif rising_edge(clk_i) then
                if io_dma_issue = '1' then
                    io_dma_issue_ff <= '1';
                elsif (io_dma_issue_ff = '1' and dcache_rvalid_i = '1') then
                    io_dma_issue_ff <= '0';
                end if;
            end if;
        end process io_dma_dcache_access_ff;

        -- parse result as dma
        io_dma_access_data : process(io_dma_issue_ff, dcache_instr_i, dcache_rvalid_i, vpro_ext_dma_cmd_i, vpro_ext_dma_we_i)
            variable pad_0 : std_ulogic_vector(7 downto 0);
            variable pad_1 : std_ulogic_vector(7 downto 0);
            variable pad_2 : std_ulogic_vector(7 downto 0);
            variable pad_3 : std_ulogic_vector(7 downto 0);
        begin
            dma_cmd_we_o        <= '0';
            dma_cmd_o.cluster   <= (others => '0');
            dma_cmd_o.unit_mask <= (others => '0');
            dma_cmd_o.ext_base  <= (others => '0');
            dma_cmd_o.loc_base  <= (others => '0');
            dma_cmd_o.x_stride  <= (others => '0');
            dma_cmd_o.x_size    <= (others => '0');
            dma_cmd_o.y_size    <= (others => '0');
            dma_cmd_o.dir       <= "0"; -- e 2 l
            dma_cmd_o.pad       <= (others => '0');

            if (io_dma_issue_ff = '1' and dcache_rvalid_i = '1') then
                -- special issue of dma command from dcache (all parameters loaded by cache in parallel)
                -- use as dma command . . .
                --            is_bias_offset   := dc_multiword_output(0)(15 downto 08);
                --            is_kernel_offset := dc_multiword_output(0)(23 downto 16);
                pad_0 := dcache_instr_i(5)(23 downto 16);
                pad_1 := dcache_instr_i(5)(31 downto 24);
                pad_2 := dcache_instr_i(6)(07 downto 00);
                pad_3 := dcache_instr_i(6)(15 downto 08);

                if SINGLE_DAM_TRIGGER_CLUSTER_IS_INT_INSTEAD_MASK_DOWNWARD_COMP_DEPREC then
                    dma_cmd_o.cluster                                                        <= (others => '0');
                    dma_cmd_o.cluster(to_integer(unsigned(dcache_instr_i(0)(31 downto 24)))) <= '1';
                else
                    dma_cmd_o.cluster <= dcache_instr_i(0)(31 downto 24);
                end if;

                dma_cmd_o.unit_mask <= dcache_instr_i(1)(31 downto 0);
                dma_cmd_o.ext_base  <= dcache_instr_i(2)(31 downto 0);
                dma_cmd_o.loc_base  <= dcache_instr_i(3)(31 downto 0);
                dma_cmd_o.x_stride  <= dcache_instr_i(4)(15 - 3 downto 00);
                dma_cmd_o.x_size    <= dcache_instr_i(4)(31 - 3 downto 16);
                dma_cmd_o.y_size    <= dcache_instr_i(5)(15 - 3 downto 00);

                dma_cmd_o.dir(0) <= dcache_instr_i(0)(01);
                dma_cmd_o.pad    <= pad_0(0) & pad_1(0) & pad_2(0) & pad_3(0);

                -- TOP (0) , RIGHT (1) , BOTTOM (2) , LEFT (3) from SW / in DMA
                --            dma_cmd_o.pad       <= pad_3(0) & pad_2(0) & pad_1(0) & pad_0(0); -- orig from mips

                dma_cmd_we_o <= '1';

            elsif vpro_ext_dma_we_i = '1' then
                -- issue of dma command from Custom Risc-V VPRO Extension (VPRO/DMA Registerfile) 
                dma_cmd_o    <= vpro_ext_dma_cmd_i;
                dma_cmd_we_o <= '1';
            end if;
        end process io_dma_access_data;

    end generate;
end architecture RTL;
