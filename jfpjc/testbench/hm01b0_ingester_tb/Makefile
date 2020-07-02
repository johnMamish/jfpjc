VERILOG:=../../verilog

all: hm01b0_ingester_tb.vvp

hm01b0_ingester_tb.vvp: hm01b0_ingester_tb.v $(VERILOG)/hm01b0_ingester.v $(VERILOG)/hm01b0_sim.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
