/**
 * Copyright John Mamish, 2020
 *
 * TODOs
 *   ( ) reorder microcode to avoid some redundant loads
 *   ( ) rom module should have individual signals named.
 */

`timescale 1ns/100ps

`include "fixed_point_consts.v"

`define UCODE_LEN (6'd57)

module multiplier_constants(input [2:0] select,
                            output reg [15:0] out);
    always @ * begin
        case (select)
            3'd0: out = `_1C3_COS_3Q12;
            3'd1: out = `_1C3_SIN_3Q12;
            3'd2: out = `_1C1_COS_3Q12;
            3'd3: out = `_1C1_SIN_3Q12;
            3'd4: out = `_R2C1_COS_3Q12;
            3'd5: out = `_R2C1_SIN_3Q12;
            3'd6: out = `_SQRT2_3Q12;
            3'd7: out = `_SQRT2_OVER4_3Q12;
        endcase
    end
endmodule

`define SRC_FETCH 1'b0
`define SRC_SPAD 1'b1
`define SRC_DC   1'bx

`define OP1_RETAIN 1'b0
`define OP1_LATCH 1'b1

`define OP1_NNEGATE 1'b0
`define OP1_NEGATE 1'b1

`define OP2_NNEGATE 1'b0
`define OP2_NEGATE 1'b1

`define OP1_SRC_MEM 1'b0
`define OP1_SRC_MUL 1'b1
`define OP1_SRC_DC  1'bx

