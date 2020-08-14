#!/usr/bin/python3

# This tool takes a binary image which represents an image at the input and converts it to a
# Verilog-compatiable .bin file.
#
# The bin file is organized into words of configurable length, of which a configurable number of
# bits can be used. Unused bits will be padded with 'x'

import argparse
import numpy as np
from PIL import Image
import PIL

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Convert a .pbm image into a Verilog bin file")
    parser.add_argument('inputfile', metavar='<input file>', type=str,
                        help="pbm image to be input.")
    parser.add_argument('outputfile', metavar='<output file>', type=str,
                        help="bin file to write to.")
    parser.add_argument('--bitwidth', metavar='<bit width>', type=int, default=8,
                        help="bitwidth of output bin file")
    parser.add_argument('--lsbs-to-use', metavar='<number of bits>', type=int, default=None,
                        help=("optionally, you can specify to use only a limited number of the "
                              "LSbits of the words to hold information. For instance, if you have "
                              "words that are 8 bits long and only want to use the bottom 3 bits "
                              "to hold data from an image with pixels abc...lmno, it would look like\n"
                              "    xxxx_xcba\n"
                              "    xxxx_xfed\n"
                              "     .....   \n"
                              "    xxxx_xonm\n"
                              "This arg is set equal to bitwidth by default."))
    parser.add_argument('--msb-fill', metavar='bit', choices=['x', 'z', '0', '1'], type=str,
                        default='x', help='value to use to fill unused MSbits of output words')

    args = parser.parse_args()
    lsbs = args.bitwidth if args.lsbs_to_use is None else args.lsbs_to_use

    try:
        mask = Image.open(args.inputfile)
    except (FileNotFoundError) as e:
        print(e)
        quit(1)

    if (mask.mode != '1'): print("Warning: " + args.inputfile + " doesn't have one-bit depth. Rounding all non-zero pixels to 1.")
    if ((mask.size[0] % lsbs) != 0):
        print("Warning: mask image width {} is not a multiple of arg --lsbs-to-use {}".format(str(mask.size[0]), lsbs))

    arr = np.reshape(np.array(mask, dtype=int).flatten(), (-1, lsbs))

    with open(args.outputfile, "w") as f:
        for row in arr:
            s = ''.join(['0' if (x == 0) else '1' for x in row][::-1])
            s = ''.join([args.msb_fill for x in range(args.bitwidth - lsbs)]) + s + "\n"
            f.write(s)
        f.close()
