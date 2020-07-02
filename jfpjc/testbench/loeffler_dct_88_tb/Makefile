VERILOG:=../../verilog

all: loeffler_dct_88_tb.vvp

loeffler_dct_88_tb.vvp:  loeffler_dct_88_tb.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v $(VERILOG)/loeffler_dct_88.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
