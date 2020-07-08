VERILOG:=../../verilog

all: jpeg_huffman_encode_tb.vvp

jpeg_huffman_encode_tb.vvp: jpeg_huffman_encode_tb.v $(VERILOG)/jpeg_huffman_encode.v $(VERILOG)/coefficient_encoder.v $(VERILOG)/ice40_ebr.v $(VERILOG)/address_zigzagger.v
	iverilog -I$(VERILOG) -Wall -Wno-sensitivity-entire-array -o $@ $^
