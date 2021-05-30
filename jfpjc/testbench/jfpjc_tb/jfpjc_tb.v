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

    // interface to obfuscation table ebr
    wire [8:0]               obfuscation_table_ebr_raddr;
    wire                     obfuscation_table_ebr_ren;
    wire                     obfuscation_table_ebr_rclk;
    wire [7:0]               obfuscation_table_ebr_dout;

    ice40_ebr obfuscation_table(.din(8'h0), .write_en(1'b0), .waddr(9'h0), .wclk(1'b0),
                              .raddr(obfuscation_table_ebr_raddr),
                              .rclk(obfuscation_table_ebr_ren & obfuscation_table_ebr_rclk),
                              .dout(obfuscation_table_ebr_dout));
    defparam obfuscation_table.addr_width = 9;
    defparam obfuscation_table.data_width = 8;

    // interface to quantization table ebr
    wire [5:0]               quantization_table_ebr_raddr;
    wire                     quantization_table_ebr_ren;
    wire                     quantization_table_ebr_rclk;
    wire [7:0]               quantization_table_ebr_dout;
    ice40_ebr quantization_table(.din(8'h0), .write_en(1'b0), .waddr(9'h0), .wclk(1'b0),
                              .raddr({ 3'h0, quantization_table_ebr_raddr }),
                              .rclk(quantization_table_ebr_ren & quantization_table_ebr_rclk),
                              .dout(quantization_table_ebr_dout));

    wire compressor_data_good;
    wire compressor_vsync;
    wire [7:0] compressor_data_out;
    jfpjc compressor(.nreset(nreset),
                     .clock(clock),

                     .hm01b0_pixclk(hm01b0_pixclk),
                     .hm01b0_pixdata(hm01b0_pixdata),
                     .hm01b0_hsync(hm01b0_hsync),
                     .hm01b0_vsync(hm01b0_vsync),

                     .obfuscation_table_ebr_raddr(obfuscation_table_ebr_raddr),
                     .obfuscation_table_ebr_ren(obfuscation_table_ebr_ren),
                     .obfuscation_table_ebr_rclk(obfuscation_table_ebr_rclk),
                     .obfuscation_table_ebr_dout(obfuscation_table_ebr_dout),

                     .quantization_table_ebr_raddr(quantization_table_ebr_raddr),
                     .quantization_table_ebr_ren(quantization_table_ebr_ren),
                     .quantization_table_ebr_rclk(quantization_table_ebr_rclk),
                     .quantization_table_ebr_dout(quantization_table_ebr_dout),

                     .hsync(compressor_data_good),
                     .data_out(compressor_data_out));
    defparam compressor.quant_table_file = "./quantization_table.hextestcase";

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
    always @(posedge clock) begin : store_output
        if (compressor_data_good) begin
            huffman_out[outbuf_idx] = compressor_data_out;
            outbuf_idx = outbuf_idx + 1;
        end
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

        $readmemh("./testimg.hex", hm01b0.hm01b0_image);

        $readmemh("../common_data/jpeg_header_info.hextestcase", fixed_header_info);

        $readmemh("./quantization_table.hextestcase", fixed_header_info, `QUANT_TABLE_OFFSET, `QUANT_TABLE_OFFSET + 64);
        //$readmemh("./quantization_table.hextestcase", compressor.quantization_table_ebr.mem);

        for (i = 0; i < 5; i = i + 1) begin
            $dumpvars(1, compressor.dct_buffer_fetch_addr[i]);
        end
        for (i = 0; i < 4; i = i + 1) begin
            $dumpvars(1, compressor.encoder.index[i]);
            $dumpvars(1, compressor.encoder.valid[i]);
        end
        $dumpvars(1, compressor.encoder.do_rollback[0]); $dumpvars(1, compressor.encoder.do_rollback[1]);

        //
        clock = 1'b0;
        hm01b0_mclk = 1'b0;
        nreset = 1'b0;
        #5000;
        nreset = 1'b1;

        // read some number of lines in
`define LINES_TO_READ (260)
        for (i = 0; i < `LINES_TO_READ; i = i + 1) begin
            $display("line %d / %d", i, `LINES_TO_READ);
            while (!((hm01b0_hsync == 0))) begin
                #1000;
            end
            while (!((hm01b0_hsync == 1))) begin
                #1000;
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
        $fwrite(file_handle, "\377\331");
        $fclose(file_handle);

        $finish;
    end
endmodule
