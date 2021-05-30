`ifndef HM01B0_INGESTER_V
`define HM01B0_INGESTER_V

`timescale 1ns/100ps

/**
 * This connects to an hm01b0 and outputs the given pixels to a
 *
 * TODO: make ingester clock rate not the same as rest of system.
 */
`define SYNCHRONOUS
`ifdef SYNCHRONOUS
module hm01b0_ingester(input                      clock,
                       input                      nreset,

                       // hm01b0 interface
                       input                      hm01b0_pixclk,
                       input [7:0]                hm01b0_pixdata,
                       input                      hm01b0_hsync,
                       input                      hm01b0_vsync,

                       // output buffer select; common to both obfuscation map output and EBR
                       // buffer output.
                       output reg [0:0]           frontbuffer_select,

                       // EBR buffer output interface
                       output reg [($clog2(num_ebr) - 1):0] output_block_select,
                       output reg [($clog2(ebr_size) - 1):0] output_write_addr,
                       output reg [7:0]           output_pixval,

                       output reg [0:0]           wren);
    parameter x_front_padding = 0, x_back_padding = 0, y_front_padding = 0, y_back_padding = 0;
    localparam width_pix = 320, height_pix = 240, num_ebr = 5, ebr_size = 512;
    localparam width_mcu = (width_pix / 8), height_mcu = (height_pix / 8);
    reg [7:0] hm01b0_pixdata_prev;
    reg hm01b0_pixclk_prev [0:1];
    reg [2:0] px;
    reg [2:0] py;
    reg [$clog2(width_pix / 8) - 1 : 0] mcux;
    reg [$clog2(height_pix / 8) - 1 : 0] mcuy;

    reg new_mcu_row;

    // TODO: does this name make sense given the consts used to size it?
    reg [$clog2(ebr_size / 64) - 1 : 0] mcunum_div_num_ebr;
    always @(posedge clock) begin
        if (nreset) begin
            hm01b0_pixdata_prev <= hm01b0_pixdata;
            hm01b0_pixclk_prev[0] <= hm01b0_pixclk;
            hm01b0_pixclk_prev[1] <= hm01b0_pixclk_prev[0];

            // mind the edge direction: sparkfun code seems to think that this is rising edge, but
            // other sources disagree.
            if ((!hm01b0_pixclk_prev[1] && hm01b0_pixclk_prev[0]) &&
                (hm01b0_hsync && hm01b0_vsync)) begin
                wren <= 1'b1;
                output_pixval <= hm01b0_pixdata_prev + 8'h80;
            end else begin
                wren <= 1'b0;
                output_pixval <= 8'hxx;
            end

            // if write enable was high on the previous cycle, we need to advance the addresses
            // TODO: derive / sanity check these from hsync.
            // ebr.addr
            // 0.0, 0.1, 0.2, ... 0.7; 1.0, 1.1, ... 1.7; ... 4.7;     MCU 0 - 4, row 0 (40 pixels)
            // 0.64, 0.65, ...   0.71; 1.64, ...    1.71; ... 4.71;    MCU 5 - 9, row 0  (40 pixels)
            // 0.128, ...       0.135; 1.128, ...  1.135; ... 4.135;   MCU 10 - 14, row 0 (40 pix)
            // ... MCU 15 - 19 (40 pixels)
            // ... MCU 20 - 24 (40 pixels)
            // ... MCU 25 - 29 (40 pixels)
            // ... MCU 30 - 34 (40 pixels)
            // ... MCU 35 - 39 (40 pixels)
            // 0.8, 0.9, ...     0.15; 1.8, 1.9, ...1.15; ... 4.15;    MCU 0 - 4, row 1 (40 pixels)
            // 0.72, 0.73, ...   0.79; 1.72, ...    1.79; ... 4.79;    MCU 5 - 9, row 1 (40 pixels)
            //
            // these patterns can be implemented by a ripple counter that's slightly more convoluted
            // than the sort of ripple counter that you'd use for an hour / minute / second clock.
            if (wren) begin
                // updates:
                //    output_block_select
                //    px
                //    py
                //    mcunum_div_num_ebr
                //    mcux
                //    frontbuffer_select
                if (px == 'h7) begin
                    if (output_block_select == (num_ebr - 1)) begin
                        output_block_select <= 'h0;
                    end else begin
                        output_block_select <= output_block_select + 'h1;
                    end
                end else begin
                    output_block_select <= output_block_select;
                end

                px <= (px == 'h7) ? ('h0) : (px + 'h1);

                if ((px == 'h7) && (output_block_select == (num_ebr - 1))) begin
                    // even though this condition doesn't directly check that mcunum_div_num_ebr
                    // won't overflow the size of an EBR (for instance, a value of 8 for
                    // mcunum_div_num_ebr would try to deposit line 0 of an MCU outside of an EBR),
                    // we are still guaranteed by our precompile condition of
                    // ((width_pix * 8) >= (num_ebr * ebr_size)) that this won't happen.
                    if (mcux == ((width_pix / 8) - 1)) begin
                        mcunum_div_num_ebr <= 'h0;
                    end else begin
                        mcunum_div_num_ebr <= mcunum_div_num_ebr + 'h1;
                    end
                end else begin
                    mcunum_div_num_ebr <= mcunum_div_num_ebr;
                end

                // mcux
                if (px == 'h7) begin
                    mcux <= (mcux == ((width_pix / 8) - 1)) ? 'h0 : (mcux + 'h1);
                end else begin
                    mcux <= mcux;
                end

                py <= ((px == 'h7) && (mcux == ((width_pix / 8) - 1))) ? (py + 'h1) : py;

                //mcuy <= new_mcu_row ? (mcuy == ;
                mcuy <= mcuy;
                frontbuffer_select <= new_mcu_row ? (frontbuffer_select + 'h1) : frontbuffer_select;
            end else begin
                px <= px;
                py <= py;
                output_block_select <= output_block_select;
            end
        end else begin
            // RESET
            output_block_select <= 'h0;
            frontbuffer_select <= 'h0;
            output_pixval <= 'hxx;
            wren <= 'h0;

            hm01b0_pixclk_prev[0] <= hm01b0_pixclk;
            hm01b0_pixclk_prev[1] <= hm01b0_pixclk;
            px <= 'h0;
            mcunum_div_num_ebr <= 'h0;
            mcux <= 'h0;
            mcuy <= 'h0;
            py <= 'h0;
        end
    end

    always @* begin
        // this is a cheaper (mcunum_div_num_ebr * 64) + (py * 8) + px
        output_write_addr = {mcunum_div_num_ebr, py, px};

        new_mcu_row = ((px == 'h7) && (mcux == ((width_pix / 8) - 1)) && (py == 'h7));
    end
endmodule

`else // !`ifdef SYNCHRONOUS
// TODO: different module for alternate clock domain for hm01b0 pixclk.

`endif

`endif