`define OP2_SRC_MEM 1'b0
`define OP2_SRC_MUL 1'b1
`define OP2_SRC_DC  1'bx

`define WRITE_SPAD 1'b0
`define WRITE_OUT 1'b1

`define WRITE_NEN 1'b0
`define WRITE_EN 1'b1

`define WRITE_SRC_ADDER 1'b0
`define WRITE_SRC_MUL   1'b1

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
 * * Control <21:21> - write adder or mul? (0 is adder, 1 is multiplier)
 */
module loeffler_dct_8_control_rom(input      [ 5:0] addr,
                                  output reg [21:0] control);
    always @ * begin
        case(addr)
            // next cycle, fetch_data[0] appears on output of EBR
            6'd0:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE,  `OP1_LATCH, `SRC_FETCH, 5'h00 };

            // next cycle, fetch_data[0] is latched in the operand latch
            //             fetch_data[7] appears on output of EBR
            6'd1:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE,  `OP1_LATCH, `SRC_FETCH, 5'h07 };

            // next cycle, operand_latch + EBR output is stored in scratchpad
            //             fetch_data[1] appears on output of EBR
            // Side note: bit 6 COULD be x, but making it 0 makes me feel comfy.
            6'd2:     control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h00, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH, 5'h01 };

            // next cycle, fetch_data[1] is latched in the operand latch
            //             fetch_data[6] appears on output of EBR
            6'd3:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h06 };

            // next cycle, operand_latch + EBR output is stored in scratchpad
            //             fetch_data[1] appears on output of EBR
            6'd4:     control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h01, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH, 5'h02 };

            6'd5:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h05 };
            6'd6:     control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h02, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h03 };


            // scratchpad[3] = input_data[3] + input_data[4]
            6'd7:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h04 };
            6'd8:     control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h03, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h03 };

            // scratchpad[4] = input_data[3] - input_data[4]
            6'd9:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h04 };
            6'd10:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h04, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h02 };

            // scratchpad[5] = input_data[2] - input_data[5]
            6'd11:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h05 };
            6'd12:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h05, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h01 };

            // scratchpad[6] = input_data[1] - input_data[6]
            6'd13:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h06 };
            6'd14:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h06, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_FETCH,  5'h00 };

            // scratchpad[7] = input_data[0] - input_data[7]
            6'd15:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_FETCH, 5'h07 };
            6'd16:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'h07, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD,  5'd00 };

            // scratchpad[8] = scratchpad[0] + scratchpad[3]
            6'd17:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd03 };
            6'd18:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd08, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD,  5'd01 };

            // scratchpad[9] = scratchpad[1] + scratchpad[2]
            6'd19:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd02 };
            6'd20:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd09, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD,  5'd01 };

            // scratchpad[10] = scratchpad[1] - scratchpad[2]
            6'd21:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd02 };
            6'd22:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd10, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD,  5'd00 };

            // scratchpad[11] = scratchpad[0] - scratchpad[3]
            6'd23:     control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd03 };
            6'd24:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd11, 3'hx, `OP2_SRC_MEM, `OP1_SRC_MEM,
                                   `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD,  5'd04 };


            // scratchpad[12] = scratchpad[4] * _1C3_COS + scratchpad[7] * _1C3_SIN
            // scratchpad[15] = -scratchpad[4] * _1C3_SIN + scratchpad[7] * _1C3_COS
            // scratchpad[13] = scratchpad[5] * _1C1_COS + scratchpad[6] * _1C1_COS
            // scratchpad[14] = -scratchpad[5] * _1C1_SIN + scratchpad[6] * _1C1_COS
            6'd25:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h0, `OP2_SRC_DC, `OP1_SRC_DC,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd07 };
            6'd26:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h1, `OP2_SRC_DC, `OP1_SRC_DC,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd04 };
            6'd27:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h1, `OP2_SRC_DC, `OP1_SRC_MUL,    // next cycle, sp[4] * 1c3cos -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd07 };
            6'd28:    control = { `WRITE_SRC_ADDER, `WRITE_EN,  `WRITE_SPAD, 5'd12, 3'h0, `OP2_SRC_MUL, `OP1_SRC_DC,    // next cycle, op_latch + (sp[7] * 1c3sin) -> sp[12]
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd5 };
            6'd29:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h2,  `OP2_SRC_DC, `OP1_SRC_MUL,   // next cycle, sp[4] * 1c3sin -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd6 };
            6'd30:    control = { `WRITE_SRC_ADDER, `WRITE_EN,  `WRITE_SPAD, 5'd15, 3'h3, `OP2_SRC_MUL, `OP1_SRC_DC,    // next cycle, -op_latch + (sp[7] * 1c3cos) -> sp[15]
                                  `OP2_NNEGATE, `OP1_NEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd5 };
            6'd31:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h3, `OP2_SRC_DC, `OP1_SRC_MUL,    // next cycle, sp[5] * 1c1cos -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd6 };
            6'd32:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd13, 3'h2, `OP2_SRC_MUL, `OP1_SRC_DC,    // next cycle, op_latch + (sp[6] * 1c1sin) -> sp[13]
                                   `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd8 };        // start loading next stage into mul pipeline
            6'd33:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h7, `OP2_SRC_DC, `OP1_SRC_MUL,   // next cycle, sp[5] * 1c1sin -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd9 };
            6'd34:    control = {  `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd14, 3'h7, `OP2_SRC_MUL, `OP1_SRC_DC,    // next cycle, -op_latch + (sp[6] * 1c1cos) -> sp[14]
                                  `OP2_NNEGATE,  `OP1_NEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd8 };

            // data_out[0] = scratchpad[8] * _SQRT2_OVER4 + scratchpad[9] * _SQRT2_OVER4
            // data_out[4] = scratchpad[8] * _SQRT2_OVER4 - scratchpad[9] * _SQRT2_OVER4
            6'd35:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h7, `OP2_SRC_DC, `OP1_SRC_MUL,   // next cycle, sp[8] * (r(2) / 4) -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd9 };
            6'd36:    control = { `WRITE_SRC_ADDER, `WRITE_EN,  `WRITE_OUT,  5'd0, 3'h7, `OP2_SRC_MUL, `OP1_SRC_DC,    // next cycle, op_latch + (sp[9] * (r(2) / 4)) -> out0
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd10 };
            6'd37:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h4, `OP2_SRC_DC, `OP1_SRC_MUL,   // sp[8] * (r(2) / 4) -> op_latch (redundant)
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd11 };
            6'd38:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_OUT, 5'd4, 3'h5, `OP2_SRC_MUL, `OP1_SRC_DC ,     // op_latch - (sp[9] * (r(2) / 4)) -> out[4]
                                  `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd10 };
            6'd39:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h5, `OP2_SRC_DC, `OP1_SRC_MUL,   // sp[10] * r2c1cos -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd11 };
            6'd40:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_OUT, 5'd2, 3'h4, `OP2_SRC_MUL, `OP1_SRC_DC,    // op_latch  + (sp[11] * r2c1sin) -> out[2]
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'hxx };

            6'd41:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_DC, `OP1_SRC_MUL,   // sp[10] * r2c1sin -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd12 };
            6'd42:    control = { `WRITE_SRC_ADDER, `WRITE_EN,  `WRITE_OUT, 5'd6, 3'hx, `OP2_SRC_MUL, `OP1_SRC_MEM,   // -op_latch + (sp[11] * r2c1cos) -> out[6]
                                  `OP2_NNEGATE, `OP1_NEGATE, `OP1_LATCH, `SRC_SPAD, 5'd14 };         // sp[12] -> op_latch

            6'd43:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd20, 3'hx, `OP2_SRC_MEM, `OP1_SRC_DC,    // op_latch + sp[14] -> sp[20]
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd13 };
            6'd44:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_DC, `OP1_SRC_MEM,   // sp[13] -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd15 };

            6'd45:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd21, 3'hx, `OP2_SRC_MEM, `OP1_SRC_DC,    // op_latch + sp[15] -> sp[21]
                                  `OP2_NNEGATE, `OP1_NEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd12 };
            6'd46:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_DC, `OP1_SRC_MEM,   // sp[12] -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd14 };

            6'd47:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd22, 3'hx, `OP2_SRC_MEM, `OP1_SRC_DC,    // op_latch - sp[14] -> sp[22]
                                  `OP2_NEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd13 };
            6'd48:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_DC, `OP1_SRC_MEM,   // sp[13] -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd15 };

            6'd49:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_SPAD, 5'd23, 3'hx, `OP2_SRC_MEM, `OP1_SRC_DC,    // op_latch + sp[15] -> sp[23]
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd20 };

            6'd50:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'hx, `OP2_SRC_DC, `OP1_SRC_MEM,  // sp[20] -> op_latch
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_LATCH, `SRC_SPAD, 5'd23 };
            6'd51:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_OUT, 5'd7, 3'hx, `OP2_SRC_MEM, `OP1_SRC_DC,      // -op_latch + sp[23] -> out[7]
                                  `OP2_NNEGATE, `OP1_NEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd23 };
            6'd52:    control = { `WRITE_SRC_ADDER, `WRITE_EN, `WRITE_OUT, 5'd1, 3'hx, `OP2_SRC_MEM, `OP1_SRC_DC,      // op_latch + sp[21] -> out[1]
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd21 };

            6'd53:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h6, `OP2_SRC_DC, `OP1_SRC_DC,    // sp[21] and _SQRT2 enter multiplier
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'd22 };
            6'd54:    control = { `WRITE_SRC_ADDER, `WRITE_NEN, `WRITE_SPAD, 5'hxx, 3'h6, `OP2_SRC_DC, `OP1_SRC_DC,    // sp[22] and _SQRT2 enter multiplier
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'hxx };

            6'd55:    control = { `WRITE_SRC_MUL, `WRITE_EN, `WRITE_OUT, 5'd3, 3'hx, `OP2_SRC_DC, `OP1_SRC_DC,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_SPAD, 5'hxx };
            6'd56:    control = { `WRITE_SRC_MUL, `WRITE_EN, `WRITE_OUT, 5'd5, 3'hx, `OP2_SRC_DC, `OP1_SRC_DC,
                                  `OP2_NNEGATE, `OP1_NNEGATE, `OP1_RETAIN, `SRC_DC, 5'hxx };

            default:  control = 21'h0;
        endcase
    end
