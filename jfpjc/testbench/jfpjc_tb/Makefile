VERILOG:=../../verilog
C_FILES:=../c_common

all: jfpjc_tb.vvp

jfpjc_tb.vvp: jfpjc_tb.v $(VERILOG)/hm01b0_ingester.v $(VERILOG)/loeffler_dct_88.v $(VERILOG)/loeffler_dct_8.v $(VERILOG)/pipelined_multiplier.v $(VERILOG)/coefficient_encoder.v $(VERILOG)/jpeg_huffman_encode.v $(VERILOG)/hm01b0_sim.v $(VERILOG)/ice40_ebr.v $(VERILOG)/jfpjc.v $(C_FILES)/vpi_jpeg_utils.c $(C_FILES)/dct_utils.c
	iverilog-vpi $(C_FILES)/vpi_jpeg_utils.c $(C_FILES)/dct_utils.c
	iverilog -I$(VERILOG) -Wall -o $@ $(filter %.v,$^)
