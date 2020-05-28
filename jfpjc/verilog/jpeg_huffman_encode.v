
/**
 * ultimately, I plan to put these values in 2 EBRs. Unfortunately, because we need 4 + 16 = 20 bit
 * wide data and our EBRs are all 1, 2, 4, 8, or 16 bits wide, a lot of one EBR will be wasted.
 *
 * I suppose that, if we wanted to be able to select from 4 different tables, we could use 5EBRs,
 * where 4 of the EBRs hold huffman code values and 1 holds lengths for the 4 different tables. meh.
 *
 * This test huffman table mimics the EBRs in the sense that it takes one clock cycle to read.
 *
 * These are ac and dc luminance tables taken from jmcujc.c. I used gdb to halt the program after
 * huffman reverse lookup tables were constructed and then used a bit of low-grade gdb-fu to
 * generate the verilog found below. Note that the stored huffman_bitlen is one less than the
 * actual bitlen, this is to avoid storing an unnecessary bit; we will never have a huffman code
 * of length 0.
 *
 * The following lines can be used in GDB to harvest the data from the huffman reverse lookup
 * tables. Some lines with invalid huffman codes will need to be picked out, you can tell which
 * ones those are because the bit_length - 1 will cause the uint32_t to roll over to ffffffff.
 *
 * (gdb) set $loop = 0
 * (gdb) while $loop < 256
 * (gdb) printf "8'h%02x: huffman_code <= 16'h%04x; huffman_bitlen <= 4'h%x; huffman_valid <= 1'b1\n",$loop,params->dc_hrlts[0].entries[$loop].value,params->dc_hrlts[0].entries[$loop].bit_length-1
 * (gdb) set $loop = $loop + 1
 * (gdb) end
 */
module test_huffman_table_dc(input clock,
                             input [7:0] addr,

                             output reg [15:0] huffman_code,
                             output reg  [3:0] huffman_bitlen,

                             // this one is just here for debugging purposes... we should remove it
                             // for deployed hardware. Anyways, we could have
                             // huffman code = 0x0000 and bitlen = 15 be our code for "this one's bad".
                             output reg  [0:0] huffman_valid);

    always @(posedge clock) begin
        case(addr)
            8'h00: huffman_code <= 16'h0000; huffman_bitlen <= 4'h1; huffman_valid <= 1'b1;
            8'h01: huffman_code <= 16'h0002; huffman_bitlen <= 4'h2; huffman_valid <= 1'b1;
            8'h02: huffman_code <= 16'h0003; huffman_bitlen <= 4'h2; huffman_valid <= 1'b1;
            8'h03: huffman_code <= 16'h0004; huffman_bitlen <= 4'h2; huffman_valid <= 1'b1;
            8'h04: huffman_code <= 16'h0005; huffman_bitlen <= 4'h2; huffman_valid <= 1'b1;
            8'h05: huffman_code <= 16'h0006; huffman_bitlen <= 4'h2; huffman_valid <= 1'b1;
            8'h06: huffman_code <= 16'h000e; huffman_bitlen <= 4'h3; huffman_valid <= 1'b1;
            8'h07: huffman_code <= 16'h001e; huffman_bitlen <= 4'h4; huffman_valid <= 1'b1;
            8'h08: huffman_code <= 16'h003e; huffman_bitlen <= 4'h5; huffman_valid <= 1'b1;
            8'h09: huffman_code <= 16'h007e; huffman_bitlen <= 4'h6; huffman_valid <= 1'b1;
            8'h0a: huffman_code <= 16'h00fe; huffman_bitlen <= 4'h7; huffman_valid <= 1'b1;
            8'h0b: huffman_code <= 16'h01fe; huffman_bitlen <= 4'h8; huffman_valid <= 1'b1;
            default: huffman_code <= 16'h0000; huffman_bitlen <= 4'hf; huffman_valid <= 1'b0;
        endcase
    end
endmodule // test_huffman_table_dc

