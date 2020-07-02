VERILOG:=../../verilog

all: coefficient_encoder_tb.vvp

coefficient_encoder_tb.vvp: coefficient_encoder_tb.v $(VERILOG)/coefficient_encoder.v
	iverilog -I$(VERILOG) -Wall -o $@ $^
