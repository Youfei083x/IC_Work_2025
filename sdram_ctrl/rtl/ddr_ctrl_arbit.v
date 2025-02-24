//-----------------------------------------------------------------------------------------------
// Date : 10/29/2024
// Author : Yufei Fu(Fred) 
// Description : arbitor module of SDRAM controller
// ----------------------------------------------------------------------------------------------
`timescale 1ns/10ps

`include "ddr_params.v"

module ddr_ctrl_arbit(
	//system signals
			input 					sys_clk 		,		//系统时钟，167M	
			input 					sys_rst_n 		,		//系统复位信号，低电平有效
	//init signals					
			input 					init_end_i 		    ,		//初始化结束标志		
			input  	[3:0]			init_cmd_i 		    ,		//初始化阶段命令
			input 	[1:0]			init_ba_i			,		//初始化阶段bank地址
			input 	[12:0]			init_addr_i 		,		//初始化阶段地址总线
	//aref signals					
			input 					aref_req_i		,		//刷新请求信号
			input 					aref_end_i 		,		//刷新结束信号
			input 	[3:0]			aref_cmd_i 		,		//刷新阶段命令
			input 	[1:0]			aref_ba_i 		,		//刷新阶段bank地址
			input 	[12:0]			aref_addr_i		,		//刷新阶段地址
	//write signals					
			input 					wr_req_i 			,		//写数据请求
			input 					wr_end_i 			,		//一次写结束信号
			input 	[3:0]			wr_cmd_i 			,		//写阶段命令
			input 	[1:0]			wr_ba_i 			,		//写阶段BANK地址
			input 	[12:0]			wr_addr_i 	    	,		//写阶段地址总线
			input 	[15:0]			wr_data_i 		    ,		//写数据
			input 					wr_sdram_en_i 	    ,		//写sdram使能信号
	//read signals				
			input 					rd_req_i 			,		//读请求
			input 					rd_end_i 			,		//读数据结束
			input 	[3:0]			rd_cmd_i 			,		//读阶段命令
			input 	[1:0] 			rd_ba_i 			,		//读阶段bank地址
			input 	[12:0]			rd_addr_i   		,		//读地址总线
	//output signals				
			output  	reg			aref_en_o 		    ,		//刷新请求
			output 		reg			wr_en_o 			,		//写数据使能
			output 		reg			rd_en_o 			,		//读数据使能
			output 		wire		sdram_cke_o 		,		//sdram时钟有效信号
			output 		wire		sdram_cs_n_o 		,		//sdram片选信号
			output 		wire		sdram_cas_n_o 	    ,		//sdram行选通信号
			output 		wire		sdram_ras_n_o		,		//sdram列选通信号
			output 		wire		sdram_we_n_o		,		//sdram写使能信号
			output reg	[1:0]		sdram_ba_o 		    ,		//sdram的bank地址
			output reg	[12:0]		sdram_addr_o 		,		//sdram的地址总线
			inout wire [15:0] 		sdram_dq_o				//sdram的数据总线
);

//localparam
localparam 		IDLE 	=	3'b000		,		//初始状态
				ARBIT 	=	3'b001		,		//仲裁状态
				AREF 	=	3'b011		,		//自动刷新
				WRITE 	=	3'b010		,		//写状态
				READ 	=	3'b110		;		//读状态
//命令
localparam 		NOP 	=	4'b0111		;	//空操作命令


//reg define
reg 	[3:0]		sdram_cmd	;	//写入SDRAM 命令
reg 	[2:0]		state_cs 	;	//当前状态
reg 	[2:0]		state_ns	;	//下一状态
reg 	[15:0]	 	wr_data_reg	;	//数据寄存

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n == 1'b0) begin
        state_cs <= IDLE;
    end else
        state_cs <= state_ns;
end

