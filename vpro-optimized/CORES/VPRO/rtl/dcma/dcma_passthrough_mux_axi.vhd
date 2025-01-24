--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
-- coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library eisv;
use eisv.eisV_sys_pkg.all;

entity dcma_passthrough_mux_axi is
    generic(
        NUM_CLUSTERS                  : integer                            := 8;
        DCMA_ADDR_WIDTH               : integer                            := 32; -- Address Width
        DCMA_DATA_WIDTH               : integer                            := 64; -- Data Width
        VPRO_DATA_WIDTH               : integer                            := 16;
        -- Parameters for Axi Interface Unit
        AXI_INTERFACE_UNIT_FIFO_DEPTH : integer                            := 8;
        MIG_BASE_ADDR                 : integer                            := 0; --16#40000000#;
        -- Parameters of Axi Master Bus Interface M_AXI
        C_S_AXI_ID_WIDTH              : integer                            := 1;
        C_S_AXI_ADDR_WIDTH            : integer                            := 32;
        C_S_AXI_DATA_WIDTH            : integer                            := 512;
        C_S_AXI_AWUSER_WIDTH          : integer                            := 0;
        C_S_AXI_ARUSER_WIDTH          : integer                            := 0;
        C_S_AXI_WUSER_WIDTH           : integer                            := 0;
        C_S_AXI_RUSER_WIDTH           : integer                            := 0;
        C_S_AXI_BUSER_WIDTH           : integer                            := 0;
        -- AXI ADDR Editor Params
        C_M_ADDR_RANGE                : std_ulogic_vector(48 - 1 downto 0) := std_ulogic_vector(to_unsigned(4096, 48))
    );
    port(
        dma_clk_i      : in  std_ulogic; -- DCMA/DMA Clock 
        axi_clk_i      : in  std_ulogic;
        areset_n_i     : in  std_ulogic;
        dma_base_adr_i : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_ADDR_WIDTH - 1 downto 0); -- addressing bytes
        dma_size_i     : in  std_ulogic_vector(NUM_CLUSTERS * 20 - 1 downto 0); -- quantity
        dma_dat_o      : out std_ulogic_vector(NUM_CLUSTERS * DCMA_DATA_WIDTH - 1 downto 0); -- data from main memory
        dma_dat_i      : in  std_ulogic_vector(NUM_CLUSTERS * DCMA_DATA_WIDTH - 1 downto 0); -- data to main memory
        dma_req_i      : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- memory request
        dma_busy_o     : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- no request possible right now
        dma_rw_i       : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- read/write a block from/to memory
        dma_rden_i     : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- FIFO read enable
        dma_wren_i     : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- FIFO write enable
        dma_wrdy_o     : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- data can be written
        dma_wr_last_i  : in  std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- last word of write-block
        dma_rrdy_o     : out std_ulogic_vector(NUM_CLUSTERS - 1 downto 0); -- read data ready
        -- axi master interface unit (AIU) interface --
        m_axi_awid     : out std_ulogic_vector(C_S_AXI_ID_WIDTH - 1 downto 0); -- constant 0
        m_axi_awaddr   : out std_ulogic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
        m_axi_awlen    : out std_ulogic_vector(7 downto 0);
        m_axi_awsize   : out std_ulogic_vector(2 downto 0); -- constant burst size for 512 bit
        m_axi_awburst  : out std_ulogic_vector(1 downto 0); -- constant burst increment = "01"
        m_axi_awlock   : out std_ulogic; -- constant 0
        m_axi_awcache  : out std_ulogic_vector(3 downto 0); -- constant "0010"
        m_axi_awprot   : out std_ulogic_vector(2 downto 0); -- constant 0
        m_axi_awqos    : out std_ulogic_vector(3 downto 0); -- constant 0
        m_axi_awuser   : out std_ulogic_vector(C_S_AXI_AWUSER_WIDTH - 1 downto 0); -- constant 0
        m_axi_awvalid  : out std_ulogic;
        m_axi_awready  : in  std_ulogic;
        m_axi_wdata    : out std_ulogic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        m_axi_wstrb    : out std_ulogic_vector(C_S_AXI_DATA_WIDTH / 8 - 1 downto 0);
        m_axi_wlast    : out std_ulogic;
        m_axi_wuser    : out std_ulogic_vector(C_S_AXI_WUSER_WIDTH - 1 downto 0); -- constant 0
        m_axi_wvalid   : out std_ulogic;
        m_axi_wready   : in  std_ulogic;
        m_axi_bid      : in  std_ulogic_vector(C_S_AXI_ID_WIDTH - 1 downto 0); -- constant 0
        m_axi_bresp    : in  std_ulogic_vector(1 downto 0);
        m_axi_buser    : in  std_ulogic_vector(C_S_AXI_BUSER_WIDTH - 1 downto 0); -- constant 0
        m_axi_bvalid   : in  std_ulogic;
        m_axi_bready   : out std_ulogic;
        m_axi_arid     : out std_ulogic_vector(C_S_AXI_ID_WIDTH - 1 downto 0); -- constant 0
        m_axi_araddr   : out std_ulogic_vector(C_S_AXI_ADDR_WIDTH - 1 downto 0);
        m_axi_arlen    : out std_ulogic_vector(7 downto 0);
        m_axi_arsize   : out std_ulogic_vector(2 downto 0); -- constant burst size for 512 bit
        m_axi_arburst  : out std_ulogic_vector(1 downto 0); -- constant burst increment = "01"
        m_axi_arlock   : out std_ulogic; -- constant 0
        m_axi_arcache  : out std_ulogic_vector(3 downto 0); -- constant "0010"
        m_axi_arprot   : out std_ulogic_vector(2 downto 0); -- constant 0
        m_axi_arqos    : out std_ulogic_vector(3 downto 0); -- constant 0
        m_axi_aruser   : out std_ulogic_vector(C_S_AXI_ARUSER_WIDTH - 1 downto 0); -- constant 0
        m_axi_arvalid  : out std_ulogic;
        m_axi_arready  : in  std_ulogic;
        m_axi_rid      : in  std_ulogic_vector(C_S_AXI_ID_WIDTH - 1 downto 0); -- constant 0
        m_axi_rdata    : in  std_ulogic_vector(C_S_AXI_DATA_WIDTH - 1 downto 0);
        m_axi_rresp    : in  std_ulogic_vector(1 downto 0);
        m_axi_rlast    : in  std_ulogic;
        m_axi_ruser    : in  std_ulogic_vector(C_S_AXI_RUSER_WIDTH - 1 downto 0); -- constant 0
        m_axi_rvalid   : in  std_ulogic;
        m_axi_rready   : out std_ulogic
    );
