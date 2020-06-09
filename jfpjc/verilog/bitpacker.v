`timescale 1ns/100ps

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
endmodule
