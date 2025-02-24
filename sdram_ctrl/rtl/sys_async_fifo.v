//-------------------------------------------------------------------------------------------
//      Date : 10/31/2024
//      Author : Yufei Fu (Fred)
//      Description :   asynchronous fifo with 128 depth and 16 width
//-------------------------------------------------------------------------------------------
`timescale 1ns/10ps

module  sys_async_fifo #(
    parameter                                       DATA_WIDTH = 16,
    parameter                                       FIFO_DEPTH = 128,
    parameter                                       PTR_WIDTH  = 7 
)(
    // system signals
    input wire                                                  sys_clk0    ,       // write side
    input wire                                                  sys_rst_n0  ,
    input wire                                                  sys_clk1    ,       // read side
    input wire                                                  sys_rst_n1  ,
    // read and write signals
    input wire                                                  wr_en_i     ,       // write request enable
    input wire                  [DATA_WIDTH - 1: 0]             wr_data_i   ,       // write data
    input wire                                                  rd_en_i     ,       // read request enable
    output wire                 [DATA_WIDTH - 1: 0]             rd_data_o   ,       // read data
    // status signal
    output wire                                                 fifo_empty_o,       // fifo empty
    output wire                                                 fifo_full_o ,       // fifo full 
    output wire                                                 fifo_overrun_o,       // fifo overrun
    output wire                                                 fifo_underrun_o,      // fifo underrun  
    output wire                 [FIFO_DEPTH-1:0]                fifo_data_num_o,        // fifo available data number
    output wire                 [FIFO_DEPTH-1:0]                fifo_room_num_o        // fifo available space number          
);

//***********************Internal signals*********************************************************
//
//************************************************************************************************
localparam                                          PTR_DEPTH = 2 * FIFO_DEPTH;
reg             [PTR_WIDTH  : 0]                              wr_ptr;             // fifo write pointer
reg             [PTR_WIDTH  : 0]                              rd_ptr;             // fifo read pointer

reg             [DATA_WIDTH - 1: 0]                             fifo_regs   [FIFO_DEPTH - 1: 0];  // fifo storage 16 * 128


wire             [PTR_WIDTH : 0]                              wr_ptr_gray;
reg              [PTR_WIDTH : 0]                              wr_ptr_gray_r;
wire             [PTR_WIDTH : 0]                              rd_ptr_gray;
reg              [PTR_WIDTH : 0]                              rd_ptr_gray_r;

reg              [PTR_WIDTH : 0]                              wr_ptr_clk1_r0, wr_ptr_clk1_r1;
reg              [PTR_WIDTH : 0]                              rd_ptr_clk0_r0, rd_ptr_clk0_r1;
wire             [PTR_WIDTH : 0]                              wr_ptr_clk1_bin;
wire             [PTR_WIDTH : 0]                              rd_ptr_clk0_bin;

// read and write pointer logic
always @(posedge sys_clk0 or negedge sys_rst_n0) begin: write_ptr_logic
    if (sys_rst_n0 == 1'b0)
        wr_ptr      <= 'd0;
	else if (wr_en_i) begin
		if (fifo_full_o == 1'b1)
			wr_ptr      <= wr_ptr;
        else if (wr_ptr == PTR_DEPTH - 1)
            wr_ptr      <= 'd0;
        else
            wr_ptr      <= wr_ptr   + 1'b1;
	end
end

always @(posedge sys_clk1 or negedge sys_rst_n1) begin: read_ptr_logic
    if (sys_rst_n1 == 1'b0)
        rd_ptr      <= 'd0;
	else if (rd_en_i) begin
		if (fifo_empty_o == 1'b1)
			rd_ptr      <= rd_ptr;
        else if (rd_ptr == PTR_DEPTH - 1)
            rd_ptr      <= 'd0;
        else
            rd_ptr      <= rd_ptr  + 1'b1;
	end
end

// write pointer bin to gray
assign      wr_ptr_gray     =   (wr_ptr >> 1) ^ wr_ptr;

always @(posedge sys_clk0 or negedge sys_rst_n0) begin
    if (sys_rst_n0 == 1'b0)
        wr_ptr_gray_r <= 'd0;
    else
        wr_ptr_gray_r <= wr_ptr_gray;
end

//  wr pointer synchronizer
always @( posedge sys_clk1 or negedge sys_rst_n1) begin
    if (sys_rst_n1 == 1'b0) begin
        wr_ptr_clk1_r0 <= 'd0;
        wr_ptr_clk1_r1 <= 'd0;
    end else begin
        wr_ptr_clk1_r0 <= wr_ptr_gray_r;
        wr_ptr_clk1_r1 <= wr_ptr_clk1_r0;
    end
end

// write pointer gray to bin
genvar  j;
generate 
    for (j = 0; j < PTR_WIDTH; j = j+1) begin
        assign  wr_ptr_clk1_bin[j] =    wr_ptr_clk1_bin[j+1] ^ wr_ptr_clk1_r1[j];
    end
endgenerate

assign wr_ptr_clk1_bin[PTR_WIDTH] = wr_ptr_clk1_r1[PTR_WIDTH];


// rd pointer bin to gray
assign      rd_ptr_gray     =   (rd_ptr >> 1) ^ rd_ptr;

always @(posedge sys_clk1 or negedge sys_rst_n1) begin
    if (sys_rst_n1 == 1'b0)
        rd_ptr_gray_r <= 'd0;
    else
        rd_ptr_gray_r <= rd_ptr_gray;
end

//  rd pointer synchronizer
always @( posedge sys_clk0 or negedge sys_rst_n0) begin
    if (sys_rst_n0 == 1'b0) begin
        rd_ptr_clk0_r0 <= 'd0;
        rd_ptr_clk0_r1 <= 'd0;
    end else begin
        rd_ptr_clk0_r0 <= rd_ptr_gray_r;
        rd_ptr_clk0_r1 <= rd_ptr_clk0_r0;
    end
end

// rd pointer gray to bin
genvar  k;
generate 
    for (k = 0; k < PTR_WIDTH ; k = k+1) begin
        assign  rd_ptr_clk0_bin[k] =    rd_ptr_clk0_bin[k+1] ^ rd_ptr_clk0_r1[k];
    end
endgenerate

assign rd_ptr_clk0_bin[PTR_WIDTH] = rd_ptr_clk0_r1[PTR_WIDTH];


// fifo reg logic
integer  i; 
always @(posedge sys_clk0 or negedge sys_rst_n0) begin : fifo_write
    if (sys_rst_n0 == 1'b0) begin
        for ( i = 0; i <= FIFO_DEPTH -1; i = i + 1) begin: reset
            fifo_regs[i] <= 'd0;
        end
    end
    else if (wr_en_i && (fifo_empty_o == 1'b0)) begin
        fifo_regs[wr_ptr[PTR_WIDTH-1:0]] <= wr_data_i;
    end else if (wr_en_i && (!rd_en_i) && (fifo_empty_o == 1'b1)) begin
        fifo_regs[wr_ptr[PTR_WIDTH-1:0]] <= wr_data_i;
    end         
end

// read output assignment
assign          rd_data_o = (rd_en_i && (fifo_empty_o == 1'b0)) ?  fifo_regs[rd_ptr[PTR_WIDTH-1:0]] : 
                            (rd_en_i && wr_en_i && (fifo_empty_o == 1'b1))  ?     wr_data_i   :   'd0;

// judge fifo overrun and underrun
assign          fifo_overrun_o = wr_en_i && fifo_full_o ;
assign          fifo_underrun_o = rd_en_i && fifo_empty_o;

// judge fifo empty and full

assign          fifo_empty_o = (rd_ptr[PTR_WIDTH] == wr_ptr_clk1_bin[PTR_WIDTH]) && (rd_ptr[PTR_WIDTH-1 : 0] == wr_ptr_clk1_bin[PTR_WIDTH-1 : 0]);
assign          fifo_full_o  =  (wr_ptr[PTR_WIDTH] != rd_ptr_clk0_bin[PTR_WIDTH]) && (wr_ptr[PTR_WIDTH-1 : 0] == rd_ptr_clk0_bin[PTR_WIDTH-1 : 0]);

// calculate available data number and space number
assign          fifo_data_num_o = (rd_ptr_clk0_bin[PTR_WIDTH:0] <=  wr_ptr[PTR_WIDTH:0]) ? (wr_ptr[PTR_WIDTH : 0] - rd_ptr_clk0_bin[PTR_WIDTH : 0]) : 
                                                                                    FIFO_DEPTH - (rd_ptr_clk0_bin[PTR_WIDTH : 0] - wr_ptr[PTR_WIDTH : 0]);
assign			fifo_room_num_o = FIFO_DEPTH - fifo_data_num_o;
																				//assign          fifo_room_num_o = (rd_ptr[PTR_WIDTH] != wr_ptr_clk1_bin[PTR_WIDTH]) ? (rd_ptr[PTR_WIDTH : 0] - wr_ptr_clk1_bin[PTR_WIDTH : 0]) : 
                                                                                   // FIFO_DEPTH - (wr_ptr_clk1_bin[PTR_WIDTH : 0] - rd_ptr[PTR_WIDTH : 0]);

endmodule



 
