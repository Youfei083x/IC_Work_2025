// The interface allows verification components to access DUT signals
// using a virtual interface handle
interface init_interface(input bit sys_clk);
  
	logic							sys_rst_n	;
	logic							init_start	;
	logic		[3:0]				init_cmd	;
	logic       [1:0]				init_ba		;
	logic       [12:0]				init_addr	;
	logic							init_end	;

endinterface