module test_huffman_table_ac(input clock,
                             input [7:0] addr,

                             );

    always @(posedge clock) begin
        case(addr)
            8'h00: huffman_code <= 16'h000a; huffman_bitlen <= 4'h3; huffman_valid <= 1'b1;
            8'h01: huffman_code <= 16'h0000; huffman_bitlen <= 4'h1; huffman_valid <= 1'b1;
            8'h02: huffman_code <= 16'h0001; huffman_bitlen <= 4'h1; huffman_valid <= 1'b1;
            8'h03: huffman_code <= 16'h0004; huffman_bitlen <= 4'h2; huffman_valid <= 1'b1;
            8'h04: huffman_code <= 16'h000b; huffman_bitlen <= 4'h3; huffman_valid <= 1'b1;
            8'h05: huffman_code <= 16'h001a; huffman_bitlen <= 4'h4; huffman_valid <= 1'b1;
            8'h06: huffman_code <= 16'h0078; huffman_bitlen <= 4'h6; huffman_valid <= 1'b1;
            8'h07: huffman_code <= 16'h00f8; huffman_bitlen <= 4'h7; huffman_valid <= 1'b1;
            8'h08: huffman_code <= 16'h03f6; huffman_bitlen <= 4'h9; huffman_valid <= 1'b1;
            8'h09: huffman_code <= 16'hff82; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h0a: huffman_code <= 16'hff83; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h11: huffman_code <= 16'h000c; huffman_bitlen <= 4'h3; huffman_valid <= 1'b1;
            8'h12: huffman_code <= 16'h001b; huffman_bitlen <= 4'h4; huffman_valid <= 1'b1;
            8'h13: huffman_code <= 16'h0079; huffman_bitlen <= 4'h6; huffman_valid <= 1'b1;
            8'h14: huffman_code <= 16'h01f6; huffman_bitlen <= 4'h8; huffman_valid <= 1'b1;
            8'h15: huffman_code <= 16'h07f6; huffman_bitlen <= 4'ha; huffman_valid <= 1'b1;
            8'h16: huffman_code <= 16'hff84; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h17: huffman_code <= 16'hff85; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h18: huffman_code <= 16'hff86; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h19: huffman_code <= 16'hff87; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h1a: huffman_code <= 16'hff88; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h21: huffman_code <= 16'h001c; huffman_bitlen <= 4'h4; huffman_valid <= 1'b1;
            8'h22: huffman_code <= 16'h00f9; huffman_bitlen <= 4'h7; huffman_valid <= 1'b1;
            8'h23: huffman_code <= 16'h03f7; huffman_bitlen <= 4'h9; huffman_valid <= 1'b1;
            8'h24: huffman_code <= 16'h0ff4; huffman_bitlen <= 4'hb; huffman_valid <= 1'b1;
            8'h25: huffman_code <= 16'hff89; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h26: huffman_code <= 16'hff8a; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h27: huffman_code <= 16'hff8b; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h28: huffman_code <= 16'hff8c; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h29: huffman_code <= 16'hff8d; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h2a: huffman_code <= 16'hff8e; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h31: huffman_code <= 16'h003a; huffman_bitlen <= 4'h5; huffman_valid <= 1'b1;
            8'h32: huffman_code <= 16'h01f7; huffman_bitlen <= 4'h8; huffman_valid <= 1'b1;
            8'h33: huffman_code <= 16'h0ff5; huffman_bitlen <= 4'hb; huffman_valid <= 1'b1;
            8'h34: huffman_code <= 16'hff8f; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h35: huffman_code <= 16'hff90; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h36: huffman_code <= 16'hff91; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h37: huffman_code <= 16'hff92; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h38: huffman_code <= 16'hff93; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h39: huffman_code <= 16'hff94; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h3a: huffman_code <= 16'hff95; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h41: huffman_code <= 16'h003b; huffman_bitlen <= 4'h5; huffman_valid <= 1'b1;
            8'h42: huffman_code <= 16'h03f8; huffman_bitlen <= 4'h9; huffman_valid <= 1'b1;
            8'h43: huffman_code <= 16'hff96; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h44: huffman_code <= 16'hff97; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h45: huffman_code <= 16'hff98; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h46: huffman_code <= 16'hff99; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h47: huffman_code <= 16'hff9a; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h48: huffman_code <= 16'hff9b; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h49: huffman_code <= 16'hff9c; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h4a: huffman_code <= 16'hff9d; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h51: huffman_code <= 16'h007a; huffman_bitlen <= 4'h6; huffman_valid <= 1'b1;
            8'h52: huffman_code <= 16'h07f7; huffman_bitlen <= 4'ha; huffman_valid <= 1'b1;
            8'h53: huffman_code <= 16'hff9e; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h54: huffman_code <= 16'hff9f; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h55: huffman_code <= 16'hffa0; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h56: huffman_code <= 16'hffa1; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h57: huffman_code <= 16'hffa2; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h58: huffman_code <= 16'hffa3; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h59: huffman_code <= 16'hffa4; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h5a: huffman_code <= 16'hffa5; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h61: huffman_code <= 16'h007b; huffman_bitlen <= 4'h6; huffman_valid <= 1'b1;
            8'h62: huffman_code <= 16'h0ff6; huffman_bitlen <= 4'hb; huffman_valid <= 1'b1;
            8'h63: huffman_code <= 16'hffa6; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h64: huffman_code <= 16'hffa7; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h65: huffman_code <= 16'hffa8; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h66: huffman_code <= 16'hffa9; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h67: huffman_code <= 16'hffaa; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h68: huffman_code <= 16'hffab; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h69: huffman_code <= 16'hffac; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h6a: huffman_code <= 16'hffad; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h71: huffman_code <= 16'h00fa; huffman_bitlen <= 4'h7; huffman_valid <= 1'b1;
            8'h72: huffman_code <= 16'h0ff7; huffman_bitlen <= 4'hb; huffman_valid <= 1'b1;
            8'h73: huffman_code <= 16'hffae; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h74: huffman_code <= 16'hffaf; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h75: huffman_code <= 16'hffb0; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h76: huffman_code <= 16'hffb1; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h77: huffman_code <= 16'hffb2; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h78: huffman_code <= 16'hffb3; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h79: huffman_code <= 16'hffb4; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h7a: huffman_code <= 16'hffb5; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h81: huffman_code <= 16'h01f8; huffman_bitlen <= 4'h8; huffman_valid <= 1'b1;
            8'h82: huffman_code <= 16'h7fc0; huffman_bitlen <= 4'he; huffman_valid <= 1'b1;
            8'h83: huffman_code <= 16'hffb6; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h84: huffman_code <= 16'hffb7; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h85: huffman_code <= 16'hffb8; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h86: huffman_code <= 16'hffb9; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h87: huffman_code <= 16'hffba; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h88: huffman_code <= 16'hffbb; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h89: huffman_code <= 16'hffbc; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h8a: huffman_code <= 16'hffbd; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h91: huffman_code <= 16'h01f9; huffman_bitlen <= 4'h8; huffman_valid <= 1'b1;
            8'h92: huffman_code <= 16'hffbe; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h93: huffman_code <= 16'hffbf; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h94: huffman_code <= 16'hffc0; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h95: huffman_code <= 16'hffc1; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h96: huffman_code <= 16'hffc2; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h97: huffman_code <= 16'hffc3; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h98: huffman_code <= 16'hffc4; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h99: huffman_code <= 16'hffc5; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'h9a: huffman_code <= 16'hffc6; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha1: huffman_code <= 16'h01fa; huffman_bitlen <= 4'h8; huffman_valid <= 1'b1;
            8'ha2: huffman_code <= 16'hffc7; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha3: huffman_code <= 16'hffc8; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha4: huffman_code <= 16'hffc9; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha5: huffman_code <= 16'hffca; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha6: huffman_code <= 16'hffcb; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha7: huffman_code <= 16'hffcc; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha8: huffman_code <= 16'hffcd; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'ha9: huffman_code <= 16'hffce; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'haa: huffman_code <= 16'hffcf; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb1: huffman_code <= 16'h03f9; huffman_bitlen <= 4'h9; huffman_valid <= 1'b1;
            8'hb2: huffman_code <= 16'hffd0; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb3: huffman_code <= 16'hffd1; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb4: huffman_code <= 16'hffd2; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb5: huffman_code <= 16'hffd3; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb6: huffman_code <= 16'hffd4; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb7: huffman_code <= 16'hffd5; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb8: huffman_code <= 16'hffd6; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hb9: huffman_code <= 16'hffd7; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hba: huffman_code <= 16'hffd8; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc1: huffman_code <= 16'h03fa; huffman_bitlen <= 4'h9; huffman_valid <= 1'b1;
            8'hc2: huffman_code <= 16'hffd9; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc3: huffman_code <= 16'hffda; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc4: huffman_code <= 16'hffdb; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc5: huffman_code <= 16'hffdc; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc6: huffman_code <= 16'hffdd; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc7: huffman_code <= 16'hffde; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc8: huffman_code <= 16'hffdf; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hc9: huffman_code <= 16'hffe0; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hca: huffman_code <= 16'hffe1; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd1: huffman_code <= 16'h07f8; huffman_bitlen <= 4'ha; huffman_valid <= 1'b1;
            8'hd2: huffman_code <= 16'hffe2; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd3: huffman_code <= 16'hffe3; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd4: huffman_code <= 16'hffe4; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd5: huffman_code <= 16'hffe5; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd6: huffman_code <= 16'hffe6; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd7: huffman_code <= 16'hffe7; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd8: huffman_code <= 16'hffe8; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hd9: huffman_code <= 16'hffe9; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hda: huffman_code <= 16'hffea; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he1: huffman_code <= 16'hffeb; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he2: huffman_code <= 16'hffec; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he3: huffman_code <= 16'hffed; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he4: huffman_code <= 16'hffee; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he5: huffman_code <= 16'hffef; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he6: huffman_code <= 16'hfff0; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he7: huffman_code <= 16'hfff1; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he8: huffman_code <= 16'hfff2; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'he9: huffman_code <= 16'hfff3; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hea: huffman_code <= 16'hfff4; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf0: huffman_code <= 16'h07f9; huffman_bitlen <= 4'ha; huffman_valid <= 1'b1;
            8'hf1: huffman_code <= 16'hfff5; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf2: huffman_code <= 16'hfff6; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf3: huffman_code <= 16'hfff7; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf4: huffman_code <= 16'hfff8; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf5: huffman_code <= 16'hfff9; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf6: huffman_code <= 16'hfffa; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf7: huffman_code <= 16'hfffb; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf8: huffman_code <= 16'hfffc; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hf9: huffman_code <= 16'hfffd; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            8'hfa: huffman_code <= 16'hfffe; huffman_bitlen <= 4'hf; huffman_valid <= 1'b1;
            default: huffman_code <= 16'h0000; huffman_bitlen <= 4'hf; huffman_valid <= 1'b0;
        endcase

    end
