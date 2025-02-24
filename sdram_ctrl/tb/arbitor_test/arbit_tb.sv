`timescale 1ns / 10ps


module arbit_tb();
//============== Instantiate parameters and the interface of the dut ==============
    localparam STOP_AT_ERR = 1; //set to 1 to stop tb at first error
	logic					sys_clk_i;
	// interface
	arbit_interface	arbit_interface(sys_clk_i);
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
	ddr_ctrl_arbit    u_ddr_ctrl_arbit(
		.sys_clk(sys_clk_i),
		.sys_rst_n(arbit_interface.sys_rst_n),
		.init_end_i(arbit_interface.init_end),
		.init_cmd_i(arbit_interface.init_cmd),
		.init_ba_i(arbit_interface.init_ba),
		.init_addr_i(arbit_interface.init_addr),
		.aref_req_i(arbit_interface.aref_req),
		.aref_end_i(arbit_interface.aref_end),
		.aref_cmd_i(arbit_interface.aref_cmd),
		.aref_ba_i(arbit_interface.aref_ba),
		.aref_addr_i(arbit_interface.aref_addr),
		.wr_req_i(arbit_interface.wr_req),
		.wr_end_i(arbit_interface.wr_end),
		.wr_cmd_i(arbit_interface.wr_cmd),
		.wr_ba_i(arbit_interface.wr_ba),
		.wr_addr_i(arbit_interface.wr_addr),
		.wr_data_i(arbit_interface.wr_data),
		.wr_sdram_en_i(arbit_interface.wr_sdram_en),
		.rd_req_i(arbit_interface.rd_req),
		.rd_end_i(arbit_interface.rd_end),
		.rd_cmd_i(arbit_interface.rd_cmd),
		.rd_ba_i(arbit_interface.rd_ba),
		.rd_addr_i(arbit_interface.rd_addr),
		.aref_en_o(arbit_interface.aref_en),
		.wr_en_o(arbit_interface.wr_en),
		.rd_en_o(arbit_interface.rd_en),
		.sdram_cke_o(arbit_interface.sdram_cke),
		.sdram_cs_n_o(arbit_interface.sdram_cs_n),
		.sdram_cas_n_o(arbit_interface.sdram_cas_n),
		.sdram_ras_n_o(arbit_interface.sdram_ras_n),
		.sdram_we_n_o(arbit_interface.sdram_we_n),
		.sdram_ba_o(arbit_interface.sdram_ba),
		.sdram_addr_o(arbit_interface.sdram_addr),
		.sdram_dq_o(arbit_interface.sdram_dq)
    );
//================= Testbench Tasks ==================

    task initialize_signals; //set inputs to default values
    begin
        arbit_interface.init_end = 1'b0;
		arbit_interface.init_cmd = 4'b0111;
		arbit_interface.init_ba = 2'b11;
		arbit_interface.init_addr = 13'h1fff;
		arbit_interface.aref_req = 1'b0;
		arbit_interface.aref_end = 1'b0;
		arbit_interface.aref_cmd = 4'b0111;
		arbit_interface.aref_ba = 2'b11;
		arbit_interface.aref_addr = 13'h1fff;
		arbit_interface.rd_req = 1'b0;
		arbit_interface.rd_end = 1'b0;
		arbit_interface.rd_cmd = 4'b0111;
		arbit_interface.rd_ba = 2'b11;
		arbit_interface.rd_addr = 13'h1fff;
		arbit_interface.wr_req = 1'b0;
		arbit_interface.wr_end = 1'b0;
		arbit_interface.wr_cmd = 4'b0111;
		arbit_interface.wr_ba = 2'b11;
		arbit_interface.wr_addr = 13'h1fff;
		arbit_interface.wr_data = 'd0;
		arbit_interface.wr_sdram_en = 1'b0;
    end
    endtask
    
    task reset_dut; //task to properly reset design
    begin
        @(negedge sys_clk_i); //toggle reset away from positive edge of the clock
			arbit_interface.sys_rst_n	= 1'b0;
        @(negedge sys_clk_i); //hold reset for two cycles
        @(negedge sys_clk_i); //release reset away from positive edge of the clock
			arbit_interface.sys_rst_n	 = 1'b1;
    end
    endtask

	task init_start;	// start init stimulus
	begin
		arbit_interface.init_end = 1'b0;
		arbit_interface.init_cmd = 4'b0111;
		arbit_interface.init_ba = 2'b11;
		arbit_interface.init_addr = 13'h1fff;
		repeat(40) begin
			@(posedge sys_clk_i);
		end
	end
	endtask
	
	task init_complete;	// complete init stimulus
	begin
		arbit_interface.init_end = 1'b1;
		arbit_interface.init_cmd = 4'b0111;
		arbit_interface.init_ba = 2'b11;
		arbit_interface.init_addr = 13'h1fff;
		repeat(2) begin
			@(posedge sys_clk_i);
		end
	end
	endtask
	
	task arbit_rd;  // start read operation
	begin
		arbit_interface.rd_req = 1'b1;
		arbit_interface.rd_end = 1'b0;
		arbit_interface.rd_cmd = 4'b0101;
		arbit_interface.rd_addr = 13'h11ff;
		arbit_interface.rd_ba = 2'b01;
		@(posedge sys_clk_i);
		arbit_interface.rd_req = 1'b0;
		repeat(40) begin
		@(posedge sys_clk_i);
		end
	end
	endtask

	task arbit_rdComplete;  // complete read operation
	begin
		arbit_interface.rd_req = 1'b0;
		arbit_interface.rd_end = 1'b1;
		arbit_interface.rd_cmd = 4'b0111;
		arbit_interface.rd_addr = 13'h1fff;
		arbit_interface.rd_ba = 2'b11;
		@(posedge sys_clk_i);
		arbit_interface.rd_end = 1'b0;
		repeat(40) begin
		@(posedge sys_clk_i);
		end
	end
	endtask
	
	task arbit_wr;  // start write operation
	begin
		arbit_interface.wr_req = 1'b1;
		arbit_interface.wr_end = 1'b0;
		arbit_interface.wr_cmd = 4'b0100;
		arbit_interface.wr_addr = 13'h111f;
		arbit_interface.wr_ba = 2'b10;
		arbit_interface.wr_sdram_en = 1'b1;
		arbit_interface.wr_data = 16'd1024;
		@(posedge sys_clk_i);
		arbit_interface.wr_req = 1'b0;
		repeat(20) begin
		@(posedge sys_clk_i);
		end
	end
	endtask

	task arbit_wrComplete; // complete write operation
	begin
		arbit_interface.wr_req = 1'b0;
		arbit_interface.wr_end = 1'b1;
		arbit_interface.wr_cmd = 4'b0111;
		arbit_interface.wr_addr = 13'h1fff;
		arbit_interface.wr_ba = 2'b11;
		arbit_interface.wr_sdram_en = 1'b0;
		arbit_interface.wr_data = 16'd0;
		@(posedge sys_clk_i);
		arbit_interface.wr_end = 1'b0;
		repeat(40) begin
		@(posedge sys_clk_i);
		end
	end
	endtask
	
	task arbit_aref; // start auto refresh operation
	begin
		arbit_interface.aref_req = 1'b1;
		arbit_interface.aref_end = 1'b0;
		arbit_interface.aref_cmd = 4'b0110;
		arbit_interface.aref_addr = 13'h1111;
		arbit_interface.aref_ba = 2'b00;
		@(posedge sys_clk_i);
		arbit_interface.aref_req = 1'b0;
		repeat(40) begin
		@(posedge sys_clk_i);
		end
	end
	endtask

	task arbit_arefComplete;  // complete auto refresh operation
	begin
		arbit_interface.aref_req = 1'b0;
		arbit_interface.aref_end = 1'b1;
		arbit_interface.aref_cmd = 4'b0111;
		arbit_interface.aref_addr = 13'h1fff;
		arbit_interface.aref_ba = 2'b11;
		@(posedge sys_clk_i);
		arbit_interface.aref_end = 1'b0;
		repeat(40) begin
		@(posedge sys_clk_i);
		end
	end
	endtask


	// stimulus task
    task check_out_init;
    begin
		// check signal response before init complete
		init_start();
		arbit_rd();
		arbit_rdComplete();
		arbit_wr();
		arbit_wrComplete();
		arbit_aref();
		arbit_arefComplete();
		init_complete();

		//	
		@(posedge sys_clk_i);
		$display("init check is completed");
	end
	endtask

	task check_out_commandNoComplete;
	begin
		init_start();
		init_complete();
		// check signal response when command is not complete
		arbit_rd();

		arbit_wr();
		arbit_wrComplete();
		arbit_aref();
		arbit_arefComplete();
		// 
		@(posedge sys_clk_i);
		$display("command blocking check is complete");
		end
	endtask
	
	task check_random_rd_wr_aref;
	begin
		init_start();
		init_complete();
		// check the common order of the arbitor
		arbit_rd();
		arbit_rdComplete();
		arbit_wr();
		arbit_wrComplete();
		arbit_aref();
		arbit_arefComplete();
		arbit_rd();
		arbit_rdComplete();
		arbit_wr();
		arbit_wrComplete();
		//
		@(posedge sys_clk_i);
		$display("command check is complete");
	end
endtask


//================== Run Test Cases ==================
    initial begin
       // $vcdpluson; //set up trace dump for DVE
       // $vcdplusmemon;
        
        initialize_signals();
        reset_dut();

		check_random_rd_wr_aref();
		@(negedge sys_clk_i)
        $finish;
    end

endmodule
