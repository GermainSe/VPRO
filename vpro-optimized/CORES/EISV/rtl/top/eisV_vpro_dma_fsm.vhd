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

library core_v2pro;
use core_v2pro.v2pro_package.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_vpro_dma_fsm is
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
end entity;

architecture RTL of eisV_vpro_dma_fsm is

    constant DMA_BYTE_OFFSET_IN_MEM : integer := 32;

    type fsm_t is (IDLE, BLOCK_LOOP, FINAL);
    signal state_nxt, state_ff : fsm_t;

    signal core_access_addr_trigger : std_ulogic;
    signal core_acces_size          : std_ulogic;
    signal core_single_dma_trigger  : std_ulogic;

    signal active_int : std_ulogic;
    signal fsm_req    : std_ulogic;
    signal fsm_dma    : multi_cmd_t;

    signal size_nxt, size_ff           : unsigned(31 downto 0);
    signal base_addr_nxt, base_addr_ff : std_ulogic_vector(31 downto 0);

    signal outstanding_nxt, outstanding_ff : unsigned(1 downto 0); -- range -1 to 4;

    --
    -- The buffer for requested data (but cmd fifo of dma signals full)
    --
    type buffer_fsm_t is (FALLTHROUGH, BUFFER_1, BUFFER_2, BUFFER_3);
    signal buffer_state_nxt, buffer_state_ff : buffer_fsm_t;

    signal buffer_cnt_nxt, buffer_cnt_ff : unsigned(1 downto 0); --integer range 0 to 3;

    type buffer_t is array (0 to 1) of multi_cmd_t;
    signal buffer_nxt, buffer_ff : buffer_t;

    signal dcache_stall_ff                                           : std_ulogic;
    signal core_access_addr_trigger_nxt, core_access_addr_trigger_ff : std_ulogic;
    signal core_single_dma_trigger_nxt, core_single_dma_trigger_ff   : std_ulogic;
    signal vpro_fsm_stall_ff, vpro_fsm_stall_ff2                     : std_ulogic;
    signal fsm_stall_int                                             : std_ulogic;
    signal io_dma_trigger, io_dma_trigger_ff                         : std_ulogic;

    signal dma_cmd_we_int : std_ulogic;
    signal dma_cmd_int    : multi_cmd_t;

