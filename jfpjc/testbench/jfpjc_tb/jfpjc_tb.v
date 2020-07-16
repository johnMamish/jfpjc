`timescale 1ns/100ps

`define QUANT_TABLE_OFFSET (25)

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

    reg [7:0] huffman_out [0:(1 << 17)];

    // empty out DCT output buffers whenever a new result is available.
    reg signed [15:0] dct_result [0:(320 * 240) - 1];
    integer outbuf_idx; initial outbuf_idx = 0;
    always @(posedge clock) begin : DCT_ingestion
        integer j;
//`define _ENABLE_DCT_INGESTION_QUANT
`define _READ_FROM_HUFFMAN_OUTPUT
`ifdef _ENABLE_DCT_INGESTION_QUANT
        reg [1:0] quantizer_output_buffer_prev;

        if (compressor.quotient_valid) begin
            dct_result[outbuf_idx] <= compressor.quotient;
            outbuf_idx <= outbuf_idx + 1;
        end
 `elsif _READ_FROM_HUFFMAN_OUTPUT
        if (compressor.bit_packer_data_out_valid) begin
            for (j = 3; j >= 0; j = j - 1) begin
                huffman_out[outbuf_idx] = compressor.bit_packer_data_out[(j * 8) +: 8];
                outbuf_idx = outbuf_idx + 1;

                // bytestuff
                if (compressor.bit_packer_data_out[(j * 8) +: 8] == 8'hff) begin
                    huffman_out[outbuf_idx] = 8'h00;
                    outbuf_idx = outbuf_idx + 1;
                end
            end
        end

/*        if ((quantizer_output_buffer_prev != compressor.quotient_tag[7:6])) begin
            for (j = 0; j < 64; j = j + 1) begin
                dct_result[outbuf_idx] =
                     compressor.quotient_output_mem.mem[j + (quantizer_output_buffer_prev * 64)];
                outbuf_idx = outbuf_idx + 1;
            end
        end*/
`else
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
`endif
    end

    integer i, j, k;
    reg signed [15:0] dct_testmem [0:(320 * 240) - 1];
    reg signed [15:0] test;
    reg signed [7:0] test2;
    integer file_handle;
    reg [7:0] fixed_header_info [0:327];
    initial begin
        $dumpfile("jfpjc_tb.vcd");
        $dumpvars(0, jfpjc_tb);

        //$readmemh("../pictures/checkerboard_highfreq_80x80.hex", hm01b0.hm01b0_image);
        $readmemh("../pictures/boat_gray.hex", hm01b0.hm01b0_image);
        $image_take_dcts(hm01b0.hm01b0_image, dct_testmem, 320, 240);

        $readmemh("jpeg_header_info.hextestcase", fixed_header_info);
        $readmemh("quantization_table.hextestcase", fixed_header_info, `QUANT_TABLE_OFFSET, `QUANT_TABLE_OFFSET + 64);
        $readmemh("quantization_table.hextestcase", compressor.quantization_table_ebr.mem);

        for (i = 0; i < 5; i = i + 1) begin
            $dumpvars(1, compressor.dct_buffer_fetch_addr[i]);
        end
        for (i = 0; i < 4; i = i + 1) begin
            $dumpvars(1, compressor.encoder.index[i]);
        end
        $dumpvars(1, compressor.encoder.do_rollback[0]); $dumpvars(1, compressor.encoder.do_rollback[1]);

        //
        clock = 1'b0;
        hm01b0_mclk = 1'b0;
        nreset = 1'b0;
        #5000;
        nreset = 1'b1;

        // read some number of lines in
//`define LINES_TO_READ (80 * 8)
`define LINES_TO_READ (280)
        for (i = 0; i < `LINES_TO_READ; i = i + 1) begin
            $display("line %d / %d", i, `LINES_TO_READ);
            while (!((hm01b0_hsync == 0))) begin
                #1000;
            end
            while (!((hm01b0_hsync == 1))) begin
                #1000;
            end
        end

        //while

        for (i = 0; i < (64 * 40 * 5); i = i + 1) begin
            if (dct_result[i] !== dct_testmem[i]) begin
                $display("%d, %h;%h", i, dct_result[i], dct_testmem[i]);
            end
        end
        for (i = 0; i < outbuf_idx; i = i + 1) begin
             $write("%h ", huffman_out[i]);
        end
        $display();

        file_handle = $fopen("output.jpg", "w");
        for (i = 0; i < 9'h148; i = i + 1) begin
            $fwrite(file_handle, "%c", fixed_header_info[i]);
        end
        for (i = 0; i < outbuf_idx; i = i + 1) begin
            $fwrite(file_handle, "%c", huffman_out[i]);
        end
        $fclose(file_handle);

        $finish;
    end
endmodule
