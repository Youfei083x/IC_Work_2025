//-----------------------------------------------------------------------------------------------
// Date : 10/26/2024
// Author : Yufei Fu(Fred) 
// Description : Refresh module of SDRAM controller
// ----------------------------------------------------------------------------------------------
`timescale 1ns/10ps

`include  "ddr_params.v"

module ddr_ctrl_aref(
    input wire                              sys_clk,
    input wire                              sys_rst_n,
    input wire                              init_end_i,  // init process end flag
//    input wire                              aref_en_i,   // aref enable signal

    output reg                              aref_req_o,
    output reg      [3:0]                   aref_cmd_o,  // aref output command
    output reg      [`ADDR_WIDTH- 1 : 0]    aref_addr_o, // aref output address
    output reg      [`BA_WIDTH - 1 : 0 ]    aref_ba_o,   // aref output ba
    output wire                             aref_end_o   // aref end flag        
);

//********************************************************************//
//****************** Parameter and Internal Signal *******************//
//********************************************************************//

localparam      CNT_REF_MAX = 11'd1248    ;  // auto refresh cycle time = 7.5us

localparam      TRP_CLK  = 3'd2  ,          // precharge waiting time
                TRC_CLK  = 4'd6  ;          // refresh cycle time

localparam      NOP      = 4'b0111, 
                PRE      = 4'b0010,
                AREF     = 4'b0001;

localparam  AREF_IDLE   =   3'b000      ,   //初始状态,等待自动刷新使能
            AREF_PCHA   =   3'b001      ,   //预充电状态
            AREF_TRP    =   3'b011      ,   //预充电等待          tRP
            AREF_REF    =   3'b010      ,   //自动刷新状态
            AREF_TRF    =   3'b100      ,   //自动刷新等待        tRC
            AREF_END    =   3'b101      ;   //自动刷新结束 

//wire  define
wire            trp_end     ;   //预充电等待结束标志
wire            trf_end     ;   //自动刷新等待结束标志
wire            aref_ack    ;   //自动刷新应答信号

reg     [10:0]          cnt_aref    ;                   // refresh counter
reg     [2:0]           aref_state_cs, aref_state_ns  ; // aref fsm states
reg     [2:0]           cnt_clk     ;                   // clock cycle counter
reg                     cnt_clk_rst ;                   // cnt counter reset signal
reg     [1:0]           cnt_aref_times  ;               // refresh time counter

//cnt_ref:刷新计数器
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cnt_aref    <=  10'd0;
    else    if(cnt_aref >= CNT_REF_MAX)
        cnt_aref    <=  10'd0;
    else    if(init_end_i == 1'b1)
        cnt_aref    <=  cnt_aref + 1'b1;
end

// set up req flag for sdram after the slack
always@(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n == 1'b0)
        aref_req_o <= 'd0;
    else if (cnt_aref == CNT_REF_MAX - 1'b1)
        aref_req_o <= 1'b1;
    else if (aref_ack == 1'b1)
        aref_req_o <= 1'b0;
end

//aref_ack:自动刷新应答信号
assign  aref_ack = (aref_state_ns == AREF_PCHA ) ? 1'b1 : 1'b0;

//aref_end:自动刷新结束标志
assign  aref_end_o = (aref_state_cs == AREF_END ) ? 1'b1 : 1'b0;

//cnt_clk:时钟周期计数,记录初始化各状态等待时间
always@(posedge sys_clk or negedge sys_rst_n)
    if(sys_rst_n == 1'b0)
        cnt_clk <=  3'd0;
    else    if(cnt_clk_rst == 1'b1)
        cnt_clk <=  3'd0;
    else
        cnt_clk <=  cnt_clk + 1'b1;

//trp_end,trf_end,tmrd_end:等待结束标志
assign  trp_end = ((aref_state_cs == AREF_TRP)
                    && (cnt_clk == TRP_CLK )) ? 1'b1 : 1'b0;
assign  trf_end = ((aref_state_cs == AREF_TRF)
                    && (cnt_clk == TRC_CLK )) ? 1'b1 : 1'b0;

//cnt_aref_aref:初始化过程自动刷新次数计数器
always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        cnt_aref_times   <=  2'd0;
    else    if(aref_state_cs == AREF_IDLE)
        cnt_aref_times   <=  2'd0;
    else    if(aref_state_cs == AREF_REF)
        cnt_aref_times   <=  cnt_aref_times + 1'b1;
    else
        cnt_aref_times   <=  cnt_aref_times;
end

always@(posedge sys_clk or negedge sys_rst_n) begin: fsm
    if (sys_rst_n == 1'b0)
        aref_state_cs <= AREF_IDLE;
    else 
        aref_state_cs <= aref_state_ns;
end

always@(*) begin
    case(aref_state_cs) 
        AREF_IDLE: begin
            if (aref_req_o == 1'b1 && init_end_i == 1'b1)
                aref_state_ns = AREF_PCHA;
            else
                aref_state_ns = AREF_IDLE;
        end
        AREF_PCHA :
            aref_state_ns = AREF_TRP;
        AREF_TRP : begin
            if (trp_end == 1'b1)
                aref_state_ns = AREF_REF;
            else
                aref_state_ns = AREF_TRP;
        end
        AREF_REF:
            aref_state_ns = AREF_TRF;
        AREF_TRF: begin
            if (trf_end == 1'b1) begin
                if(cnt_aref_times == 2'b10)
                    aref_state_ns = AREF_END;
                else 
                    aref_state_ns = AREF_REF;
            end
            else begin
                aref_state_ns = AREF_TRF;
            end
        end
        AREF_END:
            aref_state_ns = AREF_IDLE;
        default:
            aref_state_ns = AREF_IDLE;
    endcase
end

always@(*) begin 
    case(aref_state_cs) 
            AREF_IDLE : cnt_clk_rst = 1'b1;

            AREF_TRP :  cnt_clk_rst = (trp_end == 1'b1) ? 1'b1 : 1'b0;

            AREF_TRF :  cnt_clk_rst = (trf_end == 1'b1) ? 1'b1 : 1'b0;

            default: cnt_clk_rst = 1'b0;
    endcase
end

always@(posedge sys_clk or negedge sys_rst_n) begin
    if(sys_rst_n == 1'b0)
        begin
            aref_cmd_o    <=  NOP;
            aref_ba_o     <=  2'b11;
            aref_addr_o   <=  13'h1fff;
        end
    else
        case(aref_state_cs)
            AREF_IDLE,AREF_TRP,AREF_TRF:    //执行空操作指令
                begin
                    aref_cmd_o    <=  NOP;
                    aref_ba_o     <=  2'b11;
                    aref_addr_o   <=  13'h1fff;
                end
            AREF_PCHA:  //预充电指令
                begin
                    aref_cmd_o    <=  PRE;
                    aref_ba_o     <=  2'b11;
                    aref_addr_o   <=  13'h1fff;
                end 
            AREF_REF:   //自动刷新指令
                begin
                    aref_cmd_o    <=  AREF;
                    aref_ba_o     <=  2'b11;
                    aref_addr_o   <=  13'h1fff;
                end
            AREF_END:   //一次自动刷新完成
                begin
                    aref_cmd_o    <=  NOP;
                    aref_ba_o     <=  2'b11;
                    aref_addr_o   <=  13'h1fff;
                end    
            default:
                begin
                    aref_cmd_o    <=  NOP;
                    aref_ba_o     <=  2'b11;
                    aref_addr_o   <=  13'h1fff;
                end    
        endcase
end

endmodule


