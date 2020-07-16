/**
 * This output buffer takes 32-bit inputs and outputs them in parallel as 8-bit words.
 *
 * It consumes 2 EBRs internally.
 */

`timescale 1ns/100ps

module width_adapter_buffer(input                      clock,
                            input                      nreset,

                            input                      data_in_valid,
                            input [31:0]               data_in,

                            output reg                 data_out_valid,
                            output reg [7:0]           data_out);
    // input_width must be a multiple of output_width.
    parameter integer input_width = 32, output_width = 8, buffer_width = 16, buffer_depth = 256;
    parameter integer num_ebrs = (((input_width - 1) / buffer_width) + 1);
    parameter integer ratio = (input_width / output_width);
    parameter [$clog2(ratio) - 1 : 0] data_out_latch_slice_select_max_value = ratio - 1;

    reg [$clog2(buffer_depth) - 1 : 0] data_in_ptr;
    reg [$clog2(buffer_depth) - 1 : 0] data_out_ptr;
    wire [input_width  - 1 : 0] data_out_wire;
    reg [$clog2(ratio) - 1 : 0] data_out_latch_slice_select;
    reg data_out_latch_valid;

    genvar i;
    generate
        for (i = 0; i < num_ebrs; i = i + 1) begin: buffers
            defparam buffer.data_width = buffer_width;
            defparam buffer.addr_width = $clog2(buffer_depth);

            ice40_ebr buffer(.din(data_in[(i * buffer_width) +: buffer_width]),
                             .write_en(data_in_valid),
                             .waddr(data_in_ptr),
                             .wclk(clock),

                             .raddr(data_out_ptr),
                             .rclk(clock),
                             .dout(data_out_wire[(i * buffer_width) +: buffer_width]));
        end
    endgenerate

    // logic for advancing input pointer.
    always @(posedge clock) begin
        if (nreset) begin
            if (data_in_valid) begin
                data_in_ptr <= data_in_ptr + 'h1;
            end else begin
                data_in_ptr <= data_in_ptr;
            end
        end else begin
            data_in_ptr <= 'h0;
        end
    end

    // data_out_latch_valid[1] tells us if the data_out_latch presently holds valid data
    // that's unused.
    // we want to set it when we latch in new data.
    // we want to clear it when we've used up the data.

    // logic for advancing output pointer.
    // We only want to latch a new output word if there's a valid word to read on the output of
    // the buffer EBRs AND we aren't already processing a word.
    always @(posedge clock) begin
        if (nreset) begin
            if (data_in_ptr != data_out_ptr) begin
                data_out_latch_valid <= 1'b1;
            end else if (data_out_latch_slice_select == data_out_latch_slice_select_max_value) begin
                data_out_latch_valid <= 1'b0;
            end else begin
                data_out_latch_valid <= data_out_latch_valid;
            end

            if (!data_out_latch_valid ||
                (data_out_latch_slice_select == data_out_latch_slice_select_max_value)) begin
                data_out_latch_slice_select <= 'h0;
            end else begin
                data_out_latch_slice_select <= data_out_latch_slice_select + 'h1;
            end

            if (data_out_latch_valid &&
                (data_out_latch_slice_select == (data_out_latch_slice_select_max_value - 2'h1))) begin
                data_out_ptr <= data_out_ptr + 'h1;
            end else begin
                data_out_ptr <= data_out_ptr;
            end

            data_out <= data_out_wire[(data_out_latch_slice_select * 8) +: 8];
            data_out_valid <= data_out_latch_valid;
        end else begin
            data_out_ptr <= 'h0;
            data_out_latch_valid <= 'h0;
            data_out_latch_slice_select <= 'h0;
        end
    end
endmodule
