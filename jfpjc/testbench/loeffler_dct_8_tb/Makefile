VERILOG:=../../verilog

all: loeffler_dct_8_tb.vvp

loeffler_dct_8_tb.vvp: loeffler_dct_8_tb.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
