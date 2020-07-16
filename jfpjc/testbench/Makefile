MAKE:= make

SUBDIRS:=
SUBDIRS += bitpacker_tb coefficient_encoder_tb hm01b0_ingester_tb jpeg_huffman_encode_tb loeffler_dct_8_tb loeffler_dct_88_tb jfpjc_tb width_adapter_buffer_tb

all: $(SUBDIRS)
$(SUBDIRS):
	$(MAKE) -C $@

.PHONY: all $(SUBDIRS)
