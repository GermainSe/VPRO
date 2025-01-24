--  SPDX-License-Identifier: MIT
--  SPDX-FileCopyrightText: TU Braunschweig, Institut fuer Theoretische Informatik
--  SPDX-FileCopyrightText: 2021, Chair for Chip Design for Embedded Computing, https://www.tu-braunschweig.de/eis
--  SPDX-FileContributor: Sven Gesper <s.gesper@tu-braunschweig.de>
--
--------------------------------------------------------------------------------
--                                                                            --
-- Description:    Execution stage: Hosts ALU and MUL unit                    --
--                 ALU: computes additions/subtractions/comparisons           --
--                 MUL: computes normal multiplications                       --
--                                                                            --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library eisv;
use eisv.eisV_pkg.all;
use eisv.eisV_pkg_units.all;

entity eisV_ex_stage is
    port(
        clk_i                : in  std_ulogic;
        rst_ni               : in  std_ulogic;
        -- stall signales
        ex_ready_o           : out std_ulogic; -- to ID
        ex_valid_o           : out std_ulogic; -- to MEM
        mem_ready_i          : in  std_ulogic; -- from MEM
        -- pipeline signals
        ex_pipeline_i        : in  ex_pipeline_t; -- input from ID/EX pipeline register
        mem_pipeline_o       : out mem_pipeline_t; -- output from EX/MEM pipeline register
        -- forward signals
        ex_fwd_o             : out fwd_t;
        mem_fwd_i            : in  fwd_bundle_t(MEM_DELAY - 1 downto 0);
        wb_fwd_i             : in  fwd_t;
        -- special outputs
        ex_csr_wdata_o       : out std_ulogic_vector(31 downto 0);
        ex_csr_addr_o        : out std_ulogic_vector(11 downto 0);
        ex_branch_decision_o : out std_ulogic;
        ex_multicycle_o      : out std_ulogic; -- indicates still runnning div for counters/events
        -- post fwd mux (hazards resolved if data is used)
        ex_operand_a_o       : out std_ulogic_vector(31 downto 0);
        ex_operand_b_o       : out std_ulogic_vector(31 downto 0)
    );
end entity eisV_ex_stage;

architecture RTL of eisV_ex_stage is
    signal ex_fwd_mux_operand_a, ex_fwd_mux_operand_b : std_ulogic_vector(31 downto 0);

    signal ex_lsu_wdata                        : std_ulogic_vector(31 downto 0);
    signal ex_valid_int                        : std_ulogic;
    signal ex_mult_ready_int, ex_alu_ready_int : std_ulogic;

    signal mult_en, alu_en : std_ulogic; -- includes stall due to operand missing (~ id not valid?)

    signal ex_alu_result  : std_ulogic_vector(31 downto 0);
    signal mem_mult_wdata : std_ulogic_vector(31 downto 0);

    signal ex_mult_multicycle_int : std_ulogic; -- @suppress "signal ex_mult_multicycle_int is never read"
    signal ex_alu_multicycle_int  : std_ulogic; -- @suppress "signal ex_alu_multicycle_int is never read"

    signal ex_fwd_wb_data_stall : std_ulogic;

    signal ex_operand_a, ex_operand_b : std_ulogic_vector(31 downto 0);
