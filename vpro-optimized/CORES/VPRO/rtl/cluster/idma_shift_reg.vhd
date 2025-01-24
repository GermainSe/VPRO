--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2022, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
--coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

entity idma_shift_reg IS
    generic(
        DATA_WIDTH      : integer := 128; -- data width at write port
        SUBDATA_WIDTH   : integer := 16; -- data width at write port
        DATA_DEPTH_LOG2 : integer := 2  -- fifo depth (number of words with data width), log2
    );

    port(
        clk      : in  std_ulogic;
        reset_n  : in  std_ulogic;
        -- *** write port ***
        wr_full  : out std_ulogic;      -- can new data be written?
        wr_en    : in  std_ulogic_vector(integer(ceil(log2(real(DATA_WIDTH / SUBDATA_WIDTH)))) DOWNTO 0); -- how many subwords are written
        wdata    : in  std_ulogic_vector(DATA_WIDTH - 1 DOWNTO 0);
        -- *** read port ***
        rd_count : out std_ulogic_vector(integer(ceil(log2(real(DATA_WIDTH / SUBDATA_WIDTH)))) DOWNTO 0); -- number of valid fifo entries up to DATA_WIDTH / SUBDATA_WIDTH
        rd_en    : in  std_ulogic_vector(integer(ceil(log2(real(DATA_WIDTH / SUBDATA_WIDTH)))) DOWNTO 0); -- how many subwords are read
        rdata    : out std_ulogic_vector(DATA_WIDTH - 1 DOWNTO 0)
    );
end idma_shift_reg;

architecture behavioral OF idma_shift_reg IS
    component idma_shift_reg_mem
        generic(
            ADDR_WIDTH : integer := 10;
            DATA_WIDTH : integer := 16
        );
        port(
            clk     : in  std_ulogic;
            wr_en   : in  std_ulogic;
            wr_addr : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            rd_addr : in  std_ulogic_vector(ADDR_WIDTH - 1 downto 0);
            wdata   : in  std_ulogic_vector(DATA_WIDTH - 1 downto 0);
            rdata   : out std_ulogic_vector(DATA_WIDTH - 1 downto 0)
        );
    end component idma_shift_reg_mem;

    constant fifo_depth_c      : integer := 2 ** DATA_DEPTH_LOG2 * DATA_WIDTH / SUBDATA_WIDTH;
    constant fifo_depth_log2_c : integer := integer(ceil(log2(real(fifo_depth_c))));

    constant ram_depth_c      : integer := 2 ** DATA_DEPTH_LOG2;
    constant ram_depth_log2_c : integer := integer(ceil(log2(real(fifo_depth_c))));

    constant num_subwords_c      : integer := DATA_WIDTH / SUBDATA_WIDTH;
    constant num_subwords_log2_c : integer := integer(ceil(log2(real(num_subwords_c))));

    type subram_type is array (0 to ram_depth_c - 1) of std_ulogic_vector(SUBDATA_WIDTH - 1 DOWNTO 0);
    type ram_type is array (0 to DATA_WIDTH / SUBDATA_WIDTH - 1) of subram_type;
    signal ram_ff, ram_nxt : ram_type;

    signal wr_pointer_ff, wr_pointer_nxt       : std_ulogic_vector(fifo_depth_log2_c downto 0);
    signal rd_pointer_ff, rd_pointer_nxt       : std_ulogic_vector(fifo_depth_log2_c downto 0);
    signal complete_full_ff, complete_full_nxt : std_ulogic;

    type ram_addr_t is array (0 to DATA_WIDTH / SUBDATA_WIDTH - 1) of std_ulogic_vector(ram_depth_log2_c - 1 downto 0);
    type ram_data_t is array (0 to DATA_WIDTH / SUBDATA_WIDTH - 1) of std_ulogic_vector(SUBDATA_WIDTH - 1 downto 0);
    signal ram_wr_addr    : ram_addr_t;
    signal ram_rd_addr    : ram_addr_t;
    signal ram_wr_word_en : std_ulogic_vector(DATA_WIDTH / SUBDATA_WIDTH - 1 downto 0);
    signal ram_wr_data    : ram_data_t;
    signal ram_rd_data    : ram_data_t;

