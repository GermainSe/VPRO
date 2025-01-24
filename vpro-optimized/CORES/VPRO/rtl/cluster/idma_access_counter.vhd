--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2023, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Gia Bao Thieu <g.thieu@tu-braunschweig.de>
--
--coverage off
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

library core_v2pro;
use core_v2pro.v2pro_package.all;
use core_v2pro.package_datawidths.all;

entity idma_access_counter IS
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
end idma_access_counter;

architecture behavioral of idma_access_counter is
    -- constants
    constant mm_data_width_bytes_log2_c : natural := integer(ceil(log2(real(mm_data_width_c / 8))));

    -- types
    type remaining_counter_t is array (num_clusters - 1 downto 0) of std_ulogic_vector(mem_bundle_dma2mem_i(0).size'length - mm_data_width_bytes_log2_c downto 0);

    -- register
    signal read_hit_counter_ff, read_hit_counter_nxt     : dma_access_counter_t(0 to num_clusters - 1);
    signal read_miss_counter_ff, read_miss_counter_nxt   : dma_access_counter_t(0 to num_clusters - 1);
    signal write_hit_counter_ff, write_hit_counter_nxt   : dma_access_counter_t(0 to num_clusters - 1);
    signal write_miss_counter_ff, write_miss_counter_nxt : dma_access_counter_t(0 to num_clusters - 1);

    signal read_remaining_counter_ff, read_remaining_counter_nxt   : remaining_counter_t;
    signal write_remaining_counter_ff, write_remaining_counter_nxt : remaining_counter_t;

    -- signals

begin             
--coverage off
    no_instantiation_gen : if not instantiate_idma_access_counter_c generate
        read_hit_cycles_o   <= (others => (others => '0'));
        read_miss_cycles_o  <= (others => (others => '0'));
        write_hit_cycles_o  <= (others => (others => '0'));
        write_miss_cycles_o <= (others => (others => '0'));
    end generate;

    instantiation_gen : if instantiate_idma_access_counter_c generate
        read_hit_cycles_o   <= read_hit_counter_ff;
        read_miss_cycles_o  <= read_miss_counter_ff;
        write_hit_cycles_o  <= write_hit_counter_ff;
        write_miss_cycles_o <= write_miss_counter_ff;

        seq : process(dma_clk_i, dma_rst_i)
        begin
            if dma_rst_i = active_reset_c then
                read_hit_counter_ff   <= (others => (others => '0'));
                read_miss_counter_ff  <= (others => (others => '0'));
                write_hit_counter_ff  <= (others => (others => '0'));
                write_miss_counter_ff <= (others => (others => '0'));

                read_remaining_counter_ff  <= (others => (others => '0'));
                write_remaining_counter_ff <= (others => (others => '0'));
            elsif rising_edge(dma_clk_i) then
                read_hit_counter_ff   <= read_hit_counter_nxt;
                read_miss_counter_ff  <= read_miss_counter_nxt;
                write_hit_counter_ff  <= write_hit_counter_nxt;
                write_miss_counter_ff <= write_miss_counter_nxt;

                read_remaining_counter_ff  <= read_remaining_counter_nxt;
                write_remaining_counter_ff <= write_remaining_counter_nxt;
            end if;
        end process;

        comb : process(read_hit_counter_ff, read_miss_counter_ff, write_hit_counter_ff, write_miss_counter_ff, reset_counters_i, read_remaining_counter_ff, mem_bundle_dma2mem_i, mem_bundle_mem2dma_i, write_remaining_counter_ff)
        begin
            -- default
            read_hit_counter_nxt   <= read_hit_counter_ff;
            read_miss_counter_nxt  <= read_miss_counter_ff;
            write_hit_counter_nxt  <= write_hit_counter_ff;
            write_miss_counter_nxt <= write_miss_counter_ff;

            write_remaining_counter_nxt <= write_remaining_counter_ff;
            read_remaining_counter_nxt  <= read_remaining_counter_ff;

            for cluster in 0 to num_clusters - 1 loop
                if mem_bundle_dma2mem_i(cluster).req = '1' and mem_bundle_mem2dma_i(cluster).busy = '0' then
                    if mem_bundle_dma2mem_i(cluster).rw = '1' then
                        write_remaining_counter_nxt(cluster) <= std_ulogic_vector(signed(write_remaining_counter_ff(cluster)) + resize(1 + shift_right(resize(signed('0' & mem_bundle_dma2mem_i(cluster).base_adr(mm_data_width_bytes_log2_c - 1 downto 0)), write_remaining_counter_nxt(cluster)'length) + signed('0' & mem_bundle_dma2mem_i(cluster).size) - 1, mm_data_width_bytes_log2_c), write_remaining_counter_nxt(cluster)'length));
                    else
                        read_remaining_counter_nxt(cluster) <= std_ulogic_vector(signed(read_remaining_counter_ff(cluster)) + resize(1 + shift_right(resize(signed('0' & mem_bundle_dma2mem_i(cluster).base_adr(mm_data_width_bytes_log2_c - 1 downto 0)), read_remaining_counter_nxt(cluster)'length) + signed('0' & mem_bundle_dma2mem_i(cluster).size) - 1, mm_data_width_bytes_log2_c), read_remaining_counter_nxt(cluster)'length));
                    end if;
                end if;

                if mem_bundle_dma2mem_i(cluster).rden = '1' and mem_bundle_mem2dma_i(cluster).rrdy = '1' then
                    read_hit_counter_nxt(cluster)       <= std_ulogic_vector(unsigned(read_hit_counter_ff(cluster)) + 1);
                    read_remaining_counter_nxt(cluster) <= std_ulogic_vector(signed(read_remaining_counter_ff(cluster)) - 1);

                    if mem_bundle_dma2mem_i(cluster).req = '1' and mem_bundle_mem2dma_i(cluster).busy = '0' and mem_bundle_dma2mem_i(cluster).rw = '0' then
                        read_remaining_counter_nxt(cluster) <= std_ulogic_vector(signed(read_remaining_counter_ff(cluster)) - 1 + resize(1 + shift_right(resize(signed('0' & mem_bundle_dma2mem_i(cluster).base_adr(mm_data_width_bytes_log2_c - 1 downto 0)), read_remaining_counter_nxt(cluster)'length) + signed('0' & mem_bundle_dma2mem_i(cluster).size) - 1, mm_data_width_bytes_log2_c), read_remaining_counter_nxt(cluster)'length));
                    end if;
                else
                    if signed(read_remaining_counter_ff(cluster)) /= 0 then
                        read_miss_counter_nxt(cluster) <= std_ulogic_vector(unsigned(read_miss_counter_ff(cluster)) + 1);
                    end if;
                end if;

                if mem_bundle_dma2mem_i(cluster).wren = '1' and mem_bundle_mem2dma_i(cluster).wrdy = '1' then
                    write_hit_counter_nxt(cluster)       <= std_ulogic_vector(unsigned(write_hit_counter_ff(cluster)) + 1);
                    write_remaining_counter_nxt(cluster) <= std_ulogic_vector(signed(write_remaining_counter_ff(cluster)) - 1);

                    if mem_bundle_dma2mem_i(cluster).req = '1' and mem_bundle_mem2dma_i(cluster).busy = '0' and mem_bundle_dma2mem_i(cluster).rw = '1' then
                        write_remaining_counter_nxt(cluster) <= std_ulogic_vector(signed(write_remaining_counter_ff(cluster)) - 1 + resize(1 + shift_right(resize(signed('0' & mem_bundle_dma2mem_i(cluster).base_adr(mm_data_width_bytes_log2_c - 1 downto 0)), write_remaining_counter_nxt(cluster)'length) + signed('0' & mem_bundle_dma2mem_i(cluster).size) - 1, mm_data_width_bytes_log2_c), write_remaining_counter_nxt(cluster)'length));
                    end if;
                else
                    if signed(write_remaining_counter_ff(cluster)) /= 0 then
                        write_miss_counter_nxt(cluster) <= std_ulogic_vector(unsigned(write_miss_counter_ff(cluster)) + 1);
                    end if;
                end if;
            end loop;

            if reset_counters_i = '1' then
                read_hit_counter_nxt        <= (others => (others => '0'));
                read_miss_counter_nxt       <= (others => (others => '0'));
                write_hit_counter_nxt       <= (others => (others => '0'));
                write_miss_counter_nxt      <= (others => (others => '0'));
                read_remaining_counter_nxt  <= (others => (others => '0'));
                write_remaining_counter_nxt <= (others => (others => '0'));
            end if;
        end process;

    end generate;
             
--coverage on
end behavioral;
