--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

--library core_mips;
--use core_mips.mips_package.all;

library eisv;
use eisv.eisV_pkg.all;
--use eisv.eisV_pkg_units.all;

entity eisV_data_distributor is
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
end eisV_data_distributor;

architecture RTL of eisV_data_distributor is
    -- types
    type fsm_state_t is (IDLE, DCACHE_ACCESS, DCACHE_ACCESS_RAW, DCACHE_ACCESS_RAW_RD, IO_ACCESS, DMA_ACCESS);

    -- register
    signal state_ff_ff, state_ff, state_nxt : fsm_state_t;

    signal io_rdata_ff  : std_ulogic_vector(word_width_g - 1 downto 0);
    signal dma_rdata_ff : std_ulogic_vector(word_width_g - 1 downto 0);

    signal io_rd_valid_ff, dma_rd_valid_ff, dcache_rd_valid_ff : std_ulogic;

    signal dcache_wr_ff, dcache_wr_nxt           : std_ulogic;
    signal dcache_wr_addr_ff, dcache_wr_addr_nxt : std_ulogic_vector(addr_width_g - 1 downto 0);

    signal vpro_dma_fsm_busy_ff          : std_ulogic;
    signal dcache_req_nxt, dcache_req_ff : std_ulogic;

    signal dma_fsm_access, dma_fsm_access_ff     : std_ulogic;
    signal dcache_fsm_req_nxt, dcache_fsm_req_ff : std_ulogic;

    signal vpro_dma_fsm_stall_int : std_ulogic;
    -- signals
