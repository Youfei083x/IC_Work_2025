//-----------------------------------------------------------------------------------------------
// Date : 10/26/2024
// Author : Yufei Fu(Fred) 
// Description : Write module of SDRAM controller
// ----------------------------------------------------------------------------------------------
`timescale 1ns/10ps

`include "ddr_params.v"

module ddr_ctrl_wr(
    input wire                                                                sys_clk,
    input wire                                                                sys_rst_n,
    input wire                                                                init_end_i,         // init process end flag
    input wire                                                                wr_en_i,            // write enable signal
    input wire                  [23:0]                                        wr_addr_i,          // write address
    input wire                  [`DATA_WIDTH -1 :0]                           wr_data_i,          // write data
    input wire                  [9:0]                                         wr_burst_len_i,     // busrt length

    output wire                                                               wr_ack_o,           // write acknowledgement
    output wire                                                               wr_end_o,           // write process end flag
    output reg                  [3:0]                                         wr_cmd_o,           // write command
    output reg                  [`ADDR_WIDTH -1 : 0]                          wr_addr_o,          // write sdram address
    output reg                  [`BA_WIDTH -1 : 0]                            wr_ba_o,            // write ba address
    output reg                                                                wr_sdram_en_o,      // sdram enable signal
    output wire                 [`DATA_WIDTH -1 :0]                           wr_sdram_data_o    // sdram data be written                              
);

//********************************* Parameter and internal signal definition ****************************************************
//parameter     define
parameter   TRCD_CLK    =   'd2   ,   //激活周期
            TRP_CLK     =   'd2   ;   //预充电周期


parameter   WR_IDLE     =   3'b000 ,   //初始状态
            WR_ACTIVE   =   3'b001 ,   //激活
            WR_TRCD     =   3'b011 ,   //激活等待
            WR_WRITE    =   3'b010 ,   //写操作
            WR_DATA     =   3'b100 ,   //写数据
            WR_PRE      =   3'b101 ,   //预充电
            WR_TRP      =   3'b111 ,   //预充电等待
            WR_END      =   3'b110 ;   //一次突发写结束

parameter   NOP         =   4'b0111 ,
            PRE         =   4'b0010 ,
            ACT         =   4'b0011 ,
            WRITE       =   4'b0100 ,
            BR_T        =   4'b0110 ;

//wire  define
wire            trcd_end    ;   //激活等待周期结束
wire            twrite_end  ;   //突发写结束
wire            trp_end     ;   //预充电有效周期结束

//reg   define
reg     [3:0]   write_state_cs, write_state_ns ;   //SDRAM写状态
reg     [9:0]   cnt_clk     ;   //时钟周期计数,记录写数据阶段各状态等待时间
reg             cnt_clk_rst ;   //时钟周期计数复位标志
reg     [15:0]	sdram_data_r;   // sdram output data register
//********************************************************************//
//***************************** Main Code ****************************//
//********************************************************************//