begin

    -- 2:1 MUX for: A register | IMM,PC-Register (ID1 MUX) 
    operand_a_ex_mux : process(ex_pipeline_i)
    begin
        case (ex_pipeline_i.operand_a_data_mux) is
            when OP_A_REGA => ex_operand_a <= ex_pipeline_i.operand_a_data_reg;
            when others    => ex_operand_a <= ex_pipeline_i.operand_a_data_pre;
        end case;
    end process;

    -- 2:1 MUX for: B register | IMM (ID1 MUX)
    operand_b_ex_mux : process(ex_pipeline_i)
    begin
        case (ex_pipeline_i.operand_b_data_mux) is
            when OP_B_REGB => ex_operand_b <= ex_pipeline_i.operand_b_data_reg;
            when others    => ex_operand_b <= ex_pipeline_i.operand_b_data_pre;
        end case;
    end process;

    -- EX Forward MUX A
    process(ex_pipeline_i, mem_fwd_i, wb_fwd_i, ex_operand_a)
        variable reg_fwd_data : std_ulogic_vector(31 downto 0);
    begin
        reg_fwd_data := ex_operand_a;
        if ex_pipeline_i.operand_a_fwd_src = SEL_FW_WB then
            reg_fwd_data := wb_fwd_i.wdata;
        end if;

        if (MEM_DELAY = 1) then
            if ex_pipeline_i.operand_a_fwd_src = SEL_FW_MEM1 then
                reg_fwd_data := mem_fwd_i(0).wdata;
            end if;
        end if;
        if (MEM_DELAY = 2) then
            if ex_pipeline_i.operand_a_fwd_src = SEL_FW_MEM1 then
                reg_fwd_data := mem_fwd_i(0).wdata;
            elsif ex_pipeline_i.operand_a_fwd_src = SEL_FW_MEM2 then
                reg_fwd_data := mem_fwd_i(1).wdata;
            end if;
        end if;
        if (MEM_DELAY = 3) then
            if ex_pipeline_i.operand_a_fwd_src = SEL_FW_MEM1 then
                reg_fwd_data := mem_fwd_i(0).wdata;
            elsif ex_pipeline_i.operand_a_fwd_src = SEL_FW_MEM2 then
                reg_fwd_data := mem_fwd_i(1).wdata;
            elsif ex_pipeline_i.operand_a_fwd_src = SEL_FW_MEM3 then
                reg_fwd_data := mem_fwd_i(2).wdata;
            end if;
        end if;

        -- only regfile or forward if no immediate (operand_a_reg)
        if ex_pipeline_i.operand_a_data_mux /= OP_A_REGA or ex_pipeline_i.operand_a_fwd_src = SEL_REGFILE then
            ex_fwd_mux_operand_a <= ex_operand_a;
        else
            ex_fwd_mux_operand_a <= reg_fwd_data;
        end if;

        -- coverage off
        if ex_pipeline_i.operand_a_fwd_src = SEL_REGFILE then
            ex_operand_a_o <= ex_pipeline_i.operand_a_data_reg;
        else
            ex_operand_a_o <= reg_fwd_data;
        end if;
        -- coverage on

    end process;

    -- EX Forward MUX B
    -- can also be lsu wdata
    process(ex_pipeline_i, mem_fwd_i, wb_fwd_i, ex_operand_b)
        variable reg_fwd_data : std_ulogic_vector(31 downto 0);
    begin
        reg_fwd_data := ex_operand_b;
        if ex_pipeline_i.operand_b_fwd_src = SEL_FW_WB then
            reg_fwd_data := wb_fwd_i.wdata;
        end if;
        -- coverage off 
        if (MEM_DELAY = 1) then
            if ex_pipeline_i.operand_b_fwd_src = SEL_FW_MEM1 then
                reg_fwd_data := mem_fwd_i(0).wdata;
            end if;
        end if;
        -- coverage on 
        if (MEM_DELAY = 2) then
            if ex_pipeline_i.operand_b_fwd_src = SEL_FW_MEM1 then
                reg_fwd_data := mem_fwd_i(0).wdata;
            elsif ex_pipeline_i.operand_b_fwd_src = SEL_FW_MEM2 then
                reg_fwd_data := mem_fwd_i(1).wdata;
            end if;
        end if;
        -- coverage off 
        if (MEM_DELAY = 3) then
            if ex_pipeline_i.operand_b_fwd_src = SEL_FW_MEM1 then
                reg_fwd_data := mem_fwd_i(0).wdata;
            elsif ex_pipeline_i.operand_b_fwd_src = SEL_FW_MEM2 then
                reg_fwd_data := mem_fwd_i(1).wdata;
            elsif ex_pipeline_i.operand_b_fwd_src = SEL_FW_MEM3 then
                reg_fwd_data := mem_fwd_i(2).wdata;
            end if;
        end if;
        -- coverage on

        -- only regfile or forward if no immediate (operand_b_reg)
        if ex_pipeline_i.operand_b_data_mux /= OP_B_REGB or ex_pipeline_i.operand_b_fwd_src = SEL_REGFILE then
            ex_fwd_mux_operand_b <= ex_operand_b;
        else
            ex_fwd_mux_operand_b <= reg_fwd_data;
        end if;

        -- write data always from register file or forward
        if ex_pipeline_i.operand_b_fwd_src = SEL_REGFILE then
            ex_lsu_wdata <= ex_pipeline_i.lsu_wdata;
        else
            ex_lsu_wdata <= reg_fwd_data;
        end if;

        if ex_pipeline_i.operand_b_fwd_src = SEL_REGFILE then
            ex_operand_b_o <= ex_pipeline_i.operand_b_data_reg;
        else
            ex_operand_b_o <= reg_fwd_data;
        end if;
    end process;

    wb_stall : process(ex_pipeline_i, wb_fwd_i.wen)
    begin
        --
        -- load is not deterministic (can be delayed response if cache miss etc.)
        -- this needs additional this check (not possible in id stage)
        -- if wb not rdy, stall ex input + ID by ID
        --
        ex_fwd_wb_data_stall <= '0';
        if ex_pipeline_i.alu_op = '1' or ex_pipeline_i.mult_op = '1' then -- for load / store, alu is active (address add)
            if ex_pipeline_i.operand_a_fwd_src = SEL_FW_WB then
                if wb_fwd_i.wen = '0' then
                    ex_fwd_wb_data_stall <= '1';
                end if;
            end if;
            if ex_pipeline_i.operand_b_fwd_src = SEL_FW_WB then
                if wb_fwd_i.wen = '0' then
                    ex_fwd_wb_data_stall <= '1';
                end if;
            end if;
        end if;
    end process;

    ex_csr_wdata_o <= ex_fwd_mux_operand_a;
    ex_csr_addr_o  <= ex_fwd_mux_operand_b(11 downto 0);

    ----------------------------
    --  ALU (+Div)
    ----------------------------
    alu_i : eisV_alu
        port map(
            clk_i                  => clk_i,
            rst_ni                 => rst_ni,
            ex_enable_i            => alu_en,
            ex_operator_i          => ex_pipeline_i.alu_operator,
            ex_operand_a_i         => ex_fwd_mux_operand_a,
            ex_operand_b_i         => ex_fwd_mux_operand_b,
            ex_result_o            => ex_alu_result,
            ex_comparison_result_o => ex_branch_decision_o,
            ex_alu_multicycle_o    => ex_alu_multicycle_int,
            ex_alu_ready_o         => ex_alu_ready_int,
            mem_ready_i            => mem_ready_i -- TODO: do not repeat mult / buffer result until mem have read it
        );

    alu_en <= ex_pipeline_i.alu_op when ex_fwd_wb_data_stall = '0' else '0';

    ----------------------------------------------------------------
    --  Mult
    ----------------------------------------------------------------
    mult_i : eisV_mult
        port map(
            clk_i                => clk_i,
            rst_ni               => rst_ni,
            ex_enable_i          => mult_en,
            ex_operator_i        => ex_pipeline_i.mult_operator,
            ex_signed_i          => ex_pipeline_i.mult_signed_mode,
            ex_op_a_i            => ex_fwd_mux_operand_a,
            ex_op_b_i            => ex_fwd_mux_operand_b,
            mem_result_o         => mem_mult_wdata,
            ex_mult_multicycle_o => ex_mult_multicycle_int,
            ex_mult_ready_o      => ex_mult_ready_int,
            mem_ready_i          => mem_ready_i -- TODO: do not repeat mult / buffer result until mem have read it
        );

    mult_en <= ex_pipeline_i.mult_op when ex_fwd_wb_data_stall = '0' else '0';

    -- pipeline reg
    process(clk_i, rst_ni)
    begin
        if rst_ni = '0' then
            mem_pipeline_o.lsu_addr      <= (others => '-');
            mem_pipeline_o.lsu_data_type <= WORD;
            mem_pipeline_o.lsu_op        <= LSU_NONE;
            mem_pipeline_o.lsu_sign_ext  <= '-';
            mem_pipeline_o.lsu_wdata     <= (others => '-');
            mem_pipeline_o.alu_wdata     <= (others => '-');
            mem_pipeline_o.mult_op       <= '0';
            mem_pipeline_o.rf_waddr      <= (others => '-');
            mem_pipeline_o.rf_wen        <= '0';
        elsif rising_edge(clk_i) then
            if (mem_ready_i = '1' and ex_valid_int = '1') then
                mem_pipeline_o.lsu_addr      <= ex_alu_result;
                mem_pipeline_o.lsu_data_type <= ex_pipeline_i.lsu_data_type;
                mem_pipeline_o.lsu_op        <= ex_pipeline_i.lsu_op;
                mem_pipeline_o.lsu_sign_ext  <= ex_pipeline_i.lsu_sign_ext;
                mem_pipeline_o.lsu_wdata     <= ex_lsu_wdata;
                mem_pipeline_o.alu_wdata     <= ex_alu_result;
                if ex_pipeline_i.ex_csr_access = '1' then
                    mem_pipeline_o.alu_wdata <= ex_pipeline_i.ex_csr_rdata;
                end if;
                mem_pipeline_o.mult_op       <= ex_pipeline_i.mult_op;
                mem_pipeline_o.rf_waddr      <= ex_pipeline_i.rf_waddr;
                mem_pipeline_o.rf_wen        <= ex_pipeline_i.rf_wen;
            end if;
        end if;
    end process;

    ex_fwd_o.waddr <= ex_pipeline_i.rf_waddr;
    ex_fwd_o.wen   <= ex_pipeline_i.rf_wen when ex_fwd_wb_data_stall = '0' else '0';
    ex_fwd_o.valid <= '0';
    ex_fwd_o.wdata <= (others => '0');

    process(ex_pipeline_i)
    begin
        ex_fwd_o.is_alu  <= '0';
        ex_fwd_o.is_mul  <= '0';
        ex_fwd_o.is_load <= '0';

        if ex_pipeline_i.lsu_op = LSU_LOAD then
            ex_fwd_o.is_load <= '1';
        end if;

        if ex_pipeline_i.alu_op = '1' then
            ex_fwd_o.is_alu <= '1';
        end if;

        if ex_pipeline_i.mult_op = '1' then
            ex_fwd_o.is_mul <= '1';
        end if;
    end process;

    mem_pipeline_o.mult_wdata <= mem_mult_wdata;

    ex_valid_int <= mem_ready_i and ex_alu_ready_int and --
                    --coverage off
                    -- ex_mult_ready_int and -- mult is no mulitcycle -> always rdy
                    --coverage on
                    not ex_fwd_wb_data_stall;
    ex_valid_o <= ex_valid_int;
    ex_ready_o <= ex_valid_int;

    ex_multicycle_o <= ex_alu_multicycle_int or ex_mult_multicycle_int;

end architecture RTL;