end dcma_passthrough_mux_axi;

architecture RTL of dcma_passthrough_mux_axi is
    -- types
    type cluster_dcma_addr_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_ADDR_WIDTH - 1 downto 0);
    type cluster_dcma_data_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    type cluster_dcma_data_logic_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_logic_vector(DCMA_DATA_WIDTH - 1 downto 0);
    type cluster_dma_size_array_t is array (NUM_CLUSTERS - 1 downto 0) of std_ulogic_vector(dma_size_i'length / NUM_CLUSTERS - 1 downto 0);

    -- signals
    signal dma_base_adr_int : cluster_dcma_addr_array_t;
    signal dma_size_int     : cluster_dma_size_array_t;
    signal dma_dat_o_int    : cluster_dcma_data_logic_array_t;
    signal dma_dat_i_int    : cluster_dcma_data_array_t;

    signal axi_awid    : std_logic_vector(NUM_CLUSTERS * C_S_AXI_ID_WIDTH - 1 downto 0);
    signal axi_awaddr  : std_logic_vector(NUM_CLUSTERS * C_S_AXI_ADDR_WIDTH - 1 downto 0);
    signal axi_awlen   : std_logic_vector(NUM_CLUSTERS * 8 - 1 downto 0);
    signal axi_awsize  : std_logic_vector(NUM_CLUSTERS * 3 - 1 downto 0);
    signal axi_awburst : std_logic_vector(NUM_CLUSTERS * 2 - 1 downto 0);
    signal axi_awlock  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_awcache : std_logic_vector(NUM_CLUSTERS * 4 - 1 downto 0);
    signal axi_awprot  : std_logic_vector(NUM_CLUSTERS * 3 - 1 downto 0);
    signal axi_awqos   : std_logic_vector(NUM_CLUSTERS * 4 - 1 downto 0);
    signal axi_awuser  : std_logic_vector(NUM_CLUSTERS * C_S_AXI_AWUSER_WIDTH - 1 downto 0);
    signal axi_awvalid : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_awready : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_wdata   : std_logic_vector(NUM_CLUSTERS * C_S_AXI_DATA_WIDTH - 1 downto 0);
    signal axi_wstrb   : std_logic_vector(NUM_CLUSTERS * C_S_AXI_DATA_WIDTH / 8 - 1 downto 0);
    signal axi_wlast   : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_wuser   : std_logic_vector(NUM_CLUSTERS * C_S_AXI_WUSER_WIDTH - 1 downto 0);
    signal axi_wvalid  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_wready  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_bid     : std_ulogic_vector(NUM_CLUSTERS * C_S_AXI_ID_WIDTH - 1 downto 0);
    signal axi_bresp   : std_ulogic_vector(NUM_CLUSTERS * 2 - 1 downto 0);
    signal axi_buser   : std_ulogic_vector(NUM_CLUSTERS * C_S_AXI_BUSER_WIDTH - 1 downto 0);
    signal axi_bvalid  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_bready  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_arid    : std_logic_vector(NUM_CLUSTERS * C_S_AXI_ID_WIDTH - 1 downto 0);
    signal axi_araddr  : std_logic_vector(NUM_CLUSTERS * C_S_AXI_ADDR_WIDTH - 1 downto 0);
    signal axi_arlen   : std_logic_vector(NUM_CLUSTERS * 8 - 1 downto 0);
    signal axi_arsize  : std_logic_vector(NUM_CLUSTERS * 3 - 1 downto 0);
    signal axi_arburst : std_logic_vector(NUM_CLUSTERS * 2 - 1 downto 0);
    signal axi_arlock  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_arcache : std_logic_vector(NUM_CLUSTERS * 4 - 1 downto 0);
    signal axi_arprot  : std_logic_vector(NUM_CLUSTERS * 3 - 1 downto 0);
    signal axi_arqos   : std_logic_vector(NUM_CLUSTERS * 4 - 1 downto 0);
    signal axi_aruser  : std_logic_vector(NUM_CLUSTERS * C_S_AXI_ARUSER_WIDTH - 1 downto 0);
    signal axi_arvalid : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_arready : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_rid     : std_ulogic_vector(NUM_CLUSTERS * C_S_AXI_ID_WIDTH - 1 downto 0);
    signal axi_rdata   : std_ulogic_vector(NUM_CLUSTERS * C_S_AXI_DATA_WIDTH - 1 downto 0);
    signal axi_rresp   : std_ulogic_vector(NUM_CLUSTERS * 2 - 1 downto 0);
    signal axi_rlast   : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_ruser   : std_ulogic_vector(NUM_CLUSTERS * C_S_AXI_RUSER_WIDTH - 1 downto 0);
    signal axi_rvalid  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
    signal axi_rready  : std_ulogic_vector(NUM_CLUSTERS - 1 downto 0);
begin
    axi_m_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        axi_interface_unit_inst : axi_interface_unit
            generic map(
                FIFO_DEPTH                => AXI_INTERFACE_UNIT_FIFO_DEPTH,
                MIG_BASE_ADDR             => MIG_BASE_ADDR,
                ENDIANESS_SWAP            => false,
                WORD_SWAP                 => false,
                PROC_DATA_WIDTH           => VPRO_DATA_WIDTH,
                CACHE_DATA_WIDTH          => DCMA_DATA_WIDTH,
                GEN_TRACE                 => false,
                TRACE_FILE                => "",
                READ_REQ_ERROR_HANDLING   => false,
                READ_DATA_ERROR_HANDLING  => false,
                WRITE_REQ_ERROR_HANDLING  => false,
                WRITE_DATA_ERROR_HANDLING => false,
                ALLOW_REQ_OVERLAP         => false,
                C_M00_AXI_ID_WIDTH        => C_S_AXI_ID_WIDTH,
                C_M00_AXI_ADDR_WIDTH      => C_S_AXI_ADDR_WIDTH,
                C_M00_AXI_DATA_WIDTH      => C_S_AXI_DATA_WIDTH,
                C_M00_AXI_AWUSER_WIDTH    => C_S_AXI_AWUSER_WIDTH,
                C_M00_AXI_ARUSER_WIDTH    => C_S_AXI_ARUSER_WIDTH,
                C_M00_AXI_WUSER_WIDTH     => C_S_AXI_WUSER_WIDTH,
                C_M00_AXI_RUSER_WIDTH     => C_S_AXI_RUSER_WIDTH,
                C_M00_AXI_BUSER_WIDTH     => C_S_AXI_BUSER_WIDTH
            )
            port map(
                cmd_clk            => dma_clk_i,
                cmd_req_i          => dma_req_i(I),
                cmd_busy_o         => dma_busy_o(I),
                cmd_rw_i           => dma_rw_i(I),
                cmd_read_length_i  => std_logic_vector(dma_size_int(I)),
                cmd_base_adr_i     => std_logic_vector(dma_base_adr_int(I)),
                cmd_fifo_rden_i    => dma_rden_i(I),
                cmd_fifo_wren_i    => dma_wren_i(I),
                cmd_fifo_wr_last_i => dma_wr_last_i(I),
                cmd_fifo_data_o    => dma_dat_o_int(I),
                cmd_fifo_wrdy_o    => dma_wrdy_o(I),
                cmd_fifo_rrdy_o    => dma_rrdy_o(I),
                cmd_fifo_data_i    => std_logic_vector(dma_dat_i_int(I)),
                cmd_wr_done_o      => open,
                m00_axi_aclk       => axi_clk_i,
                m00_axi_aresetn    => areset_n_i,
                m00_axi_awid       => axi_awid((I + 1) * C_S_AXI_ID_WIDTH - 1 downto I * C_S_AXI_ID_WIDTH),
                m00_axi_awaddr     => axi_awaddr((I + 1) * C_S_AXI_ADDR_WIDTH - 1 downto I * C_S_AXI_ADDR_WIDTH),
                m00_axi_awlen      => axi_awlen((I + 1) * 8 - 1 downto I * 8),
                m00_axi_awsize     => axi_awsize((I + 1) * 3 - 1 downto I * 3),
                m00_axi_awburst    => axi_awburst((I + 1) * 2 - 1 downto I * 2),
                m00_axi_awlock     => axi_awlock(I),
                m00_axi_awcache    => axi_awcache((I + 1) * 4 - 1 downto I * 4),
                m00_axi_awprot     => axi_awprot((I + 1) * 3 - 1 downto I * 3),
                m00_axi_awqos      => axi_awqos((I + 1) * 4 - 1 downto I * 4),
                m00_axi_awuser     => axi_awuser((I + 1) * C_S_AXI_AWUSER_WIDTH - 1 downto I * C_S_AXI_AWUSER_WIDTH),
                m00_axi_awvalid    => axi_awvalid(I),
                m00_axi_awready    => axi_awready(I),
                m00_axi_wdata      => axi_wdata((I + 1) * C_S_AXI_DATA_WIDTH - 1 downto I * C_S_AXI_DATA_WIDTH),
                m00_axi_wstrb      => axi_wstrb((I + 1) * C_S_AXI_DATA_WIDTH / 8 - 1 downto I * C_S_AXI_DATA_WIDTH / 8),
                m00_axi_wlast      => axi_wlast(I),
                m00_axi_wuser      => axi_wuser((I + 1) * C_S_AXI_WUSER_WIDTH - 1 downto I * C_S_AXI_WUSER_WIDTH),
                m00_axi_wvalid     => axi_wvalid(I),
                m00_axi_wready     => axi_wready(I),
                m00_axi_bid        => std_logic_vector(axi_bid((I + 1) * C_S_AXI_ID_WIDTH - 1 downto I * C_S_AXI_ID_WIDTH)),
                m00_axi_bresp      => std_logic_vector(axi_bresp((I + 1) * 2 - 1 downto I * 2)),
                m00_axi_buser      => std_logic_vector(axi_buser((I + 1) * C_S_AXI_BUSER_WIDTH - 1 downto I * C_S_AXI_BUSER_WIDTH)),
                m00_axi_bvalid     => axi_bvalid(I),
                m00_axi_bready     => axi_bready(I),
                m00_axi_arid       => axi_arid((I + 1) * C_S_AXI_ID_WIDTH - 1 downto I * C_S_AXI_ID_WIDTH),
                m00_axi_araddr     => axi_araddr((I + 1) * C_S_AXI_ADDR_WIDTH - 1 downto I * C_S_AXI_ADDR_WIDTH),
                m00_axi_arlen      => axi_arlen((I + 1) * 8 - 1 downto I * 8),
                m00_axi_arsize     => axi_arsize((I + 1) * 3 - 1 downto I * 3),
                m00_axi_arburst    => axi_arburst((I + 1) * 2 - 1 downto I * 2),
                m00_axi_arlock     => axi_arlock(I),
                m00_axi_arcache    => axi_arcache((I + 1) * 4 - 1 downto I * 4),
                m00_axi_arprot     => axi_arprot((I + 1) * 3 - 1 downto I * 3),
                m00_axi_arqos      => axi_arqos((I + 1) * 4 - 1 downto I * 4),
                m00_axi_aruser     => axi_aruser((I + 1) * C_S_AXI_ARUSER_WIDTH - 1 downto I * C_S_AXI_ARUSER_WIDTH),
                m00_axi_arvalid    => axi_arvalid(I),
                m00_axi_arready    => axi_arready(I),
                m00_axi_rid        => std_logic_vector(axi_rid((I + 1) * C_S_AXI_ID_WIDTH - 1 downto I * C_S_AXI_ID_WIDTH)),
                m00_axi_rdata      => std_logic_vector(axi_rdata((I + 1) * C_S_AXI_DATA_WIDTH - 1 downto I * C_S_AXI_DATA_WIDTH)),
                m00_axi_rresp      => std_logic_vector(axi_rresp((I + 1) * 2 - 1 downto I * 2)),
                m00_axi_rlast      => axi_rlast(I),
                m00_axi_ruser      => std_logic_vector(axi_ruser((I + 1) * C_S_AXI_RUSER_WIDTH - 1 downto I * C_S_AXI_RUSER_WIDTH)),
                m00_axi_rvalid     => axi_rvalid(I),
                m00_axi_rready     => axi_rready(I)
            );
    end generate;

    axi_n_to_1_mux_inst : axi_n_to_1_interconnect_mux
        generic map(
            NR_MASTERS_G         => NUM_CLUSTERS,
            C_S_AXI_ID_WIDTH     => C_S_AXI_ID_WIDTH,
            C_S_AXI_ADDR_WIDTH   => C_S_AXI_ADDR_WIDTH,
            C_S_AXI_DATA_WIDTH   => C_S_AXI_DATA_WIDTH,
            C_S_AXI_AWUSER_WIDTH => C_S_AXI_AWUSER_WIDTH,
            C_S_AXI_ARUSER_WIDTH => C_S_AXI_ARUSER_WIDTH,
            C_S_AXI_WUSER_WIDTH  => C_S_AXI_WUSER_WIDTH,
            C_S_AXI_RUSER_WIDTH  => C_S_AXI_RUSER_WIDTH,
            C_S_AXI_BUSER_WIDTH  => C_S_AXI_BUSER_WIDTH,
            C_M_ADDR_RANGE       => C_M_ADDR_RANGE,
            ROUND_ROBIN          => true
        )
        port map(
            axi_clk            => axi_clk_i,
            axi_aresetn        => areset_n_i,
            s_axi_addr_offsets => (others => '0'),
            s_axi_awid         => std_ulogic_vector(axi_awid),
            s_axi_awaddr       => std_ulogic_vector(axi_awaddr),
            s_axi_awlen        => std_ulogic_vector(axi_awlen),
            s_axi_awsize       => std_ulogic_vector(axi_awsize),
            s_axi_awburst      => std_ulogic_vector(axi_awburst),
            s_axi_awlock       => axi_awlock,
            s_axi_awcache      => std_ulogic_vector(axi_awcache),
            s_axi_awprot       => std_ulogic_vector(axi_awprot),
            s_axi_awqos        => std_ulogic_vector(axi_awqos),
            s_axi_awuser       => std_ulogic_vector(axi_awuser),
            s_axi_awvalid      => axi_awvalid,
            s_axi_awready      => axi_awready,
            s_axi_wdata        => std_ulogic_vector(axi_wdata),
            s_axi_wstrb        => std_ulogic_vector(axi_wstrb),
            s_axi_wlast        => axi_wlast,
            s_axi_wuser        => std_ulogic_vector(axi_wuser),
            s_axi_wvalid       => axi_wvalid,
            s_axi_wready       => axi_wready,
            s_axi_bid          => axi_bid,
            s_axi_bresp        => axi_bresp,
            s_axi_buser        => axi_buser,
            s_axi_bvalid       => axi_bvalid,
            s_axi_bready       => axi_bready,
            s_axi_arid         => std_ulogic_vector(axi_arid),
            s_axi_araddr       => std_ulogic_vector(axi_araddr),
            s_axi_arlen        => std_ulogic_vector(axi_arlen),
            s_axi_arsize       => std_ulogic_vector(axi_arsize),
            s_axi_arburst      => std_ulogic_vector(axi_arburst),
            s_axi_arlock       => axi_arlock,
            s_axi_arcache      => std_ulogic_vector(axi_arcache),
            s_axi_arprot       => std_ulogic_vector(axi_arprot),
            s_axi_arqos        => std_ulogic_vector(axi_arqos),
            s_axi_aruser       => std_ulogic_vector(axi_aruser),
            s_axi_arvalid      => axi_arvalid,
            s_axi_arready      => axi_arready,
            s_axi_rid          => axi_rid,
            s_axi_rdata        => axi_rdata,
            s_axi_rresp        => axi_rresp,
            s_axi_rlast        => axi_rlast,
            s_axi_ruser        => axi_ruser,
            s_axi_rvalid       => axi_rvalid,
            s_axi_rready       => axi_rready,
            m_axi_awid         => m_axi_awid,
            m_axi_awaddr       => m_axi_awaddr,
            m_axi_awlen        => m_axi_awlen,
            m_axi_awsize       => m_axi_awsize,
            m_axi_awburst      => m_axi_awburst,
            m_axi_awlock       => m_axi_awlock,
            m_axi_awcache      => m_axi_awcache,
            m_axi_awprot       => m_axi_awprot,
            m_axi_awqos        => m_axi_awqos,
            m_axi_awuser       => m_axi_awuser,
            m_axi_awvalid      => m_axi_awvalid,
            m_axi_awready      => m_axi_awready,
            m_axi_wdata        => m_axi_wdata,
            m_axi_wstrb        => m_axi_wstrb,
            m_axi_wlast        => m_axi_wlast,
            m_axi_wuser        => m_axi_wuser,
            m_axi_wvalid       => m_axi_wvalid,
            m_axi_wready       => m_axi_wready,
            m_axi_bid          => m_axi_bid,
            m_axi_bresp        => m_axi_bresp,
            m_axi_buser        => m_axi_buser,
            m_axi_bvalid       => m_axi_bvalid,
            m_axi_bready       => m_axi_bready,
            m_axi_arid         => m_axi_arid,
            m_axi_araddr       => m_axi_araddr,
            m_axi_arlen        => m_axi_arlen,
            m_axi_arsize       => m_axi_arsize,
            m_axi_arburst      => m_axi_arburst,
            m_axi_arlock       => m_axi_arlock,
            m_axi_arcache      => m_axi_arcache,
            m_axi_arprot       => m_axi_arprot,
            m_axi_arqos        => m_axi_arqos,
            m_axi_aruser       => m_axi_aruser,
            m_axi_arvalid      => m_axi_arvalid,
            m_axi_arready      => m_axi_arready,
            m_axi_rid          => m_axi_rid,
            m_axi_rdata        => m_axi_rdata,
            m_axi_rresp        => m_axi_rresp,
            m_axi_rlast        => m_axi_rlast,
            m_axi_ruser        => m_axi_ruser,
            m_axi_rvalid       => m_axi_rvalid,
            m_axi_rready       => m_axi_rready
        );

    connect_dma_ports_with_internal_signals_gen : for I in 0 to NUM_CLUSTERS - 1 generate
        -- DMA signals
        dma_dat_o(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I) <= std_ulogic_vector(dma_dat_o_int(I));

        dma_dat_i_int(I)    <= dma_dat_i(DCMA_DATA_WIDTH * (I + 1) - 1 downto DCMA_DATA_WIDTH * I);
        dma_size_int(I)     <= dma_size_i(dma_size_i'length / NUM_CLUSTERS * (I + 1) - 1 downto dma_size_i'length / NUM_CLUSTERS * I);
        dma_base_adr_int(I) <= std_ulogic_vector(dma_base_adr_i(DCMA_ADDR_WIDTH * (I + 1) - 1 downto DCMA_ADDR_WIDTH * I));
    end generate;
end architecture RTL;
