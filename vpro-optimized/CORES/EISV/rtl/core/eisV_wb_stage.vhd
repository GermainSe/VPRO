--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Write Back Stage                                           -- 
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_misc.all;            -- @suppress "Non-standard package"

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_wb_stage is
    port(
        clk_i            : in  std_logic; -- @suppress "Unused port: clk_i is not used in eisv.eisV_wb_stage(RTL)"
        rst_ni           : in  std_logic; -- @suppress "Unused port: rst_ni is not used in eisv.eisV_wb_stage(RTL)"
        -- stall signales
        wb_ready_o       : out std_ulogic; -- to MEM
        -- pipeline signals
        wb_pipeline_i    : in  wb_pipeline_t; -- input from MEM/WB pipeline register
        -- forward signals (or result)
        wb_fwd_data_o    : out fwd_t;
        -- Data memory signals (extern memory)
        wb_data_rdata_i  : in  std_ulogic_vector(31 downto 0);
        wb_data_rvalid_i : in  std_ulogic
    );
end entity eisV_wb_stage;

architecture RTL of eisV_wb_stage is

    signal wb_rdata_b_ext, wb_rdata_h_ext : std_ulogic_vector(31 downto 0);
    signal wb_rdata                       : std_ulogic_vector(31 downto 0);
    signal wb_raddr                       : std_ulogic_vector(1 downto 0);

begin

    wb_raddr <= wb_pipeline_i.alu_wdata(1 downto 0);

    -- sign extension for half words
    process(wb_pipeline_i, wb_data_rdata_i, wb_raddr)
    begin
        if wb_raddr = "00" then
            if wb_pipeline_i.lsu_sign_ext = '0' then
                wb_rdata_h_ext <= x"0000" & wb_data_rdata_i(15 downto 0);
            else
                wb_rdata_h_ext <= bit_repeat(16, wb_data_rdata_i(15)) & wb_data_rdata_i(15 downto 0);
            end if;
        else
            if wb_pipeline_i.lsu_sign_ext = '0' then
                wb_rdata_h_ext <= x"0000" & wb_data_rdata_i(31 downto 16);
            else
                wb_rdata_h_ext <= bit_repeat(16, wb_data_rdata_i(31)) & wb_data_rdata_i(31 downto 16);
            end if;
        end if;
        --        case (wb_raddr) is
        --            when "01" | "11" =>
        --                if (wb_pipeline_i.lsu_request_pending = LSU_LOAD) then
        ----                    assert wb_pipeline_i.lsu_data_type /= HALFWORD report "[WB] RH on byte address! -> Misaligned Memory Access!!!" severity failure;
        --                end if;
        --            when "10" =>
        --            when others =>              -- "00"
        --        end case;
    end process;

    -- sign extension for bytes
    process(wb_pipeline_i, wb_data_rdata_i, wb_raddr)
    begin
        case (wb_raddr) is
            when "01" =>
                if wb_pipeline_i.lsu_sign_ext = '0' then
                    wb_rdata_b_ext <= x"000000" & wb_data_rdata_i(15 downto 8);
                else
                    wb_rdata_b_ext <= bit_repeat(24, wb_data_rdata_i(15)) & wb_data_rdata_i(15 downto 8);
                end if;
            when "10" =>
                if wb_pipeline_i.lsu_sign_ext = '0' then
                    wb_rdata_b_ext <= x"000000" & wb_data_rdata_i(23 downto 16);
                else
                    wb_rdata_b_ext <= bit_repeat(24, wb_data_rdata_i(23)) & wb_data_rdata_i(23 downto 16);
                end if;
            when "11" =>
                if wb_pipeline_i.lsu_sign_ext = '0' then
                    wb_rdata_b_ext <= x"000000" & wb_data_rdata_i(31 downto 24);
                else
                    wb_rdata_b_ext <= bit_repeat(24, wb_data_rdata_i(31)) & wb_data_rdata_i(31 downto 24);
                end if;
            when others =>              -- "00"
                if wb_pipeline_i.lsu_sign_ext = '0' then
                    wb_rdata_b_ext <= x"000000" & wb_data_rdata_i(7 downto 0);
                else
                    wb_rdata_b_ext <= bit_repeat(24, wb_data_rdata_i(7)) & wb_data_rdata_i(7 downto 0);
                end if;
        end case;
    end process;

    -- select word, half word or byte sign extended version
    process(wb_pipeline_i, wb_rdata_b_ext, wb_rdata_h_ext, wb_data_rdata_i, wb_raddr) -- @suppress "Superfluous signals in sensitivity list. The process is not sensitive to signal 'wb_raddr'"
    begin
        case (wb_pipeline_i.lsu_data_type) is
            when WORD =>
                if (wb_pipeline_i.lsu_request_pending = LSU_LOAD) then
                    --                    assert wb_raddr = "00" report "[WB] RW on (half)byte address! -> Misaligned Memory Access!!!" severity failure;
                end if;
                wb_rdata <= wb_data_rdata_i;
            when HALFWORD =>
                wb_rdata <= wb_rdata_h_ext;
            when BYTE =>
                wb_rdata <= wb_rdata_b_ext;
        end case;
    end process;

    -- output signal assignments
    process(wb_pipeline_i, wb_data_rvalid_i, wb_rdata)
    begin
        wb_ready_o            <= '1';
        wb_fwd_data_o.valid   <= wb_pipeline_i.rf_wen;
        wb_fwd_data_o.wen     <= wb_pipeline_i.rf_wen;
        wb_fwd_data_o.waddr   <= wb_pipeline_i.rf_waddr;
        wb_fwd_data_o.is_alu  <= '0';
        wb_fwd_data_o.is_mul  <= '0';
        wb_fwd_data_o.is_load <= '0';

        if wb_pipeline_i.mult_op = '1' then
            wb_fwd_data_o.wdata   <= wb_pipeline_i.mult_wdata;
            wb_fwd_data_o.is_alu  <= '0';
            wb_fwd_data_o.is_mul  <= '1';
            wb_fwd_data_o.is_load <= '0';
        else
            wb_fwd_data_o.wdata   <= wb_pipeline_i.alu_wdata;
            wb_fwd_data_o.is_alu  <= '1';
            wb_fwd_data_o.is_mul  <= '0';
            wb_fwd_data_o.is_load <= '0';
        end if;

        if (wb_pipeline_i.lsu_request_pending = LSU_LOAD) then
            wb_fwd_data_o.is_alu  <= '0';
            wb_fwd_data_o.is_mul  <= '0';
            wb_fwd_data_o.is_load <= '1';
            if wb_data_rvalid_i = '0' then
                wb_ready_o          <= '0';
                wb_fwd_data_o.valid <= '0';
                wb_fwd_data_o.wen   <= '0';
            else
                wb_fwd_data_o.wdata <= wb_rdata;
                wb_fwd_data_o.valid <= wb_pipeline_i.rf_wen;
                wb_fwd_data_o.wen   <= wb_pipeline_i.rf_wen;
            end if;
        elsif (wb_pipeline_i.lsu_request_pending = LSU_NONE) then
            -- STORE also receives a rvalid response
            --            assert wb_data_rvalid_i /= '1' report "WB stage got data (rvalid) from external data memory but does not expect to receive any data! -> can happen if external responds following cycle after req (e.g. for a write command)" severity warning;
        end if;
    end process;

end architecture RTL;
