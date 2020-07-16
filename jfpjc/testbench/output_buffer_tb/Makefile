VERILOG:=../../verilog

all: output_buffer_tb.vvp

output_buffer_tb.vvp: output_buffer_tb.v $(VERILOG)/output_buffer.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
