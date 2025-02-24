`timescale 1ns / 10ps

module init_tb();
//============== Instantiate parameters and the interface of the dut ==============
    localparam STOP_AT_ERR = 1; //set to 1 to stop tb at first error
	logic					sys_clk_i;
	// interface
	init_interface	init_if(sys_clk_i);
    
	integer file_golden;
	integer file_actual;

//=============== Generate the clock =================
    // params
    localparam CLK_PERIOD = 10;
    localparam DUTY_CYCLE = 0.5;
    //run the clock forever, flipping back and forth between 1 and 0
    initial begin
			sys_clk_i	= 1'b0;
        forever begin
            #(CLK_PERIOD*DUTY_CYCLE) sys_clk_i = 1'b1;
            #(CLK_PERIOD*DUTY_CYCLE) sys_clk_i = 1'b0;
        end
	end
//================= Instantiate DUT ==================
	ddr_ctrl_init    u_ddr_ctrl_init(
	    .sys_clk(sys_clk_i),
        .sys_rst_n(init_if.sys_rst_n),
	    .init_start_i(init_if.init_start),
	    .init_addr_o(init_if.init_addr),
        .init_cmd_o(init_if.init_cmd),
	    .init_ba_o(init_if.init_ba),
		.init_end_o(init_if.init_end)
    );
//================= Testbench Tasks ==================

    task initialize_signals; //set inputs to default values
    begin
        init_if.init_start = 1'b0;
		init_if.sys_rst_n = 1'b0;
    end
    endtask
    
    task reset_dut; //task to properly reset design
    begin
        @(negedge sys_clk_i); //toggle reset away from positive edge of the clock
			init_if.sys_rst_n	= 1'b0;
        @(negedge sys_clk_i); //hold reset for two cycles
        @(negedge sys_clk_i); //release reset away from positive edge of the clock
			init_if.sys_rst_n	 = 1'b1;
    end
    endtask

	task release_dut; // task to properly deassert reset
	begin
		repeat(5) begin
			@(posedge sys_clk_i);
			init_if.sys_rst_n = 1'b0;
		end
		@(negedge sys_clk_i)	init_if.sys_rst_n = 1'b1;
	end
	endtask
	
	typedef struct {
		bit		[1:0]	ba;
		bit		[3:0]	cmd;
		bit     [12:0]	addr;
		logic			init_end;
	}	INIT_type;

	// function model
    function INIT_type init_golden(input logic start, input int cycle_cnt);
		if (start == 1'b1) begin			// init module start 
		    if (cycle_cnt >= 'd391) begin							// end phase
				init_golden.ba = 2'b11;
				init_golden.cmd = 4'b0111;
				init_golden.addr = 13'h1fff;
				init_golden.init_end = 1 'b1;
			end
			else if (cycle_cnt == 'd353) begin							// precharge
				init_golden.ba = 2'b11;
				init_golden.cmd = 4'b0010;
				init_golden.addr = 13'h1fff;
				init_golden.init_end = 1'b0;
			end
			else if (cycle_cnt == 'd358 || cycle_cnt == 'd371) begin    // auto refresh
				init_golden.ba = 2'b11;
				init_golden.cmd = 4'b0001;
				init_golden.addr = 13'h1fff;
				init_golden.init_end = 1'b 0;
			end
			else if (cycle_cnt == 'd384) begin							// lmr mode
				init_golden.ba = 2'b00; 
				init_golden.cmd = 4'b0000;
				init_golden.addr = 13'd55;
				init_golden.init_end = 1'b0;
			end
			else begin
				init_golden.ba = 2'b11; 
				init_golden.cmd = 4'b0111;
				init_golden.addr = 13'h1fff;
				init_golden.init_end = 1 'b0;
			end
		end else begin
				init_golden.ba = 2'b11;  
				init_golden.cmd = 4'b0111;
				init_golden.addr = 13'h1fff;
				init_golden.init_end = 1'b0;
		end		        
    endfunction
	
	// stimulus task
    task check_out_1round;
    begin
        INIT_type init_out;
		int		cycle_cnt = 'd0;
		int		start	  = 1'b0;
		file_golden = $fopen("./golden_output.txt", "w");
		file_actual = $fopen("./actual_output.txt", "w");
		
		if (file_golden == 0) begin
			$display("The target file_golden is no found!");
			$finish;
		end
		
		if (file_actual == 0) begin
			$display("The target file_actual is no found!");
			$finish;
		end
		
		for (int i = 0; i <= 400; i = i + 1) begin
			init_if.init_start = start;
			@(posedge sys_clk_i)	start = 1'b1;
			cycle_cnt ++;
			init_out = init_golden(start, cycle_cnt);

			// print out golden model's output as a reference
			$fwrite(file_golden, "Cycle# %d : %0d,	%0d,	%0d,	%0d\n", cycle_cnt, init_out.ba, init_out.cmd, init_out.addr, init_out.init_end);
			$fwrite(file_actual, "Cycle# %d : %0d,	%0d,	%0d,	%0d\n", cycle_cnt, init_if.init_ba, init_if.init_cmd, init_if.init_addr, init_if.init_end);
			
			#(0.1 * CLK_PERIOD); //don't check value right at positive edge wait 0.1*CLK_PERIOD
			if(init_if.init_ba == init_out.ba) ; else
			 	begin 
					$error("CYCLE# %d FAILED, BA Expected %d Actual %d", cycle_cnt, init_out.ba, init_if.init_ba);
				if(STOP_AT_ERR) begin //stop tb at first error if STOP_AT_ERR set to 1
					repeat(3) //add some cycles to end of trace to make it easier to read
						@(posedge sys_clk_i); 
					$finish;
				end
			end
			if(init_if.init_cmd == init_out.cmd) ; else	
				begin  
			 		$error("CYCLE# %d FAILED, CMD Expected %d Actual %d", cycle_cnt, init_out.cmd, init_if.init_cmd);
				if(STOP_AT_ERR) begin //stop tb at first error if STOP_AT_ERR set to 1
					repeat(3) //add some cycles to end of trace to make it easier to read
						@(posedge sys_clk_i); 
					$finish;
				end
			end
			if(init_if.init_addr == init_out.addr) ; else
				begin  
					$error("CYCLE# %d FAILED,ADDR Expected %d Actual %d", cycle_cnt, init_out.addr, init_if.init_addr);
				if(STOP_AT_ERR) begin //stop tb at first error if STOP_AT_ERR set to 1
					repeat(3) //add some cycles to end of trace to make it easier to read
						@(posedge sys_clk_i); 
					$finish;
				end
			end
			if(init_if.init_end == init_out.init_end) ; else
				begin  
					$error("CYCLE# %d FAILED, END Expected %d Actual %d", cycle_cnt, init_out.init_end, init_if.init_end);
				if(STOP_AT_ERR) begin //stop tb at first error if STOP_AT_ERR set to 1
					repeat(3) //add some cycles to end of trace to make it easier to read
						@(posedge sys_clk_i); 
					$finish;
				end
			end
			end
			$fclose(file_actual);
			$fclose(file_golden);
			$display("output of golden model is collected successfully!");
		end
	endtask



//================== Run Test Cases ==================
    initial begin
       // $vcdpluson; //set up trace dump for DVE
       // $vcdplusmemon;
        
        initialize_signals();
        reset_dut();

		check_out_1round();
		@(negedge sys_clk_i)
        $finish;
    end

endmodule
