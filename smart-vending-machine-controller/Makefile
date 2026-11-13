.PHONY: all sim synth clean

all: sim

sim:
	mkdir -p sim
	iverilog -g2012 -Wall -o sim/sim.out rtl/vending_machine.sv tb/tb_vending_machine.sv
	cd sim && vvp sim.out | tee sim.log

synth:
	yosys -q -s synth/syn.ys
	@cat synth/stat.txt

clean:
	rm -f sim/sim.out sim/dump.vcd
