VERILOG=../verilog

all: loeffler_dct_8_tb loeffler_dct_88_tb coefficient_encoder_tb bitpacker_tb

loeffler_dct_8_tb: loeffler_dct_8_tb.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o $@ $^

loeffler_dct_88_tb:  loeffler_dct_88_tb.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/ice40_ebr.v $(VERILOG)/loeffler_dct_88.v
	iverilog -I$(VERILOG) -Wall -o $@ $^

coefficient_encoder_tb: coefficient_encoder_tb.v $(VERILOG)/coefficient_encoder.v
	iverilog -I$(VERILOG) -Wall -o $@ $^

bitpacker_tb: bitpacker_tb.v $(VERILOG)/bitpacker.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
