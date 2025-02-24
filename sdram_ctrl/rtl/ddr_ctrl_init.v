//-----------------------------------------------------------------------------------------------
// Date : 10/26/2024
// Author : Yufei Fu(Fred) 
// Description : initialization module of SDRAM controller
// ----------------------------------------------------------------------------------------------
`timescale 1ns/10ps

`include    "ddr_params.v"

module ddr_ctrl_init(
    input wire                               sys_clk,       // system clock 167MHZ period = 6ns
    input wire                               sys_rst_n,     // system rst signal
	input wire   						     init_start_i,  // init start signal
    output reg      [3:0]                    init_cmd_o,    // SDRAM command lines (cs_n, ras_n, cas_n, we_n)
    output reg      [`BA_WIDTH - 1 : 0]      init_ba_o,     // ba address
    output reg      [`ADDR_WIDTH - 1 : 0]    init_addr_o,   // addr address
    output reg                               init_end_o    // process end flag
);

//parameter define
// sdram commands configuration
localparam      NOP         =   4'b0111,            // null operation
                PRE         =   4'b0010,            // precharge, shutdomn previous activated row for next read/write (Remember DRAM BL/BLc will be 0/1 instead of VDD/2 after each read/write)
                AREF        =   4'b0001,            // auto refresh, shutdown read/write operations by deactivating we_n while keep other signals on for refreshing
                LMR         =   4'b0000,            // Logic mode register set-up
                ACT         =   4'b0011,            // activation command, turn on row selection
                RD          =   4'b0101,            // read operation, make sure before it precharge, activate and AREF are all done in a good ordering. So here we_n and ras_n are not required
                WE          =   4'b0100,            // write operation, row selection is done and this time enable we_n to get data out
                BR_T        =   4'b0110;            // burst end indicator

// local counter
localparam      cnt_pow         = 'd350, // 200MHZ, power up waiting time 200us
                cnt_rp          = 'd4    , // 200MHZ, precharge waiting time 20ns
                cnt_rfc         = 'd12   , // 200MHZ, refresh cycle time 70ns
                cnt_mrd         = 'd6    ; // 200MHZ, mode register setup waiting time 30ns

// states of local state machine
localparam      INIT_IDLE   =   3'b000, // idle
                INIT_PRE    =   3'b001, // precharge
                INIT_TRP    =   3'b011, // precharge waiting
                INIT_AREF   =   3'b010, // auto refresh
                INIT_TRFC   =   3'b110, // auto refresh waiting
                INIT_LMR    =   3'b111, // mode register setting
                INIT_TMRD   =   3'b110, // register setting waiting
                INIT_END    =   3'b100; // init end state

localparam      aref_num    = 2;

localparam      init_lmrset = { 3'b000 , // A12-A10; reserved fields
                            1'b0,        // A9 mode 0: burst read and burst write, 1: burst read and single beat write
                            2'b00,       // {A8, A7} standard mode default
                            3'b011,      // {A6, A5, A4}   CAS hidden latency
                            1'b0,        // A3 burst mode 0 : incremental 1: jumping
                            3'b111       // {A2, A1, A0} burst length 000: single byte 001: 2 bytes 010: 4 bytes 011: 8 bytes 111: whole page, rest : reserved
                            };

// define internal regs
reg 	[15:0]	cnt_200us			;			//power up waiting counter

//fsm states cs ns
reg		[2:0]	init_state_cs		;			//初始化状态机  当前状态
reg		[2:0]	init_state_ns		;			//初始化状态机  下一个状态
// flags
reg				pow_end			;			//上电结束标志
reg				pre_end			;			//预充电结束标志
reg				aref_end		;			//刷新结束标志
reg				mrd_end			;			//模式寄存器设置结束标志
// command counter
reg 	[3:0]	cnt_clk			;			//各状态记录时间
//reg 			cnt_clk_rst_n	;			//时钟周期复位信号 取消这个标志信号，直接判断是否复位

reg 	[3:0]	cnt_init_aref	;			//初始阶段刷新次数

