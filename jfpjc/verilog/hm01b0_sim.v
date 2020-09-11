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

module hm01b0_sim(input      mclk,
                  input      nreset,

                  output reg clock,
                  output reg  [7:0] pixdata,

                  output reg hsync,
                  output reg vsync);
    parameter width = 320;
    parameter height = 240;
    parameter left_padding = 1, right_padding = 1;
    parameter top_padding = 1, bottom_padding = 30;
    localparam xmax = width + left_padding + right_padding - 1;
    localparam ymax = height + top_padding + bottom_padding - 1;


    reg [7:0] hm01b0_image [0:((width * height) - 1)];

    reg [15:0] ptrx;
    reg [15:0] ptry;

    always @ (negedge mclk) begin
        if (nreset) begin
            if (ptrx == xmax) begin
                ptrx <= 16'h0;
            end else begin
                ptrx <= ptrx + 16'h1;
            end

            if (ptrx == xmax) begin
                if (ptry == ymax) begin
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
        // Unclear if this is the right vsync/hsync behavior. Need to check with a scope.
        vsync = ((ptry >= top_padding) && (ptry < (top_padding + height))) ? (1'b1) : (1'b0);
        hsync = (vsync && (ptrx >= left_padding) && (ptrx < (left_padding + width))) ? (1'b1) : (1'b0);
    end


    // for some reason, putting hm01b0_image (an array of 76800 items) inside an always @* block
    // really upsets iverilog, so we need to use these assign statements on pixdata.
    wire [7:0] pixdata_i;
    assign pixdata_i = (hsync && vsync) ?
                       hm01b0_image[((ptry - top_padding) * width) + (ptrx - left_padding)] :
                       8'hxx;
    always @* begin
        // in case you want to add a delay
        pixdata = pixdata_i;
    end

    always @* begin
        clock = mclk;
    end
endmodule

`endif
