`timescale 1ns/100ps

<<<<<<< HEAD
=======

/*
task coefficient_value_to_coded_value(input signed [15:0] coefficient, output [15:0] out, output [3:0] ssss);
begin
    integer result = 0;
    if (coefficient == 16'h0) begin
        out = 16'h0;
        ssss = 4'h0;
    end

    // there's definately a faster way to do this, but I didn't want to prematurely optimize.
    // look into __builtin_ffs when the time comes.
    int min_less1 = 0;
    int max       = 1;
    *bitlen = 1;
    integer coeff_abs = (coefficient_value < 0) ? (-coefficient_value) : (coefficient_value);
    for (; *bitlen < 13; (*bitlen)++) {
        if ((coeff_abs > min_less1) && (coeff_abs <= max)) {
            break;
        }
        min_less1 = max;
        max <<= 1;
        max |= 1;
    }

    if (*bitlen == 13) {
        return 0;
    }

    if (coefficient_value < 0) {
        result = coefficient_value + max;
    } else {
        result = coefficient_value;
    }

    return result;
end
*/

>>>>>>> e964faf5d08ad7cb9501b56ec1a86236a7e5b259
module coefficient_encoder_testbench;
    reg signed [15:0] coefficient;
    wire [15:0]       coded_value;
    wire [3:0]        coded_value_length;

    coefficient_encoder ce(.coefficient(coefficient),
                           .coded_value(coded_value),
                           .coded_value_length(coded_value_length));

    initial begin
        $dumpfile("coefficient_encoder_tb.vcd");
        $dumpvars(0, coefficient_encoder_testbench);

        coefficient = -1;
        display;
        coefficient = 1;
        display;

        coefficient = 0;
        display;

        coefficient = -5;
        display;
        coefficient = 6;
        display;

        coefficient = -46;
        display;
        coefficient = 63;
        display;
        coefficient = -63;
        display;

        coefficient = 1023;
        display;
        coefficient = -1023;
        display;
        $finish;
    end

    task display;
        #1 $display("%d, %h, %d", coefficient,  coded_value, coded_value_length);
    endtask
endmodule // coefficient_encoder_testbench
