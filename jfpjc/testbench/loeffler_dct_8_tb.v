`timescale 1ns/100ps

`include "fixed_point_consts.v"

module loeffler_dct_8_tb();

    task loeffler_dct_8_test_q7();
        //input [7:0] _data_in_q7 [7:0];
        //output [15:0] _data_out_7q8 [7:0];
        input [63:0] _data_in_q7;

        reg signed [7:0] _data_in_q7 [8];
        reg signed [15:0] _data_out_7q8 [8];

        reg signed [15:0] scratchpad_7q8 [23:0];

        scratchpad_7q8[0] = data_in_q7[0] + data_in_q7[7];
        scratchpad_7q8[1] = data_in_q7[1] + data_in_q7[6];
        scratchpad_7q8[2] = data_in_q7[2] + data_in_q7[5];
        scratchpad_7q8[3] = data_in_q7[3] + data_in_q7[4];
        scratchpad_7q8[4] = data_in_q7[3] - data_in_q7[4];
        scratchpad_7q8[5] = data_in_q7[2] - data_in_q7[5];
        scratchpad_7q8[6] = data_in_q7[1] - data_in_q7[6];
        scratchpad_7q8[7] = data_in_q7[0] - data_in_q7[7];


        scratchpad_7q8[8] = scratchpad_7q8[0] + scratchpad_7q8[3];
        scratchpad_7q8[9] = scratchpad_7q8[1] + scratchpad_7q8[2];
        scratchpad_7q8[10] = scratchpad_7q8[1] - scratchpad_7q8[2];
        scratchpad_7q8[11] = scratchpad_7q8[0] - scratchpad_7q8[3];
        scratchpad_7q8[12] = (scratchpad_7q8[4] * `_1C3_COS_7Q8) + (scratchpad_7q8[7] * `_1C3_SIN_7Q8);
        scratchpad_7q8[13] = (scratchpad_7q8[7] * `_1C3_COS_7Q8) - (scratchpad_7q8[4] * `_1C3_SIN_7Q8);
        scratchpad_7q8[14] = (scratchpad_7q8[5] * `_1C1_COS_7Q8) + (scratchpad_7q8[6] * `_1C1_SIN_7Q8);
        scratchpad_7q8[15] = (scratchpad_7q8[6] * `_1C1_COS_7Q8) - (scratchpad_7q8[5] * `_1C1_SIN_7Q8);

        data_out_7q8[0] = (scratchpad_7q8[8] * `_SQRT2_OVER4_7Q8) + (scratchpad_7q8[9] * `_SQRT2_OVER4_7Q8);
        data_out_7q8[4] = (scratchpad_7q8[8] * `_SQRT2_OVER4_7Q8) - (scratchpad_7q8[9] * `_SQRT2_OVER4_7Q8);
        data_out_7q8[2] = (scratchpad_7q8[10] * `_R2C1_COS_7Q8) + (scratchpad_7q8[11] * `_R2C1_SIN_7Q8);
        data_out_7q8[6] = (scratchpad_7q8[11] * `_R2C1_COS_7Q8) - (scratchpad_7q8[10] * `_R2C1_SIN_7Q8);
        scratchpad_7q8[20] = scratchpad_7q8[12] + scratchpad_7q8[14];
        scratchpad_7q8[21] = scratchpad_7q8[15] - scratchpad_7q8[13];
        scratchpad_7q8[22] = scratchpad_7q8[12] - scratchpad_7q8[14];
        scratchpad_7q8[23] = scratchpad_7q8[13] + scratchpad_7q8[15];

        data_out[7] = scratchpad_7q8[23] - scratchpad_7q8[20];
        data_out[3] = scratchpad_7q8[21] * `_SQRT2_7Q8;
        data_out[5] = scratchpad_7q8[22] * `_SQRT2_7Q8;
        data_out[1] = scratchpad_7q8[23] + scratchpad_7q8[20];
    endtask


    reg clock;
    reg nreset;


    wire [7:0] fetch_data;
    wire [2:0] fetch_addr;
    wire fetch_clk;

    wire [15:0] result_out;
    wire  [2:0] result_addr;
    wire        result_wren;
    wire        result_clk;

    // memory holding the 8 (int8_t) elements that we want to take the dct of.
    ice40_ebr #(.addr_width(9), .data_width(8))  data_rom (.din(8'h00),
                                                           .write_en(1'b0),
                                                           .waddr(9'h00),
                                                           .wclk(clock),

                                                           .raddr({ 6'h0, fetch_addr }),
                                                           .rclk(fetch_clk),
                                                            .dout(fetch_data));

    loeffler_dct_8 dct(.clock(clock),
                       .nreset(nreset),
                       .fetch_data(fetch_data),
                       .fetch_addr(fetch_addr),
                       .fetch_clk(fetch_clk),
                       .result_out(result_out),
                       .result_addr(result_addr),
                       .result_wren(result_wren),
                       .result_clk(result_clk));

    ice40_ebr #(.addr_width(8), .data_width(16)) output_mem(.din(result_out),
                                                            .write_en(result_wren),
                                                            .waddr({5'h0, result_addr}),
                                                            .wclk(result_clk),
                                                            .raddr(8'h0),
                                                            .rclk(1'b0),
                                                            .dout());

    // generate clock
    always
    begin
        #490;
        clock = ~clock;
        #10;
    end

    integer i;
    reg [15:0] scratchpad_result [7:0];
    reg [15:0] signed groundtruth [7:0];
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            data_rom.mem[i] = (i + 1);
        end

        scratchpad_result[0] = 16'h0009;
        scratchpad_result[1] = 16'h0009;
        scratchpad_result[2] = 16'h0009;
        scratchpad_result[3] = 16'h0009;
        scratchpad_result[4] = 16'hffff;
        scratchpad_result[5] = 16'hfffd;
        scratchpad_result[6] = 16'hfffb;
        scratchpad_result[7] = 16'hfff9;

        clock = 'b0;

        $dumpfile("loeffler_dct_8_tb.vcd");
        $dumpvars(0, loeffler_dct_8_tb);

        loeffler_dct_8_test_q7(data_rom.mem, groundtruth);

        // strobe reset for a few microseconds
        nreset = 1'b0; #3000;

        // let it run for 16 uinstructions
        nreset = 1'b1;
        while (dct.ucode_pc != 6'd57) begin
            #1000;
        end

        // check the result
        for (i = 0; i < 8; i = i + 1) begin
            if (dct.scratchpad.mem[i] != scratchpad_result[i]) begin
                $display("bad result at location %d. %h != %h", i, dct.scratchpad.mem[i], scratchpad_result[i]);
            end
        end

        $writememh("scratchpad_mem_state.hex", dct.scratchpad.mem, 0, 23);
        $writememh("output.hex", output_mem.mem, 0, 7);
        $finish;
    end
endmodule
