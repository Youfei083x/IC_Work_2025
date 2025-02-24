#!/home/fuyufei/EIC_Prj/ENTER/bin/tclsh

call {$fsdbDumpfile("dump.fsdb")}
call {$fsdbDumpvars(0, arbit_tb)}
call {$fsdbDumpMDA()}
run
