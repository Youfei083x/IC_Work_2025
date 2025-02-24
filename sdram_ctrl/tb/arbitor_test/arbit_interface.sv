// The interface allows verification components to access DUT signals
// using a virtual interface handle
interface arbit_interface(input bit sys_clk);
  
	logic							sys_rst_n	;
	// init module interconnect
	logic							init_end	;
	logic		[3:0]				init_cmd	;
	logic		[1:0]				init_ba		;
	logic		[12:0]				init_addr	;
	// auto-refresh module interconnect
	logic							aref_req	;
	logic							aref_end	;
	logic		[3:0]				aref_cmd	;
	logic		[1:0]				aref_ba		;
	logic		[12:0]				aref_addr	;
	// write module interconnect	
	logic							wr_req		;
	logic							wr_end		;
	logic		[3:0]				wr_cmd		;
	logic		[1:0]				wr_ba		;
	logic		[12:0]				wr_addr		;
	logic		[15:0]				wr_data		;
	logic							wr_sdram_en	;
	// read module interconnect
	logic							rd_req		;
	logic		[3:0]				rd_cmd		;
	logic       [1:0]				rd_ba		;
	logic       [12:0]				rd_addr		;
	logic							rd_end		;
	// output
	logic							aref_en		;
	logic							wr_en		;
	logic							rd_en		;
	logic							sdram_cke	;
	logic							sdram_cs_n	;
	logic							sdram_cas_n ;
	logic							sdram_ras_n ;
	logic							sdram_we_n  ;
	logic		[1:0]				sdram_ba	;
	logic		[12:0]				sdram_addr	;
	wire		[15:0]				sdram_dq	;	

endinterface