endmodule


/**
 * This hardware component reads bytes sequentially from a memory buffer
 * and computes an 8-element DCT on them.
 *
 * @input  clock
 * @input  nreset       Holding this signal low for one full clock cycle will reset the module so it
 *                      starts at the beginning of a DCT transform.
 * @input  src_data_in  This bus should be hooked up to an input buffer containing the data that we
 *                      want to take the DCT of. This module treats the data as if it is signed and
 *                      in the 7q8 format, with values between [-128, 127] representing values in
 *                      the range [-0.5, 0.49609375].
 *                      We expect the input memory to have a one-cycle delay from the time that the
 *                      address is presented til the time that the requested data is presented on
 *                      the output bus.
 * @output fetch_addr   This bus holds the address of the input data that we are trying to fetch.
 * @output data_out
 *
 * @output result_addr
 * @output result_wren
 *
 * @output read_src_scratchpad    Read src can be either 0 for input memory or 1 for scratchpad. This signal is
 *                      useful for situations where the input memory and the scratchpad share the
 *                      same instantiated memory block. Because only one memory will be read from
 *                      on each cycle, this sort of sharing can be achieved with single read port
 *                      memories
 *
 * @output finished     This signal goes high one cycle before the DCT is finished. To initiate a
 *                      new DCT once 'finished' is high, nreset needs to be brought low for one
 *                      cycle
 */
