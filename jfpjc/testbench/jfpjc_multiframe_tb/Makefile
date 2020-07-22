VERILOG:=../../verilog
C_FILES:=../c_common

all: jfpjc_multiframe_tb.vvp

VERILOG_FILES:=
VERILOG_FILES+= jfpjc_multiframe_tb.v
VERILOG_FILES+= $(VERILOG)/bitpacker.v
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
VERILOG_FILES+= $(VERILOG)/width_adapter_buffer.v
VERILOG_FILES+= $(VERILOG)/bytestuffer.v
VERILOG_FILES+= $(VERILOG)/dct_reset_manager.v
VERILOG_FILES+= $(VERILOG)/quantizer_manager_fsm.v

C_SOURCES:=
C_SOURCES+= $(C_FILES)/vpi_jpeg_utils.c
C_SOURCES+= $(C_FILES)/dct_utils.c

# -Wno-sensitivity-entire-array prevents us from generating warnings when we dereference a large
# array inside of an always @* block.
#     e.g. warning: @* is sensitive to all 4 words in array 'index'
# I'd expect this to still synthesize exactly what I intend, but according to a forum post I dug
# up on google, it might result in slower simulation.
#     https://sourceforge.net/p/iverilog/mailman/message/35079608/
VERILOG_WARNING_FLAGS:=
VERILOG_WARNING_FLAGS+= -Wall -Wno-sensitivity-entire-array

jfpjc_multiframe_tb.vvp: $(VERILOG_FILES) $(C_SOURCES)
	iverilog-vpi $(C_FILES)/vpi_jpeg_utils.c $(C_FILES)/dct_utils.c
	iverilog -I$(VERILOG) $(VERILOG_WARNING_FLAGS) -o $@ $(filter %.v,$^)
