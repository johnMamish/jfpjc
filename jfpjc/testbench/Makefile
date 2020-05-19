VERILOG=../verilog

# Makefile for CPU with testbench
all: loeffler_dct_8_tb.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o loeffler_dct_8_tb loeffler_dct_8_tb.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v $(VERILOG)/pipelined_multiplier.v
