`timescale 1ns / 1ps
/*========================================FILE_HEADER=====================================
# Author:  Fred Fu(fuyufei083x@163.com)
#
# Critical Timing: 2024-2025 -
#
# date: 2024-11-15 
#
# Filename: wr_packet.sv
#
#
=========================================FILE_HEADER====================================*/

class wr_packet;

	// define transaction items, set up general constraints and display functions
	
	// variables
	rand bit		[23:0]				wr_addr			;	
	rand bit		[9:0]				wr_burst_len	;
	rand shortint						data_packet[]	;
	// constraints
	constraint	burst_length {
		solve wr_burst_len before data_packet;
		data_packet.size == wr_burst_len;
		wr_burst_len inside {[1:16]};
	}

	constraint addr_range {
		wr_addr <= 1024;
		wr_addr >= 16;
	}

	constraint data_value {
		solve wr_burst_len before data_packet;
		foreach (data_packet[i]) {
			data_packet[i] dist { 1 := 20, 3 := 80};
	}
	}

//	function void randomize_array ();
//		if (this.randomize(wr_burst_len)) begin
//			this.randomize(data_packet);
//		end
//	endfunction

	
	// this function allows us to print contents of the data packet
	function void print(string tag = "packet print");
		$display("T=%0t [%s] The packet contains the following contents:\n wr_addr :\t%0d \n wr_burst_length :\t%0d \n data_packet with %0d entries",
						$time, tag, wr_addr, wr_burst_len, wr_burst_len);
	endfunction
endclass

