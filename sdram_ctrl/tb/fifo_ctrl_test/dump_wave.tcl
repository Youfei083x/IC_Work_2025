#!/home/fuyufei/EIC_Prj/ENTER/bin/tclsh

call {$fsdbDumpfile("dump.fsdb")}
call {$fsdbDumpvars(0, fifo_ctrl_tb, "+all")}
call {$fsdbDumpMDA()}
run
