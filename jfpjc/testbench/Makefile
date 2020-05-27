VERILOG=../verilog

all: 1d_dct_test 2d_dct_test coefficient_encoder

# Makefile for CPU with testbench
1d_dct_test: loeffler_dct_8_tb.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o loeffler_dct_8_tb loeffler_dct_8_tb.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v $(VERILOG)/pipelined_multiplier.v

2d_dct_test:  loeffler_dct_88_tb.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v $(VERILOG)/loeffler_dct_88.v
	iverilog -I$(VERILOG) -Wall -o loeffler_dct_88_tb loeffler_dct_88_tb.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_88.v

coefficient_encoder:
	iverilog -I$(VERILOG) -Wall -o coefficient_encoder_tb coefficient_encoder_tb.v $(VERILOG)/coefficient_encoder.v
