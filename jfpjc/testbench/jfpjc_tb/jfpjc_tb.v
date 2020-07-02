`timescale 1ns/100ps

module jfpjc_tb();
    reg clock;
    reg nreset;

    //hm01b0
    reg hm01b0_mclk;          // 100kHz
    wire       hm01b0_pixclk;
    wire [7:0] hm01b0_pixdata;
    wire       hm01b0_hsync;
    wire       hm01b0_vsync;
    hm01b0_sim hm01b0(.mclk(hm01b0_mclk),
                      .nreset(nreset),

                      .clock(hm01b0_pixclk),
                      .pixdata(hm01b0_pixdata),
                      .hsync(hm01b0_hsync),
                      .vsync(hm01b0_vsync));

    jfpjc compressor(.nreset(nreset),
                     .clock(clock),

                     .hm01b0_pixclk(hm01b0_pixclk),
                     .hm01b0_pixdata(hm01b0_pixdata),
                     .hm01b0_hsync(hm01b0_hsync),
                     .hm01b0_vsync(hm01b0_vsync));

    // generate hm01b0 clock
    always begin
        #1250; hm01b0_mclk = ~hm01b0_mclk; #1250;
    end

    // generate system clock
    always begin
        #250; clock = ~clock; #250;
    end

    // empty out DCT output buffers whenever a new result is available.
    reg signed [15:0] dct_result [0:(320 * 240) - 1];
    integer outbuf_idx; initial outbuf_idx = 0;
    always @(posedge clock) begin : DCT_ingestion
        integer j;
        reg [1:0] dcts_frontbuffer_prev;
        dcts_frontbuffer_prev <= compressor.dcts_frontbuffer;

        if (dcts_frontbuffer_prev != compressor.dcts_frontbuffer) begin
            // Wish I could do this with a for loop; I'm sure there's a verilog trick, but I
            // don't know how right now. Right now, verilog is telling me that I can't index
            // compressor.dcts with a variable because it's a scope index expression.
            //
            // There's definately a way to do it with a generate block, but I'll do it later.
            for (j = 0; j < 64; j = j + 1) begin
                dct_result[outbuf_idx] = compressor.dcts[0].dct_output_mem.mem[j + (dcts_frontbuffer_prev * 64)];
                outbuf_idx = outbuf_idx + 1;
            end
            for (j = 0; j < 64; j = j + 1) begin
                dct_result[outbuf_idx] = compressor.dcts[1].dct_output_mem.mem[j + (dcts_frontbuffer_prev * 64)];
                outbuf_idx = outbuf_idx + 1;
            end
            for (j = 0; j < 64; j = j + 1) begin
                dct_result[outbuf_idx] = compressor.dcts[2].dct_output_mem.mem[j + (dcts_frontbuffer_prev * 64)];
                outbuf_idx = outbuf_idx + 1;
            end
            for (j = 0; j < 64; j = j + 1) begin
                dct_result[outbuf_idx] = compressor.dcts[3].dct_output_mem.mem[j + (dcts_frontbuffer_prev * 64)];
                outbuf_idx = outbuf_idx + 1;
            end
            for (j = 0; j < 64; j = j + 1) begin
                dct_result[outbuf_idx] = compressor.dcts[4].dct_output_mem.mem[j + (dcts_frontbuffer_prev * 64)];
                outbuf_idx = outbuf_idx + 1;
            end
        end
    end

    integer i, j, k;
    reg signed [15:0] dct_testmem [0:(320 * 240) - 1];
    initial begin
        $dumpfile("jfpjc_tb.vcd");
        $dumpvars(0, jfpjc_tb);

        $readmemh("../pictures/boat_gray.hex", hm01b0.hm01b0_image);
        $image_take_dcts(hm01b0.hm01b0_image, dct_testmem, 320, 240);

        for (i = 0; i < 5; i = i + 1) begin
            $dumpvars(1, compressor.dct_buffer_fetch_addr[i]);
        end


        //
        clock = 1'b0;
        hm01b0_mclk = 1'b0;
        nreset = 1'b0;
        #5000;
        nreset = 1'b1;

        // read some number of lines in
`define LINES_TO_READ 240
        for (i = 0; i < `LINES_TO_READ; i = i + 1) begin
            while (!((hm01b0_hsync == 0))) begin
                #1000;
            end
            while (!((hm01b0_hsync == 1))) begin
                #1000;
            end
        end

        for (i = 0; i < (320 * 10 * 8); i = i + 1) begin
            if (dct_result[i] != dct_testmem[i]) begin
                $display("foodct_result[%d] = %h; groundtruth[%d] = %h", i, dct_result[i], i, dct_testmem[i]);
            end
        end

        /*$writememh("jfpjc_ingester_0.hex", compressor.ebrs[0].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_1.hex", compressor.ebrs[1].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_2.hex", compressor.ebrs[2].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_3.hex", compressor.ebrs[3].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_4.hex", compressor.ebrs[4].jpeg_buffer.mem);*/

        $finish;
    end
endmodule