// assign flag ack and end
assign  wr_ack_o = (write_state_cs == WR_WRITE) || ((write_state_cs == WR_DATA) && (cnt_clk <= (wr_burst_len_i - 2'd2)));

assign wr_end_o = (write_state_cs == WR_END) ? 1'b1 : 1'b0;

// clock counter
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cnt_clk <= 'd0;
    else if (cnt_clk_rst == 1'b1)
        cnt_clk <= 'd0;
    else
        cnt_clk <= cnt_clk + 1'b1;
end

//计数器控制逻辑
always@(*)
    begin
        case(write_state_cs)
            WR_IDLE:    cnt_clk_rst   <=  1'b1;
            WR_TRCD:    cnt_clk_rst   <=  (trcd_end == 1'b1) ? 1'b1 : 1'b0;
            WR_WRITE:   cnt_clk_rst   <=  1'b1;
            WR_DATA:    cnt_clk_rst   <=  (twrite_end == 1'b1) ? 1'b1 : 1'b0;
            WR_TRP:     cnt_clk_rst   <=  (trp_end == 1'b1) ? 1'b1 : 1'b0;
            WR_END:     cnt_clk_rst   <=  1'b1;
            default:    cnt_clk_rst   <=  1'b1;
        endcase
    end

assign      trcd_end        = ((write_state_cs == WR_TRCD) && (cnt_clk == TRCD_CLK - 1)) ? 1'b1 : 1'b0;
assign      twrite_end      = ((write_state_cs == WR_DATA) && (cnt_clk == wr_burst_len_i - 1)) ? 1'b1 : 1'b0;
assign      trp_end         = ((write_state_cs == WR_TRP) && (cnt_clk == TRP_CLK )) ? 1'b1   : 1'b0;

always@(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n == 1'b0)
        write_state_cs <= WR_IDLE;
    else 
        write_state_cs <= write_state_ns;
end

always@(*) begin: fsm_logic
    case(write_state_cs)
            WR_IDLE:
                if((wr_en_i ==1'b1) && (init_end_i == 1'b1))
                        write_state_ns <=  WR_ACTIVE;
                else
                        write_state_ns <=  write_state_cs;
            WR_ACTIVE:
                write_state_ns <=  WR_TRCD;
            WR_TRCD:
                if(trcd_end == 1'b1)
                    write_state_ns <=  WR_WRITE;
                else
                    write_state_ns <=  write_state_cs;
            WR_WRITE:
                write_state_ns <=  WR_DATA;
            WR_DATA:
                if(twrite_end == 1'b1)
                    write_state_ns <=  WR_PRE;
                else
                    write_state_ns <=  write_state_cs;
            WR_PRE:
                write_state_ns <=  WR_TRP;
            WR_TRP:
                if(trp_end == 1'b1)
                    write_state_ns <=  WR_END;
                else
                    write_state_ns <=  write_state_cs;
            WR_END:
                write_state_ns <=  WR_IDLE;
            default:
                write_state_ns <=  WR_IDLE;
    endcase
end

//SDRAM操作指令控制
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        begin
            wr_cmd_o   <=  NOP;
            wr_ba_o    <=  2'b11;
            wr_addr_o  <=  13'h1fff;
        end
    else begin
        case(write_state_cs)
            WR_IDLE,WR_TRCD,WR_TRP:
                begin
                    wr_cmd_o   <=  NOP;
                    wr_ba_o    <=  2'b11;
                    wr_addr_o  <=  13'h1fff;
                end
            WR_ACTIVE: 
                begin
                    wr_cmd_o   <=  ACT;
                    wr_ba_o    <=  wr_addr_i[23:22];
                    wr_addr_o  <=  wr_addr_i[21:9];  // row selection
                end
            WR_WRITE:
                begin
                    wr_cmd_o   <=  WRITE;
                    wr_ba_o    <=  wr_addr_i[23:22];
                    wr_addr_o  <=  {4'b0000,wr_addr_i[8:0]}; // column selection
                end     
            WR_DATA:
                begin
                    if(twrite_end == 1'b1)
                        wr_cmd_o <=  BR_T;
                    else
                        begin
                            wr_cmd_o   <=  NOP;
                            wr_ba_o    <=  2'b11;
                            wr_addr_o  <=  13'h1fff;
                        end
                end
            WR_PRE: 
                begin
                    wr_cmd_o   <= PRE;
                    wr_ba_o    <= wr_addr_i[23:22];
                    wr_addr_o  <= 13'h0400;
                end
            WR_END:
                begin
                    wr_cmd_o  <=  NOP;
                    wr_ba_o    <=  2'b11;
                    wr_addr_o  <=  13'h1fff;
                end
            default:
                begin
                    wr_cmd_o   <=  NOP;
                    wr_ba_o    <=  2'b11;
                    wr_addr_o  <=  13'h1fff;
                end
        endcase
    end
end

// assign sdram enable and data 
always@(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n == 1'b0)
        wr_sdram_en_o <= 1'b0;
    else
        wr_sdram_en_o <= wr_ack_o;
end

always @(posedge sys_clk or negedge sys_rst_n) begin
	if (sys_rst_n == 1'b0)
		sdram_data_r <= 'd0;
	else
		sdram_data_r <= wr_data_i;
end

assign wr_sdram_data_o = (wr_sdram_en_o == 1'b1) ? sdram_data_r : 16'd0;

endmodule




