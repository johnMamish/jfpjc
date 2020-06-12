/**
 * This non-synthesizable module simulates an hm01b0.
 *
 * Its image is 320x240.
 *
 * Hold nreset low to reset the
 *
 * the output clock will be the same as the input clock
 */

`timescale 1ns/100ps

`define WIDTH (320)
`define HEIGHT (240)

`define HPADDING (20)
`define VPADDING (2)

module hm01b0_sim(input      nreset,
                  input      mclk,

                  output reg clock,
                  output reg [7:0] pixdata,

                  output reg hsync,
                  output reg vsync);
    assign clock = mclk;

    parameter output_freq = 750000;

    reg [7:0] hm01b0_image [0:((320 * 240) - 1)];

    reg [16:0] ptrx;
    reg [16:0] ptry;

    always @ (posedge mclk) begin
        if (nreset) begin
            if (ptrx == ((`WIDTH + `HPADDING) - 1)) begin
                ptrx <= 16'h0;
            end else begin
                ptrx <= ptrx + 1;
            end

            if (ptrx == ((`WIDTH + `HPADDING) - 1)) begin
                if (ptry == ((`HEIGHT + `VPADDING) - 1)) begin
                    ptry <= 16'h0;
                end else begin
                    ptry <= ptry + 1;
                end
            end else begin
                ptry <= ptry;
            end

        end else begin
            ptrx <= 'h0;
            ptry <= 'h0;
        end
    end

    always @* begin
        if ((ptrx < `WIDTH) && (ptry < `HEIGHT)) begin
            pixdata <= hm01b0_image[(ptry * `WIDTH) + ptrx];
        end else begin
            pixdata <= 8'hxx;
        end

        // Unclear if this is the right vsync/hsync behavior. Need to check with a scope.
        hsync = (ptrx < `WIDTH) ? (1'b1) : (1'b0);
        vsync = (ptry < `HEIGHT) ? (1'b1) : (1'b0);
    end
endmodule
