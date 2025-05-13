IVERILOG_FLAGS = -g2005-sv     # or -g2012

run_sim_processing_system:
	iverilog -o sim.out src/*.v test/tb_processing_system_file.v
	vvp sim.out
	gtkwave wave.vcd

run_sim_tt:
	iverilog $(IVERILOG_FLAGS) -o sim.out src/*.v test/tb_tt_module.v
	vvp sim.out
	gtkwave wave.vcd

run_sim_ram:
	iverilog -o sim.out src/*.v test/tb_ram_wide.v
	vvp sim.out


