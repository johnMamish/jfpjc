`timescale 1ns/100ps

`ifdef FORMAL
    `ifdef BITPACKER
        `define ASSUME assume
    `else
        `define ASSUME assert
    `endif
`endif

module lsbs_mask(input [5:0] width,
                 output reg [31:0] mask);
    always @* begin
        // using a lookup table cause IDK if I trust the synth to make something smart here.
        case (width)
            6'd00: mask = 32'b0000_0000_0000_0000_0000_0000_0000_0000;
            6'd01: mask = 32'b0000_0000_0000_0000_0000_0000_0000_0001;
            6'd02: mask = 32'b0000_0000_0000_0000_0000_0000_0000_0011;
            6'd03: mask = 32'b0000_0000_0000_0000_0000_0000_0000_0111;
            6'd04: mask = 32'b0000_0000_0000_0000_0000_0000_0000_1111;
            6'd05: mask = 32'b0000_0000_0000_0000_0000_0000_0001_1111;
            6'd06: mask = 32'b0000_0000_0000_0000_0000_0000_0011_1111;
            6'd07: mask = 32'b0000_0000_0000_0000_0000_0000_0111_1111;
            6'd08: mask = 32'b0000_0000_0000_0000_0000_0000_1111_1111;
            6'd09: mask = 32'b0000_0000_0000_0000_0000_0001_1111_1111;
            6'd10: mask = 32'b0000_0000_0000_0000_0000_0011_1111_1111;
            6'd11: mask = 32'b0000_0000_0000_0000_0000_0111_1111_1111;
            6'd12: mask = 32'b0000_0000_0000_0000_0000_1111_1111_1111;
            6'd13: mask = 32'b0000_0000_0000_0000_0001_1111_1111_1111;
            6'd14: mask = 32'b0000_0000_0000_0000_0011_1111_1111_1111;
            6'd15: mask = 32'b0000_0000_0000_0000_0111_1111_1111_1111;
            6'd16: mask = 32'b0000_0000_0000_0000_1111_1111_1111_1111;
            6'd17: mask = 32'b0000_0000_0000_0001_1111_1111_1111_1111;
            6'd18: mask = 32'b0000_0000_0000_0011_1111_1111_1111_1111;
            6'd19: mask = 32'b0000_0000_0000_0111_1111_1111_1111_1111;
            6'd20: mask = 32'b0000_0000_0000_1111_1111_1111_1111_1111;
            6'd21: mask = 32'b0000_0000_0001_1111_1111_1111_1111_1111;
            6'd22: mask = 32'b0000_0000_0011_1111_1111_1111_1111_1111;
            6'd23: mask = 32'b0000_0000_0111_1111_1111_1111_1111_1111;
            6'd24: mask = 32'b0000_0000_1111_1111_1111_1111_1111_1111;
            6'd25: mask = 32'b0000_0001_1111_1111_1111_1111_1111_1111;
            6'd26: mask = 32'b0000_0011_1111_1111_1111_1111_1111_1111;
            6'd27: mask = 32'b0000_0111_1111_1111_1111_1111_1111_1111;
            6'd28: mask = 32'b0000_1111_1111_1111_1111_1111_1111_1111;
            6'd29: mask = 32'b0001_1111_1111_1111_1111_1111_1111_1111;
            6'd30: mask = 32'b0011_1111_1111_1111_1111_1111_1111_1111;
            6'd31: mask = 32'b0111_1111_1111_1111_1111_1111_1111_1111;
            6'd32: mask = 32'b1111_1111_1111_1111_1111_1111_1111_1111;
            default: mask = 32'hxxxx_xxxx;
        endcase // case (width)
    end

    always @* begin
`ifdef FORMAL
        assert(mask == ((32'h1 << width) - 32'h1));
`endif
    end
endmodule

/**
 * This memory interface module lets our huffman encoder write words of variable bit length
 * (up to 32 bits), and it aligns and packs them into 32-bit words.
 *
 * This is my first ever module that I'm writing Formal Verification assert/assume statements for,
 * so they'll be accompanied by unnecessary comments describing my thought process.
 */
