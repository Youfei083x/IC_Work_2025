// The interface allows verification components to access DUT signals
// using a virtual interface handle
interface fifo_ctrl_if(input bit sys_clk0, input bit clk1, input bit clk2);
	logic  		           	 sys_rst_n 	;
	logic  		           	 wr_fifo_wr_req 	;
	logic  		[15 : 0]	 wr_fifo_wr_data 	;
	logic  		[9 : 0]	 	 wr_burst_len 	;
	logic  		[23 : 0]	 wr_b_addr 	;
	logic  		           	 wr_rst 	;
	logic  		           	 wr_fifo_rdy 	;
	logic  		           	 rd_fifo_rd_req 	;
	logic  		[23 : 0]	 rd_b_addr 	;
	logic  		[9 : 0]	 	 rd_burst_len 	;
	logic  		           	 rd_rst 	;
	logic  		           	 rd_fifo_rdy 	;
	logic  		           	 init_end 	;
	logic  		[15 : 0]	 rd_fifo_rd_data 	;
	logic  		           	 sdram_wr_ack 	;
	logic  		           	 sdram_wr_req 	;
	logic  		[23 : 0]	 sdram_wr_addr 	;
	logic  		[9 : 0]	 	 sdram_wr_burst_len 	;
	logic  		[15 : 0]	 sdram_data_in 	;
	logic  		           	 sdram_rd_ack 	;
	logic  		           	 sdram_rd_req 	;
	logic  		[23 : 0]	 sdram_rd_addr 	;
	logic  		           	 sdram_data_valid 	;
	logic  		[9 : 0]	 	 sdram_rd_burst_len 	;
	logic  		[15 : 0]	 sdram_data_out 	;
	
/*
	tasks are allowed to be implemented in interface blocks
	regard an interface block as a type of unique class type and we are allowed to implement methods inside
	including functions and tasks in SystemVerilog 
	we can implement the sequence task in the top testbench as well but for simplicity, use signals defined in the interface directly!
	time management statements are of course allowed here
	tasks can only be called out in a procedual blocks, remember!
*/		
	task 		write_transaction(input bit [9:0] burst_length, 
									input bit [15:0] data[]);
		// appropriate delay before each transaction
		repeat(30)
			@(posedge clk1);
		
		// send write request
		@(posedge clk1)
		wr_fifo_wr_req = 1'b1;
		wr_burst_len   = burst_length;
		wr_b_addr      = 24'h1FFFFF;
		sdram_wr_ack   = 1'b0;

		@(posedge clk1)
		wr_fifo_wr_req = 1'b0;
		wr_burst_len   = 'd0;
		wr_b_addr      = 'd0;
		sdram_wr_ack   = 1'b0;
		foreach(data[i]) begin
			wr_fifo_wr_data = data[i];
			@(posedge clk1);
		end
		wr_fifo_wr_data = 'd0;

		// delay between write fifo request and sdram write request
		repeat(10)
			@(posedge sys_clk0);
		if(sdram_wr_req == 1'b1) begin
			@(posedge sys_clk0);
			sdram_wr_ack = 1'b1;
		end else begin
			@(posedge sys_clk0);
			$display("the sdram write request is not raised !!! check your rtl code");
		end

		@(posedge sys_clk0) sdram_wr_ack = 1'b0;

		// wait for the remaining transaction complete
		repeat(20)
			@(posedge sys_clk0);
	endtask

	task 		read_transaction(input bit [9:0] burst_length, 
									input bit [15:0] data[]);

		// appropriate delay before each transaction
		repeat(30)
		@(posedge clk2);
	
		// send write request
		@(posedge clk2)
		rd_fifo_rd_req = 1'b1;
		rd_burst_len   = burst_length;
		rd_b_addr      = 24'h1FFFFF;

		@(posedge clk2)
		rd_fifo_rd_req = 1'b0;
		rd_burst_len   = 'd0;
		rd_b_addr      = 'd0;

		repeat(10)
			@(posedge sys_clk0);
		
		if(sdram_rd_req == 1'b1) begin
			sdram_rd_ack = 1'b1;
			@(posedge sys_clk0);
			sdram_rd_ack = 1'b0;
			// rcd delay
			repeat(20) @(posedge sys_clk0);

			sdram_data_valid = 1'b1;
			foreach(data[i]) begin
				sdram_data_out = data[i];
				@(posedge sys_clk0);
			end
			sdram_data_out = 'd0;
			sdram_data_valid = 1'b0;
		end else begin
			@(posedge sys_clk0);
			$display("the sdram read request is not raised !!! check your rtl code");
		end
		@(posedge sys_clk0);
		// wait for the remaining transaction complete
		repeat(20)
			@(posedge sys_clk0);
	endtask
	
	
	// ready check assertions(assertion means this behavior is assumed to be true every time the conditional statement is asserted.)
	property write_ready_check;
	 @(posedge clk1)  (!wr_fifo_rdy) |-> (!wr_fifo_wr_req);
	endproperty
	
	WR_RDY_CHECK: assert property (write_ready_check);

	property read_ready_check;
	 @(posedge clk2)  (!rd_fifo_rdy) |-> (!rd_fifo_rd_req);
	endproperty

	RD_RDY_CHECK: assert property (read_ready_check);
endinterface
