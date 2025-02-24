`timescale 1ns / 10ps


module fifo_ctrl_tb();
//============== Define parameters and create an interface of the dut ==============
    localparam STOP_AT_ERR = 1; //set to 1 to stop tb at first error
	logic 					sys_clk;
	logic					clk_0;
	logic					clk_1;
	// interface
	fifo_ctrl_if fifo_ctrl_if(sys_clk, clk_0, clk_1);
	fifo_crtl_packet packet = new();
//=============== Generate the write clock =================
    // params
    localparam CLK_PERIOD0 = 20;
    localparam DUTY_CYCLE0 = 0.5;
    //run the clock forever, flipping back and forth between 1 and 0
    initial begin
			sys_clk	= 1'b0;
        forever begin
            #(CLK_PERIOD0 * DUTY_CYCLE0) sys_clk = 1'b1;
            #(CLK_PERIOD0 * DUTY_CYCLE0) sys_clk = 1'b0;
        end
	end
//=============== Generate the read clock =================
    // params
    localparam CLK_PERIOD1 = 30;
    localparam DUTY_CYCLE1 = 0.5;
    //run the clock forever, flipping back and forth between 1 and 0
    initial begin
			clk_0	= 1'b0;
			clk_1   = 1'b0;
        forever begin
            #(CLK_PERIOD1 * DUTY_CYCLE1)	 clk_0 = 1'b1; clk_1 = 1'b1; 
            #(CLK_PERIOD1 * DUTY_CYCLE1) 	 clk_0 = 1'b0; clk_1 = 1'b0;
        end
	end
//================= Instantiate DUT ==================
	sys_fifo_ctrl	u_sys_fifo_ctrl (
		.sys_clk( sys_clk)     ,	
		.sys_rst_n( fifo_ctrl_if.sys_rst_n)     ,	
		.wr_fifo_wr_req( fifo_ctrl_if.wr_fifo_wr_req)     ,	
		.wr_fifo_wr_data( fifo_ctrl_if.wr_fifo_wr_data)     ,	
		.wr_fifo_wr_clk( clk_0)     ,	
		.wr_burst_len( fifo_ctrl_if.wr_burst_len)     ,	
		.wr_b_addr( fifo_ctrl_if.wr_b_addr)     ,	
		.wr_rst( fifo_ctrl_if.wr_rst)     ,	
		.wr_fifo_rdy( fifo_ctrl_if.wr_fifo_rdy)     ,	
		.rd_fifo_rd_clk( clk_1)     ,	
		.rd_fifo_rd_req( fifo_ctrl_if.rd_fifo_rd_req)     ,	
		.rd_b_addr( fifo_ctrl_if.rd_b_addr)     ,	
		.rd_burst_len( fifo_ctrl_if.rd_burst_len)     ,	
		.rd_rst( fifo_ctrl_if.rd_rst)     ,	
		.rd_fifo_rdy( fifo_ctrl_if.rd_fifo_rdy)     ,	
		.init_end( fifo_ctrl_if.init_end)     ,	
		.rd_fifo_rd_data( fifo_ctrl_if.rd_fifo_rd_data)     ,	
		.sdram_wr_ack( fifo_ctrl_if.sdram_wr_ack)     ,	
		.sdram_wr_req( fifo_ctrl_if.sdram_wr_req)     ,	
		.sdram_wr_addr( fifo_ctrl_if.sdram_wr_addr)     ,	
		.sdram_wr_burst_len( fifo_ctrl_if.sdram_wr_burst_len)     ,	
		.sdram_data_in( fifo_ctrl_if.sdram_data_in)     ,	
		.sdram_rd_ack( fifo_ctrl_if.sdram_rd_ack)     ,	
		.sdram_rd_req( fifo_ctrl_if.sdram_rd_req)     ,	
		.sdram_rd_addr( fifo_ctrl_if.sdram_rd_addr)     ,	
		.sdram_data_valid( fifo_ctrl_if.sdram_data_valid)     ,	
		.sdram_rd_burst_len( fifo_ctrl_if.sdram_rd_burst_len)     ,	
		.sdram_data_out( fifo_ctrl_if.sdram_data_out) 	
);
//================= Testbench Tasks ==================

    task initialize_signals; //set inputs to default values
    begin
		fifo_ctrl_if.wr_fifo_wr_req = 1'b0;
		fifo_ctrl_if.wr_burst_len   = 'd0;
		fifo_ctrl_if.wr_b_addr      = 'd0;
		fifo_ctrl_if.sdram_wr_ack   = 1'b0;
		fifo_ctrl_if.wr_fifo_wr_data = 'd0;
		fifo_ctrl_if.rd_fifo_rd_req = 1'b0;
		fifo_ctrl_if.rd_burst_len   = 'd0;
		fifo_ctrl_if.rd_b_addr      = 'd0;
		fifo_ctrl_if.sdram_data_valid = 'd0;
		fifo_ctrl_if.sdram_rd_ack = 1'b0;
		fifo_ctrl_if.sdram_data_out = 'd0;
		fifo_ctrl_if.init_end = 1'b0;
	end
    endtask
    
    task reset_dut; //task to properly reset design
    begin
			fifo_ctrl_if.sys_rst_n	= 1'b0;
			fifo_ctrl_if.wr_rst    = 1'b0;
			fifo_ctrl_if.rd_rst		= 1'b0;
			fifo_ctrl_if.init_end   = 1'b0;
        repeat(10) @(negedge sys_clk); //hold reset for 10 cycles
			fifo_ctrl_if.sys_rst_n	= 1'b1;
			fifo_ctrl_if.wr_rst    = 1'b1;
			fifo_ctrl_if.rd_rst		= 1'b1;
			fifo_ctrl_if.init_end   = 1'b1;
    end
    endtask

//================== Run Test Cases ==================
    initial begin
       // $vcdpluson; //set up trace dump for DVE
       // $vcdplusmemon;
        
        initialize_signals();
        reset_dut();
		
		//write transaction 
		packet.randomize() with {packet.burst_length == 8;};
		packet.display_random_values();
		fifo_ctrl_if.write_transaction(packet.burst_length, packet.data);
		// read transaction
		repeat(20) @(posedge sys_clk);
		packet.randomize() with {packet.burst_length == 8;};
		packet.display_random_values();
		fifo_ctrl_if.read_transaction(packet.burst_length, packet.data);

		$display("simulation complete !!!");
	//	burst_write_test();
		@(posedge sys_clk);
        $finish;
    end

endmodule
