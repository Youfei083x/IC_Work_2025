`timescale 1ns / 1ps
/*========================================FILE_HEADER=====================================
# Author:  Fred Fu(fuyufei083x@163.com)
#
# Critical Timing: 2024-2025 -
#
# date: 2024-11-15 
#
# Filename: aref_packet.sv
#
#
=========================================FILE_HEADER====================================*/

class aref_packet;

	// define transaction items, set up general constraints and display functions
	// capture the transaction via interface
	rand bit					init_end;
	rand bit					aref_en;
	// rend bit		[15:0]		data_i;
	
	constraint init_end_flag{
		init_end = 1'b1;
	}

	constraint aref_en_req {
		aref_en = 1'b1;
	}

	// this function allows us to print contents of the data packet
	function void print(string tag = "packet print");
		$display("T=%0t [%s] set init_end as %0d and aref_en as %0d",
						$time, tag, init_end, aref_en);
	endfunction
endclass

