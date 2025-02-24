//-----------------------------------------------------------------------------------------------
// Date : 10/26/2024
// Author : Yufei Fu(Fred) 
// Description : top module of SDRAM controller
// ----------------------------------------------------------------------------------------------
`timescale 1ns/10ps

`include "ddr_params.v"

module ddr_ctrl_top(
    input wire                                          sys_clk,
    input wire                                          sys_rst_n,
    // write/read controller
    input wire                  [23 : 0]                addr_i      ,
    input wire                  [`DATA_WIDTH-1:0]       data_i      ,
    input wire                  [9 : 0]                 burst_len_i ,
    // write request
    input wire                                          write_req_i ,
    // read request
    input wire                                          read_req_i  ,
    // init start flag
    input wire                                          start_i,

    // outputs to sdram module
    output 		wire		sdram_cke_o 		,		//sdram时钟有效信号
    output 		wire		sdram_cs_n_o 		,		//sdram片选信号
    output 		wire		sdram_cas_n_o 	    ,		//sdram行选通信号
    output 		wire		sdram_ras_n_o		,		//sdram列选通信号
    output 		wire		sdram_we_n_o		,		//sdram写使能信号
    output wire	[1:0]		sdram_ba_o 		    ,		//sdram的bank地址
    output wire	[12:0]		sdram_addr_o 		,		//sdram的地址总线
    output wire             wr_ack_o            ,
    output wire             rd_ack_o            ,
    output wire [15:0]      rd_data_o           ,       // read module output data
    inout wire [15:0] 		sdram_dq_o				//sdram的数据总线
);

// internal signals //
// init
wire                                      init_end;
wire          [3:0]                       init_cmd;
wire          [1:0]                       init_ba;
wire          [`ADDR_WIDTH - 1 :0]        init_addr;
// aref
wire                                      aref_req;
wire                                      aref_end;
wire          [3:0]                       aref_cmd;
wire          [1:0]                       aref_ba;
wire          [`ADDR_WIDTH - 1 :0]        aref_addr;
// write
wire                                      wr_end;
wire          [3:0]                       wr_cmd;
wire          [1:0]                       wr_ba;
wire          [`ADDR_WIDTH - 1 :0]        wr_addr;
wire          [15:0]                      wr_data;
wire                                      wr_sdram_en;
// read
wire                                      rd_end;
wire          [3:0]                       rd_cmd;
wire          [1:0]                       rd_ba;
wire          [`ADDR_WIDTH - 1 :0]        rd_addr;
// arbitor enable signals
wire                                      aref_en;
wire                                      wr_en;
wire                                      rd_en;

ddr_ctrl_init u_ddr_ctrl_init (
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .init_start_i(start_i),
    .init_addr_o(init_addr),
    .init_ba_o(init_ba),
    .init_cmd_o(init_cmd),
    .init_end_o(init_end)
);

ddr_ctrl_aref u_ddr_ctrl_aref(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .init_end_i(init_end),
    .aref_cmd_o(aref_cmd),
    .aref_addr_o(aref_addr),
    .aref_ba_o(aref_ba),
    .aref_end_o(aref_end),
    .aref_req_o(aref_req)
);

ddr_ctrl_wr u_ddr_ctrl_wr(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .init_end_i(init_end),
    .wr_en_i(wr_en),
    .wr_addr_i(addr_i),
    .wr_data_i(data_i),
    .wr_burst_len_i(burst_len_i),

    .wr_ack_o(wr_ack_o),
    .wr_end_o(wr_end),
    .wr_addr_o(wr_addr),
    .wr_cmd_o(wr_cmd),
    .wr_ba_o(wr_ba),
    .wr_sdram_data_o(wr_data),
    .wr_sdram_en_o(wr_sdram_en)
);

ddr_ctrl_rd u_ddr_ctrl_rd(
    .sys_clk(sys_clk),
    .sys_rst_n(sys_rst_n),
    .init_end_i(init_end),
    .rd_en_i(rd_en),
    .rd_addr_i(addr_i),
    .rd_data_i(sdram_dq_o),
    .rd_burst_len_i(burst_len_i),

    .rd_ack_o(rd_ack_o),
    .rd_end_o(rd_end),
    .rd_addr_o(rd_addr),
    .rd_cmd_o(rd_cmd),
    .rd_ba_o(rd_ba),
    .rd_sdram_data_o(rd_data_o)   
);

ddr_ctrl_arbit u_ddr_ctrl_arbit (
    // System signals
    .sys_clk        (sys_clk),        // 系统时钟，167M
    .sys_rst_n      (sys_rst_n),      // 系统复位信号，低电平有效

    // Init signals
    .init_end_i     (init_end),     // 初始化结束标志
    .init_cmd_i     (init_cmd),     // 初始化阶段命令
    .init_ba_i      (init_ba),      // 初始化阶段bank地址
    .init_addr_i    (init_addr),    // 初始化阶段地址总线

    // Aref signals
    .aref_req_i     (aref_req),     // 刷新请求信号
    .aref_end_i     (aref_end),     // 刷新结束信号
    .aref_cmd_i     (aref_cmd),     // 刷新阶段命令
    .aref_ba_i      (aref_ba),      // 刷新阶段bank地址
    .aref_addr_i    (aref_addr),    // 刷新阶段地址

    // Write signals
    .wr_req_i       (wr_req_i),       // 写数据请求
    .wr_end_i       (wr_end),       // 一次写结束信号
    .wr_cmd_i       (wr_cmd),       // 写阶段命令
    .wr_ba_i        (wr_ba),        // 写阶段BANK地址
    .wr_addr_i      (wr_addr),      // 写阶段地址总线
    .wr_data_i      (wr_data),      // 写数据
    .wr_sdram_en_i  (wr_sdram_en),  // 写sdram使能信号

    // Read signals
    .rd_req_i       (rd_req_i),       // 读请求
    .rd_end_i       (rd_end),       // 读数据结束
    .rd_cmd_i       (rd_cmd),       // 读阶段命令
    .rd_ba_i        (rd_ba),        // 读阶段bank地址
    .rd_addr_i      (rd_addr),      // 读地址总线

    // Output signals
    .aref_en_o      (aref_en),      // 刷新请求
    .wr_en_o        (wr_en),        // 写数据使能
    .rd_en_o        (rd_en),        // 读数据使能
    .sdram_cke_o    (sdram_cke_o),    // sdram时钟有效信号
    .sdram_cs_n_o   (sdram_cs_n_o),   // sdram片选信号
    .sdram_cas_n_o  (sdram_cas_n_o),  // sdram行选通信号
    .sdram_ras_n_o  (sdram_ras_n_o),  // sdram列选通信号
    .sdram_we_n_o   (sdram_we_n_o),   // sdram写使能信号
    .sdram_ba_o     (sdram_ba_o),     // sdram的bank地址
    .sdram_addr_o   (sdram_addr_o),   // sdram的地址总线
    .sdram_dq_o     (sdram_dq_o)      // sdram的数据总线
);


endmodule