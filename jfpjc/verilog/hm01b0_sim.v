/**
 * This non-synthesizable module simulates an hm01b0.
 *
 * Its image is 320x240.
 *
 * TODO: add hsync and vsync.
 *
 * Hold nreset low to reset the
 */

`timescale 1ns/100ps

module hm01b0_sim(input      nreset,
                  output reg clock,
                  output reg [7:0] pixdata);
    parameter output_freq = 750000;

    reg [7:0] hm01b0_image [0:((320 * 240) - 1)];

    always begin
        if (nreset) begin
            #(1000000000 / (2 * output_freq));
            clock = ~clock;
        end else begin
            clock = 0;
            ptr = 0;
        end
    end

    reg [16:0] ptr;

    always @ (posedge clock) begin
        ptr <= ptr + 1;
    end
endmodule
