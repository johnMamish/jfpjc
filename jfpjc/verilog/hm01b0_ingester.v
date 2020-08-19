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

                       // obfusction map
                       // The obfuscation map has one bit per MCU. If the obfuscation bit
                       // corresponding to a given MCU is '1', that MCU shall be obfuscated.
                       // The obfuscation bit corresponding to MCU x in row y is at bit number
                       // x % 5 of byte number (x / 5) + (y * 8). Lower bits correspond to MCUs
                       // that are further left.
                       //
                       // |----- 40 bits spread over 8 bytes -----|
                       // |                                       |
                       // xxxbbbbb xxxbbbbb xxxbbbbb ..... xxxbbbbb   <---- row 0
                       // xxxbbbbb xxxbbbbb xxxbbbbb ..... xxxbbbbb   <---- row 1
                       // ...         ...   ...      .....  ...
                       // xxxbbbbb xxxbbbbb xxxbbbbb ..... xxxbbbbb   <---- row 29
                       output reg [8:0]           obfuscation_map_fetch_addr,
                       input [7:0]                obfuscation_map_fetch_data,
                       output reg                 obfuscation_map_rclken,
                       output reg                 obfuscation_map_rclk,

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
                       output reg [0:0]           wren,

                       // obfuscation map output interface
                       output reg [39:0]          obfuscation_map_out,
                       output reg [0:0]           obfuscation_map_wren);

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

    // obfuscation map loader
    // TODO: need to keep track of y-position within image / obfuscation map

    // On cycle after nreset is released, we need to start loading first row, so we need to keep
    // track of nreset_prev.
    reg [39:0] obfuscation_map_accum, obfuscation_map_accum_next;
    reg [39:0] obfuscation_map_out_next;
    reg nreset_prev;

    always @* begin obfuscation_map_rclk = clock; end
    reg obfuscation_map_read_state, obfuscation_map_read_state_next;
    reg [2:0] obfuscation_map_read_ptr, obfuscation_map_read_ptr_next;
`define OBFU_MAP_READ_STATE_IDLE 1'b0
`define OBFU_MAP_READ_STATE_ACTIVE 1'b1

    always @* begin
        case (obfuscation_map_read_state)
            `OBFU_MAP_READ_STATE_IDLE: begin
                obfuscation_map_read_ptr_next = 3'h0;
                if (new_mcu_row || (nreset && !nreset_prev)) begin
                    obfuscation_map_out_next = obfuscation_map_accum;
                    obfuscation_map_accum_next = 40'h00_0000_0000;
                    obfuscation_map_read_state_next = `OBFU_MAP_READ_STATE_ACTIVE;
                    obfuscation_map_rclken = 1'b1;
                end else begin
                    obfuscation_map_out_next = obfuscation_map_out;
                    obfuscation_map_accum_next = obfuscation_map_accum;
                    obfuscation_map_read_state_next = `OBFU_MAP_READ_STATE_IDLE;
                    obfuscation_map_rclken = 1'b0;;
                end
            end

            `OBFU_MAP_READ_STATE_ACTIVE: begin
                obfuscation_map_out_next = obfuscation_map_out;
                obfuscation_map_rclken = 1'b1;
                if (obfuscation_map_read_ptr == 3'h5) begin
                    obfuscation_map_read_state_next = `OBFU_MAP_READ_STATE_IDLE;
                    obfuscation_map_read_ptr_next = 3'h0;
                end else begin
                    obfuscation_map_read_state_next = `OBFU_MAP_READ_STATE_ACTIVE;
                    obfuscation_map_read_ptr_next = obfuscation_map_read_ptr + 3'h1;
                end

                obfuscation_map_accum_next = obfuscation_map_accum;
                obfuscation_map_accum_next[(obfuscation_map_read_ptr * 5) +: 5] =
                    obfuscation_map_fetch_data[4:0];
            end

            default: begin
                obfuscation_map_rclken = 1'b0;
                obfuscation_map_read_ptr_next = 3'hx;
                obfuscation_map_read_state_next = 'hx;
                obfuscation_map_accum_next = 40'hxx_xxxx_xxxx;
            end
        endcase
    end

    always @(posedge clock) begin
        nreset_prev <= nreset;

        if (nreset) begin
            obfuscation_map_accum <= obfuscation_map_accum_next;
            obfuscation_map_read_state <= obfuscation_map_read_state_next;
            obfuscation_map_read_ptr <= obfuscation_map_read_ptr_next;
            obfuscation_map_out <= obfuscation_map_out_next;
        end else begin
            obfuscation_map_accum <= 40'hff_ffff_ffff;
            obfuscation_map_read_state <= `OBFU_MAP_READ_STATE_IDLE;
            obfuscation_map_read_ptr <= 3'h0;
            obfuscation_map_out <= 40'hff_ffff_ffff;
        end
    end
endmodule

`else // !`ifdef SYNCHRONOUS
// TODO: different module for alternate clock domain for hm01b0 pixclk.

`endif

`endif
