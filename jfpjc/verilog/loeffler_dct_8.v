/**
 * Copyright John Mamish, 2020
 */

`define UCODE_LEN (6'h05)

`timescale 1ns/100ps

/**
 *
 * * Control <4:0> - Read addr
 * * Control <5:5> - Read src (0:fetch_data or 1:internal scratchpad)
 * * Control <6:6> - Latch read value in operand?
 * * Control <7:7> - Negate operand1 of adder?
 * * Control <8:8> - Negate operand2 of adder?
 *
 * * Control <13:9> - Write addr
 * * Control <14:14> - Write enable
 */
module loeffler_dct_8_control_rom(input      [ 5:0] addr,
                                 output reg [14:0] control);
    always @ * begin
        case(addr)
            // next cycle, fetch_data[0] appears on output of EBR
            6'd0:     control = { 1'h0, 5'hxx, 1'hx, 1'hx, 1'hx, 1'hx, 5'h00 };

            // next cycle, fetch_data[0] is latched in the operand latch
            //             fetch_data[7] appears on output of EBR
            6'd1:     control = { 1'h0, 5'hxx, 1'hx, 1'h0, 1'h1, 1'h0, 5'h07 };

            // next cycle, operand_latch + EBR output is stored in scratchpad
            //             fetch_data[1] appears on output of EBR
            // Side note: bit 6 COULD be x, but making it 0 makes me feel comfy.
            6'd2:     control = { 1'h1, 5'h00, 1'h0, 1'h0, 1'h0, 1'hx, 5'h01 };

            // next cycle, fetch_data[1] is latched in the operand latch
            //             fetch_data[6] appears on output of EBR
            6'd3:     control = { 1'h0, 5'hxx, 1'h0, 1'h0, 1'h1, 1'h0, 5'h06 };

            // next cycle, operand_latch + EBR output is stored in scratchpad
            //             fetch_data[1] appears on output of EBR
            // Side note: bit 6 COULD be x, but making it 0 makes me feel comfy.
            6'd4:     control = { 1'h1, 5'h00, 1'h0, 1'h0, 1'h0, 1'hx, 5'h01 };

            //
            //6'd5:     control = { };

            default:  control = 15'h0;
        endcase
    end
endmodule


/**
 * This hardware component reads bytes sequentially from a memory buffer
 * and computes an 8-element DCT on them.
 *
 *
 */
module loeffler_dct_8(input             clock,
                      input             nreset,
                      input      [7:0]  fetch_data,
                      output reg [2:0]  fetch_addr,
                      output            fetch_clk);

    assign fetch_clk = clock;

    // Internal scratchpad memory
    reg  [15:0] scratchpad_writedata;
    reg         scratchpad_wren;
    reg  [7:0]  scratchpad_waddr;
    reg  [7:0]  scratchpad_raddr;
    wire [15:0] scratchpad_readdata;
    ice40_ebr #(.addr_width(8), .data_width(16))  scratchpad(.din(scratchpad_writedata),
                                                             .write_en(scratchpad_wren),
                                                             .waddr(scratchpad_waddr),
                                                             .wclk(clock),
                                                             .raddr(scratchpad_raddr),
                                                             .rclk(clock),
                                                             .dout(scratchpad_readdata));

    // control ROM
    reg [5:0] ucode_pc;
    wire [4:0] ucode_readaddr;
    wire ucode_read_src;
    wire ucode_latch_operand1;
    wire ucode_negate_operand1;
    wire ucode_negate_operand2;
    wire [4:0] ucode_scratchpad_writeaddr;
    wire ucode_scratchpad_write_enable;
    loeffler_dct_8_control_rom rom(.addr(ucode_pc),
                                   .control({ucode_scratchpad_write_enable,
                                             ucode_scratchpad_writeaddr,
                                             ucode_negate_operand2,
                                             ucode_negate_operand1,
                                             ucode_latch_operand1,
                                             ucode_read_src,
                                             ucode_readaddr}));

    reg [15:0] load_data;
    always @ * begin
        if (ucode_read_src) begin
            load_data = scratchpad_readdata;
        end else begin
            load_data = {{fetch_data[7]}, fetch_data[7:0]};
        end
    end

    always @ * begin
        scratchpad_wren = ucode_scratchpad_write_enable;
        scratchpad_waddr = { 3'h0, ucode_scratchpad_writeaddr };
        scratchpad_raddr = { 3'h0, ucode_readaddr };
        fetch_addr = ucode_readaddr[2:0];
    end

    // Operand latch
    reg  [15:0] operand_latch;
    always @ (posedge clock) begin
        if (nreset) begin
            // increment ucode program counter
            ucode_pc <= (ucode_pc < `UCODE_LEN) ? (ucode_pc + 6'h1) : (6'h0);

            // operand latch
            if (ucode_latch_operand1) begin
                operand_latch <= load_data;
            end else begin
                operand_latch <= operand_latch;
            end
        end else begin
            ucode_pc <= 'h0;
            operand_latch <= 'h0;
        end
    end

    reg  [15:0] adder_output;
    always @* begin
        // adder
        case ({ucode_negate_operand2, ucode_negate_operand1})
            2'b00: adder_output =  operand_latch + load_data;
            2'b01: adder_output = -operand_latch + load_data;
            2'b10: adder_output =  operand_latch - load_data;
            2'b11: adder_output = -operand_latch - load_data;
        endcase
        scratchpad_writedata = adder_output;
    end

endmodule
