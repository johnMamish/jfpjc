#!/usr/bin/python3

# This tool finds the magnitude of the difference between 2 images of the same dimensions.
import numpy as np
from PIL import Image
import PIL
import sys
if __name__ == "__main__":
    if (len(sys.argv) != 3):
        print("2 args are required. Usage: " + sys.argv[0] + " <image 1> <image 2>\n");
        quit(0)

    try:
        img1 = Image.open(sys.argv[1])
        img2 = Image.open(sys.argv[2])
    except (FileNotFoundError) as e:
        print(e)
        quit(1)

    print(str(np.linalg.norm(np.array(img1).flatten() - np.array(img2).flatten())))
