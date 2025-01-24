--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
-- coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_specializations.all;
use core_v2pro.package_datawidths.all;

entity dcma_ram_wrapper is
    generic(
        ADDR_WIDTH      : integer := 12; -- Address Width: maximum is 4K x 72 bit
        DATA_WIDTH      : integer := 64; -- Data Width: maximum is 72 bit
        VPRO_WORD_WIDTH : integer := 16 -- needed for wr enable
    );
    port(
        clk     : in  std_ulogic;       -- Clock 
        -- Port A
        wr_en_a : in  std_ulogic_vector(DATA_WIDTH / VPRO_WORD_WIDTH - 1 downto 0); -- Write Enable
        rd_en_a : in  std_ulogic;       -- Memory Enable
        busy_a  : out std_ulogic;
        wdata_a : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Data Input  
        addr_a  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- Address Input
        rdata_a : out std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Data Output
        -- Port B
        wr_en_b : in  std_ulogic_vector(DATA_WIDTH / VPRO_WORD_WIDTH - 1 downto 0); -- Write Enable
        rd_en_b : in  std_ulogic;       -- Memory Enable
        busy_b  : out std_ulogic;
        wdata_b : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0); -- Data Input  
        addr_b  : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0); -- Address Input
        rdata_b : out std_ulogic_vector(DATA_WIDTH - 1 downto 0) -- Data Output
    );
end entity dcma_ram_wrapper;

architecture RTL of dcma_ram_wrapper is
    -- constants
    constant dcma_num_pipeline_reg_half_c : integer := dcma_num_pipeline_reg_c / 2;

    component dcma_ram
        generic(
            AWIDTH  : integer := 12;
            DWIDTH  : integer := 72;
            NUM_COL : integer := 9
        );
        port(
            clk      : in  std_ulogic;      -- Clock 
            -- Port A
            we_a     : in  std_ulogic_vector(NUM_COL - 1 downto 0); -- Write Enable
            mem_en_a : in  std_ulogic;      -- Memory Enable
            din_a    : in  std_ulogic_vector(DWIDTH - 1 downto 0); -- Data Input  
            addr_a   : in  std_ulogic_vector(AWIDTH - 1 downto 0); -- Address Input
            dout_a   : out std_ulogic_vector(DWIDTH - 1 downto 0); -- Data Output
            -- Port B
            we_b     : in  std_ulogic_vector(NUM_COL - 1 downto 0); -- Write Enable
            mem_en_b : in  std_ulogic;      -- Memory Enable
            din_b    : in  std_ulogic_vector(DWIDTH - 1 downto 0); -- Data Input  
            addr_b   : in  std_ulogic_vector(AWIDTH - 1 downto 0); -- Address Input
            dout_b   : out std_ulogic_vector(DWIDTH - 1 downto 0) -- Data Output
        );
    end component dcma_ram;

    -- types    
    type addr_pipeline_t is array (dcma_num_pipeline_reg_half_c - 1 downto 0) of std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
    type data_pipeline_t is array (dcma_num_pipeline_reg_half_c - 1 downto 0) of std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    type wren_pipeline_t is array (dcma_num_pipeline_reg_half_c - 1 downto 0) of std_ulogic_vector(DATA_WIDTH / VPRO_WORD_WIDTH - 1 downto 0);

    -- pipeline registers
    signal mem_ena_ff, mem_enb_ff : std_ulogic_vector(dcma_num_pipeline_reg_half_c - 1 downto 0) := (others => '0');
    signal wea_ff, web_ff         : wren_pipeline_t;
    signal dina_ff, dinb_ff       : data_pipeline_t;
    signal douta_ff, doutb_ff     : data_pipeline_t;
    signal addra_ff, addrb_ff     : addr_pipeline_t;

    -- signals
    signal mem_ena     : std_ulogic;
    signal mem_enb     : std_ulogic;
    signal rdata_a_int : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
    signal rdata_b_int : std_ulogic_vector(DATA_WIDTH - 1 downto 0);
