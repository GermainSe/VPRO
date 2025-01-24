#ifndef _SCGENMOD_sim_wrapper_
#define _SCGENMOD_sim_wrapper_

#include "systemc.h"

class sim_wrapper : public sc_foreign_module
{
public:
    sc_in<bool> i_clk;
    sc_in<bool> i_rst_n;
    sc_in<bool> i_core_en;
    sc_in<bool> i_i2c_i2s_flag;
    sc_in<sc_bv<64> > i_imem_rd_data;
    sc_out<sc_bv<13> > o_imem_rd_addr;
    sc_out<sc_bv<15> > o_ex_bus_rd_0_addr;
    sc_out<bool> o_ex_bus_rd_0_en;
    sc_out<bool> o_ex_bus_rd_0_x2_en;
    sc_out<sc_bv<15> > o_ex_bus_rd_1_addr;
    sc_out<bool> o_ex_bus_rd_1_en;
    sc_out<bool> o_ex_bus_rd_1_x2_en;
    sc_out<sc_bv<15> > o_ex_bus_wr_0_addr;
    sc_out<bool> o_ex_bus_wr_0_en;
    sc_out<bool> o_ex_bus_wr_0_x2_en;
    sc_out<sc_bv<15> > o_ex_bus_wr_1_addr;
    sc_out<bool> o_ex_bus_wr_1_en;
    sc_out<bool> o_ex_bus_wr_1_x2_en;
    sc_in<sc_bv<64> > i_ex_bus_rd_0_data;
    sc_in<sc_bv<64> > i_ex_bus_rd_0_data_x2;
    sc_in<sc_bv<64> > i_ex_bus_rd_1_data;
    sc_in<sc_bv<64> > i_ex_bus_rd_1_data_x2;
    sc_out<sc_bv<64> > o_ex_bus_wr_0_data;
    sc_out<sc_bv<64> > o_ex_bus_wr_0_data_x2;
    sc_out<sc_bv<64> > o_ex_bus_wr_1_data;
    sc_out<sc_bv<64> > o_ex_bus_wr_1_data_x2;


    sim_wrapper(sc_module_name nm, const char* hdl_name)
     : sc_foreign_module(nm),
       i_clk("i_clk"),
       i_rst_n("i_rst_n"),
       i_core_en("i_core_en"),
       i_i2c_i2s_flag("i_i2c_i2s_flag"),
       i_imem_rd_data("i_imem_rd_data"),
       o_imem_rd_addr("o_imem_rd_addr"),
       o_ex_bus_rd_0_addr("o_ex_bus_rd_0_addr"),
       o_ex_bus_rd_0_en("o_ex_bus_rd_0_en"),
       o_ex_bus_rd_0_x2_en("o_ex_bus_rd_0_x2_en"),
       o_ex_bus_rd_1_addr("o_ex_bus_rd_1_addr"),
       o_ex_bus_rd_1_en("o_ex_bus_rd_1_en"),
       o_ex_bus_rd_1_x2_en("o_ex_bus_rd_1_x2_en"),
       o_ex_bus_wr_0_addr("o_ex_bus_wr_0_addr"),
       o_ex_bus_wr_0_en("o_ex_bus_wr_0_en"),
       o_ex_bus_wr_0_x2_en("o_ex_bus_wr_0_x2_en"),
       o_ex_bus_wr_1_addr("o_ex_bus_wr_1_addr"),
       o_ex_bus_wr_1_en("o_ex_bus_wr_1_en"),
       o_ex_bus_wr_1_x2_en("o_ex_bus_wr_1_x2_en"),
       i_ex_bus_rd_0_data("i_ex_bus_rd_0_data"),
       i_ex_bus_rd_0_data_x2("i_ex_bus_rd_0_data_x2"),
       i_ex_bus_rd_1_data("i_ex_bus_rd_1_data"),
       i_ex_bus_rd_1_data_x2("i_ex_bus_rd_1_data_x2"),
       o_ex_bus_wr_0_data("o_ex_bus_wr_0_data"),
       o_ex_bus_wr_0_data_x2("o_ex_bus_wr_0_data_x2"),
       o_ex_bus_wr_1_data("o_ex_bus_wr_1_data"),
       o_ex_bus_wr_1_data_x2("o_ex_bus_wr_1_data_x2")
    {
        elaborate_foreign_module(hdl_name);
    }
    ~sim_wrapper()
    {}

};

#endif

