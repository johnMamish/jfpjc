`timescale 1ns/100ps


module loeffler_dct_8_tb();
    reg clock;
    reg nreset;


    wire [7:0] fetch_data;
    wire [2:0] fetch_addr;
    wire fetch_clk;

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
                       .fetch_clk(fetch_clk));

    // generate clock
    always
    begin
        #490;
        clock = ~clock;
        #10;
    end

    integer i;
    initial begin
        for (i = 0; i < 8; i = i + 1) begin
            data_rom.mem[i] = (i + 1);
        end
        clock = 'b0;

        $dumpfile("loeffler_dct_8_tb.vcd");
        $dumpvars(0, loeffler_dct_8_tb);

        // strobe reset for a few microseconds
        nreset = 1'b0; #3000;

        // let it run for a little
        nreset = 1'b1; #20000;

        $writememh("scratchpad_mem_state.hex", dct.scratchpad.mem);
        $finish;
    end
endmodule
