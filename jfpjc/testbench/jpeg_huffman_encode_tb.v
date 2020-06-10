`timescale 1ns/100ps

module jpeg_huffman_encode_tb();
    reg clock;
    reg nreset;
    reg stall;

    wire [5:0] fetch_addr;
    wire signed [15:0] src_data_into_huff;

    wire huff_output_wren;
    wire [5:0] huff_output_length;
    wire [31:0] huff_output_data;

    reg [31:0] output_memory [0:127];
    reg [4:0] output_lengths [0:127];

    jpeg_huffman_encode huff(.clock(clock),
                             .nreset(nreset),
                             .stall(1'b0),

                             .fetch_addr(fetch_addr),
                             .src_data_in(src_data_into_huff),

                             .output_wren(huff_output_wren),
                             .output_length(huff_output_length),
                             .output_data(huff_output_data));

    // Memory holding 64 int16_t coefficients.
    //
    // Practically all of the coefficients will be in [-128, 127], but they can theoretically be
    // in [-1024, 1023].
    //
    // TODO: add zig-zagger so this memory can hold samples in row-major order. This will ease
    // loading of different test cases.
    ice40_ebr #(.addr_width(8), .data_width(16)) sample_memory(.din(16'h0000),
                                                               .write_en(1'b0),
                                                               .waddr(8'h00),
                                                               .wclk(1'b0),

                                                               .raddr({2'b00, fetch_addr}),
                                                               .rclk(clock),
                                                               .dout(src_data_into_huff));

    // generate clock
    always begin
        #250;
        clock = ~clock;
        #250;
    end

    integer output_index;
    integer i;
    initial begin
        $dumpfile("jpeg_huffman_encode_tb.vcd");
        $dumpvars(jpeg_huffman_encode_tb);

        $readmemh("huffman_testcase_1_in.hex", sample_memory.mem);
        output_index = 0;

        clock = 'b0;

        // strobe reset for a few clock cycles
        nreset = 'b0;
        #2000;

        for (i = 0; i < 68; i = i + 1) begin
            if (huff_output_wren) begin
                output_memory[output_index] = huff_output_data;
                output_lengths[output_index] = huff_output_length;
                output_index = output_index + 1;
            end

            #1000;
        end

        $writememh("jpeg_huffman_encode_testcase_1_out_values.hex", output_memory);
        $writememh("jpeg_huffman_encode_testcase_1_out_lengths.hex", output_lengths);

        $finish;
    end
endmodule
