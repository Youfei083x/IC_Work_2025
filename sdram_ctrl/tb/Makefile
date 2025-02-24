####################################### vcs+verdi simulation ########################################

### Directories
SIM_DIR 	:= 	${PWD}
RUN_DIR 	:=  ${PWD}/sim

### Simulation and Compile tools
VCS  		:=  vcs
VERDI 		:=  verdi

### Testcase
#TESTCASE 	:=  arbitor_test
#TESTCASE    :=  init_test
#TESTCASE    :=  aref_test
#TESTCASE    :=  wr_test
#TESTCASE    :=  rd_test
#TESTCASE    :=  fifo_test
#TESTCASE    :=  fifo_ctrl_test
#TESTCASE    :=  top_sys_test
#TESTCASE     := async_fifo_test
TESTCASE     :=  fifo_ctrl_test

### Simulation files
FILE_LIST 	:=  ${RUN_DIR}/file.list
TCL_DUMP 	:=  ${RUN_DIR}/dump_wave.tcl
FILE_TB     :=  $(wildcard  ${RUN_DIR}/*.sv   ${RUN_DIR}/*.v )
MODULE_NAME	:=  sys_fifo_ctrl

### Compilation details

VCS_OBJ  	:= ${SIM_DIR}/simv*

### Tool options
VCS_OPTIONS1 	:= -full64 +v2k +notice +lint=all -debug_access -debug_acc+pp+dmptf 
VCS_OPTIONS1    += +plusarg_save +libext+.v+.V+.sv+.svh 
VCS_OPTIONS1	+= -P ${Verdi_HOME}/share/PLI/VCS/LINUX64/novas.tab
VCS_OPTIONS1    += ${Verdi_HOME}/share/PLI/VCS/LINUX64/pli.a 
VCS_OPTIONS1    += -debug_region+cell+encrypt -j8
VCS_OPTIONS1    += -sverilog -timescale=1ns/10ps
VCS_OPTIONS1    += -cpp /usr/bin/g++ -cc /usr/bin/gcc
			  
VCS_OPTIONS2  	:= -l compile.log -LDFLAGS -Wl,--no-as-needed 

# if you wanna generate vpd file for dve: +vpdfile+./simulation.vpd

VERDI_OPTIONS 	:=  -nologo &

##################################### EXPLANATION ################################################
#-full64 is the version 64 for the output executable file
# -notice will make vcs show information
# +v2k means it should support verilog-2001 +lint=all means do lint check while run cimpilation
# (important!!!) if you wanna run the ./simv -ucli -i dumpfile -l sim.log automatically, use -R
# ln -sf file is just for link the target file instead of running anything
# -debug_access activate debug mode, pp dmptf region includes cell and lib and encrypt
# +plusarg_save it will save the arguments defined in the file.list and macros.list
# +libext+.v+.V+.sv+.svh is to make compiler understand these file extensions
# -P Verdi ... only use these can run ./simv and call fsdbDumpfile and fsdbDumpvars
#-j8 is an optimiztion option 8 lines
#-sverilog is another necessary option
#-P and verdi path is necessary or it will get error: no verdi path
#-cpp -cc should be changed to a version that ubuntu has
#-l sets the logbook name and last two are a optimization(recommended)

install: 
	mkdir -p ${SIM_DIR}/sim
	cp -rf ${SIM_DIR}/${TESTCASE}/* ${RUN_DIR}
	cp -rf ${SIM_DIR}/../rtl/${MODULE_NAME}.v ${RUN_DIR}
	@echo "install is completed"

.PHONY: vcs verdi clean vcs_compile vcs_sim install

dafault: all

all: vcs verdi

vcs: vcs_compile vcs_sim

vcs_compile:
	$(VCS) $(VCS_OPTIONS1) -file $(FILE_LIST) $(FILE_TB) $(VCS_OPTIONS2)

vcs_sim:
	$(VCS_OBJ) -ucli -i $(TCL_DUMP) -l sim.log -o ${SIM_DIR}/sim_exe

dve:
	dve -full64 -cov -dir simv.vdb&

verdi:
	$(VERDI) -ssf dump.fsdb $(VERDI_OPTIONS)

clean:
	rm -rf ./dump*
	rm -rf ./simv ./simv.daidir
	rm -f vc_hdrs.h
	rm -rf *.log
	rm -rf ucli.key
	rm -rf csrc
	rm -rf novas*
	rm -rf *Log

clean_sim:
	rm -rf ./sim

update: 
	cp -rf ${RUN_DIR}/${MODULE_NAME}.v ./../rtl/${MODULE_NAME}.v
	rm -rf ./${TESTCASE}/*
	cp -rf ${RUN_DIR}/* ./${TESTCASE}


test:
	#this is a test
