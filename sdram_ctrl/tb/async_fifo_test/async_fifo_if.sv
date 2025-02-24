// The interface allows verification components to access DUT signals
// using a virtual interface handle
interface async_fifo_if(input bit sys_clk0, input bit sys_clk1);
  
	logic   												sys_rst_n0	;
	logic													sys_rst_n1	;

	logic 													wr_en		;
	logic													rd_en		;
	logic  					[15:0]							wr_data		;
	logic   				[15:0]							rd_data		;

	logic													fifo_empty	;
	logic  													fifo_full	;
	logic 													fifo_overrun	;
	logic     												fifo_underrun	;
	logic  					[127:0]							fifo_data_num	;
	logic  					[127:0]							fifo_room_num	;	

endinterface
