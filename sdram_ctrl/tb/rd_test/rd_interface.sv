// The interface allows verification components to access DUT signals
// using a virtual interface handle
interface rd_interface(input bit sys_clk);
  
	logic							sys_rst_n	;
	logic							init_end	;
	logic							rd_en		;
	logic		[23:0]				addr		;
	logic		[15:0]				data		;
	logic		[9:0]				rd_burst_len;
	logic							rd_ack		;
	logic		[3:0]				rd_cmd		;
	logic       [1:0]				rd_ba		;
	logic       [12:0]				rd_addr		;
	logic							rd_end		;
	logic       [15:0]				rd_sdram_data;

endinterface