begin
    assert (io_area_begin_g = x"C0000000") report "[Data Distributor] IO Address begin needs to be xC000_0000 for implementation: MSB '31 - '30 is used for differentiation!" severity failure;
    assert (dma_area_begin_g = x"80000000") report "[Data Distributor] DMA Address begin needs to be x8000_0000 for implementation: MSB '31 is used for differentiation!" severity failure;

    seq : process(clk_i, rst_i)
    begin
        if (rst_i = '1') then
            state_ff             <= IDLE;
            state_ff_ff          <= IDLE;
            dcache_wr_ff         <= '0';
            vpro_dma_fsm_busy_ff <= '0';
            dma_fsm_access_ff    <= '0';
        elsif rising_edge(clk_i) then
            state_ff             <= state_nxt;
            state_ff_ff          <= state_ff;
            dcache_wr_ff         <= dcache_wr_nxt;
            dcache_wr_addr_ff    <= dcache_wr_addr_nxt;
            vpro_dma_fsm_busy_ff <= vpro_dma_fsm_busy_i;
            dma_fsm_access_ff    <= dma_fsm_access;
        end if;
    end process seq;

    assert_proc : process(clk_i)
    begin
        if falling_edge(clk_i) then
            assert ((dma_fsm_access and vpro_dma_fsm_busy_ff) = '0') report "[DMA FSM Access] Error: dma already busy, this access will be dropped!" severity failure;
        end if;
    end process;

    -- helper
    dma_fsm_access <= '1' when (eisV_we_i = '1') and (eisV_be_i = "1111") and (eisV_req_i = '1') and --
                      ((eisV_addr_i = FSM_START_ADDRESS_TRIGGER) or --
                       (eisV_addr_i = FSM_SIZE) or --
                       (eisV_addr_i = SINGLE_DMA_TRIGGER)) else
                      '0';

    fsm : process(dcache_stall_i, dma_stall_i, eisV_addr_i, eisV_be_i, eisV_req_i, eisV_wdata_i, eisV_we_i, io_ack_i, state_ff, dcache_wr_addr_ff, dcache_wr_ff, vpro_dma_fsm_busy_ff, dcache_req_ff, dma_fsm_access_ff, vpro_dma_fsm_busy_i, vpro_dma_fsm_dcache_addr_i, vpro_dma_fsm_dcache_req_i, vpro_dma_fifo_full_i, vpro_dma_fsm_stall_int, dcache_fsm_req_ff)
    begin
        --default 
        state_nxt          <= state_ff;
        dcache_wr_nxt      <= '0';
        dcache_wr_addr_nxt <= (others => '-');
        eisV_gnt_o         <= '0';

        -- DMA Interface --
        dma_req_o      <= '0';
        dma_rden_o     <= '0';
        dma_wren_o     <= (others => '0');
        dma_adr_o      <= eisV_addr_i;
        dma_wdata_o    <= eisV_wdata_i;
        -- DCache Interface --
        dcache_oe_o    <= '0';
        dcache_req_o   <= '0';
        dcache_req_nxt <= '0';
        dcache_rden_o  <= '0';
        dcache_wren_o  <= (others => '0');
        dcache_adr_o   <= eisV_addr_i;
        dcache_wdata_o <= eisV_wdata_i;
        -- IO Interface --
        io_ren_o       <= '0';
        io_wen_o       <= (others => '0');
        io_adr_o       <= eisV_addr_i;
        io_wdata_o     <= eisV_wdata_i;

        --DMA FSM
        dcache_fsm_req_nxt     <= '0';
        vpro_dma_fsm_stall_int <= '0';

        -- MUX select signal for axi signals behind dcache/dma
        mux_sel_dma_o <= '0';           -- '1' = dma, '0' = dcache

        case state_ff is
            when IDLE =>
                eisV_gnt_o <= not dcache_stall_i; -- and not vpro_dma_fsm_busy_ff; --'1';   

                -- DONE: pass access to dcache to fsm
                if dcache_stall_i = '1' then
                    dcache_fsm_req_nxt <= dcache_fsm_req_ff;
                elsif vpro_dma_fsm_busy_i = '1' then
                    dcache_adr_o       <= vpro_dma_fsm_dcache_addr_i;
                    dcache_req_o       <= vpro_dma_fsm_dcache_req_i;
                    dcache_fsm_req_nxt <= vpro_dma_fsm_dcache_req_i; -- to get the rvalid lateron
                    dcache_rden_o      <= '1';
                    dcache_wren_o      <= (others => '0');
                    dcache_wdata_o     <= (others => '-'); -- dont care
                end if;

                if eisV_req_i = '1' then
                    -- DONE: if dma fsm access, io will be called. It will always ack + ignore access as no unit listens on this address
                    if eisV_addr_i(31 downto 30) = "11" then -- >= C000 0000
                        state_nxt <= IO_ACCESS;
                        io_ren_o  <= not eisV_we_i;
                        io_wen_o  <= eisV_be_i;
                        if eisV_we_i = '0' then
                            io_wen_o <= (others => '0');
                        end if;
                    else
                        if eisV_addr_i(31) = '1' then -- >= 8000 0000
                            vpro_dma_fsm_stall_int <= '1';
                            state_nxt              <= DMA_ACCESS;
                            mux_sel_dma_o          <= '1';
                            dma_req_o              <= '1';
                            dma_rden_o             <= not eisV_we_i;
                            dma_wren_o             <= eisV_be_i;
                            if eisV_we_i = '0' then
                                dma_wren_o <= (others => '0');
                            end if;
                        else
                            -- DONE: Stall DMA FSM when eis-v accesss the dcache
                            vpro_dma_fsm_stall_int <= '1';
                            state_nxt              <= DCACHE_ACCESS;
                            dcache_oe_o            <= '1';
                            dcache_req_o           <= '1';
                            dcache_req_nxt         <= '1';
                            dcache_rden_o          <= not eisV_we_i;
                            dcache_wren_o          <= eisV_be_i;
                            dcache_adr_o           <= eisV_addr_i;
                            dcache_wdata_o         <= eisV_wdata_i;
                            if eisV_we_i = '0' then
                                dcache_wren_o <= (others => '0');
                            else
                                dcache_wr_nxt      <= '1';
                                dcache_wr_addr_nxt <= eisV_addr_i;
                            end if;
                        end if;
                    end if;
                end if;

            when DCACHE_ACCESS =>
                dcache_oe_o    <= '1';
                dcache_req_nxt <= dcache_req_ff;

                -- DONE: Stall DMA FSM when eis-v accesss the dcache
                vpro_dma_fsm_stall_int <= '1';

                if dcache_stall_i = '0' then
                    dcache_req_nxt <= '0';
                    state_nxt      <= IDLE;
                    eisV_gnt_o     <= '1';

                    --                    if vpro_dma_fsm_busy_i = '1' then
                    --                        dcache_req_nxt <= '1'; -- to get the rvalid lateron
                    --                    end if;

                    if eisV_req_i = '1' then
                        if eisV_addr_i(31 downto 30) = "11" then -- >= C000 0000
                            state_nxt <= IO_ACCESS;
                            io_ren_o  <= not eisV_we_i;
                            io_wen_o  <= eisV_be_i;
                            if eisV_we_i = '0' then
                                io_wen_o <= (others => '0');
                            end if;
                        else
                            if eisV_addr_i(31) = '1' then -- >= 8000 0000
                                state_nxt     <= DMA_ACCESS;
                                mux_sel_dma_o <= '1';
                                dma_req_o     <= '1';
                                dma_rden_o    <= not eisV_we_i;
                                dma_wren_o    <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dma_wren_o <= (others => '0');
                                end if;
                            else
                                vpro_dma_fsm_stall_int <= '1';
                                state_nxt              <= DCACHE_ACCESS;
                                dcache_oe_o            <= '1';
                                dcache_req_o           <= '1';
                                dcache_req_nxt         <= '1';
                                dcache_rden_o          <= not eisV_we_i;
                                dcache_wren_o          <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dcache_wren_o <= (others => '0');
                                    -- check for RAW Conflicts of the DCACHE
                                    if dcache_wr_ff = '1' then
                                        if eisV_addr_i = dcache_wr_addr_ff then
                                            -- stall next access
                                            state_nxt          <= DCACHE_ACCESS_RAW;
                                            dcache_oe_o        <= '0';
                                            dcache_req_o       <= '0';
                                            dcache_req_nxt     <= '0';
                                            dcache_wr_addr_nxt <= eisV_addr_i;
                                        end if;
                                    end if;
                                else
                                    dcache_wr_nxt      <= '1';
                                    dcache_wr_addr_nxt <= eisV_addr_i;
                                end if;
                            end if;
                        end if;
                    end if;
                else                    -- dcache_stall_i
                    dcache_wr_nxt      <= dcache_wr_ff;
                    dcache_wr_addr_nxt <= dcache_wr_addr_ff;
                end if;

            when DCACHE_ACCESS_RAW =>
                vpro_dma_fsm_stall_int <= '1';
                -- stall next access
                eisV_gnt_o             <= '0';
                state_nxt              <= DCACHE_ACCESS_RAW_RD;

                -- this was a RD
                dcache_oe_o    <= '1';
                dcache_req_o   <= '1';
                dcache_req_nxt <= '1';
                dcache_rden_o  <= '1';
                dcache_wren_o  <= (others => '0');
                dcache_adr_o   <= dcache_wr_addr_ff;

            when DCACHE_ACCESS_RAW_RD =>
                vpro_dma_fsm_stall_int <= '1';
                dcache_oe_o            <= '1';
                dcache_req_nxt         <= dcache_req_ff;
                if dcache_stall_i = '0' then
                    dcache_req_nxt <= '0';
                    state_nxt      <= IDLE;
                    eisV_gnt_o     <= '1';

                    if eisV_req_i = '1' then
                        if eisV_addr_i(31 downto 30) = "11" then -- >= C000 0000
                            state_nxt <= IO_ACCESS;
                            io_ren_o  <= not eisV_we_i;
                            io_wen_o  <= eisV_be_i;
                            if eisV_we_i = '0' then
                                io_wen_o <= (others => '0');
                            end if;
                        else
                            if eisV_addr_i(31) = '1' then -- >= 8000 0000
                                state_nxt     <= DMA_ACCESS;
                                mux_sel_dma_o <= '1';
                                dma_req_o     <= '1';
                                dma_rden_o    <= not eisV_we_i;
                                dma_wren_o    <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dma_wren_o <= (others => '0');
                                end if;
                            else
                                state_nxt      <= DCACHE_ACCESS;
                                dcache_oe_o    <= '1';
                                dcache_req_o   <= '1';
                                dcache_req_nxt <= '1';
                                dcache_rden_o  <= not eisV_we_i;
                                dcache_wren_o  <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dcache_wren_o <= (others => '0');
                                else
                                    dcache_wr_nxt      <= '1';
                                    dcache_wr_addr_nxt <= eisV_addr_i;
                                end if;
                            end if;
                        end if;
                    end if;
                else                    -- dcache_stall_i
                    dcache_wr_nxt      <= dcache_wr_ff;
                    dcache_wr_addr_nxt <= dcache_wr_addr_ff;
                end if;

            when IO_ACCESS =>

                -- DONE: pass access to dcache to fsm
                if dcache_stall_i = '1' then
                    dcache_fsm_req_nxt <= dcache_fsm_req_ff;
                elsif vpro_dma_fsm_busy_i = '1' then
                    dcache_adr_o       <= vpro_dma_fsm_dcache_addr_i;
                    dcache_req_o       <= vpro_dma_fsm_dcache_req_i;
                    dcache_fsm_req_nxt <= vpro_dma_fsm_dcache_req_i; -- to get the rvalid lateron
                    dcache_rden_o      <= '1';
                    dcache_wren_o      <= (others => '0');
                    dcache_wdata_o     <= (others => '-'); -- dont care
                end if;

                if io_ack_i = '1' then  -- wait for ack
                    state_nxt <= IDLE;

                    if eisV_req_i = '1' then
                        if eisV_addr_i(31 downto 30) = "11" then -- >= C000 0000
                            state_nxt <= IO_ACCESS;
                            io_ren_o  <= not eisV_we_i;
                            io_wen_o  <= eisV_be_i;
                            if eisV_we_i = '0' then
                                io_wen_o <= (others => '0');
                            end if;
                        else
                            if eisV_addr_i(31) = '1' then -- >= 8000 0000
                                vpro_dma_fsm_stall_int <= '1';
                                state_nxt              <= DMA_ACCESS;
                                mux_sel_dma_o          <= '1';
                                dma_req_o              <= '1';
                                dma_rden_o             <= not eisV_we_i;
                                dma_wren_o             <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dma_wren_o <= (others => '0');
                                end if;
                            else
                                vpro_dma_fsm_stall_int <= '1';
                                state_nxt              <= DCACHE_ACCESS;
                                dcache_oe_o            <= '1';
                                dcache_req_o           <= '1';
                                dcache_req_nxt         <= '1';
                                dcache_rden_o          <= not eisV_we_i;
                                dcache_wren_o          <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dcache_wren_o <= (others => '0');
                                end if;
                            end if;
                        end if;
                    end if;
                end if;

            when DMA_ACCESS =>
                vpro_dma_fsm_stall_int <= '1';
                mux_sel_dma_o          <= '1';
                if dma_stall_i = '0' then
                    state_nxt  <= IDLE;
                    eisV_gnt_o <= '1';

                    if eisV_req_i = '1' then
                        if eisV_addr_i(31 downto 30) = "11" then -- >= C000 0000
                            state_nxt <= IO_ACCESS;
                            io_ren_o  <= not eisV_we_i;
                            io_wen_o  <= eisV_be_i;
                            if eisV_we_i = '0' then
                                io_wen_o <= (others => '0');
                            end if;
                        else
                            if eisV_addr_i(31) = '1' then -- >= 8000 0000
                                state_nxt     <= DMA_ACCESS;
                                mux_sel_dma_o <= '1';
                                dma_req_o     <= '1';
                                dma_rden_o    <= not eisV_we_i;
                                dma_wren_o    <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dma_wren_o <= (others => '0');
                                end if;
                            else
                                state_nxt      <= DCACHE_ACCESS;
                                dcache_oe_o    <= '1';
                                dcache_req_o   <= '1';
                                dcache_req_nxt <= '1';
                                dcache_rden_o  <= not eisV_we_i;
                                dcache_wren_o  <= eisV_be_i;
                                if eisV_we_i = '0' then
                                    dcache_wren_o <= (others => '0');
                                end if;
                            end if;
                        end if;
                    end if;
                end if;
        end case;

        -- DONE: use dma_fsm_busy for cycle after new trigger -> Stall Risc-V one cycle
        if dma_fsm_access_ff = '1' and vpro_dma_fsm_busy_ff = '1' then
            eisV_gnt_o <= '0';
        end if;