// power up -> system setup reset clock and power charge, waiting 200us, note it starts counting after reset is asserted by watchdog
always@(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n == 1'b0) begin 
        cnt_200us <= 'd0;
        pow_end <= 1'b0;   
    end else if (cnt_200us == cnt_pow) begin
        cnt_200us <= 'd0;
        pow_end <= 1'b1;
    end else if (init_start_i == 1'b1) begin
        cnt_200us  <= cnt_200us + 1;
        pow_end <= 1'b0;
	end else begin
		cnt_200us <= cnt_200us;
		pow_end <= 1'b0;
	end
end 

// command clock counter
always @(posedge sys_clk or negedge sys_rst_n) begin 
	if(sys_rst_n == 1'b0) begin
		cnt_clk <= 0 	;
	end 
	else if(pow_end == 1 || pre_end == 1 || aref_end == 1 ) begin
		 cnt_clk <=	0  	;
	end
	else if (init_state_cs == INIT_IDLE || init_state_cs == INIT_END)
		cnt_clk 	<=	cnt_clk;
	else
		cnt_clk 	<= 	cnt_clk + 1'b1; 
end

// count refresh times
always@(posedge sys_clk or negedge sys_rst_n) begin
    if (sys_rst_n == 1'b0)
        cnt_init_aref <= 'd0;
    else if (init_state_cs == INIT_IDLE) 
        cnt_init_aref <= 'd0;
    else if (init_state_cs == INIT_AREF) 
        cnt_init_aref <= cnt_init_aref + 1;
    else
        cnt_init_aref <= cnt_init_aref;
end

//pre_end
always@(*)	begin
	if(init_state_cs == INIT_TRP && cnt_clk == cnt_rp)
				pre_end 		= 			1 	;
	else
				pre_end			=			0 	;
end

//aref_end
always@(*)	begin
	if(init_state_cs == INIT_TRFC && cnt_clk == cnt_rfc)
				aref_end 		= 			1 	;
	else
				aref_end			=			0 	;
end


//mrd_end
always@(*)	begin
	if(init_state_cs == INIT_TMRD && cnt_clk == cnt_mrd)
				mrd_end	 	 		= 			1 	;
	else
				mrd_end				=			0 	;
end


// three stage fsm 
always @(posedge sys_clk or negedge sys_rst_n) begin 
	if(sys_rst_n == 1'b0) begin
		 init_state_cs <= INIT_IDLE;
	end 
	else begin
		 init_state_cs <= init_state_ns ;
	end
end


// next state transform
always@(*) begin
	case(init_state_cs)
		INIT_IDLE	:
						if(pow_end == 1)
							init_state_ns	=	INIT_PRE	;
						else
							init_state_ns	=	INIT_IDLE	;

		INIT_PRE	:
							init_state_ns	=	INIT_TRP	;
							
		INIT_TRP	:
						if(pre_end == 1)
							init_state_ns	=	INIT_AREF	;
						else
							init_state_ns	=	INIT_TRP	;

		INIT_AREF:  	 	init_state_ns 	= 	INIT_TRFC	; 

		INIT_TRFC	:
						if(aref_end == 1)	//	刷新结束，需要判断刷新次数
							if(cnt_init_aref == aref_num)
							 		init_state_ns	=	INIT_LMR	;
							else
									init_state_ns   = 	INIT_AREF 	;
						else
							init_state_ns	=	INIT_TRFC	;

		INIT_LMR 	: 		init_state_ns	=	INIT_TMRD 	;

		INIT_TMRD	:
						if(mrd_end == 1)
							init_state_ns	=	INIT_END	;
						else
							init_state_ns	=	INIT_TMRD	;
		INIT_END	:
							init_state_ns   =   INIT_IDLE	;
		default:
							init_state_ns 	= 	INIT_IDLE	;
	endcase // init_state_cs

end

always @(posedge sys_clk or negedge sys_rst_n) begin 
	if(~sys_rst_n) begin
				init_cmd_o	 	 <= NOP				;
			    init_ba_o		 <= 2'b11			;
			    init_addr_o 	 <= 13'h1fff		;
		 		init_end_o 	     <= 1'b0 			;	
	end 
	else begin
		 case (init_state_cs)
		 	INIT_IDLE,INIT_TRP,INIT_TRFC,INIT_TMRD: begin
		 		 			init_cmd_o	 <= NOP				;
			     			init_ba_o		 <= 2'b11			;
			     			init_addr_o 	 <= 13'h1fff		;
		 	end
				
			INIT_PRE	: begin
						  	init_cmd_o 	 <= PRE				;
			     			init_ba_o		 <= 2'b11			;
			     			init_addr_o 	 <= 13'h1fff		;
			end

			INIT_AREF 	:	begin
							init_cmd_o	 <= AREF			;
			     			init_ba_o		 <= 2'b11			;
			     			init_addr_o 	 <= 13'h1fff		;
			end			
							
			INIT_LMR	: 	begin
							init_cmd_o	 <= LMR				;
			     			init_ba_o		 <= 2'b00			;	//这里11和00有什么区别吗
			     			init_addr_o 	 <= init_lmrset		;
			end
			

			INIT_END	: begin 
		 		 			init_cmd_o	 <= NOP				;
			     			init_ba_o		 <= 2'b11			;
			     			init_addr_o 	 <= 13'h1fff		;
			     			init_end_o	 <=	1'b1 			;
		 	end
		 	default : /* default */begin
		 					init_cmd_o	 <= NOP				;
			     			init_ba_o		 <= 2'b11			;
			     			init_addr_o 	 <= 13'h1fff		;
		 	end
		 endcase
	end
end


endmodule
