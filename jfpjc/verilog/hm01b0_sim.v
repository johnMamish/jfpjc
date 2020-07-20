/**
 * This non-synthesizable module simulates an hm01b0.
 *
 * Its image is 320x240.
 *
 * Hold nreset low to reset the
 *
 * the output clock will be the same as the input clock
 */

`ifndef HM01B0_SIM_V
`define HM01B0_SIM_V

`timescale 1ns/100ps

`define WIDTH (320)
`define HEIGHT (240)

`define HPADDING (20)
`define VPADDING (30)

module hm01b0_sim(input      mclk,
                  input      nreset,

                  output reg clock,
                  output reg  [7:0] pixdata,

                  output reg hsync,
                  output reg vsync);

    reg [7:0] hm01b0_image [0:((320 * 240) - 1)];

    reg [15:0] ptrx;
    reg [15:0] ptry;

    always @ (negedge mclk) begin
        if (nreset) begin
            if (ptrx == ((`WIDTH + `HPADDING) - 1)) begin
                ptrx <= 16'h0;
            end else begin
                ptrx <= ptrx + 16'h1;
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

    // for some reason, putting hm01b0_image (an array of 76800 items) inside an always @* block
    // really upsets iverilog, so we need to use these assign statements on pixdata.
    wire [7:0] pixdata_i;
    assign pixdata_i = ((ptrx < `WIDTH) && (ptry < `HEIGHT)) ?
                       hm01b0_image[(ptry * `WIDTH) + ptrx] :
                       8'hxx;
    always @* begin
        // in case you want to add a delay
        pixdata = pixdata_i;
    end

    always @* begin
        // Unclear if this is the right vsync/hsync behavior. Need to check with a scope.
        hsync = (ptrx < `WIDTH) ? (1'b1) : (1'b0);
        vsync = (ptry < `HEIGHT) ? (1'b1) : (1'b0);
    end

    always @* begin
        clock = mclk;
    end
endmodule

`endif
