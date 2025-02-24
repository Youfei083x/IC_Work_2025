//-------------------------------------------------------------------------------------------
//      Date : 10/31/2024
//      Author : Yufei Fu (Frederick)
//      Description :   multi-clock domain tx rx transitor
//      1. A triple clock domain transitor for connecting a data provider and
//      a data consumer to SDRAM IP through a DDR controller
//      2. For write transactions, the up stream asserts a req flag and write
//      data into the tx-fifo if its not full. Otherwise response an error
//      signal to resend the req some time later. The sdram write req should
//      be activated internally if the number of data in tx-fifo is larger
//      than the SDRAM burst length. 
//      3. For read transactions, the down stream asserts a read req and
//      waiting for the data to be read out and loaded into the rx-fifo. The
//      read transaction of SDRAM should be activated internally after a read
//      req is asserted and load data into rx-fifo. during this time the down
//      stream side should wait and until a ready signal is asserted then the
//      data is ready.
//-------------------------------------------------------------------------------------------
`timescale 1ns/10ps

module sys_fifo_ctrl (
		//system signals
		input 					sys_clk 			,		//系统时钟，167MHZ
		input 					sys_rst_n 			,		//系统复位信号，低电平有效
		
		//写fifo信号				//
		input					wr_fifo_wr_clk		,		//写fifo写时钟
		input 					wr_fifo_wr_req 		,		//写fifo写请求
		input 	[15:0]			wr_fifo_wr_data 	,		//写fifo写数据
		input 	[23:0]			wr_b_addr 			,		// burst write beginning address
		input 	[9:0]			wr_burst_len 		,		// burst write length
		input 					wr_rst 				,		// write domain reset, reset sequential logic in the write clock domain
		output  wire 		    wr_fifo_rdy			,		// tx-fifo ready signal		
		//读fifo信号				//
		input					rd_fifo_rd_clk		,		//读fifo读时钟
		input 					rd_fifo_rd_req 		,		//读fifo读请求
		input 	[23:0]			rd_b_addr 			,		//读SDRAM的首地址
		input 	[9:0]			rd_burst_len 		,		//读SDRAM的突发长度
		input 					rd_rst 				,		//读复位信号，读fifo清零
		output 	wire  [15:0]	rd_fifo_rd_data 	,		//读fifo读数据
		output  wire			rd_fifo_rdy			,		// rx_fifo ready signal
		//
		input 					init_end 			,		//SDRAM初始化结束信号
		//
		//SDRAM写信号		//
		input 					sdram_wr_ack 		,		//SDRAM写响应
		output 	reg 			sdram_wr_req 		,		//SDRAM写请求
		output 	reg 	[23:0]	sdram_wr_addr 		,		//SDRAM写地址a
		output  reg		[9:0]	sdram_wr_burst_len	,       //write burst length 
		output 	wire 	[15:0]	sdram_data_in 		,		//写入SDRAM的数据
		//SDRAM读信号		//
		input 					sdram_rd_ack		,		//SDRAM读响应
		input 			[15:0]	sdram_data_out 		,		//SDRAM读出的数据
		input   				sdram_data_valid	,		//data valid flag
		output 	reg 			sdram_rd_req		,		//SDRAM读请求
		output  reg		[9:0]	sdram_rd_burst_len  ,       //read burst length 
		output  reg		[23:0]	sdram_rd_addr 				//SDRAM读地址	
	);


//======================================
//param and internal signals
//======================================
localparam						IDLE	= 2'b00	;	
localparam						ACCESS	= 2'b01	;
localparam						TRANS	= 2'b11	;

// write transaction
reg         [2:0]				wr_state_r, wr_state_nxt;
reg								wr_fifo_req				;  // fifo write enable signal
reg			[9:0]				wr_fifo_cnt				;  // fifo burst write counter
wire							wr_burst_end			;  // when burst length equals counter value
wire							wr_valid_req			;  // valid request 
wire							wr_fifo_full			;  // fifo full
wire     						wr_fifo_empty			;
reg 		[2:0]				wr_sdram_rd_req			;  // b0 : data fifo req, b1 : addr fifo req, b2 : burst length fifo req  		
wire        [23:0]				wr_fifo_addr			;
wire    	[9:0]				wr_fifo_burst_len		;
wire    						sdram_burst_end			;
// read transaction
reg			[1:0]				rd_state_r, rd_state_nxt;
// wire								rd_fifo_req				;  // fifo read enable signal
reg			[9:0]				rd_fifo_cnt				;  // fifo burst read counter
wire							rd_burst_end			;  // when burst length equals counter value
wire						    rd_valid_req			;  // valid request
wire							rd_fifo_empty			;  // fifo empty
// reg 		[2:0]				rd_sdram_wr_req			;  // b0 : data fifo req, b1 : addr fifo req, b2 : burst length fifo req

// synchronization
reg 							wr_init_end_r0;
reg	    						wr_init_end_r1;
reg 							rd_init_end_r0;
reg								rd_init_end_r1;

// negedge detector for sdram_data_valid
reg  										sdram_data_valid_r0, sdram_data_valid_r1;
reg   										sdram_valid_negedge, sdram_valid_negedge_r0, sdram_valid_negedge_r1, sdram_valid_negedge_r2;
reg 										sdram_valid_edge_ack_r1, sdram_valid_edge_ack_r0;
reg  										sdram_rd_ack_r, sdram_rd_ack_r0, sdram_rd_ack_r1;
// pulse synchronizer
wire  											sdram_valid_edge;
wire  											rd_valid_edge	;

/* operate ready signals for write domain and read domain
*  1. when tx_fifo is full, wr_rdy is deasserted
*  2. when rx_fifo is empty, rd_rdy is deasserted
*  3. when init_end is active high, deassert both read and write ready signals
*  4. when burst begin address is larger or equal to the end address, deassert
*  the correspending ready signals
*  5. otherwise keep it being active high 
*/

always@(posedge wr_fifo_wr_clk or negedge wr_rst) begin
	if(wr_rst != 1'b1) begin
		wr_init_end_r0 <= 1'b0;
		wr_init_end_r1 <= 1'b0;
	end 
	else begin 
		wr_init_end_r0 <= init_end;
		wr_init_end_r1 <= wr_init_end_r0;
	end
end

always@(posedge rd_fifo_rd_clk or negedge rd_rst) begin
	if(rd_rst != 1'b1) begin
		rd_init_end_r0 <= 1'b0;
		rd_init_end_r1 <= 1'b0;
	end 
	else begin 
		rd_init_end_r0 <= init_end;
		rd_init_end_r1 <= rd_init_end_r0;
	end
end


assign  wr_fifo_rdy		=	wr_init_end_r1 && (!wr_fifo_full)		;
assign  rd_fifo_rdy		=	rd_init_end_r1 && (rd_fifo_empty)	;

/* 
* handle request signal handshake
*/

assign		wr_valid_req = (wr_fifo_wr_req && wr_fifo_rdy);
assign		rd_valid_req = (rd_fifo_rd_req && rd_fifo_rdy);

/*
*   write transaction handler 
*/
reg   						[9:0]						wr_burst_len_r;

always@(posedge wr_fifo_wr_clk or negedge wr_rst)  begin
	if(wr_rst != 1'b1)
		wr_burst_len_r <= 'd0;
	else begin
		if(wr_valid_req == 1'b1)
			wr_burst_len_r <=  wr_burst_len; 
	end
end

assign      wr_burst_end = (wr_fifo_cnt == wr_burst_len_r);

// input data sequence handler
always@(posedge wr_fifo_wr_clk or negedge wr_rst) begin
	if(wr_rst != 1'b1)
		wr_fifo_req <= 1'b0;
	else begin
		if(wr_fifo_cnt == (wr_burst_len_r - 1'b1))
			wr_fifo_req	<= 1'b0;
		else if(wr_valid_req == 1'b1)
			wr_fifo_req <= 1'b1;
		else
			wr_fifo_req <= wr_fifo_req;
	end
end

always@(posedge wr_fifo_wr_clk or negedge wr_rst) begin
	if(wr_rst != 1'b1) 
		wr_fifo_cnt		<=	'd0;
	else begin
		if(wr_burst_end == 1'b1) 
			wr_fifo_cnt <= 'd0;
		else if(wr_fifo_req == 1'b1 || wr_valid_req == 1'b1)
			wr_fifo_cnt <=  wr_fifo_cnt + 1'b1;
	end
end

// sdram write transaction fsm
always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1)
		wr_state_r <= IDLE;
	else
		wr_state_r <= wr_state_nxt;
end

always@(*) begin
	case(wr_state_r)
		IDLE: begin
			if(wr_fifo_empty != 1'b1)
				wr_state_nxt = ACCESS;
			else
				wr_state_nxt = IDLE;
		end
		ACCESS: begin
			if(sdram_wr_ack == 1'b1)
				wr_state_nxt = TRANS;
			else
				wr_state_nxt = ACCESS;
		end
		TRANS: begin
			if(sdram_burst_end == 1'b1)
				wr_state_nxt = IDLE;
			else
				wr_state_nxt = TRANS;
		end	
		default: begin
			wr_state_nxt = wr_state_r;
		end
	endcase
end

// set up sdram write request
always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
		sdram_wr_addr <= 'd0;
		sdram_wr_burst_len <= 'd0;
	end
	else begin
		if(wr_sdram_rd_req[2] && wr_sdram_rd_req[1] && (!wr_sdram_rd_req[0])) begin
			sdram_wr_addr 		<= wr_fifo_addr;
			sdram_wr_burst_len 	<= wr_fifo_burst_len;
		end
		else if(wr_state_r == ACCESS && sdram_wr_ack != 1'b1) begin
			sdram_wr_addr 		<= sdram_wr_addr;
			sdram_wr_burst_len  <= sdram_wr_burst_len;
		end
		else begin
			sdram_wr_addr		<= 'd0;
			sdram_wr_burst_len  <= 'd0;
		end	 
	end
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) 
		sdram_wr_req <= 1'b0;
	else begin
		if((wr_state_r == IDLE && wr_fifo_empty != 1'b1) || (wr_state_r == ACCESS && sdram_wr_ack != 1'b1))
			sdram_wr_req <= 1'b1;
		else
			sdram_wr_req <= 1'b0;
	end
end

reg   			[9:0]				sdram_wr_cnt;
reg  			[9:0]				sdram_burst_len_r;

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1)
		sdram_burst_len_r <= 'd0;
	else begin
		if(wr_sdram_rd_req[2] && wr_sdram_rd_req[1] && (!wr_sdram_rd_req[0]))
			sdram_burst_len_r <= wr_fifo_burst_len;
		else if(wr_state_r == ACCESS || wr_state_r == TRANS)
			sdram_burst_len_r <= sdram_burst_len_r;
		else
			sdram_burst_len_r <= 'd0;
	end
end

assign 	sdram_burst_end = (sdram_wr_cnt == sdram_burst_len_r);

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1)
		sdram_wr_cnt <= 'd0;
	else  begin
		if(sdram_burst_end == 1'b1)
			sdram_wr_cnt <= 'd0;
		else if((wr_state_r == ACCESS && sdram_wr_ack == 1'b1) || (wr_state_r == TRANS))
			sdram_wr_cnt <= sdram_wr_cnt + 1'b1;
	end
end

// handle fifo request
always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1)
		wr_sdram_rd_req <= 'd0;
	else begin
		if(wr_state_r == IDLE && wr_fifo_empty != 1'b1)
			wr_sdram_rd_req <= 3'b110;
		else if((wr_state_r == ACCESS && sdram_wr_ack == 1'b1) || (wr_state_r == TRANS && sdram_burst_end != 1'b1))
			wr_sdram_rd_req <= 3'b001;
		else 
			wr_sdram_rd_req <= 'd0;
	end
end

/*
*   read transaction handler 
*/
always@(posedge rd_fifo_rd_clk or negedge rd_rst) begin
	if(rd_rst != 1'b1)
		rd_state_r <= IDLE;
	else 
		rd_state_r <= rd_state_nxt;
end

always@(*) begin
	case(rd_state_r) 
	IDLE: begin
		if(rd_valid_req == 1'b1)
			rd_state_nxt = ACCESS;
		else
			rd_state_nxt = IDLE;	
	end
	ACCESS: begin
		if(sdram_rd_ack_r1 == 1'b1)
			rd_state_nxt = TRANS;
		else
			rd_state_nxt = ACCESS;
	end
	TRANS: begin
		if(rd_burst_end == 1'b1)
			rd_state_nxt = IDLE;
		else
			rd_state_nxt = TRANS;
	end
	default : begin
			rd_state_nxt = rd_state_r;
	end
	endcase
end

// signal synchronizer
reg    				[23:0]							rd_addr_r, rd_addr_r0, rd_addr_r1;
reg  				[9:0]							rd_burst_len_r, rd_burst_len_r0, rd_burst_len_r1;
reg   												rd_fifo_rd_req_r, rd_fifo_rd_req_r0, rd_fifo_rd_req_r1;

always@(posedge wr_fifo_wr_clk or negedge wr_rst) begin
	if(rd_rst != 1'b1)
		rd_addr_r <= 'd0;
	else if(rd_state_r == IDLE)
		rd_addr_r <= rd_b_addr;
	else if(rd_state_r == TRANS)
		rd_addr_r <= 'd0;
end

always@(posedge wr_fifo_wr_clk or negedge wr_rst) begin
	if(rd_rst != 1'b1)
		rd_burst_len_r <= 'd0;
	else if(rd_state_r == IDLE) 
		rd_burst_len_r <= rd_burst_len;
	else if(rd_state_r == TRANS)
		rd_burst_len_r <= rd_burst_len_r;
end

always@(posedge wr_fifo_wr_clk or negedge wr_rst) begin
	if(rd_rst != 1'b1)
		rd_fifo_rd_req_r <= 'd0;
	else if(rd_state_r == IDLE) 
		rd_fifo_rd_req_r <= rd_valid_req;
	else if(rd_state_r == TRANS)
		rd_fifo_rd_req_r <= 'd0;
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
		rd_addr_r0 <= 'd0;
		rd_addr_r1 <= 'd0;
	end
	else begin
		rd_addr_r0 <= rd_addr_r;
		rd_addr_r1 <= rd_addr_r0;		
	end
end

assign sdram_rd_addr = rd_addr_r1;

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
		rd_burst_len_r0 <= 'd0;
		rd_burst_len_r1 <= 'd0;
	end
	else begin
		rd_burst_len_r0 <= rd_burst_len_r;
		rd_burst_len_r1 <= rd_burst_len_r0;		
	end
end

assign sdram_rd_burst_len = rd_burst_len_r1;

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
		rd_fifo_rd_req_r0 <= 'd0;
		rd_fifo_rd_req_r1 <= 'd0;
	end
	else begin
		rd_fifo_rd_req_r0 <= rd_fifo_rd_req_r;
		rd_fifo_rd_req_r1 <= rd_fifo_rd_req_r0;		
	end
end

assign sdram_rd_req = rd_fifo_rd_req_r1;

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
		sdram_data_valid_r0 <= 'd0;
		sdram_data_valid_r1 <= 'd0;
	end
	else begin
		sdram_data_valid_r0 <= sdram_data_valid;
		sdram_data_valid_r1 <= sdram_data_valid_r0;
	end
end


assign 					sdram_valid_edge = (~sdram_data_valid_r0) && sdram_data_valid_r1;

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
		sdram_valid_negedge <= 'd0;
	end
	else begin
		sdram_valid_negedge <=  (sdram_valid_edge_ack_r1 == 1'b1) ? 1'b0 :
										(sdram_valid_edge == 1'b1) ? 
											 1'b1 : sdram_valid_negedge;  	
	end
end

always@(posedge wr_fifo_wr_clk or negedge rd_rst) begin
	if(rd_rst != 1'b1) begin
		sdram_valid_negedge_r0 <= 'd0;
		sdram_valid_negedge_r1 <= 'd0;
		sdram_valid_negedge_r2 <= 'd0;
	end
	else begin
		sdram_valid_negedge_r0 <= sdram_valid_negedge;
		sdram_valid_negedge_r1 <= sdram_valid_negedge_r0;
		sdram_valid_negedge_r2 <= sdram_valid_negedge_r1;	
	end
end

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
		sdram_valid_edge_ack_r0 <= 'd0;
		sdram_valid_edge_ack_r1 <= 'd0;
	end 
	else begin
		sdram_valid_edge_ack_r0 <= sdram_valid_negedge_r1;
		sdram_valid_edge_ack_r1 <= sdram_valid_edge_ack_r0;		
	end
end
assign rd_valid_edge = sdram_valid_negedge_r2 && (!sdram_valid_negedge_r1);

always@(posedge sys_clk or negedge sys_rst_n) begin
	if(sys_rst_n != 1'b1) begin
			sdram_rd_ack_r <= 'd0;
	end
	else begin
			sdram_rd_ack_r <= sdram_rd_ack;
	end
end

always@(posedge wr_fifo_wr_clk or negedge rd_rst) begin
	if(rd_rst != 1'b1) begin
		sdram_rd_ack_r0 <= 'd0;
		sdram_rd_ack_r1 <= 'd0;
	end
	else begin
		sdram_rd_ack_r0 <= sdram_rd_ack_r;
		sdram_rd_ack_r1 <= sdram_rd_ack_r0;	
	end
end

// rd fifo output handler
reg   										wr_fifo_en;

assign  rd_burst_end = (rd_fifo_cnt + 1'b1 == rd_burst_len_r);

always@(posedge wr_fifo_wr_clk or negedge rd_rst) begin
	if(rd_rst != 1'b1)
		wr_fifo_en <= 'd0;
	else begin
		if(rd_valid_edge == 1'b1)
			wr_fifo_en <= 1'b1;
		else if(rd_burst_end == 1'b1)
			wr_fifo_en <= 1'b0;
	end
end

always@(posedge wr_fifo_wr_clk or negedge rd_rst) begin
	if(rd_rst != 1'b1)
		rd_fifo_cnt <= 'd0;
	else begin
		if(rd_burst_end == 1'b1)
			rd_fifo_cnt <= 'd0;
		else if(wr_fifo_en == 1'b1)
			rd_fifo_cnt <= rd_fifo_cnt + 1'b1;
		else
			rd_fifo_cnt <= 'd0;
	end
end

// assign rd_fifo_req = (rd_fifo_cnt != 'd0);


//写fifo例化
// Instance of sys_async_fifo
sys_async_fifo #(
    .DATA_WIDTH(16),
    .FIFO_DEPTH(128),
    .PTR_WIDTH(7)
) u_sys_async_fifo_wr (
    // system signals
    .sys_clk0           (wr_fifo_wr_clk         ),  // write side clock
    .sys_rst_n0         (wr_rst       ),  // write side reset
    .sys_clk1           (sys_clk          ),  // read side clock
    .sys_rst_n1         (sys_rst_n       ),  // read side reset
    
    // read and write signals
    .wr_en_i            (wr_fifo_req         ),  // write enable
    .wr_data_i          (wr_fifo_wr_data        ),  // write data
    .rd_en_i            (wr_sdram_rd_req[0]         ),  // read enable
    .rd_data_o          (sdram_data_in        ),  // read data
    
    // status signals
    .fifo_empty_o       ( wr_fifo_empty ),  // fifo empty
    .fifo_full_o        ( wr_fifo_full     ),  // fifo full
    .fifo_overrun_o     ( ),  // fifo overrun
    .fifo_underrun_o    ( ),  // fifo underrun
    .fifo_data_num_o    ( ),  // available data count
    .fifo_room_num_o    ( )   // available space count
);

//读fifo例化
sys_async_fifo #(
    .DATA_WIDTH(16),
    .FIFO_DEPTH(128),
    .PTR_WIDTH(7)
) u_sys_async_fifo_rd (
    // system signals
    .sys_clk0           (sys_clk         ),  // write side clock
    .sys_rst_n0         (sys_rst_n       ),  // write side reset
    .sys_clk1           (rd_fifo_rd_clk          ),  // read side clock
    .sys_rst_n1         (rd_rst       ),  // read side reset
    
    // read and write signals
    .wr_en_i            (sdram_data_valid        ),  // write enable
    .wr_data_i          (sdram_data_out        ),  // write data
    .rd_en_i            (wr_fifo_en         ),  // read enable
    .rd_data_o          (rd_fifo_rd_data        ),  // read data
    
    // status signals
    .fifo_empty_o       (rd_fifo_empty ),  // fifo empty
    .fifo_full_o        ( ),  // fifo full
    .fifo_overrun_o     ( ),  // fifo overrun
    .fifo_underrun_o    ( ),  // fifo underrun
    .fifo_data_num_o    ( ),  // available data count
    .fifo_room_num_o    ( )   // available space count
);

// write addr fifo 
sys_async_fifo #(
    .DATA_WIDTH(24),
    .FIFO_DEPTH(8),
    .PTR_WIDTH(3)
) u_sys_async_fifo_wr_addr (
    // system signals
    .sys_clk0           (wr_fifo_wr_clk         ),  // write side clock
    .sys_rst_n0         (wr_rst			       ),  // write side reset
    .sys_clk1           (sys_clk	           ),  // read side clock
    .sys_rst_n1         (sys_rst_n		       ),  // read side reset
    
    // read and write signals
    .wr_en_i            (wr_valid_req          ),  // write enable
    .wr_data_i          (wr_b_addr        			),  // write data
    .rd_en_i            (wr_sdram_rd_req[1]         ),  // read enable
    .rd_data_o          (wr_fifo_addr		        ),  // read data
    
    // status signals
    .fifo_empty_o       ( ),  // fifo empty
    .fifo_full_o        ( ),  // fifo full
    .fifo_overrun_o     ( ),  // fifo overrun
    .fifo_underrun_o    ( ),  // fifo underrun
    .fifo_data_num_o    ( ),  // available data count
    .fifo_room_num_o    ( )   // available space count
);

// write burst length fifo 
sys_async_fifo #(
    .DATA_WIDTH(10),
    .FIFO_DEPTH(8),
    .PTR_WIDTH(3)
) u_sys_async_fifo_wr_burst (
    // system signals
    .sys_clk0           (wr_fifo_wr_clk         ),  // write side clock
    .sys_rst_n0         (wr_rst			       ),  // write side reset
    .sys_clk1           (sys_clk	           ),  // read side clock
    .sys_rst_n1         (sys_rst_n		       ),  // read side reset
    
    // read and write signals
    .wr_en_i            (wr_valid_req          ),  // write enable
    .wr_data_i          (wr_burst_len        			),  // write data
    .rd_en_i            (wr_sdram_rd_req[2]         ),  // read enable
    .rd_data_o          (wr_fifo_burst_len	        ),  // read data
    
    // status signals
    .fifo_empty_o       ( ),  // fifo empty
    .fifo_full_o        ( ),  // fifo full
    .fifo_overrun_o     ( ),  // fifo overrun
    .fifo_underrun_o    ( ),  // fifo underrun
    .fifo_data_num_o    ( ),  // available data count
    .fifo_room_num_o    ( )   // available space count
);


endmodule
