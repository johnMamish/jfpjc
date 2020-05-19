/**
 * This pipelined multiplier will hopefully infer an iCE40 sysDSP block
 */

module pipelined_multiplier (clk, a, b, out);
    parameter width = 16, depth = 2;
    input clk;
    input signed [width - 1 : 0] a;
    input signed [width - 1 : 0] b;
    output signed [(2 * width) - 1 : 0] pdt;
    reg signed [(2 * width) - 1 : 0] internal [(depth - 1) : 0];
    integer i;

    assign out = internal[depth - 1];

    always @ (posedge clk)
    begin
        // registering input of the multiplier
        internal[0] <= a * b;
        for (i = 1; i < level; i = i + 1)
          internal [i] <= internal [i - 1];
    end
endmodule
