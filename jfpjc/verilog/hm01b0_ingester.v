`ifndef HM01B0_INGESTER_V
`define HM01B0_INGESTER_V

/**
 * This connects to an hm01b0 and outputs the given pixels to a
 */


module hm01b0_ingester #(parameter width_pix = 320,
                         parameter height_pix = 240,
                         parameter num_ebr = 5,
                         parameter ebr_size = 512)

    (input                      clock,
     input                      nreset,

     input                      hm01b0_pixclk,
     input [7:0]                hm01b0_pixdata,
     input                      hm01b0_hsync,
     input                      hm01b0_vsync,

     output reg [($clog2(num_ebr) - 1):0] output_block_select,
     output reg [0:0]           frontbuffer_select,
     output reg [($clog2(ebr_size) - 1):0] output_write_addr,
     output reg [7:0]           output_pixval,
     output reg [0:0]           wren);

    // we need enough EBRs to hold all the pixels
    if (((width_pix % 8) != 0) ||
        ((height_pix % 8) != 0) ||
        (width_pix * 8) > (num_ebr * ebr_size)) begin
        $error("bad parameters for hm01b0_ingester");
    end



endmodule // hm01b0_ingester

`endif
