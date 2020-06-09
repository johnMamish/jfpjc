`timescale 1ns/100ps

module bitpacker_tb();
`ifdef FORMAL
    reg clock;
    reg nreset;
    reg data_in_valid;
    reg [31:0] data_in;
    reg [5:0] input_width;

    wire data_out_valid;
    wire [31:0] data_out;

    (* anyconst *) reg [31:0] data [0:3];
    (* anyseq *)
    reg [31:0] out [0:3];

    bitpacker bp(.clock(clock),
                 .nreset(nreset),

                 .data_in_valid(data_in_valid),
                 .data_in(data_in),
                 .input_width(input_width),

                 .data_out_valid(data_out_valid),
                 .data_out(data_out));

    integer count_cycle; initial count_cycle = 0;
    integer out_idx; initial out_idx = 0;
    always @(posedge clock) begin
        if (data_out_valid) begin
            out[out_idx] <= data_out;
            out_idx <= out_idx + 1;
        end

        if ((!nreset) && data_in_valid) begin
            in_idx <= in_idx + 1;
        end

        count_cycle <= count_cycle + 1;
    end

    initial nreset = 1'b0;

    initial clock = 1'b1;
    always @($global_clock) begin
        clock = !clock;

	if (!$rose(clock))
	begin
	    assume($stable(nreset));
	    assume($stable(data_in_valid));
	    assume($stable(data_in));
	    assume($stable(input_width));
	end
    end

    integer k;
    always @* begin
        if (count_cycle <= 1) begin
            assume(nreset == 0);
        end begin
            assume(nreset == 1);
        end

        if (in_idx >= 4) begin
            assume(data_in_valid == 0);
        end

        if () begin
        end

        if (out_idx >= 4) begin
            for (k = 0; k < 4; k = k + 1) begin
                assert(out[k] == data[k]);
            end
        end
    end


    // This generate statement for cover properties has been adapted from page 94 of
    // Seligman, Schubert, & Kumar.
    // I probably need to give it an input with total length at least 528 bits to cover all
    // of this property.
    /*genvar i;
    generate for (i = 0; i <= 32; i = i + 1) begin
        all_different_lengths: cover property (input_length == i);
    end*/ // UNMATCHED !!

    //cover

`endif

endmodule
