VERILOG:=../../verilog
C_FILES:=../c_common

all: jfpjc_tb.vvp

VERILOG_FILES:=
VERILOG_FILES+= jfpjc_tb.v
VERILOG_FILES+= $(VERILOG)/hm01b0_ingester.v
VERILOG_FILES+= $(VERILOG)/loeffler_dct_88.v
VERILOG_FILES+= $(VERILOG)/loeffler_dct_8.v
VERILOG_FILES+= $(VERILOG)/pipelined_multiplier.v
VERILOG_FILES+= $(VERILOG)/coefficient_encoder.v
VERILOG_FILES+= $(VERILOG)/jpeg_huffman_encode.v
VERILOG_FILES+= $(VERILOG)/hm01b0_sim.v
VERILOG_FILES+= $(VERILOG)/ice40_ebr.v
VERILOG_FILES+= $(VERILOG)/jfpjc.v
VERILOG_FILES+= $(VERILOG)/pipelined_divider.v
VERILOG_FILES+= $(VERILOG)/address_zigzagger.v

C_SOURCES:=
C_SOURCES+= $(C_FILES)/vpi_jpeg_utils.c
C_SOURCES+= $(C_FILES)/dct_utils.c

jfpjc_tb.vvp: $(VERILOG_FILES) $(C_SOURCES)
	iverilog-vpi $(C_FILES)/vpi_jpeg_utils.c $(C_FILES)/dct_utils.c
	iverilog -I$(VERILOG) -Wall -o $@ $(filter %.v,$^)
