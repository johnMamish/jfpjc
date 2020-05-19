/**
 * Copyright John Mamish, 2020
 *
 * TODOs
 *   ( ) reorder microcode to avoid some redundant loads
 *   ( ) rom module should have individual signals named.
 */

`timescale 1ns/100ps

`define UCODE_LEN (6'd17)


// all of these constants are positive; they are rounded and multiplied by 128 to match the 7q8 format.

// k * cos((n * pi) / 16) for 1c3 = 0.8314696123 * 0.35355339059
// 75.2560385539
`define _1C3_COS_7Q8 (9'd75)

// k * sin((n * pi) / 16) for 1c3 = 0.5555702330 * 0.35355339059
// 50.2844773345
`define _1C3_SIN_7Q8 (9'd50)

// k * cos((n * pi) / 16) for 1c1 = 0.9807852804 * 0.35355339059
// 88.7705500995
`define _1C1_COS_7Q8 (9'd89)

// k * sin((n * pi) / 16) for 1c1 = 0.1950903220 * 0.35355339059
// 17.6575602725
`define _1C1_SIN_7Q8 (9'd18)

// k * cos((n * pi) / 16) for sqrt(2)c1 = 0.54119610014 * 0.35355339059
// 48.9834793417
`define _R2C1_COS_7Q8 (9'd49)

// k * sin((n * pi) / 16) for sqrt(2)c1 = 1.30656296488 * 0.35355339059
// 118.256580161
`define _R2C1_SIN_7Q8 (9'd118)

// 1.41421356237
// 362.038671967
`define _SQRT2_7Q8 (9'd362)

// 1.41421356237 * 0.25
// 90.5096679917
`define _SQRT2_OVER4_7Q8 (9'd90)

module multiplier_constants(input [2:0] select,
                            output reg [8:0] out);
    always @ * begin
        case (select)
            3'd0: out = `_1C3_COS_7Q8;
            3'd1: out = `_1C3_SIN_7Q8;
            3'd2: out = `_1C1_COS_7Q8;
            3'd3: out = `_1C1_SIN_7Q8;
            3'd4: out = `_R2C1_COS_7Q8;
            3'd5: out = `_R2C1_SIN_7Q8;
            3'd6: out = `_SQRT2_7Q8;
            3'd7: out = `_SQRT2_OVER4_7Q8;
        endcase
    end
endmodule

`define SRC_FETCH 1'b0
`define SRC_SPAD 1'b1

`define OP1_RETAIN 1'b0
`define OP1_LATCH 1'b1

`define OP1_NNEGATE 1'b0
`define OP1_NEGATE 1'b1

`define OP2_NNEGATE 1'b0
`define OP2_NEGATE 1'b1

`define OP1_SRC_MEM 1'b0
`define OP1_SRC_MUL 1'b1

`define OP2_SRC_MEM 1'b0
`define OP2_SRC_MUL 1'b1

`define WRITE_SPAD 1'b0
`define WRITE_OUT 1'b1

`define WRITE_NEN 1'b0
`define WRITE_EN 1'b1

/**
 *
 * * Control <4:0> - Read addr
 * * Control <5:5> - Read src (0:fetch_data or 1:internal scratchpad)
 * * Control <6:6> - Latch read value in operand?
 * * Control <7:7> - Negate operand1 of adder?
 * * Control <8:8> - Negate operand2 of adder?
 * * Control <9:9> - op1 latch select (op load or multiplier output)
 * * control <10:10> - op2 select (op load or multiplier output)
 * * control <13:11> - coefficient select (see multiplier_constants)
 * * control <18:14> - write addr
 * * control <19:19> - write dest (0 is internal scratchpad, 1 is output)
 * * Control <20:20> - Write enable
 */
module loeffler_dct_8_control_rom(input      [ 5:0] addr,
                                  output reg [20:0] control);
    always @ * begin
        case(addr)
            // next cycle, fetch_data[0] appears on output of EBR
            6'd0:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE,  `OP1_LATCH, `SRC_FETCH, 5'h00 };

            // next cycle, fetch_data[0] is latched in the operand latch
            //             fetch_data[7] appears on output of EBR
            6'd1:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE,  `OP1_LATCH, `SRC_FETCH, 5'h07 };

            // next cycle, operand_latch + EBR output is stored in scratchpad
            //             fetch_data[1] appears on output of EBR
            // Side note: bit 6 COULD be x, but making it 0 makes me feel comfy.
            6'd2:     control = {  `WRITE_EN, `WRITE_SPAD, 5'h00, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH, 5'h01 };

            // next cycle, fetch_data[1] is latched in the operand latch
            //             fetch_data[6] appears on output of EBR
            6'd3:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h06 };

            // next cycle, operand_latch + EBR output is stored in scratchpad
            //             fetch_data[1] appears on output of EBR
            6'd4:     control = {  `WRITE_EN, `WRITE_SPAD, 5'h01, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH, 5'h02 };

            6'd5:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h05 };
            6'd6:     control = {  `WRITE_EN, `WRITE_SPAD, 5'h02, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h03 };


            // scratchpad[3] = input_data[3] + input_data[4]
            6'd7:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h04 };
            6'd8:     control = {  `WRITE_EN, `WRITE_SPAD, 5'h03, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h03 };

            // scratchpad[4] = input_data[3] - input_data[4]
            6'd9:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h04 };
            6'd10:    control = {  `WRITE_EN, `WRITE_SPAD, 5'h04, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h02 };

            // scratchpad[5] = input_data[2] - input_data[5]
            6'd11:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h05 };
            6'd12:    control = {  `WRITE_EN, `WRITE_SPAD, 5'h05, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h01 };

            // scratchpad[6] = input_data[1] - input_data[6]
            6'd13:    control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h06 };
            6'd14:    control = {  `WRITE_EN, `WRITE_SPAD, 5'h06, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h00 };

            // scratchpad[7] = input_data[0] - input_data[7]
            6'd15:     control = { `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h07 };
            6'd16:    control = {  `WRITE_EN, `WRITE_SPAD, 5'h07, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h00 };

            // scratchpad[8] = scratchpad[0] + scratchpad[3]


            // scratchpad[9] = scratchpad[1] + scratchpad[2]


            // scratchpad[10] = scratchpad[1] - scratchpad[2]


            // scratchpad[11] = scratchpad[0] - scratchpad[3]


            // scratchpad[12] = scratchpad[4] * _1C3_COS_7Q8 + scratchpad[7] * _1C3_SIN_7Q8


            // scratchpad[13] = -scratchpad[4] * _1C3_SIN_7Q8 + scratchpad[7] * _1C3_COS_7Q8


            // scratchpad[14] = scratchpad[5] * _1C1_COS_7Q8 + scratchpad[6] * _1C1_COS_7Q8


            // scratchpad[15] = -scratchpad[5] * _1C1_SIN_7Q8 + scratchpad[6] * _1C1_COS_7Q8



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

    // control ROM
    reg [5:0] ucode_pc;
    wire [4:0] ucode_readaddr;
    wire ucode_read_src;
    wire ucode_latch_operand1;
    wire ucode_negate_operand1;
    wire ucode_negate_operand2;
    wire ucode_op1_src;
    wire ucode_op2_sel;
    wire [2:0] ucode_coeff_select;
    wire [4:0] ucode_scratchpad_writeaddr;
    wire ucode_write_dest;
    wire ucode_scratchpad_write_enable;
    loeffler_dct_8_control_rom rom(.addr(ucode_pc),
                                   .control({ucode_scratchpad_write_enable,
                                             ucode_write_dest,
                                             ucode_scratchpad_writeaddr,
                                             ucode_coeff_select,
                                             ucode_op2_sel,
                                             ucode_op1_src,
                                             ucode_negate_operand2,
                                             ucode_negate_operand1,
                                             ucode_latch_operand1,
                                             ucode_read_src,
                                             ucode_readaddr}));

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

    wire [8:0] multiplier_consts;
    multiplier_constants mulrom(.select(ucode_coeff_select), .out(multiplier_consts));

    reg [15:0] operand_bus;
    always @ * begin
        if (ucode_read_src) begin
            operand_bus = scratchpad_readdata;
        end else begin
            operand_bus = {{fetch_data[7]}, fetch_data[7:0]};
        end
    end

    wire signed [15:0] multiplier_op1;
    wire signed [15:0] multiplier_out_7q8;
    wire signed [31:0] multiplier_out;
    pipelined_multiplier mul(clock, multiplier_op1, {7'b0, multiplier_consts}, multiplier_out);
    assign multiplier_out_7q8 = multiplier_out[23:8];

    reg [15:0] operand2;
    always @ * begin
        case (ucode_op2_sel)
            `OP2_SRC_MEM: operand2 = operand_bus;
            `OP2_SRC_MUL: operand2 = multiplier_out_7q8;
        endcase
    end

    always @ * begin
        scratchpad_wren = ucode_scratchpad_write_enable && (ucode_write_dest == `WRITE_SPAD);
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
                case (ucode_op1_src)
                    `OP1_SRC_MEM: operand_latch <= operand_bus;
                    `OP1_SRC_MUL: operand_latch <= multiplier_out_7q8;
                endcase
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
            2'b00: adder_output =  operand_latch + operand2;
            2'b01: adder_output = -operand_latch + operand2;
            2'b10: adder_output =  operand_latch - operand2;
            2'b11: adder_output = -operand_latch - operand2;
        endcase
        scratchpad_writedata = adder_output;
    end

endmodule
