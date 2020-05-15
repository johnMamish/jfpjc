/**
 * Copyright John Mamish, 2020
 */

/**
 * This hardware component reads pixel bytes sequentially in row-major order from a memory buffer
 * and computes an 8x8 DCT on them. It outputs the resuting DCT coefficients in row-major order.
 *
 *
 */

module loeffler_dct_88(input             clock,
                       input             nreset,
                       input      [7:0]  fetch_data,
                       output reg [5:0]  fetch_addr,
                       output            fetch_clk,
                       )
