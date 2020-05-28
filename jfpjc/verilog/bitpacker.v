/**
 * This memory interface module lets our huffman encoder write words of variable bit length
 * (up to 32 bits), and it aligns and packs them into 32-bit words.
 */

module bitpacker(input         clock,
                 input         data_in_valid,
                 input [31:0]  data_in,
                 input  [5:0]  input_length,

                 output        data_out_valid,
                 output [31:0] data_out);

endmodule
