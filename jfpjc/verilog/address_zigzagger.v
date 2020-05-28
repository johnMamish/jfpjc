/**
 * Given an address in row-major order, this module outputs the "zig-zag" index. For instance, the
 * pixel at location (row = 2, col = 3) is index 19 in row-major indexing and is index 17 in the
 * zig-zag order
 */
module row_major_to_zig_zag(input [5:0] row_major_index,
                            output reg [5:0] zig_zag_index);
    // I'm sure there's a smarter way to synthesize this with for loops, but I don't have time for that.
    // It took me like 10 minutes to make this table because the octal numbers make everything easy when
    // talking about row-major indexes in an 8x8 block.
    always @* begin
        case(row_major_index)
            6'o 0_0: zig_zag_index = 6'd0;

            6'o 0_1: zig_zag_index = 6'd1;
            6'o 1_0: zig_zag_index = 6'd2;

            6'o 2_0: zig_zag_index = 6'd3;
            6'o 1_1: zig_zag_index = 6'd4;
            6'o 0_2: zig_zag_index = 6'd5;

            6'o 0_3: zig_zag_index = 6'd6;
            6'o 1_2: zig_zag_index = 6'd7;
            6'o 2_1: zig_zag_index = 6'd8;
            6'o 3_0: zig_zag_index = 6'd9;

            6'o 4_0: zig_zag_index = 6'd10;
            6'o 3_1: zig_zag_index = 6'd11;
            6'o 2_2: zig_zag_index = 6'd12;
            6'o 1_3: zig_zag_index = 6'd13;
            6'o 0_4: zig_zag_index = 6'd14;

            6'o 0_5: zig_zag_index = 6'd15;
            6'o 1_4: zig_zag_index = 6'd16;
            6'o 2_3: zig_zag_index = 6'd17;
            6'o 3_2: zig_zag_index = 6'd18;
            6'o 4_1: zig_zag_index = 6'd19;
            6'o 5_0: zig_zag_index = 6'd20;

            6'o 6_0: zig_zag_index = 6'd21;
            6'o 5_1: zig_zag_index = 6'd22;
            6'o 4_2: zig_zag_index = 6'd23;
            6'o 3_3: zig_zag_index = 6'd24;
            6'o 2_4: zig_zag_index = 6'd25;
            6'o 1_5: zig_zag_index = 6'd26;
            6'o 0_6: zig_zag_index = 6'd27;

            6'o 0_7: zig_zag_index = 6'd28;
            6'o 1_6: zig_zag_index = 6'd29;
            6'o 2_5: zig_zag_index = 6'd30;
            6'o 3_4: zig_zag_index = 6'd31;
            6'o 4_3: zig_zag_index = 6'd32;
            6'o 5_2: zig_zag_index = 6'd33;
            6'o 6_1: zig_zag_index = 6'd34;
            6'o 7_0: zig_zag_index = 6'd35;

            6'o 7_1: zig_zag_index = 6'd36;
            6'o 6_2: zig_zag_index = 6'd37;
            6'o 5_3: zig_zag_index = 6'd38;
            6'o 4_4: zig_zag_index = 6'd39;
            6'o 3_5: zig_zag_index = 6'd40;
            6'o 2_6: zig_zag_index = 6'd41;
            6'o 1_7: zig_zag_index = 6'd42;

            6'o 2_7: zig_zag_index = 6'd43;
            6'o 3_6: zig_zag_index = 6'd44;
            6'o 4_5: zig_zag_index = 6'd45;
            6'o 5_4: zig_zag_index = 6'd46;
            6'o 6_3: zig_zag_index = 6'd47;
            6'o 7_2: zig_zag_index = 6'd48;

            6'o 7_3: zig_zag_index = 6'd49;
            6'o 6_4: zig_zag_index = 6'd50;
            6'o 5_5: zig_zag_index = 6'd51;
            6'o 4_6: zig_zag_index = 6'd52;
            6'o 3_7: zig_zag_index = 6'd53;

            6'o 4_7: zig_zag_index = 6'd54;
            6'o 5_6: zig_zag_index = 6'd55;
            6'o 6_5: zig_zag_index = 6'd56;
            6'o 7_4: zig_zag_index = 6'd57;

            6'o 7_5: zig_zag_index = 6'd58;
            6'o 6_6: zig_zag_index = 6'd59;
            6'o 5_7: zig_zag_index = 6'd60;

            6'o 6_7: zig_zag_index = 6'd61;
            6'o 7_6: zig_zag_index = 6'd62;

            6'o 7_7: zig_zag_index = 6'd63;
        endcase
    end
