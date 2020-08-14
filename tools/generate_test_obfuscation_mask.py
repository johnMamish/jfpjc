#!/usr/bin/python3

# This python script generates an obfuscation map which is stored as a pbm file. Pixels that are
# white (1) should be considered obfuscated and pixels that are black (0) should be considered
# not obfuscated.

# usage:

from PIL import Image, ImageDraw
import PIL
import numpy as np
import sys
import math

import argparse

def generate_image(width, height, num_circles, radius_circles, noise_level):
    image_out = Image.new("1", (args.width, args.height), color=0)
    draw = ImageDraw.Draw(image_out)

    # apply static
    obfu_points = [(x, y) for x in range(width) for y in range (height) if (np.random.uniform() < noise_level)]
    draw.point(obfu_points, fill=1)

    # generate circles
    for n in range(num_circles):
        radius = math.ceil(np.random.exponential(radius_circles))
        while (radius > (math.floor(min(width, height) / 2) - 1)):
            radius = math.ceil(np.random.exponential(radius_circles))

        x = round(np.random.uniform(radius, width - radius))
        y = round(np.random.uniform(radius, height - radius))

        draw.ellipse([(x - radius, y - radius), (x + radius, y + radius)], fill=1, outline=None, width=0)

    return image_out


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Generate a pbm binary obfuscation map")
    parser.add_argument('filename', metavar='output_filename', type=str)
    parser.add_argument('--width', metavar='W', type=int, default=40,
                        help="width of obfuscation map")
    parser.add_argument('--height', metavar='H', type=int, default=30,
                        help="height of obfuscation map")
    parser.add_argument('--seed', metavar='S', type=int, default=0,
                        help="seed for random generation")
    parser.add_argument('--circles', metavar='C', type=int, default=1,
                        help="Number of circles on image.")
    parser.add_argument('--radius_circles', metavar='N', type=int, default=10,
                        help="Radius of circles on image. Radiuses are normally distributed around this mean.")
    parser.add_argument('--noise', metavar='N', type=float, default=0.2,
                        help="Density of salt and pepper noise to superimpose on image. 1 will completely cover the image with salt and pepper noise, 0 will cover the image with no noise.")

    args = parser.parse_args()

    np.random.seed(args.seed)
    image_out = generate_image(args.width, args.height, args.circles, args.radius_circles, args.noise)

    image_out.save(args.filename)
