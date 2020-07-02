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

    integer i, j, k;
    reg signed [15:0] dct_testmem [0:(320 * 240) - 1];
    initial begin
        $dumpfile("jfpjc_tb.vcd");
        $dumpvars(0, jfpjc_tb);

        $readmemh("../pictures/checkerboard_highfreq.hex", hm01b0.hm01b0_image);

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
`define LINES_TO_READ 15
        for (i = 0; i < `LINES_TO_READ; i = i + 1) begin
            while (!((hm01b0_hsync == 0))) begin
                #1000;
            end
            while (!((hm01b0_hsync == 1))) begin
                #1000;
            end
        end

        $writememh("jfpjc_ingester_0.hex", compressor.ebrs[0].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_1.hex", compressor.ebrs[1].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_2.hex", compressor.ebrs[2].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_3.hex", compressor.ebrs[3].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_4.hex", compressor.ebrs[4].jpeg_buffer.mem);

        // test image_take_dcts function
        $image_take_dcts(hm01b0.hm01b0_image, dct_testmem, 320, 240);

        for (i = 0; i < 4; i = i + 1) begin
            for (j = 0; j < 8; j = j + 1) begin
                for (k = 0; k < 8; k = k + 1) begin
                    $write("%h ", dct_testmem[(i * 64) + (j * 8) + k]);
                end
                $write("\n");
            end
            $write("\n");
        end
        $write("\n");
        $finish;
    end
endmodule
