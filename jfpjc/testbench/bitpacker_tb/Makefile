VERILOG:=../../verilog

all: bitpacker_tb.vvp

bitpacker_tb.vvp: bitpacker_tb.v $(VERILOG)/bitpacker.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
