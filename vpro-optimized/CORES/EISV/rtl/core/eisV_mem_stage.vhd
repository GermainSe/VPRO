--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Memory Stage. Request to external Data Memory are handled  --
--                 here. Read Delay can be configured. fwd data depends on    --
--                 this stage are given by record as alu / mult data is avail -- 
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_mem_stage is
    port(
        clk_i            : in  std_logic;
        rst_ni           : in  std_logic;
        -- stall signales
        mem_ready_o      : out std_ulogic; -- to EX
        --        mem_valid_o      : out std_ulogic; -- to WB
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
end entity eisV_mem_stage;

architecture RTL of eisV_mem_stage is

    type mem_pipe_internal_t is array (0 to MEM_DELAY - 1) of mem_pipeline_t;
    signal mem_pipeline_nxt, mem_pipeline_ff : mem_pipe_internal_t;

    signal mem_data_be    : std_ulogic_vector(3 downto 0);
    signal mem_data_wdata : std_ulogic_vector(31 downto 0);
    signal mem_ready_int  : std_ulogic;

begin

    -------------------------------- BE generation --------------------------------
    process(mem_pipeline_i)
    begin
        case (mem_pipeline_i.lsu_data_type) is -- Data type 00 Word, 01 Half word, 11,10 byte
            when WORD =>                -- Writing a word
                case (mem_pipeline_i.lsu_addr(1 downto 0)) is
                    when "00"   => mem_data_be <= "1111";
                    --                    when "01"   => mem_data_be <= "1110"; -- unaligned
                    --                    when "10"   => mem_data_be <= "1100"; -- unaligned
                    --                    when "11"   => mem_data_be <= "1000"; -- unaligned
                    -- coverage off
                    when others => mem_data_be <= "1111";
                        -- coverage on
                end case;               -- case (data_addr_int(1 downto 0))

            when HALFWORD =>            -- Writing a half word
                case (mem_pipeline_i.lsu_addr(1 downto 0)) is
                    when "00"   => mem_data_be <= "0011";
                    --                    when "01"   => mem_data_be <= "0110"; -- unaligned
                    when "10"   => mem_data_be <= "1100";
                    --                    when "11"   => mem_data_be <= "1000"; -- unaligned
                    -- coverage off
                    when others => mem_data_be <= "0011";
                        -- coverage on
                end case;               -- case (data_addr_int(1 downto 0))

            when BYTE =>                -- Writing a byte
                case (mem_pipeline_i.lsu_addr(1 downto 0)) is
                    when "00"   => mem_data_be <= "0001";
                    when "01"   => mem_data_be <= "0010";
                    when "10"   => mem_data_be <= "0100";
                    when "11"   => mem_data_be <= "1000";
                    -- coverage off
                    when others => mem_data_be <= "0001";
                        -- coverage on
                end case;               -- case (data_addr_int(1 downto 0))
        end case;                       -- case (data_type_ex_i)
    end process;

    process(mem_pipeline_i)
    begin
        case (mem_pipeline_i.lsu_addr(1 downto 0)) is
            when "00"   => mem_data_wdata <= mem_pipeline_i.lsu_wdata(31 downto 0);
            when "01"   => mem_data_wdata <= mem_pipeline_i.lsu_wdata(23 downto 0) & mem_pipeline_i.lsu_wdata(31 downto 24);
            when "10"   => mem_data_wdata <= mem_pipeline_i.lsu_wdata(15 downto 0) & mem_pipeline_i.lsu_wdata(31 downto 16);
            when "11"   => mem_data_wdata <= mem_pipeline_i.lsu_wdata(7 downto 0) & mem_pipeline_i.lsu_wdata(31 downto 8);
            when others => mem_data_wdata <= mem_pipeline_i.lsu_wdata(31 downto 0);
        end case;                       -- case (mem_wdata_offset)
    end process;

    -- external data bus signals
    data_bus_interface : process(mem_data_gnt_i, mem_pipeline_i, mem_data_be, mem_data_wdata, wb_ready_i)
    begin
        mem_data_req_o   <= '0';
        mem_data_we_o    <= '0';
        mem_data_addr_o  <= (others => '0');
        mem_data_be_o    <= (others => '0');
        mem_data_wdata_o <= (others => '0');
        if (mem_data_gnt_i = '1') and (wb_ready_i = '1') then -- only if gnt and this will be executed
            if mem_pipeline_i.lsu_op /= LSU_NONE then
                mem_data_req_o               <= '1';
                if mem_pipeline_i.lsu_op = LSU_LOAD then
                    mem_data_we_o <= '0';
                else
                    mem_data_we_o <= '1';
                end if;
                mem_data_addr_o(31 downto 2) <= mem_pipeline_i.lsu_addr(31 downto 2);
                mem_data_be_o                <= mem_data_be;
                mem_data_wdata_o             <= mem_data_wdata;
            end if;
        end if;
    end process;

    -- register/pipeline signals until they get to wb stage
    mem_pipeline : process(mem_pipeline_i, mem_pipeline_ff, mem_data_gnt_i, wb_ready_i)
    begin
        mem_ready_int                     <= wb_ready_i;
        mem_pipeline_nxt(0).rf_waddr      <= mem_pipeline_i.rf_waddr;
        mem_pipeline_nxt(0).rf_wen        <= mem_pipeline_i.rf_wen;
        mem_pipeline_nxt(0).alu_wdata     <= mem_pipeline_i.alu_wdata;
        mem_pipeline_nxt(0).mult_wdata    <= mem_pipeline_i.mult_wdata;
        mem_pipeline_nxt(0).mult_op       <= mem_pipeline_i.mult_op;
        mem_pipeline_nxt(0).lsu_op        <= mem_pipeline_i.lsu_op;
        mem_pipeline_nxt(0).lsu_data_type <= mem_pipeline_i.lsu_data_type;
        mem_pipeline_nxt(0).lsu_sign_ext  <= mem_pipeline_i.lsu_sign_ext;
        mem_pipeline_nxt(0).lsu_addr      <= mem_pipeline_i.lsu_addr;
        mem_pipeline_nxt(0).lsu_wdata     <= mem_pipeline_i.lsu_wdata;

        if mem_pipeline_i.lsu_op /= LSU_NONE then -- this is an access to the data memory
            if (mem_data_gnt_i = '0') or (wb_ready_i = '0') then -- wb ready needed? -> waiting for data but req is ok!? TODO: async req to rd
                mem_ready_int                     <= '0';
                mem_pipeline_nxt(0).rf_waddr      <= (others => '-');
                mem_pipeline_nxt(0).rf_wen        <= '0';
                mem_pipeline_nxt(0).alu_wdata     <= (others => '-');
                mem_pipeline_nxt(0).mult_wdata    <= (others => '-');
                mem_pipeline_nxt(0).mult_op       <= '0';
                mem_pipeline_nxt(0).lsu_op        <= LSU_NONE;
                mem_pipeline_nxt(0).lsu_data_type <= WORD;
                mem_pipeline_nxt(0).lsu_sign_ext  <= '-';
                mem_pipeline_nxt(0).lsu_addr      <= (others => '-');
                mem_pipeline_nxt(0).lsu_wdata     <= (others => '-');
            end if;
        end if;

        if MEM_DELAY > 1 then
            for i in 0 to MEM_DELAY - 2 loop
                mem_pipeline_nxt(i + 1) <= mem_pipeline_ff(i);
            end loop;
        end if;
    end process;

    mem_ready_o <= mem_ready_int;

    -- pipeline register
    pipeline_stage : process(clk_i, rst_ni)
        constant mem_pipeline_null_c : mem_pipe_internal_t := (others => (
            rf_waddr      => (others => '-'),
            rf_wen        => '0',
            alu_wdata     => (others => '-'),
            mult_wdata    => (others => '-'),
            mult_op       => '0',
            lsu_op        => LSU_NONE,
            lsu_data_type => WORD,
            lsu_sign_ext  => '-',
            lsu_addr      => (others => '-'),
            lsu_wdata     => (others => '-')
        ));
    begin
        if (rst_ni = '0') then
            mem_pipeline_ff <= mem_pipeline_null_c;
        elsif rising_edge(clk_i) then
            --mem_valid_ff <= mem_valid_nxt;
            for i in 0 to MEM_DELAY - 1 loop
                if (wb_ready_i = '1') then
                    mem_pipeline_ff(i) <= mem_pipeline_nxt(i);
                end if;
            end loop;
        end if;
    end process;

    -- forward signals
    process(mem_pipeline_ff, mem_pipeline_i, wb_ready_i)
    begin
        mem_busy_o <= not wb_ready_i;

        mem_fwd_data_o(0).waddr   <= mem_pipeline_i.rf_waddr;
        mem_fwd_data_o(0).wen     <= mem_pipeline_i.rf_wen;
        mem_fwd_data_o(0).wdata   <= (others => '0');
        mem_fwd_data_o(0).valid   <= '0';
        mem_fwd_data_o(0).is_alu  <= '0';
        mem_fwd_data_o(0).is_mul  <= '0';
        mem_fwd_data_o(0).is_load <= '0';
        if mem_pipeline_i.lsu_op = LSU_LOAD then
            mem_fwd_data_o(0).valid   <= '0';
            mem_busy_o                <= '1';
            mem_fwd_data_o(0).is_alu  <= '0';
            mem_fwd_data_o(0).is_mul  <= '0';
            mem_fwd_data_o(0).is_load <= '1';
        elsif mem_pipeline_i.mult_op = '1' then
            mem_fwd_data_o(0).valid   <= '0';
            mem_busy_o                <= '1';
            mem_fwd_data_o(0).is_alu  <= '0';
            mem_fwd_data_o(0).is_mul  <= '1';
            mem_fwd_data_o(0).is_load <= '0';
        elsif mem_pipeline_i.lsu_op = LSU_NONE then
            mem_fwd_data_o(0).wdata   <= mem_pipeline_i.alu_wdata;
            mem_fwd_data_o(0).valid   <= mem_pipeline_i.rf_wen;
            mem_fwd_data_o(0).is_alu  <= '1';
            mem_fwd_data_o(0).is_mul  <= '0';
            mem_fwd_data_o(0).is_load <= '0';
            mem_busy_o                <= '1';
        end if;

        if MEM_DELAY > 1 then
            for i in 0 to MEM_DELAY - 2 loop
                mem_fwd_data_o(i + 1).waddr   <= mem_pipeline_ff(i).rf_waddr;
                mem_fwd_data_o(i + 1).wen     <= mem_pipeline_ff(i).rf_wen;
                mem_fwd_data_o(i + 1).wdata   <= (others => '0');
                mem_fwd_data_o(i + 1).valid   <= '0';
                mem_fwd_data_o(i + 1).is_alu  <= '0';
                mem_fwd_data_o(i + 1).is_mul  <= '0';
                mem_fwd_data_o(i + 1).is_load <= '0';
                if mem_pipeline_ff(i).lsu_op = LSU_LOAD then
                    mem_fwd_data_o(i + 1).valid   <= '0';
                    mem_busy_o                    <= '1';
                    mem_fwd_data_o(i + 1).is_alu  <= '0';
                    mem_fwd_data_o(i + 1).is_mul  <= '0';
                    mem_fwd_data_o(i + 1).is_load <= '1';
                elsif mem_pipeline_ff(i).mult_op = '1' then -- this is + 1
                    mem_fwd_data_o(i + 1).valid   <= '1';
                    mem_fwd_data_o(i + 1).wdata   <= mem_pipeline_ff(i).mult_wdata;
                    mem_fwd_data_o(i + 1).is_alu  <= '0';
                    mem_fwd_data_o(i + 1).is_mul  <= '1';
                    mem_fwd_data_o(i + 1).is_load <= '0';
                    mem_busy_o                    <= '1';
                elsif mem_pipeline_ff(i).lsu_op = LSU_NONE then
                    mem_fwd_data_o(i + 1).wdata   <= mem_pipeline_ff(i).alu_wdata;
                    mem_fwd_data_o(i + 1).valid   <= mem_pipeline_ff(i).rf_wen;
                    mem_fwd_data_o(i + 1).is_alu  <= '1';
                    mem_fwd_data_o(i + 1).is_mul  <= '0';
                    mem_fwd_data_o(i + 1).is_load <= '0';
                    mem_busy_o                    <= '1';
                end if;
            end loop;
        end if;
    end process;

    -- wb output assignments
    wb_pipeline_o.rf_waddr            <= mem_pipeline_ff(MEM_DELAY - 1).rf_waddr;
    wb_pipeline_o.rf_wen              <= mem_pipeline_ff(MEM_DELAY - 1).rf_wen;
    wb_pipeline_o.alu_wdata           <= mem_pipeline_ff(MEM_DELAY - 1).alu_wdata;
    wb_pipeline_o.mult_wdata          <= mem_pipeline_ff(MEM_DELAY - 1).mult_wdata;
    wb_pipeline_o.mult_op             <= mem_pipeline_ff(MEM_DELAY - 1).mult_op;
    wb_pipeline_o.lsu_request_pending <= mem_pipeline_ff(MEM_DELAY - 1).lsu_op;
    wb_pipeline_o.lsu_data_type       <= mem_pipeline_ff(MEM_DELAY - 1).lsu_data_type;
    wb_pipeline_o.lsu_sign_ext        <= mem_pipeline_ff(MEM_DELAY - 1).lsu_sign_ext;

end architecture RTL;
