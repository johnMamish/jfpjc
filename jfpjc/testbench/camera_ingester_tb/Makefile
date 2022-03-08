VERILOG:=../../verilog

all: camera_ingester_tb.vvp

camera_ingester_tb.vvp: camera_ingester_tb.v $(VERILOG)/camera_ingester.v $(VERILOG)/hm01b0_sim.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o $@ $^

clean: rm camera_ingester_tb.vvp