--        -- DMA FSM is active but dma fifo is full -> new io acc should not be send to DMA FSM! -> Stall Risc-V
--        --     -> not generally!!! io write to vpro cmd register should still be possible! -> solve in software -> e.g. check if busy
--        if vpro_dma_fsm_busy_ff = '1' and vpro_dma_fifo_full_i = '1' then
--            eisV_gnt_o <= '0';
--        end if;

        if vpro_dma_fsm_busy_i = '1' then
            dcache_oe_o <= '1';
        end if;

        if vpro_dma_fsm_stall_int = '1' then -- TODO: remove; not needed! req from fsm always 0 when fsm stall = 1
            dcache_fsm_req_nxt <= '0';
        end if;
    end process;

    vpro_dma_fsm_stall_o <= vpro_dma_fsm_stall_int;

    rdata_buffer : process(clk_i)
    begin
        if rising_edge(clk_i) then
            --            dcache_rdata_i;   -- no need, as they are already 2 cycle delayed
            io_rdata_ff  <= io_rdata_i;
            dma_rdata_ff <= dma_rdata_i;

            io_rd_valid_ff  <= io_ack_i;
            dma_rd_valid_ff <= not dma_stall_i;

            dcache_req_ff     <= dcache_req_nxt;
            dcache_fsm_req_ff <= dcache_fsm_req_nxt;

            dcache_rd_valid_ff           <= not dcache_stall_i and dcache_req_ff;
            vpro_dma_fsm_dcache_rvalid_o <= not dcache_stall_i and dcache_fsm_req_ff and vpro_dma_fsm_busy_ff;
        end if;
    end process;

    rdata : process(state_ff_ff, dcache_rd_valid_ff, dcache_rdata_i, dma_rd_valid_ff, dma_rdata_ff, io_rd_valid_ff, io_rdata_ff)
    begin
        eisV_rvalid_o <= '0';
        eisV_rdata_o  <= (others => '0');

        case state_ff_ff is
            when IDLE =>
            when DCACHE_ACCESS =>
                eisV_rvalid_o <= dcache_rd_valid_ff;
                eisV_rdata_o  <= dcache_rdata_i;
            when DMA_ACCESS =>
                eisV_rvalid_o <= dma_rd_valid_ff;
                eisV_rdata_o  <= dma_rdata_ff;
            when IO_ACCESS =>
                eisV_rvalid_o <= io_rd_valid_ff;
                eisV_rdata_o  <= io_rdata_ff;
            when DCACHE_ACCESS_RAW =>
            when DCACHE_ACCESS_RAW_RD =>
                eisV_rvalid_o <= dcache_rd_valid_ff;
                eisV_rdata_o  <= dcache_rdata_i;
        end case;
    end process;

end architecture RTL;
