// The interface allows verification components to access DUT signals
// using a virtual interface handle
interface wr_interface(input bit sys_clk);
  
	logic							sys_rst_n	;
	logic							init_end	;
	logic							wr_en		;
	logic		[23:0]				addr		;
	logic		[15:0]				data		;
	logic		[9:0]				wr_burst_len;
	logic							wr_ack		;
	logic		[3:0]				wr_cmd		;
	logic       [1:0]				wr_ba		;
	logic       [12:0]				wr_addr		;
	logic							wr_end		;
	logic							wr_sdram_en	;
	logic       [15:0]				wr_sdram_data;

endinterface