// fsm logic transform
always@(*) begin
    case(state_cs) 
        IDLE : begin
            if(init_end_i == 1'b1) // after initialization ends, start the fsm
                state_ns <= ARBIT;
            else
                state_ns <= IDLE;
        end
        ARBIT : begin  // refresh > write > read
            if (aref_req_i == 1'b1)
                state_ns <= AREF;
            else if (wr_req_i == 1'b1)
                state_ns <= WRITE;
            else if (rd_req_i == 1'b1)
                state_ns <= READ;
            else
                state_ns <= ARBIT;
        end
        AREF : begin
            if (aref_end_i == 1'b1)
                state_ns <= ARBIT;
            else
                state_ns <= AREF;
        end
        WRITE	:	begin
                        if(wr_end_i == 1'b1)
                            state_ns 	=	ARBIT 	;
                        else
                            state_ns 	=	WRITE	;
        end 

        READ 	:	begin
                        if(rd_end_i == 1'b1)
                            state_ns 	=	ARBIT 	;
                        else
                            state_ns	=	READ 	;
        end 
        default	:		state_ns 	=	IDLE	;
    endcase 

end 

always@(*) begin: assign_output
    case(state_cs)
        IDLE    :       begin
            sdram_addr_o = init_addr_i;
            sdram_ba_o  =   init_ba_i;
            sdram_cmd = init_cmd_i;
        end
        ARBIT   :       begin
            sdram_addr_o = 13'h1fff;
            sdram_ba_o  =   2'b11;
            sdram_cmd = NOP;
        end
        AREF    :       begin
            sdram_addr_o = aref_addr_i;
            sdram_ba_o  =   aref_ba_i;
            sdram_cmd   =   aref_cmd_i;
        end
        WRITE   :       begin
            sdram_addr_o = wr_addr_i;
            sdram_ba_o  =   wr_ba_i;
            sdram_cmd   =   wr_cmd_i;
        end
        READ    :       begin
            sdram_addr_o = rd_addr_i;
            sdram_ba_o   = rd_ba_i;
            sdram_cmd    = rd_cmd_i;
        end
        default :   begin
            sdram_addr_o = 13'h1fff;
            sdram_ba_o  =   2'b11;
            sdram_cmd = NOP;
        end
    endcase
end

//自动刷新使能
always @(posedge sys_clk or negedge sys_rst_n) begin : proc_aref_en
	if(~sys_rst_n) begin
		aref_en_o 	<= 	1'b0		;
	end 
	else if ((state_cs == ARBIT) && (aref_req_i == 1'b1) )begin
		 aref_en_o 	<= 	1'b1 		;
	end
	else if(aref_end_i == 1'b1 )
		aref_en_o 	<= 	1'b0 		;
end

//写数据使能
//wr_en
always @(posedge sys_clk or negedge sys_rst_n) begin : proc_wr_en 
	if(~sys_rst_n) begin
		wr_en_o  <= 1'b0		;
	end 
	else if((state_cs == ARBIT) && (aref_req_i == 1'b0) && (wr_req_i == 1'b1)) begin
		wr_en_o  <= 1'b1		;
	end
	else if(wr_end_i == 1'b1)
		wr_en_o 	<=	1'b0	;
end


//读数据使能
//rd_en
always @(posedge sys_clk or negedge sys_rst_n) begin : proc_rd_en 
	if(~sys_rst_n) begin
		rd_en_o  		<= 1'b0 		;
	end

	else  if((state_cs == ARBIT) && (aref_req_i == 1'b0) && (rd_req_i == 1'b1) )begin
		rd_en_o 		 <= 1'b1 		;
	end

	else if(rd_end_i	==	1'b1)
		rd_en_o 		<=	1'b0 		;
end

assign sdram_cke_o = 1'b1;
assign {sdram_cs_n_o, sdram_ras_n_o, sdram_cas_n_o, sdram_we_n_o} = sdram_cmd;

assign sdram_dq_o = (wr_sdram_en_i == 1'b1) ? wr_data_reg : 'd0;

always @(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n == 1'b0)  
        wr_data_reg <= 'd0;
    else
        wr_data_reg <= wr_data_i;
end

endmodule

            



