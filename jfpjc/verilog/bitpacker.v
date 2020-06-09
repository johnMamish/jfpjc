`timescale 1ns/100ps

/**
 * This module will mask all bits above bit 'width' out to be zero.
 *
 * masked_data = unmasked_data & ((1 << width) - 1);
 */
module lsb_masker(input       [5:0] width,
                  input      [31:0] unmasked_data,
                  output reg [31:0] masked_data);

    always @* begin
        // using a lookup table cause IDK if I trust the synth to make something smart here.
        case (width)
            6'd00: masked_data = 32'b0000_0000_0000_0000_0000_0000_0000_0000;
            6'd01: masked_data = { 31'h0, unmasked_data[ 0:0] };
            6'd02: masked_data = { 30'h0, unmasked_data[ 1:0] };
            6'd03: masked_data = { 29'h0, unmasked_data[ 2:0] };
            6'd04: masked_data = { 28'h0, unmasked_data[ 3:0] };
            6'd05: masked_data = { 27'h0, unmasked_data[ 4:0] };
            6'd06: masked_data = { 26'h0, unmasked_data[ 5:0] };
            6'd07: masked_data = { 25'h0, unmasked_data[ 6:0] };
            6'd08: masked_data = { 24'h0, unmasked_data[ 7:0] };
            6'd09: masked_data = { 23'h0, unmasked_data[ 8:0] };
            6'd10: masked_data = { 22'h0, unmasked_data[ 9:0] };
            6'd11: masked_data = { 21'h0, unmasked_data[10:0] };
            6'd12: masked_data = { 20'h0, unmasked_data[11:0] };
            6'd13: masked_data = { 19'h0, unmasked_data[12:0] };
            6'd14: masked_data = { 18'h0, unmasked_data[13:0] };
            6'd15: masked_data = { 17'h0, unmasked_data[14:0] };
            6'd16: masked_data = { 16'h0, unmasked_data[15:0] };
            6'd17: masked_data = { 15'h0, unmasked_data[16:0] };
            6'd18: masked_data = { 14'h0, unmasked_data[17:0] };
            6'd19: masked_data = { 13'h0, unmasked_data[18:0] };
            6'd20: masked_data = { 12'h0, unmasked_data[19:0] };
            6'd21: masked_data = { 11'h0, unmasked_data[20:0] };
            6'd22: masked_data = { 10'h0, unmasked_data[21:0] };
            6'd23: masked_data = {  9'h0, unmasked_data[22:0] };
            6'd24: masked_data = {  8'h0, unmasked_data[23:0] };
            6'd25: masked_data = {  7'h0, unmasked_data[24:0] };
            6'd26: masked_data = {  6'h0, unmasked_data[25:0] };
            6'd27: masked_data = {  5'h0, unmasked_data[26:0] };
            6'd28: masked_data = {  4'h0, unmasked_data[27:0] };
            6'd29: masked_data = {  3'h0, unmasked_data[28:0] };
            6'd30: masked_data = {  2'h0, unmasked_data[29:0] };
            6'd31: masked_data = {  1'h0, unmasked_data[30:0] };
            6'd32: masked_data = unmasked_data[31:0];
            default: masked_data = 32'hxxxx_xxxx;
        endcase // case (width)
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
    reg [4:0] bit_counter;
    reg [4:0] bit_counter_next;
    reg       bit_counter_carry;

    wire [63:0] lsbs_masked;
    lsb_masker lm(.width(input_length),
                  .unmasked_data(data_in),
                  .masked_data(lsbs_masked[31:0]));

    reg [31:0] output_register;
    reg [31:0] bit_accumulator_register;

    reg [63:0] shifted_input;
    always @* begin
        shifted_input = (lsbs_masked) << bit_counter;
    end

    reg [31:0] bit_accumulator_with_input_added;
    always @* begin
        bit_accumulator_with_input_added = bit_accumulator_register | shifted_input[31:0];
    end

    always @(posedge clock) begin
        if (nreset) begin
            if (bit_counter_carry) begin
                bit_accumulator_register <= shifted_input[63:32];
            end else begin
                bit_accumulator_register <= bit_accumulator_with_input_added;
            end

            if (bit_counter_carry) begin
                data_out <= bit_accumulator_with_input_added;
                data_out_valid <= 1'b1;
            end else begin
                data_out <= 32'hxxxx_xxxx;
                data_out_valid <= 1'b0;
            end

            bit_counter <= bit_counter_next;
        end else begin
            bit_accumulator_register <= 32'h0000_0000;
            data_out <= 32'hxxxx_xxxx;
            data_out_valid <= 1'b0;
            bit_counter <= 5'h0;
        end
    end

    always @* begin
        { bit_counter_carry, bit_counter_next } = bit_counter + input_length;
    end
endmodule