begin             
--coverage off

    ram_gen : for I in 0 to DATA_WIDTH / SUBDATA_WIDTH - 1 generate
        idma_shift_reg_mem_inst : idma_shift_reg_mem
            generic map(
                ADDR_WIDTH => ram_depth_log2_c,
                DATA_WIDTH => SUBDATA_WIDTH
            )
            port map(
                clk     => clk,
                wr_en   => ram_wr_word_en(I),
                wr_addr => ram_wr_addr(I),
                rd_addr => ram_rd_addr(I),
                wdata   => ram_wr_data(I),
                rdata   => ram_rd_data(I)
            );
    end generate;

    seq : process(clk, reset_n)
    begin
        if reset_n = '0' then
            ram_ff           <= (others => (others => (others => '0')));
            wr_pointer_ff    <= (others => '0');
            rd_pointer_ff    <= (others => '0');
            complete_full_ff <= '0';
        elsif rising_edge(clk) then
            ram_ff           <= ram_nxt;
            wr_pointer_ff    <= wr_pointer_nxt;
            rd_pointer_ff    <= rd_pointer_nxt;
            complete_full_ff <= complete_full_nxt;
        end if;
    end process;

    ram_wr_addr_proc : process(wr_en, wr_pointer_ff, wdata)
        variable ram_idx      : integer;
        variable pointer_incr : unsigned(wr_pointer_ff'length - 2 downto 0);
    begin
        ram_wr_word_en <= (others => '0');
        ram_wr_addr    <= (others => (others => '-'));
        ram_wr_data    <= (others => (others => '-'));

        for I in 0 to DATA_WIDTH / SUBDATA_WIDTH - 1 loop
            if I < unsigned(wr_en) then
                ram_idx                 := to_integer(unsigned(wr_pointer_ff(num_subwords_log2_c - 1 downto 0)) + I);
                pointer_incr            := resize(unsigned(wr_pointer_ff) + I, pointer_incr'length);
                ram_wr_word_en(ram_idx) <= '1';
                ram_wr_addr(ram_idx)    <= std_ulogic_vector(resize(unsigned(pointer_incr(pointer_incr'left downto num_subwords_log2_c)), ram_wr_addr(0)'length));
                ram_wr_data(ram_idx)    <= wdata((I + 1) * SUBDATA_WIDTH - 1 downto I * SUBDATA_WIDTH);
            end if;
        end loop;
    end process;

    ram_wr_comb : process(ram_ff, ram_wr_addr, ram_wr_word_en, ram_wr_data)
    begin
        ram_nxt <= ram_ff;

        if unsigned(ram_wr_word_en) /= 0 then
            for I in 0 to DATA_WIDTH / SUBDATA_WIDTH - 1 loop
                if ram_wr_word_en(I) = '1' then
                    ram_nxt(I)(to_integer(unsigned(ram_wr_addr(I)))) <= ram_wr_data(I);
                end if;
            end loop;
        end if;

        --            for I in 0 to DATA_WIDTH / SUBDATA_WIDTH - 1 loop
        --                if I < unsigned(wr_en) then
        --                    if I + unsigned(wr_pointer_ff) < fifo_depth_c then
        --                        ram_nxt(to_integer(unsigned(wr_pointer_ff) + I)) <= wdata((I + 1) * SUBDATA_WIDTH - 1 downto I * SUBDATA_WIDTH);
        --                    else
        --                        ram_nxt(to_integer(unsigned(wr_pointer_ff) + I - fifo_depth_c)) <= wdata((I + 1) * SUBDATA_WIDTH - 1 downto I * SUBDATA_WIDTH);
        --                    end if;
        --                end if;
        --            end loop;
    end process;

    --    ram_rd_gen : for I in 0 to DATA_WIDTH / SUBDATA_WIDTH - 1 generate
    --        rdata((I + 1) * SUBDATA_WIDTH - 1 downto I * SUBDATA_WIDTH) <= ram_ff(to_integer(unsigned(rd_pointer_ff) + I)) when I + unsigned(rd_pointer_ff) < fifo_depth_c else
    --                                                                       ram_ff(to_integer(unsigned(rd_pointer_ff) + I - fifo_depth_c));
    --    end generate;

    ram_rd_addr_proc : process(rd_pointer_ff)
        variable ram_idx      : integer;
        variable pointer_incr : unsigned(rd_pointer_ff'length - 2 downto 0);
    begin
        ram_rd_addr <= (others => (others => '-'));

        for I in 0 to DATA_WIDTH / SUBDATA_WIDTH - 1 loop
            ram_idx              := to_integer(unsigned(rd_pointer_ff(num_subwords_log2_c - 1 downto 0)) + I);
            pointer_incr         := resize(unsigned(rd_pointer_ff) + I, pointer_incr'length);
            ram_rd_addr(ram_idx) <= std_ulogic_vector(resize(unsigned(pointer_incr(pointer_incr'left downto num_subwords_log2_c)), ram_rd_addr(0)'length));
        end loop;
    end process;

    ram_rd_data_proc : process(ram_rd_data, rd_pointer_ff)
        variable ram_idx : integer;
    begin
        rdata <= (others => '0');

        for I in 0 to DATA_WIDTH / SUBDATA_WIDTH - 1 loop
            ram_idx                                                     := to_integer(unsigned(rd_pointer_ff(num_subwords_log2_c - 1 downto 0)) + I);
            rdata((I + 1) * SUBDATA_WIDTH - 1 downto I * SUBDATA_WIDTH) <= ram_rd_data(ram_idx);
        end loop;
    end process;

    full_comb : process(complete_full_ff, rd_pointer_nxt, wr_en, wr_pointer_nxt, rd_en)
    begin
        -- default
        complete_full_nxt <= complete_full_ff;

        if unsigned(wr_en) /= 0 then
            if wr_pointer_nxt = rd_pointer_nxt then
                complete_full_nxt <= '1';
            end if;
        elsif unsigned(rd_en) /= 0 then
            complete_full_nxt <= '0';
        end if;
    end process;

    pointer_comb : process(rd_pointer_ff, wr_pointer_ff, wr_en, rd_en)
    begin
        -- default
        wr_pointer_nxt <= wr_pointer_ff;
        rd_pointer_nxt <= rd_pointer_ff;

        if unsigned(wr_en) /= 0 then
            wr_pointer_nxt <= std_ulogic_vector(unsigned(wr_pointer_ff) + unsigned(wr_en));
            if unsigned(wr_pointer_ff) + unsigned(wr_en) >= fifo_depth_c then
                wr_pointer_nxt <= std_ulogic_vector(unsigned(wr_pointer_ff) + unsigned(wr_en) - fifo_depth_c);
            end if;
        end if;

        if unsigned(rd_en) /= 0 then
            rd_pointer_nxt <= std_ulogic_vector(unsigned(rd_pointer_ff) + unsigned(rd_en));
            if unsigned(rd_pointer_ff) + unsigned(rd_en) >= fifo_depth_c then
                rd_pointer_nxt <= std_ulogic_vector(unsigned(rd_pointer_ff) + unsigned(rd_en) - fifo_depth_c);
            end if;
        end if;
    end process;

    empty_full_comb : process(rd_pointer_ff, wr_pointer_ff, complete_full_ff)
        variable nr_free_fifo_entries : unsigned(fifo_depth_log2_c downto 0);
        variable nr_used_fifo_entries : unsigned(fifo_depth_log2_c downto 0);
    begin
        nr_free_fifo_entries := fifo_depth_c - unsigned(wr_pointer_ff) + unsigned(rd_pointer_ff);
        nr_used_fifo_entries := unsigned(wr_pointer_ff) - unsigned(rd_pointer_ff);
        if unsigned(rd_pointer_ff) > unsigned(wr_pointer_ff) then
            nr_free_fifo_entries := unsigned(rd_pointer_ff) - unsigned(wr_pointer_ff);
            nr_used_fifo_entries := unsigned(wr_pointer_ff) + fifo_depth_c - unsigned(rd_pointer_ff);
        end if;

        wr_full <= '0';
        if nr_free_fifo_entries < DATA_WIDTH / SUBDATA_WIDTH or (wr_pointer_ff = rd_pointer_ff and complete_full_ff = '1') then
            wr_full <= '1';
        end if;

        rd_count <= std_ulogic_vector(nr_used_fifo_entries(rd_count'range));
        if nr_used_fifo_entries >= DATA_WIDTH / SUBDATA_WIDTH or (wr_pointer_ff = rd_pointer_ff and complete_full_ff = '1') then
            rd_count <= std_ulogic_vector(to_unsigned(DATA_WIDTH / SUBDATA_WIDTH, rd_count'length));
        end if;
    end process;
             
--coverage on
end behavioral;