begin
    no_pipe_gen: if dcma_num_pipeline_reg_c = 0 generate
        process(rd_en_a, rd_en_b, wr_en_a, wr_en_b)
        begin
            mem_ena <= rd_en_a;
            if unsigned(wr_en_a) /= 0 then
                mem_ena <= '1';
            end if;

            mem_enb <= rd_en_b;
            if unsigned(wr_en_b) /= 0 then
                mem_enb <= '1';
            end if;
        end process;

        ram_inst : dcma_ram
            generic map(
                AWIDTH  => ADDR_WIDTH,
                DWIDTH  => DATA_WIDTH,
                NUM_COL => DATA_WIDTH / VPRO_WORD_WIDTH
            )
            port map(
                clk     => clk,
                we_a     => wr_en_a,
                mem_en_a => mem_ena,
                din_a    => wdata_a,
                addr_a   => addr_a,
                dout_a   => rdata_a,
                we_b     => wr_en_b,
                mem_en_b => mem_enb,
                din_b    => wdata_b,
                addr_b   => addr_b,
                dout_b   => rdata_b
            );

        busy_a <= '0';
        busy_b <= '0';
    end generate;
    
    pipe_gen: if dcma_num_pipeline_reg_c > 0 generate
        seq : process(clk)
        begin
            if rising_edge(clk) then
                mem_ena_ff(0) <= mem_ena;
                wea_ff(0)     <= wr_en_a;
                dina_ff(0)    <= wdata_a;
                addra_ff(0)   <= addr_a;
                douta_ff(0)   <= rdata_a_int;
                mem_enb_ff(0) <= mem_enb;
                web_ff(0)     <= wr_en_b;
                dinb_ff(0)    <= wdata_b;
                addrb_ff(0)   <= addr_b;
                doutb_ff(0)   <= rdata_b_int;
                if dcma_num_pipeline_reg_half_c > 1 then                    
                    mem_ena_ff(dcma_num_pipeline_reg_half_c - 1 downto 1) <= mem_ena_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    wea_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)     <= wea_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    dina_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)    <= dina_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    addra_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)   <= addra_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    douta_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)   <= douta_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    mem_enb_ff(dcma_num_pipeline_reg_half_c - 1 downto 1) <= mem_enb_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    web_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)     <= web_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    dinb_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)    <= dinb_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    addrb_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)   <= addrb_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                    doutb_ff(dcma_num_pipeline_reg_half_c - 1 downto 1)   <= doutb_ff(dcma_num_pipeline_reg_half_c - 2 downto 0);
                end if;
            end if;
        end process;

        process(rd_en_a, rd_en_b, wr_en_a, wr_en_b)
        begin
            mem_ena <= rd_en_a;
            if unsigned(wr_en_a) /= 0 then
                mem_ena <= '1';
            end if;

            mem_enb <= rd_en_b;
            if unsigned(wr_en_b) /= 0 then
                mem_enb <= '1';
            end if;
        end process;

        ram_inst : dcma_ram
            generic map(
                AWIDTH  => ADDR_WIDTH,
                DWIDTH  => DATA_WIDTH,
                NUM_COL => DATA_WIDTH / VPRO_WORD_WIDTH
            )
            port map(
                clk     => clk,
                we_a     => wea_ff(dcma_num_pipeline_reg_half_c - 1),
                mem_en_a => mem_ena_ff(dcma_num_pipeline_reg_half_c - 1),
                din_a    => dina_ff(dcma_num_pipeline_reg_half_c - 1),
                addr_a   => addra_ff(dcma_num_pipeline_reg_half_c - 1),
                dout_a   => rdata_a_int,
                we_b     => web_ff(dcma_num_pipeline_reg_half_c - 1),
                mem_en_b => mem_enb_ff(dcma_num_pipeline_reg_half_c - 1),
                din_b    => dinb_ff(dcma_num_pipeline_reg_half_c - 1),
                addr_b   => addrb_ff(dcma_num_pipeline_reg_half_c - 1),
                dout_b   => rdata_b_int
            );
        
        rdata_a <= douta_ff(dcma_num_pipeline_reg_half_c - 1);
        rdata_b <= doutb_ff(dcma_num_pipeline_reg_half_c - 1);

        busy_a <= '0';
        busy_b <= '0';
    end generate;
end architecture RTL;
