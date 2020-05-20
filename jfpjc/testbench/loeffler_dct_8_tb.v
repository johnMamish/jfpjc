`timescale 1ns/100ps

`include "fixed_point_consts.v"

module loeffler_dct_8_tb();
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
    initial begin
        clock = 'b0;

        $dumpfile("loeffler_dct_8_tb.vcd");
        $dumpvars(0, loeffler_dct_8_tb);

        // strobe reset for a few microseconds

        // let it run for 57 uinstructions with testcase 1
        nreset = 1'b0; #3000;
        $readmemh("dct_testcase_1_in.hex", data_rom.mem);
        nreset = 1'b1;
        while (dct.ucode_pc != 6'd57) begin
            #1000;
        end
        for (i = 0; i < 8; i = i + 1) begin
            $display("%h", output_mem.mem[i]);
        end
        $writememh("scratchpad_mem_state_1.hex", dct.scratchpad.mem, 0, 23);
        $writememh("output_1.hex", output_mem.mem, 0, 7);

        // let it run for 57 uinstructions with testcase 2
        nreset = 1'b0; #3000;
        $readmemh("dct_testcase_2_in.hex", data_rom.mem);
        nreset = 1'b1;
        while (dct.ucode_pc != 6'd57) begin
            #1000;
        end
        for (i = 0; i < 8; i = i + 1) begin
            $display("%h", output_mem.mem[i]);
        end
        $writememh("scratchpad_mem_state_2.hex", dct.scratchpad.mem, 0, 23);
        $writememh("output_2.hex", output_mem.mem, 0, 7);

        // let it run for 57 uinstructions with testcase 3
        nreset = 1'b0; #3000;
        $readmemh("dct_testcase_3_in.hex", data_rom.mem);
        nreset = 1'b1;
        while (dct.ucode_pc != 6'd57) begin
            #1000;
        end
        for (i = 0; i < 8; i = i + 1) begin
            $display("%h", output_mem.mem[i]);
        end
        $writememh("scratchpad_mem_state_3.hex", dct.scratchpad.mem, 0, 23);
        $writememh("output_3.hex", output_mem.mem, 0, 7);

        // check the result
        for (i = 0; i < 8; i = i + 1) begin
            if (dct.scratchpad.mem[i] != scratchpad_result[i]) begin
                $display("bad result at location %d. %h != %h", i, dct.scratchpad.mem[i], scratchpad_result[i]);
            end
        end

        $finish;
    end
endmodule
