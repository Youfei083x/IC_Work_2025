#!/home/fuyufei/EIC_Prj/ENTER/bin/tclsh

call {$fsdbDumpfile("dump.fsdb")}
call {$fsdbDumpvars(0, async_fifo_tb, "+all")}
call {$fsdbDumpMDA()}
run
