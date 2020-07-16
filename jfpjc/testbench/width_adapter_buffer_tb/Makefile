VERILOG:=../../verilog

all: width_adapter_buffer_tb.vvp

width_adapter_buffer_tb.vvp: width_adapter_buffer_tb.v $(VERILOG)/width_adapter_buffer.v $(VERILOG)/ice40_ebr.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