endmodule


/**
 * This module expects data to be fed into it with the zig-zag pattern.
 *
 * input nreset         should be strobed for at least one clock cycle at the start of every new image
 * input input_valid    On every clock rising edge input_valid is high, jpeg_huffman_encode will
 *                      huffman encode the data in src_data_in and put it in the output stream. Some
 *                      pipelining may be necessary, so you shouldn't assume that the data will be
 *                      written to the output stream on the very same rising edge... In other words,
 *                      the output isn't just a combinational result of the module's internal state
 *                      and the input.
 * input src_data_in    This should be an integer in [-1024, 1023] containing the DCT input values.
 *                      These values should NOT be differentially coded, and need to be the same
 *                      scale as the input pixels; if extra LSB padding was added to allow for
 *                      higher-precision fixed point calculations, it should be trimmed off.
 *
 *  huffman_read_addr and huffman_read_data should be connected to an EBR
 *
 * output output_wren   On every clock cycle that this is high, the output contains a new piece of
 *                      data with length 'output_length' bits that should be appended. This data
 *                      is not padded or bytestuffed; another hardware module needs to do that.
 *
 *
 * Each cycle, we might need to pack a maximum of 2 values. This will require a barrel shifter, which
 * requires O(n * lg2(m)) 1-bit multiplexers where n is the bit width of the input value and m is the
 * highest amount that we might want to shift by. In this case, n is 32 (because we need to shift
 * into a 32-bit number) and m is 16, giving us a requirement of 128 muxes and therefore an upper
 * bound of 128 logic elements. Not too bad, and I bet that Lattice's tools can shrink that down a
 * good bit.
 *
 * I suppose that the other option is to have a read or write fifo, or guarantee that the input is
 * fed in at a slower rate.
 */
module jpeg_huffman_encode(input clock,
                           input nreset,

                           input        input_valid,
                           input [15:0] src_data_in,

                           output reg [7:0] huffman_read_addr,
                           input     [15:0] huffman_read_code,
                           input      [3:0] huffman_read_bitlen,

                           output reg        output_wren,
                           output reg [3:0]  output_length,
                           output reg [15:0] output_data);



endmodule
