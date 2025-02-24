`timescale 1ns / 10ps


module async_fifo_tb();
//============== Define parameters and create an interface of the dut ==============
    localparam STOP_AT_ERR = 1; //set to 1 to stop tb at first error
	logic 					sys_clk0_i;
	logic					sys_clk1_i;
	// interface
	async_fifo_if async_fifo_if(sys_clk0_i, sys_clk1_i);
//	integer file_golden;
//	integer file_actual;

//=============== Generate the write clock =================
    // params
    localparam CLK_PERIOD0 = 20;
    localparam DUTY_CYCLE0 = 0.5;
    //run the clock forever, flipping back and forth between 1 and 0
    initial begin
			sys_clk0_i	= 1'b0;
        forever begin
            #(CLK_PERIOD0 * DUTY_CYCLE0) sys_clk0_i = 1'b1;
            #(CLK_PERIOD0 * DUTY_CYCLE0) sys_clk0_i = 1'b0;
        end
	end
//=============== Generate the read clock =================
    // params
    localparam CLK_PERIOD1 = 30;
    localparam DUTY_CYCLE1 = 0.5;
    //run the clock forever, flipping back and forth between 1 and 0
    initial begin
			sys_clk1_i	= 1'b0;
        forever begin
            #(CLK_PERIOD1 * DUTY_CYCLE1)	 sys_clk1_i = 1'b1;
            #(CLK_PERIOD1 * DUTY_CYCLE1) 	 sys_clk1_i = 1'b0;
        end
	end
//================= Instantiate DUT ==================
	sys_async_fifo #()    u_sys_async_fifo(
		.sys_clk0(sys_clk0_i),
		.sys_clk1(sys_clk1_i),
		.sys_rst_n0(async_fifo_if.sys_rst_n0),
		.sys_rst_n1(async_fifo_if.sys_rst_n1),
		.wr_en_i(async_fifo_if.wr_en),
		.rd_en_i(async_fifo_if.rd_en),
		.wr_data_i(async_fifo_if.wr_data),
		.rd_data_o(async_fifo_if.rd_data),
		.fifo_empty_o(async_fifo_if.fifo_empty),
		.fifo_full_o(async_fifo_if.fifo_full),
		.fifo_overrun_o(async_fifo_if.fifo_overrun),
		.fifo_underrun_o(async_fifo_if.fifo_underrun),		
		.fifo_data_num_o(async_fifo_if.fifo_data_num),
		.fifo_room_num_o(async_fifo_if.fifo_room_num)
    );
//================= Testbench Tasks ==================

    task initialize_signals; //set inputs to default values
    begin
		async_fifo_if.wr_en = 1'b0;
		async_fifo_if.rd_en = 1'b0;
		async_fifo_if.wr_data = 'd0;
    end
    endtask
    
    task reset_dut; //task to properly reset design
    begin
			async_fifo_if.sys_rst_n0	= 1'b0;
			async_fifo_if.sys_rst_n1    = 1'b0;
        repeat(10) @(negedge sys_clk0_i); //hold reset for 10 cycles
        @(negedge sys_clk0_i); //release reset away from positive edge of the clock
		async_fifo_if.sys_rst_n0	= 1'b1;
		@(negedge sys_clk1_i);
		async_fifo_if.sys_rst_n1    = 1'b1;
    end
    endtask

	task fifo_write (input integer repeat_time);
	begin
		repeat(repeat_time) begin
			@(posedge sys_clk0_i);
			async_fifo_if.wr_en = 1'b1;
			async_fifo_if.rd_en = 1'b0;
			async_fifo_if.wr_data = 16'hffff;			
		end
	end
	endtask

	task fifo_read (input integer repeat_time);
	begin
		repeat(repeat_time) begin
			@(posedge sys_clk1_i);
			@(posedge sys_clk1_i);
			async_fifo_if.wr_en = 1'b0;
			async_fifo_if.rd_en = 1'b1;
			async_fifo_if.wr_data = 'd0;			
		end
	end
	endtask

	task fifo_readAndWrite (input integer repeat_time);
	begin
		repeat(repeat_time) begin
			@(posedge sys_clk0_i);
			async_fifo_if.wr_en = 1'b1;
			async_fifo_if.wr_data = 16'h1111;
			@(posedge sys_clk1_i);
			async_fifo_if.rd_en = 1'b1;			
		end
	end
	endtask

	// testcase1 : continuous write until fifo full and overrun occurs
	task fifo_overrun_test;
		begin
			$display("TESTCASE 1 is running!");
			fifo_write(128);
			fifo_read(128);
			$display("TESTCASE 1 is complete!");
		end
	endtask

	// testcase2 : continuous read until fifo empty and underrun occurs
	task fifo_underrun_test;
		begin
			$display("TESTCASE 2 is running!");
			fifo_read(128);
			fifo_write(128);
			$display("TESTCASE 2 is complete!");
		end
	endtask

	// testcase3 : read and write occur in an interwaving manner
	task fifo_read_write_test;
	begin
		$display("TESTCASE 3 is running!");
		fifo_write(3);
		fifo_read(2);
		fifo_write(3);
		fifo_read(2);
		fifo_write(3);
		fifo_read(2);
		fifo_write(120);
		fifo_read(120);
		fifo_write(3);
		fifo_read(6);		
		$display("TESTCASE 3 is complete!");
	end
	endtask


//================== Run Test Cases ==================
    initial begin
       // $vcdpluson; //set up trace dump for DVE
       // $vcdplusmemon;
        
        initialize_signals();
        reset_dut();

		//fifo_overrun_test();
	    //fifo_underrun_test();
		fifo_read_write_test();
		@(negedge sys_clk0_i)
        $finish;
    end

endmodule
