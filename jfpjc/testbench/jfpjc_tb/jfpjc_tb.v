`timescale 1ns/100ps

// taken from a file output by jmcujc.c, the same place that we got our huffman tables from.
`define FIXED_HEADER_SIZE (328)
`define FIXED_HEADER_INFO "\377\330\377\340\000\020\112\106\111\106\000\001\001\000\000\001\000\001\000\000\377\333\000\103\000\003\014\014\014\014\014\022\014\014\014\022\022\022\022\030\044\030\030\030\030\030\060\044\044\036\044\066\060\074\074\066\060\066\066\074\110\132\110\074\102\124\102\066\066\116\146\116\124\132\140\140\146\140\074\110\154\162\154\140\162\132\140\140\140\377\304\000\037\000\000\001\005\001\001\001\001\001\001\000\000\000\000\000\000\000\000\001\002\003\004\005\006\007\010\011\012\013\377\304\000\265\020\000\002\001\003\003\002\004\003\005\005\004\004\000\000\001\175\001\002\003\000\004\021\005\022\041\061\101\006\023\121\141\007\042\161\024\062\201\221\241\010\043\102\261\301\025\122\321\360\044\063\142\162\202\011\012\026\027\030\031\032\045\046\047\050\051\052\064\065\066\067\070\071\072\103\104\105\106\107\110\111\112\123\124\125\126\127\130\131\132\143\144\145\146\147\150\151\152\163\164\165\166\167\170\171\172\203\204\205\206\207\210\211\212\222\223\224\225\226\227\230\231\232\242\243\244\245\246\247\250\251\252\262\263\264\265\266\267\270\271\272\302\303\304\305\306\307\310\311\312\322\323\324\325\326\327\330\331\332\341\342\343\344\345\346\347\350\351\352\361\362\363\364\365\366\367\370\371\372\377\300\000\013\010\002\000\002\000\001\000\021\000\377\332\000\010\001\000\000\000\077\000"

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

    reg [7:0] huffman_out [0:32767];

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
            for (j = 0; j < 4; j = j + 1) begin
                huffman_out[outbuf_idx] = compressor.bit_packer_data_out[(j * 8) +: 8];
                outbuf_idx <= outbuf_idx + 1;

                // bytestuff
                if (compressor.bit_packer_data_out[(j * 8) +: 8] == 8'hff) begin
                    huffman_out[outbuf_idx] = 8'h00;
                    outbuf_idx <= outbuf_idx + 1;
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

        $readmemh("../pictures/checkerboard_highfreq.hex", hm01b0.hm01b0_image);
        $image_take_dcts(hm01b0.hm01b0_image, dct_testmem, 320, 240);

        for (i = 0; i < 5; i = i + 1) begin
            $dumpvars(1, compressor.dct_buffer_fetch_addr[i]);
        end
        for (i = 0; i < 4; i = i + 1) begin
            $dumpvars(1, compressor.encoder.index[i]);
        end

        for (i = 0; i < 64; i = i + 1) begin
            compressor.quantization_table_ebr.mem[i] = 8'h1;
        end


        //
        clock = 1'b0;
        hm01b0_mclk = 1'b0;
        nreset = 1'b0;
        #5000;
        nreset = 1'b1;

        // read some number of lines in
`define LINES_TO_READ (8 * 8)
        for (i = 0; i < `LINES_TO_READ; i = i + 1) begin
            while (!((hm01b0_hsync == 0))) begin
                #1000;
            end
            while (!((hm01b0_hsync == 1))) begin
                #1000;
            end
        end

        for (i = 0; i < (64 * 5); i = i + 1) begin
            /*if (dct_result[i] !== dct_testmem[i]) begin
                $display("%d, %h;%h", i, dct_result[i], dct_testmem[i]);
            end*/
            $display("%h", dct_testmem[i]);
            if ((i % 64) == 63) begin
                $display;
            end
        end
        for (i = 0; i < outbuf_idx; i = i + 1) begin
             $write("%h ", huffman_out[i]);
        end
        $display();

        /*$writememh("jfpjc_ingester_0.hex", compressor.ebrs[0].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_1.hex", compressor.ebrs[1].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_2.hex", compressor.ebrs[2].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_3.hex", compressor.ebrs[3].jpeg_buffer.mem);
        $writememh("jfpjc_ingester_4.hex", compressor.ebrs[4].jpeg_buffer.mem);*/

        $readmemh("jpeg_header_info.hextestcase", fixed_header_info);

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
