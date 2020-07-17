`ifndef _PIPELINED_DIVIDER_H
`define _PIPELINED_DIVIDER_H
/**
 * This module is a standin for a real pipelined divider.
 *
 * Potential for optimization: the 8x8b "tags" memory isn't strictly necessary, but it makes
 * things simpler.
 */

`timescale 1ns/100ps

`define DIVISOR_LEN (8)
`define DIVIDEND_LEN (16)
`define DIVIDER_PIPELINE_DEPTH (8)
module pipelined_divider(input                      nreset,
                         input                      clock,

                         input signed [`DIVIDEND_LEN - 1:0] dividend,
                         input         [`DIVISOR_LEN - 1:0] divisor,
                         input         [7:0]        tag,       // for identifing pairs that go in.
                         input                      input_valid,

                         output signed [`DIVIDEND_LEN - 1:0] quotient,
                         output                        [7:0] tag_out,       // for identifing pairs that go in.
                         output     output_valid);

    reg signed [(`DIVIDEND_LEN - 1):0] quotient_internal [(`DIVIDER_PIPELINE_DEPTH - 1):0];
    reg        [7:0] tag_internal [(`DIVIDER_PIPELINE_DEPTH - 1):0];
    reg stages_valid [(`DIVIDER_PIPELINE_DEPTH - 1):0];

    assign quotient = quotient_internal[`DIVIDER_PIPELINE_DEPTH - 1];
    assign tag_out  = tag_internal[`DIVIDER_PIPELINE_DEPTH - 1];
    assign output_valid = stages_valid[`DIVIDER_PIPELINE_DEPTH - 1];

    integer i;

    // N.B. if both the dividend and divisor aren't signed, then the dividend is changed to
    // unsigned.
    wire signed [15:0] divisor_extend;
    assign divisor_extend = {8'h0, divisor};
    always @(posedge clock) begin
`ifdef YOSYS
        quotient_internal[0] <= dividend;
`else
        quotient_internal[0] <= dividend / divisor_extend;
`endif
        tag_internal[0] <= tag;
        stages_valid[0] <= input_valid;
        for (i = 1; i < `DIVIDER_PIPELINE_DEPTH; i = i + 1) begin
            quotient_internal[i] <= quotient_internal[i - 1];
            tag_internal[i] <= tag_internal[i - 1];
            stages_valid[i] <= stages_valid[i - 1];
        end
    end
endmodule

`endif
