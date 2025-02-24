// The interface allows verification components to access DUT signals
// using a virtual interface handle
interface aref_interface(input bit sys_clk);
  
	logic							sys_rst_n	;
	logic							init_end	;
	logic							aref_req	;
	logic		[3:0]				aref_cmd	;
	logic       [1:0]				aref_ba		;
	logic       [12:0]				aref_addr	;
	logic							aref_end	;

endinterface