module loeffler_dct_8(input             clock,
                      input             nreset,

                      output    [2:0]  fetch_addr,
                      input     [15:0]  src_data_in_3q12,

                      output    [4:0]  scratchpad_read_addr,
                      input     [15:0]  scratchpad_read_data,

                      output      [2:0] result_write_addr,
                      output            result_wren,
                      output reg [15:0] result_out,

                      output     [4:0]  scratchpad_write_addr,
                      output            scratchpad_wren,
                      output reg [15:0] scratchpad_write_data,

                      output            read_src_scratchpad,
                      output            finished);

    reg ucode_read_src_delayed;

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
    wire ucode_write_src;
    loeffler_dct_8_control_rom rom(.addr(ucode_pc),
                                   .control({ucode_write_src,
                                             ucode_scratchpad_write_enable,
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
    assign fetch_addr = ucode_readaddr[2:0];

    assign result_wren = ((ucode_write_dest == `WRITE_OUT) &&
                          (ucode_scratchpad_write_enable == `WRITE_EN));
    assign result_write_addr = ucode_scratchpad_writeaddr[2:0];

    assign scratchpad_wren = ((ucode_write_dest == `WRITE_SPAD) &&
                              (ucode_scratchpad_write_enable == `WRITE_EN));
    assign scratchpad_write_addr = ucode_scratchpad_writeaddr[4:0];
    assign scratchpad_read_addr = ucode_readaddr[4:0];
    assign read_src_scratchpad = (ucode_read_src == `SRC_SPAD) ? (1'b1) : (1'b0);

    wire [15:0] multiplier_consts;
    multiplier_constants mulrom(.select(ucode_coeff_select),
                                .out(multiplier_consts));


    reg [15:0] operand_bus;
    always @ * begin
        if (ucode_read_src_delayed) begin
            operand_bus = scratchpad_read_data;
        end else begin
            operand_bus = src_data_in_3q12;
        end
    end

    reg signed [15:0] multiplier_op1;
    wire signed [15:0] multiplier_out_3q12;
    wire signed [31:0] multiplier_out;
    pipelined_multiplier #(.SB_MAC16(1)) mul(.clock(clock),
                                             .nreset(nreset),
                                             .a(multiplier_op1),
                                             .b(multiplier_consts),
                                             .out(multiplier_out));

    // 7q8 * 7q8 = 14q16
    // 3q12 * 3q12 = 6q24
    assign multiplier_out_3q12 = multiplier_out[(12 + 15):12];

    reg [15:0] operand2;
    always @ * begin
        case (ucode_op2_sel)
            `OP2_SRC_MEM: operand2 = operand_bus;
            `OP2_SRC_MUL: operand2 = multiplier_out_3q12;
        endcase
    end

    always @ * begin
        multiplier_op1 = operand_bus;
    end

    // Operand latch
    reg  [15:0] operand_latch;
    always @ (posedge clock) begin
        if (nreset) begin
            // increment ucode program counter
            ucode_pc <= (ucode_pc < `UCODE_LEN) ? (ucode_pc + 6'h1) : (`UCODE_LEN);

            // operand latch
            if (ucode_latch_operand1) begin
                case (ucode_op1_src)
                    `OP1_SRC_MEM: operand_latch <= operand_bus;
                    `OP1_SRC_MUL: operand_latch <= multiplier_out_3q12;
                endcase
            end else begin
                operand_latch <= operand_latch;
            end

            ucode_read_src_delayed <= ucode_read_src;
        end else begin
            ucode_pc <= 'h0;
            operand_latch <= 'h0;
            ucode_read_src_delayed <= 'hx;
        end
    end

    reg  [15:0] arithmetic_result;
    always @* begin
        // adder
        if (ucode_write_src == `WRITE_SRC_ADDER) begin
            case ({ucode_negate_operand2, ucode_negate_operand1})
                2'b00: arithmetic_result =  operand_latch + operand2;
                2'b01: arithmetic_result = -operand_latch + operand2;
                2'b10: arithmetic_result =  operand_latch - operand2;
                2'b11: arithmetic_result = -operand_latch - operand2;
            endcase
        end else begin
            arithmetic_result = multiplier_out_3q12;
        end
        scratchpad_write_data = arithmetic_result;
        result_out = (result_wren) ? (arithmetic_result) : (16'h0000);
    end

    assign finished = ((ucode_pc == `UCODE_LEN) ||
                       (ucode_pc == (`UCODE_LEN - 1))) ? (1'b1) : (1'b0);

endmodule
