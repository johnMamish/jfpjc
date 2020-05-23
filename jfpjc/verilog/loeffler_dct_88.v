/**
 * Copyright John Mamish, 2020
 */

/**
 * In order to do a 2-D DCT composed of 1-D DCTs, first we must do 1-D DCTs on each row, and then
 * 1-D DCTs on each column.
 *
 * If the intraline index is indicated to be row major,
 *     index = (intraline index) + (8 * (line number)).
 *
 * If the intraline index is indicated to be column major,
 *     index = (8 * (intraline index)) + (line number).
 */

`define ROW_MAJOR 1'b1
`define COLUMN_MAJOR 1'b0

module block_indexer(input  [2:0] intraline_index,
                     input  [2:0]      line_number,
                     input     row_or_column_major,
                     output reg [5:0] result_index);
    always @ * begin
        case (row_or_column_major)
            `ROW_MAJOR: result_index = { line_number, intraline_index };
            `COLUMN_MAJOR: result_index = { intraline_index, line_number};
        endcase
    end
endmodule

/**
 * This hardware component reads pixel bytes sequentially in row-major order from a memory buffer
 * and computes an 8x8 DCT on them. It outputs the resuting DCT coefficients in row-major order.
 *
 *
 * The input data is expected in the q8 format, in the range [-128, 127]. The jpeg standard talks
 * about level shifting. See section A.3.1 for details. This module expects that data fed to it has
 * already been level shifted.
 */
module loeffler_dct_88(input             clock,
                       input             nreset,

                       output reg  [5:0] fetch_addr,
                       input       [7:0] src_data_in,

                       output reg  [5:0] result_write_addr,
                       output reg        result_wren,
                       output reg [15:0] result_out,

                       output reg        finished);

    reg [15:0] src_data_in_7q8;

    reg [7:0] scratchpad_write_addr;
    reg [7:0] scratchpad_read_addr;

    reg [3:0] xform_number;

    reg       dct_1d_reset;

    wire [4:0] dct_1d_scratchpad_read_addr;
    wire [15:0] dct_1d_scratchpad_read_data;
    loeffler_dct_8 dct_1d(.clock(clock),
                          .nreset(dct_1d_reset),

                          .fetch_addr(),
                          .src_data_in(src_data_in_7q8),

                          .scratchpad_read_addr(dct_1d_scratchpad_read_addr),
                          .scratchpad_read_data(dct_1d_scratchpad_read_data),
                          );


    always @ (posedge clock) begin
        // xform_number
        if (dct_finished) begin
            xform_number <= (xform_number + 1);
        end else begin
            xform_number <= xform_number;
        end


    end