module bitpacker(input         clock,
                 input         nreset,

                 input         data_in_valid,
                 input [31:0]  data_in,
                 input  [5:0]  input_length,

                 output reg         data_out_valid,
                 output reg  [31:0] data_out);
    reg [4:0] bit_accumulator;
    reg [4:0] bit_accumulator_next;
    reg       bit_accumulator_carry;

    wire [31:0] lsb_mask;
    lsbs_mask lm(.width(input_length),
                 .mask(lsb_mask));

    reg [31:0] output_register;
    reg [31:0] bit_accumulator_register;

    reg [63:0] shifted_input;
    always @* begin
        shifted_input = ({32'h0, lsb_mask} & {32'h0, data_int}) << bit_accumulator;
    end

    reg [31:0] bit_accumulator_with_input_added;
    always @* begin
        bit_accumulator_with_input_added = bit_accumulator_register | shifted_input[31:0];
    end

    always @(posedge clock) begin
        if (nreset) begin
            if (bit_accumulator_carry) begin
                bit_accumulator_register <= shifted_input[63:32];
            end else begin
                bit_accumulator_register <= bit_accumulator_with_input_added;
            end

            if (bit_accumulator_carry) begin
                data_out <= bit_accumulator_with_input_added;
                data_out_valid <= 1'b1;
            end else begin
                data_out <= 32'hxxxx_xxxx;
                data_out_valid <= 1'b0;
            end
        end else begin
            bit_accumulator_register <= 32'h0000_0000;
            data_out <= 32'hxxxx_xxxx;
            data_out_valid <= 1'b0;
        end
    end

    always @* begin
        { bit_accumulator_carry, bit_accumulator_next } = bit_accumulator + input_length;
        data_out = shift[31:0];
        data_out_valid = bit_accumulator_carry;
    end

`ifdef FORMAL

    cover property (input_length > 0);
    cover property (data_in != 0);
    cover property (data_in[31:input_length] != 0);

    // f_past_valid tells us when $past() is valid. Asserts that rely on $past(variable, N) should
    // be and-ed with (f_past_valid >= N).
    // It's worth noting that gisselquist's tutorial that introduces f_past_valid only uses
    // f_past_valid as a boolean, so I wonder how he uses $past(var, N) statements for N != 1.
    integer f_past_valid;
    initial f_past_valid = 0;
    always @(posedge i_clk) begin
        f_past_valid <= f_past_valid + 1;
    end

    // Assume that it starts in reset state
    initial nreset = 1'b0;

    // This is a precondition for the module. We use `ASSUME instead of assert because if this
    // module is being tested by itself with FV, this restricts the input space, and if it's being
    // tested as part of a larger system, we will convert it to an assert which will fire if the
    // preconditions for this module's input are violated.
    always @* begin
        assert(input_length <= 6'b10_0000);
    end


    reg f_last_clock;
    initial f_last_clock = 1'b0;
    // yosys uses $global_clock to represent things that need to be inspected at every time step.
    // The below assertions specify that things should only change on the rising edge of the clock.
    always @($global_clock) begin
        // As far as I can tell, this tells the FV engine to generate a clock signal on every time
        // step.
        assume(clock == !f_last_clock);
        f_last_clock <= clock;

        // we only expect our inputs to change on the rising edge of the clock.
        if (!($rose(clock))) begin
            `ASSUME($stable(nreset));
            `ASSUME($stable(data_in_valid));
            `ASSUME($stable(data_in));
            `ASSUME($stable(input_length));
            `ASSUME($stable(data_out_valid));
            `ASSUME($stable(data_out));
        end
    end

    always @(posedge clock) begin
        // we expect all of our internal registers to stay stable when no new data is provided.
        if ((!data_in_valid) || (input_length == 0)) begin
            assert($stable(bit_accumulator));
            assert($stable(output_register));
            assert($stable(bit_accumulator_register));
        end

        assert ({bit_accumulator_carry, bit_accumulator_next} == (input_length + bit_accumulator));

        if(f_past_valid > 0) begin
            assert(data_out_valid == $past(bit_accumulator_valid));
        end
    end
`endif

endmodule
