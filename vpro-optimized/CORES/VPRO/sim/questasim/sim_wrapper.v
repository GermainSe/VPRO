
// Verilog Simulation Wrapper for SystemC simulation

`timescale 1ns/1ps

module sim_wrapper (i_clk, i_rst_n, i_core_en, i_i2c_i2s_flag,
    i_imem_rd_data, o_imem_rd_addr,
    o_ex_bus_rd_0_addr, o_ex_bus_rd_0_en, o_ex_bus_rd_0_x2_en,
    o_ex_bus_rd_1_addr, o_ex_bus_rd_1_en, o_ex_bus_rd_1_x2_en,
    o_ex_bus_wr_0_addr, o_ex_bus_wr_0_en, o_ex_bus_wr_0_x2_en,
    o_ex_bus_wr_1_addr, o_ex_bus_wr_1_en, o_ex_bus_wr_1_x2_en,
    i_ex_bus_rd_0_data, i_ex_bus_rd_0_data_x2,
    i_ex_bus_rd_1_data, i_ex_bus_rd_1_data_x2,
    o_ex_bus_wr_0_data, o_ex_bus_wr_0_data_x2,
    o_ex_bus_wr_1_data, o_ex_bus_wr_1_data_x2);
    //         i_uart_in, o_uart_out

//    parameter IMEM_ADDR_W_C = 15;
//    parameter IMEM_DATA_W_C = 64;
//    parameter DMEM_ADDR_W_C = 12;
//    parameter DMEM_DATA_W_C = 64;

    // General Ports
    input           i_clk;
    input           i_rst_n;
    input           i_core_en;
    input           i_i2c_i2s_flag;

    // Memory Interface Ports
    input  [64-1:0]  i_imem_rd_data;
    output [13-1:0]  o_imem_rd_addr;

    output [15-1:0]  o_ex_bus_rd_0_addr;
    output           o_ex_bus_rd_0_en;
    output           o_ex_bus_rd_0_x2_en;
    output [15-1:0]  o_ex_bus_rd_1_addr;
    output           o_ex_bus_rd_1_en;
    output           o_ex_bus_rd_1_x2_en;
    output [15-1:0]  o_ex_bus_wr_0_addr;
    output           o_ex_bus_wr_0_en;
    output           o_ex_bus_wr_0_x2_en;
    output [15-1:0]  o_ex_bus_wr_1_addr;
    output           o_ex_bus_wr_1_en;
    output           o_ex_bus_wr_1_x2_en;
    input [64-1:0]   i_ex_bus_rd_0_data;
    input [64-1:0]   i_ex_bus_rd_0_data_x2;
    input [64-1:0]   i_ex_bus_rd_1_data;
    input [64-1:0]   i_ex_bus_rd_1_data_x2;
    output [64-1:0]  o_ex_bus_wr_0_data;
    output [64-1:0]  o_ex_bus_wr_0_data_x2;
    output [64-1:0]  o_ex_bus_wr_1_data;
    output [64-1:0]  o_ex_bus_wr_1_data_x2;

    //    input         i_uart_in;
    //    output        o_uart_out;

    // Internal connection wires
    wire [64-1:0]    i_imem_rd_data_bigendian;
    
    
    // transforming from little-endian to big-endian
    assign i_imem_rd_data_bigendian = {
        i_imem_rd_data[7:0],
        i_imem_rd_data[15:8],
        i_imem_rd_data[23:16],
        i_imem_rd_data[31:24],
        i_imem_rd_data[39:32],
        i_imem_rd_data[47:40],
        i_imem_rd_data[55:48],
        i_imem_rd_data[63:56]};


    // DUT instance
    kavuaka_core kavuaka_core_instance(
        .reset_n(i_rst_n),
        .clk(i_clk),
        .core_en(i_core_en),
        .i2c_i2s_flag(i_i2c_i2s_flag),
        .imem_rd_data(i_imem_rd_data),
        .imem_rd_addr(o_imem_rd_addr),
        .ex_bus_rd_0_addr(o_ex_bus_rd_0_addr),
        .ex_bus_rd_0_en(o_ex_bus_rd_0_en),
        .ex_bus_rd_0_x2_en(o_ex_bus_rd_0_x2_en),
        .ex_bus_rd_1_addr(o_ex_bus_rd_1_addr),
        .ex_bus_rd_1_en(o_ex_bus_rd_1_en),
        .ex_bus_rd_1_x2_en(o_ex_bus_rd_1_x2_en),
        .ex_bus_wr_0_addr(o_ex_bus_wr_0_addr),
        .ex_bus_wr_0_en(o_ex_bus_wr_0_en),
        .ex_bus_wr_0_x2_en(o_ex_bus_wr_0_x2_en),
        .ex_bus_wr_1_addr(o_ex_bus_wr_1_addr),
        .ex_bus_wr_1_en(o_ex_bus_wr_1_en),
        .ex_bus_wr_1_x2_en(o_ex_bus_wr_1_x2_en),
        .ex_bus_rd_0_data(i_ex_bus_rd_0_data),
        .ex_bus_rd_0_data_x2(i_ex_bus_rd_0_data_x2),
        .ex_bus_rd_1_data(i_ex_bus_rd_1_data),
        .ex_bus_rd_1_data_x2(i_ex_bus_rd_1_data_x2),
        .ex_bus_wr_0_data(o_ex_bus_wr_0_data),
        .ex_bus_wr_0_data_x2(o_ex_bus_wr_0_data_x2),
        .ex_bus_wr_1_data(o_ex_bus_wr_1_data),
        .ex_bus_wr_1_data_x2(o_ex_bus_wr_1_data_x2)
    );

    //    // Peripheral models
    //    sst25vf016B flash (.SCK(flash_sck_sig),
    //        .SI(flash_si_sig),
    //        .SO(flash_so_sig),
    //        .CEn(flash_ce_n_sig),
    //        .WPn(1'b1),
    //        .HOLDn(1'b1));

endmodule
