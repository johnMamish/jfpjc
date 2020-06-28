/**
 * This module represents the ice40's dual-port embedded block memory ram. The code is taken from
 * Lattice's Technical Note TN1250. It is copyright Lattice, NOT mine.
 */

`ifndef ICE40_EBR_V
`define ICE40_EBR_V

`timescale 1ns/100ps

module ice40_ebr (din, write_en, waddr, wclk, raddr, rclk, dout);//512x8
    parameter addr_width = 9;
    parameter data_width = 8;
    input [addr_width-1:0] waddr, raddr;
    input [data_width-1:0] din;
    input write_en, wclk, rclk;
    output reg [data_width-1:0] dout;
    reg [data_width-1:0] mem [(1<<addr_width)-1:0];

    always @(posedge wclk) // Write memory.
    begin
        if (write_en)
          mem[waddr] <= din; // Using write address bus.
    end

    always @(posedge rclk) // Read memory.
    begin
        dout <= mem[raddr]; // Using read address bus.
    end
endmodule

`endif