endmodule


module zig_zag_to_row_major(input [5:0] zig_zag_index,
                            output reg [5:0] row_major_index);
    // I'm sure there's a smarter way to synthesize this with for loops, but I don't have time for that.
    // It took me like 10 minutes to make this table because the octal numbers make everything easy when
    // talking about row-major indexes in an 8x8 block.
    always @* begin
        case(row_major_index)
            6'd0 : zig_zag_index = 6'o 0_0;

            6'd1 : zig_zag_index = 6'o 0_1;
            6'd2 : zig_zag_index = 6'o 1_0;

            6'd3 : zig_zag_index = 6'o 2_0;
            6'd4 : zig_zag_index = 6'o 1_1;
            6'd5 : zig_zag_index = 6'o 0_2;

            6'd6 : zig_zag_index = 6'o 0_3;
            6'd7 : zig_zag_index = 6'o 1_2;
            6'd8 : zig_zag_index = 6'o 2_1;
            6'd9 : zig_zag_index = 6'o 3_0;

            6'd10: zig_zag_index = 6'o 4_0;
            6'd11: zig_zag_index = 6'o 3_1;
            6'd12: zig_zag_index = 6'o 2_2;
            6'd13: zig_zag_index = 6'o 1_3;
            6'd14: zig_zag_index = 6'o 0_4;

            6'd15: zig_zag_index = 6'o 0_5;
            6'd16: zig_zag_index = 6'o 1_4;
            6'd17: zig_zag_index = 6'o 2_3;
            6'd18: zig_zag_index = 6'o 3_2;
            6'd19: zig_zag_index = 6'o 4_1;
            6'd20: zig_zag_index = 6'o 5_0;

            6'd21: zig_zag_index = 6'o 6_0;
            6'd22: zig_zag_index = 6'o 5_1;
            6'd23: zig_zag_index = 6'o 4_2;
            6'd24: zig_zag_index = 6'o 3_3;
            6'd25: zig_zag_index = 6'o 2_4;
            6'd26: zig_zag_index = 6'o 1_5;
            6'd27: zig_zag_index = 6'o 0_6;

            6'd28: zig_zag_index = 6'o 0_7;
            6'd29: zig_zag_index = 6'o 1_6;
            6'd30: zig_zag_index = 6'o 2_5;
            6'd31: zig_zag_index = 6'o 3_4;
            6'd32: zig_zag_index = 6'o 4_3;
            6'd33: zig_zag_index = 6'o 5_2;
            6'd34: zig_zag_index = 6'o 6_1;
            6'd35: zig_zag_index = 6'o 7_0;

            6'd36: zig_zag_index = 6'o 7_1;
            6'd37: zig_zag_index = 6'o 6_2;
            6'd38: zig_zag_index = 6'o 5_3;
            6'd39: zig_zag_index = 6'o 4_4;
            6'd40: zig_zag_index = 6'o 3_5;
            6'd41: zig_zag_index = 6'o 2_6;
            6'd42: zig_zag_index = 6'o 1_7;

            6'd43: zig_zag_index = 6'o 2_7;
            6'd44: zig_zag_index = 6'o 3_6;
            6'd45: zig_zag_index = 6'o 4_5;
            6'd46: zig_zag_index = 6'o 5_4;
            6'd47: zig_zag_index = 6'o 6_3;
            6'd48: zig_zag_index = 6'o 7_2;

            6'd49: zig_zag_index = 6'o 7_3;
            6'd50: zig_zag_index = 6'o 6_4;
            6'd51: zig_zag_index = 6'o 5_5;
            6'd52: zig_zag_index = 6'o 4_6;
            6'd53: zig_zag_index = 6'o 3_7;

            6'd54: zig_zag_index = 6'o 4_7;
            6'd55: zig_zag_index = 6'o 5_6;
            6'd56: zig_zag_index = 6'o 6_5;
            6'd57: zig_zag_index = 6'o 7_4;

            6'd58: zig_zag_index = 6'o 7_5;
            6'd59: zig_zag_index = 6'o 6_6;
            6'd60: zig_zag_index = 6'o 5_7;

            6'd61: zig_zag_index = 6'o 6_7;
            6'd62: zig_zag_index = 6'o 7_6;

            6'd63: zig_zag_index = 6'o 7_7;
        endcase
    end
endmodule // zig_zag_to_row_major
