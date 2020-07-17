`timescale 1ns/100ps

/**
 * Last paragraph of F.1.2.1.1 tells us how to convert coefficient values to coded values
 *
 * length = 1, values [ -1,  -1] --> [  0,   0]
 *             values [  1,   1] --> [  1,   1]
 *
 * length = 2, values [ -3,  -2] --> [  0,   1]
 *             values [  2,   3] --> [  2,   3]
 *
 * length = 3, values [ -7,  -4] --> [  0,   3]
 *             values [  4,   7] --> [  4,   7]
 *
 */
module coefficient_encoder(input signed [15:0] coefficient,
                           output reg [15:0] coded_value,
                           output reg  [3:0] coded_value_length);
    reg [15:0] absolute_value;

    always @* begin
        absolute_value = (coefficient[15] == 1'b1) ? (-coefficient) : (coefficient);
    end

    integer i;
    always @* begin
        if (absolute_value == 16'h0) begin
            coded_value = 16'hxxxx;
            coded_value_length = 4'h0;
        end else begin
            coded_value_length = 'h0;
            for (i = 0; i < 16; i = i + 1) begin
                if (absolute_value[i]) begin
                    coded_value_length = (i + 1);
                end
            end

            if (coefficient[15]) begin
                coded_value = coefficient + ((1 << coded_value_length) - 16'h1);
            end else begin
                coded_value = coefficient;
            end
        end
    end
endmodule
