IVERILOG_FLAGS = -g2012-#g2005-sv     # or -g2012

run_sim_processing_system:
	iverilog -o sim.out src/*.v test/tb_processing_system_file.v
	vvp sim.out
	gtkwave wave.vcd

run_sim_tt_project:
	iverilog $(IVERILOG_FLAGS) -o sim.out rc/processing_system.v src/ram.v src/processing_unit.v src/ado.v src/classifier.v test/tb_tt_module.v
	vvp sim.out
	gtkwave wave.vcd

run_sim_tt_processing_system_io:
	iverilog $(IVERILOG_FLAGS) -o sim.out src/processing_system.v src/ram.v src/processing_unit.v src/ado.v src/classifier.v test/tb_processing_system_io.v
	vvp sim.out
	# gtkwave wave.vcd

run_sim_ram:
	iverilog -o sim.out src/ram.v test/tb_ram16.v
	vvp sim.out


