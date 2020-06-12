/**
 * This is the top-level jpeg compressor module.
 *
 * It takes an hm01b0 pixel bus as input and produces a sequence of memory writes on the output
 * which represent a jpeg image.
 *
 * The image is first pulled into a double-buffered bank of iCE40 EBRs, with each bank consisting
 * of 5 EBRs. The input buffer therefore requires 10 EBRs in total.
 *
 * After this, a configurable number of DCT engines read from each of the EBRs in sequence
 */

module jfpjc(input                      nreset,
             input                      clock);

    hm01b0_ingester(.nreset(nreset),
                  .clock(clock));

    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin
            loeffler_88_dct dct();
            ice40_ebr dct_output_buffer();
        end
    endgenerate

    quantizer();

    jpeg_huffman_encode();

endmodule
