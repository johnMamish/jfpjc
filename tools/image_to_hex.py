#!/usr/bin/python3
from PIL import Image
import PIL
import numpy as np
import sys

# Read image
try:
    img = Image.open(sys.argv[1])

except (FileNotFoundError, ValueError, IndexError) as e:
    print("failed to open file " + sys.argv[1])
    print(e);
    quit(1)

# if the image is too small, this will add borders around the edges.
# new_im = Image.new('L', (320, 240), color=(0))
# new_im.paste(img);
#img.show()

pix = np.array(img)

i = 0
for row in pix:
    print('// %d'%i)
    print(' '.join(["%.2x"%x  for x in row]))
    print()
    i = i + 1
