#!/usr/bin/python3

# Given an image and a mask in .pbm format (with squares having a value of 0 being unobfuscated and
# squares having a value of 1 being obfuscated), this program will white-out all of the obfuscated
# areas

import argparse
import numpy as np
from PIL import Image, ImageDraw
import PIL.ImageOps
import PIL

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="obfuscate an image from a provided pbm bitmap")
    parser.add_argument("imagefile", metavar="<input image file>", type=str)
    parser.add_argument("maskfile", metavar="<input mask pbm file>", type=str)
    parser.add_argument("targetfile", metavar="<output filename>", type=str)
    parser.add_argument("--show-original-image", action="store_true", help="show preview of original image")
    parser.add_argument("--show-obfuscated-image", action="store_true", help="show preview of obfuscated image")
    parser.add_argument("--stretch-factor-x", metavar="<STRETCH X>", type=int, default=8,
                        help="factor by which to stretch the mask along the x axis for it to match up with the input image")
    parser.add_argument("--stretch-factor-y", metavar="<STRETCH Y>", type=int, default=8,
                        help="factor by which to stretch the mask along the y axis for it to match up with the input image")
    parser.add_argument("--obfuscation-color", metavar="<OBFUSCATION COLOR>", type=str,
                        choices=["black", "white", "gray"], default="gray",
                        help="Color to use to cover up obfuscated pixels")

    args = parser.parse_args()

    try:
        img = Image.open(args.imagefile)
        mask_img = Image.open(args.maskfile)
    except (FileNotFoundError) as e:
        print(e)
        quit(1)

    mask_img = mask_img.resize((mask_img.size[0] * args.stretch_factor_x, mask_img.size[1] * args.stretch_factor_y))
    mask_img = mask_img.crop((0, 0, img.size[0], img.size[1]))

    backg = Image.new(img.mode, img.size, color=PIL.ImageColor.getcolor(args.obfuscation_color, img.mode))

    if (mask_img.mode != '1'): print("Warning: " + args.maskfile + " doesn't have one-bit depth. Rounding all non-zero pixels to 1.")

    pixes = [(x, y) for x in range(mask_img.size[0]) for y in range(mask_img.size[1]) if (mask_img.getpixel((x, y)) != 0)]
    mask_invert = Image.new(img.mode, img.size, color=PIL.ImageColor.getcolor("white", img.mode))
    mask_invert_drw = ImageDraw.Draw(mask_invert)
    mask_invert_drw.point(pixes, fill=PIL.ImageColor.getcolor("black", img.mode))

    masked_image = Image.composite(img, backg, mask_invert)

    if(args.show_original_image): img.show()

    if(args.show_obfuscated_image): masked_image.show()

    masked_image.save(args.targetfile)
