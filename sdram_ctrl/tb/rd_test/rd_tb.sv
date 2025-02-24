`timescale 1ns / 10ps


module rd_tb();
//============== Instantiate parameters and the interface of the dut ==============
    localparam STOP_AT_ERR = 1; //set to 1 to stop tb at first error
	logic					sys_clk_i;
	// interface
	rd_interface	rd_if(sys_clk_i);
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
	ddr_ctrl_rd    u_ddr_ctrl_rd(
	    .sys_clk(sys_clk_i),
        .sys_rst_n(rd_if.sys_rst_n),
	    .init_end_i(rd_if.init_end),
	    .rd_addr_i(rd_if.addr),
        .rd_en_i(rd_if.rd_en),
	    .rd_data_i(rd_if.data),
		.rd_burst_len_i(rd_if.rd_burst_len),
		.rd_ack_o(rd_if.rd_ack),
		.rd_end_o(rd_if.rd_end),
		.rd_cmd_o(rd_if.rd_cmd),
		.rd_ba_o(rd_if.rd_ba),
		.rd_addr_o(rd_if.rd_addr),
		.rd_sdram_data_o(rd_if.rd_sdram_data)
    );
//================= Testbench Tasks ==================

    task initialize_signals; //set inputs to default values
    begin
        rd_if.init_end = 1'b0;
		rd_if.rd_en = 1'b0;
		rd_if.data = 'd0;
		rd_if.addr = 'd0;
		rd_if.rd_burst_len = 'd0;
		rd_if.sys_rst_n = 1'b0;
    end
    endtask
    
    task reset_dut; //task to properly reset design
    begin
        @(negedge sys_clk_i); //toggle reset away from positive edge of the clock
			rd_if.sys_rst_n	= 1'b0;
        @(negedge sys_clk_i); //hold reset for two cycles
        @(negedge sys_clk_i); //release reset away from positive edge of the clock
			rd_if.sys_rst_n	 = 1'b1;
    end
    endtask

	typedef struct {
		bit		[1:0]	ba;
		bit		[3:0]	cmd;
		bit     [12:0]	addr;
		logic			end_;
	}	rd_type;

	// stimulus task
    task check_out_1round;
    begin
		rd_packet packet; 
		packet = new();
		packet.randomize();
		@(posedge sys_clk_i);
		rd_if.init_end = 1'b1;
		rd_if.rd_en = 1'b1;
		rd_if.addr = packet.rd_addr;
		rd_if.rd_burst_len = packet.rd_burst_len;
		@(posedge sys_clk_i);
		rd_if.rd_en = 1'b0;
		rd_if.addr = 'd0;
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);
		@(posedge sys_clk_i);

		foreach(packet.data_packet[i]) begin
			rd_if.data = packet.data_packet[i];
			@(posedge sys_clk_i);
		end
		rd_if.data = 'd0;
		repeat(10) begin
			@(posedge sys_clk_i);
		end
//		fork begin
//			@(posedge rd_if.rd_end);
//			$display("One time rdite transaction is successfully completed!");
//		end
//		join_none
		$display("rdite Transaction is completed");
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
