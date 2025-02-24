`timescale 1ns / 10ps


module wr_tb();
//============== Instantiate parameters and the interface of the dut ==============
    localparam STOP_AT_ERR = 1; //set to 1 to stop tb at first error
	logic					sys_clk_i;
	// interface
	wr_interface	wr_if(sys_clk_i);
//	integer file_golden;
//	integer file_actual;

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
	ddr_ctrl_wr    u_ddr_ctrl_wr(
	    .sys_clk(sys_clk_i),
        .sys_rst_n(wr_if.sys_rst_n),
	    .init_end_i(wr_if.init_end),
	    .wr_addr_i(wr_if.addr),
        .wr_en_i(wr_if.wr_en),
	    .wr_data_i(wr_if.data),
		.wr_burst_len_i(wr_if.wr_burst_len),
		.wr_ack_o(wr_if.wr_ack),
		.wr_end_o(wr_if.wr_end),
		.wr_cmd_o(wr_if.wr_cmd),
		.wr_ba_o(wr_if.wr_ba),
		.wr_addr_o(wr_if.wr_addr),
		.wr_sdram_en_o(wr_if.wr_sdram_en),
		.wr_sdram_data_o(wr_if.wr_sdram_data)
    );
//================= Testbench Tasks ==================

    task initialize_signals; //set inputs to default values
    begin
        wr_if.init_end = 1'b0;
		wr_if.wr_en = 1'b0;
		wr_if.data = 'd0;
		wr_if.addr = 'd0;
		wr_if.wr_burst_len = 'd0;
		wr_if.sys_rst_n = 1'b0;
    end
    endtask
    
    task reset_dut; //task to properly reset design
    begin
        @(negedge sys_clk_i); //toggle reset away from positive edge of the clock
			wr_if.sys_rst_n	= 1'b0;
        @(negedge sys_clk_i); //hold reset for two cycles
        @(negedge sys_clk_i); //release reset away from positive edge of the clock
			wr_if.sys_rst_n	 = 1'b1;
    end
    endtask

	typedef struct {
		bit		[1:0]	ba;
		bit		[3:0]	cmd;
		bit     [12:0]	addr;
		logic			end_;
	}	WR_type;

	// stimulus task
    task check_out_1round;
    begin
		wr_packet packet; 
		packet = new();
		packet.randomize();
		@(posedge sys_clk_i);
		wr_if.init_end = 1'b1;
		wr_if.wr_en = 1'b1;
		wr_if.addr = packet.wr_addr;
		wr_if.wr_burst_len = packet.wr_burst_len;
		@(posedge sys_clk_i);
		wr_if.wr_en = 1'b0;
		wr_if.addr = 'd0;
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);

		foreach(packet.data_packet[i]) begin
			wr_if.data = packet.data_packet[i];
			@(posedge sys_clk_i);
		end
		wr_if.data = 'd0;
		repeat(10) begin
			@(posedge sys_clk_i);
		end
//		fork begin
//			@(posedge wr_if.wr_end);
//			$display("One time write transaction is successfully completed!");
//		end
//		join_none
		$display("Write Transaction is completed");
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