begin

    fsm_stall_int <= '1' when vpro_fsm_stall_i = '1' else io_dma_trigger;

    io_dma_trigger <= '1' when core_data_addr_i(31 downto 16) = x"FFFE" and core_data_we_i = '1' and core_data_req_i = '1' and --
                      ((core_data_addr_i(io_addr_dma_ext_base_l2e_c'range) = io_addr_dma_ext_base_l2e_c) or --
                       (core_data_addr_i(io_addr_dma_ext_base_e2l_c'range) = io_addr_dma_ext_base_e2l_c)) else -- vpro access on io (= dma cmd create)
                      '0';

    registers : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            state_ff          <= IDLE;
            size_ff           <= (others => '0');
            base_addr_ff      <= (others => '0');
            outstanding_ff    <= (others => '0');
            dcache_stall_ff   <= '0';
            vpro_fsm_stall_ff <= '0';
            io_dma_trigger_ff <= '0';

            core_access_addr_trigger_ff <= '0';
            core_single_dma_trigger_ff  <= '0';
        elsif rising_edge(clk_i) then
            base_addr_ff       <= base_addr_nxt;
            state_ff           <= state_nxt;
            size_ff            <= size_nxt;
            base_addr_ff       <= base_addr_nxt;
            outstanding_ff     <= outstanding_nxt;
            dcache_stall_ff    <= dcache_stall_i;
            vpro_fsm_stall_ff  <= fsm_stall_int;
            vpro_fsm_stall_ff2 <= vpro_fsm_stall_ff;
            io_dma_trigger_ff  <= io_dma_trigger;

            core_access_addr_trigger_ff <= core_access_addr_trigger_nxt;
            core_single_dma_trigger_ff  <= core_single_dma_trigger_nxt;
        end if;
    end process;

    core_access : process(core_data_addr_i, core_data_be_i, core_data_req_i, core_data_we_i)
    begin
        core_access_addr_trigger <= '0';
        core_acces_size          <= '0';
        core_single_dma_trigger  <= '0';
        if (core_data_we_i = '1') and (core_data_be_i = "1111") and (core_data_req_i = '1') then
            if (core_data_addr_i = FSM_START_ADDRESS_TRIGGER) then
                core_access_addr_trigger <= '1';
            elsif (core_data_addr_i = FSM_SIZE) then
                core_acces_size <= '1';
            elsif (core_data_addr_i = SINGLE_DMA_TRIGGER) then
                core_single_dma_trigger <= '1';
            end if;
        end if;
    end process;

    outstanding_nxt <= outstanding_ff + 1 when fsm_req = '1' and dcache_stall_i = '0' and dcache_rvalid_i = '0' and active_int = '1' else --fsm_stall_int already in fsm_req
                       outstanding_ff - 1 when fsm_req = '0' and outstanding_ff /= 0 and dcache_rvalid_i = '1' and active_int = '1' and vpro_fsm_stall_ff2 = '0' else -- TODO: remove /= 0 when be shure of rdata_valid onlly on req items 
                       outstanding_ff - 1 when fsm_req = '1' and dcache_stall_i = '1' and dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '0' and active_int = '1' else
                       outstanding_ff;

    fsm_dma  <= dcache_instr_i;
    active_o <= active_int;

    size_addr_cnt : process(base_addr_ff, core_data_wdata_i, core_acces_size, core_access_addr_trigger, fsm_req, size_ff, core_single_dma_trigger)
    begin
        size_nxt      <= size_ff;
        base_addr_nxt <= base_addr_ff;

        if core_acces_size = '1' then
            size_nxt <= unsigned(core_data_wdata_i);
        end if;
        if core_access_addr_trigger = '1' then
            base_addr_nxt <= std_ulogic_vector(unsigned(core_data_wdata_i));
        elsif core_single_dma_trigger = '1' then
            size_nxt      <= to_unsigned(1, size_nxt'length);
            base_addr_nxt <= std_ulogic_vector(unsigned(core_data_wdata_i));
        elsif fsm_req = '1' then
            size_nxt      <= unsigned(size_ff) - 1;
            base_addr_nxt <= std_ulogic_vector(unsigned(base_addr_ff) + DMA_BYTE_OFFSET_IN_MEM);
        end if;
    end process;

    fsm_p : process(state_ff, dcache_stall_ff, buffer_cnt_ff, dma_cmd_full_i, outstanding_ff, core_access_addr_trigger, base_addr_ff, size_ff, core_single_dma_trigger, dcache_rvalid_i, dcache_stall_i, core_access_addr_trigger_ff, core_single_dma_trigger_ff, fsm_stall_int, vpro_fsm_stall_ff)
    begin
        state_nxt <= state_ff;

        core_access_addr_trigger_nxt <= core_access_addr_trigger_ff;
        core_single_dma_trigger_nxt  <= core_single_dma_trigger_ff;

        dcache_req_o  <= '0';
        dcache_addr_o <= (others => '-');
        active_int    <= '0';
        fsm_req       <= '0';

        case (state_ff) is
            when IDLE =>
                if (core_access_addr_trigger = '1' or core_access_addr_trigger_ff = '1') and dcache_stall_i = '0' and fsm_stall_int = '0' then
                    core_access_addr_trigger_nxt <= '0';
                    state_nxt                    <= BLOCK_LOOP;
                elsif (core_access_addr_trigger = '1' and dcache_stall_i = '1') or (core_access_addr_trigger = '1' and fsm_stall_int = '1') then -- stall trigger
                    core_access_addr_trigger_nxt <= '1';
                end if;

                if (core_single_dma_trigger = '1' or core_single_dma_trigger_ff = '1') and dcache_stall_i = '0' and fsm_stall_int = '0' then
                    core_single_dma_trigger_nxt <= '0';
                    state_nxt                   <= BLOCK_LOOP;
                elsif (core_single_dma_trigger = '1' and dcache_stall_i = '1') or (core_single_dma_trigger = '1' and fsm_stall_int = '1') then -- stall trigger
                    core_single_dma_trigger_nxt <= '1';
                end if;

            when BLOCK_LOOP =>
                active_int <= '1';
                if size_ff = 0 then
                    state_nxt <= FINAL;
                else
                    if (fsm_stall_int = '0') then -- no new req
                        if (dma_cmd_full_i = '0' and (buffer_cnt_ff + outstanding_ff <= 2) and (dcache_rvalid_i = '1' and vpro_fsm_stall_ff = '0')) or -- in flow (buffer is on max (2))
                            (dma_cmd_full_i = '0' and (buffer_cnt_ff + outstanding_ff <= 1)) then -- no flow yet (but buffer has free entrie)
                            if dcache_stall_i = '0' and dcache_stall_ff = '0' then -- already requested but stalled by  dcache. addr will buffer, outstanding will not count up
                                fsm_req       <= '1';
                                dcache_req_o  <= '1';
                                dcache_addr_o <= base_addr_ff;
                            end if;
                        end if;
                    end if;
                end if;

            when FINAL =>
                -- wait for last rdata return + empty buffers before enable to start new block/dma command
                active_int <= '1';
                if outstanding_ff = 0 and buffer_cnt_ff = 0 then
                    state_nxt <= IDLE;
                end if;
        end case;
    end process;

    buffer_registers : process(clk_i)
    begin
        if rising_edge(clk_i) then
            if (rst_i = '1') then
                buffer_state_ff <= FALLTHROUGH;
                buffer_cnt_ff   <= (others => '0');
            else
                buffer_state_ff <= buffer_state_nxt;
                buffer_cnt_ff   <= buffer_cnt_nxt;
                buffer_ff       <= buffer_nxt;
            end if;
        end if;
    end process;

    dma_cmd_we_o <= dma_cmd_we_int;
    dma_cmd_o    <= dma_cmd_int;

    buffer_fsm : process(buffer_state_ff, dcache_rvalid_i, fsm_dma, buffer_cnt_ff, buffer_ff, dma_cmd_full_i, state_ff, vpro_fsm_stall_ff2, outstanding_ff, io_dma_trigger_ff)
    begin
        buffer_state_nxt <= buffer_state_ff;
        buffer_cnt_nxt   <= buffer_cnt_ff;
        buffer_nxt       <= buffer_ff;

        -- defaults
        dma_cmd_we_int <= '0';
        dma_cmd_int    <= fsm_dma;      --vpro_ext_dma_cmd_i;

        case (buffer_state_ff) is
            when FALLTHROUGH =>
                if state_ff = IDLE then
                    dma_cmd_we_int <= '0'; --vpro_ext_dma_we_i;
                    dma_cmd_int    <= fsm_dma; --vpro_ext_dma_cmd_i;
                else
                    if dma_cmd_full_i = '0' and vpro_fsm_stall_ff2 = '0' and outstanding_ff /= 0 and io_dma_trigger_ff = '0' then -- TODO: remove /= 0 when be shure of rdata_valid onlly on req items
                        dma_cmd_int    <= fsm_dma;
                        dma_cmd_we_int <= dcache_rvalid_i;
                    else
                        if dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '0' then
                            dma_cmd_we_int   <= '0';
                            buffer_nxt(0)    <= fsm_dma;
                            buffer_cnt_nxt   <= "01"; --1
                            buffer_state_nxt <= BUFFER_1;
                            -- start to buffer
                        end if;
                    end if;
                end if;

            when BUFFER_1 =>
                if dma_cmd_full_i = '0' then
                    dma_cmd_int    <= buffer_ff(0);
                    dma_cmd_we_int <= '1';
                    if dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '0' then
                        buffer_nxt(0)  <= fsm_dma;
                        buffer_cnt_nxt <= "01"; --1
                    else
                        buffer_cnt_nxt   <= "00"; --0
                        buffer_state_nxt <= FALLTHROUGH;
                    end if;
                else
                    if dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '0' then
                        dma_cmd_we_int   <= '0';
                        buffer_nxt(1)    <= fsm_dma;
                        buffer_cnt_nxt   <= "10"; --2
                        buffer_state_nxt <= BUFFER_2;
                        -- continue to buffer
                    end if;
                end if;

            when BUFFER_2 =>
                if dma_cmd_full_i = '0' then
                    dma_cmd_int    <= buffer_ff(0);
                    dma_cmd_we_int <= '1';
                    if dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '0' then
                        buffer_nxt(0)  <= buffer_ff(1);
                        buffer_nxt(1)  <= fsm_dma;
                        buffer_cnt_nxt <= "10"; --2
                    else
                        buffer_nxt(0)    <= buffer_ff(1);
                        buffer_cnt_nxt   <= "01"; --1
                        buffer_state_nxt <= BUFFER_1;
                    end if;
                else
                    if dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '0' then
                        dma_cmd_we_int   <= '0';
                        buffer_nxt(1)    <= fsm_dma;
                        buffer_cnt_nxt   <= "11"; --3
                        buffer_state_nxt <= BUFFER_3;
                        -- should not happen as req is disabled when fifo is full
                        -- continue to buffer
                    end if;
                end if;

            when BUFFER_3 =>
                assert (dcache_rvalid_i = '0' or (dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '1')) report "[DMA Block FSM] Buffer overflow. Data from cache received while dma fifo is full. buffer will lose those data!" severity failure;
                if dma_cmd_full_i = '0' then
                    dma_cmd_int    <= buffer_ff(0);
                    dma_cmd_we_int <= '1';
                    if dcache_rvalid_i = '1' and vpro_fsm_stall_ff2 = '0' then
                        buffer_nxt(0)  <= buffer_ff(1);
                        buffer_nxt(1)  <= fsm_dma;
                        buffer_cnt_nxt <= "11"; --3
                    else
                        buffer_nxt(0)    <= buffer_ff(1);
                        buffer_nxt(1)    <= fsm_dma;
                        buffer_cnt_nxt   <= "10"; --2
                        buffer_state_nxt <= BUFFER_2;
                    end if;
                    --                else
                    --                    if dcache_rvalid_i = '1' and fsm_stall_int = '0' then
                    -- data lost !
                    -- continue to buffer
                    --                    end if;
                end if;

        end case;
    end process;

end architecture RTL;

