VERILOG:= ../../verilog

all: bytestuffer_tb.vvp

bytestuffer_tb.vvp: bytestuffer_tb.v $(VERILOG)/bytestuffer.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
