#!/bin/bash

# If we don't have images yet, get them.
IMAGE_COUNT=$(ls -1q ./dsp-test-images/ | wc -l)
echo $IMAGE_COUNT " images found"
if [ $IMAGE_COUNT -lt 20 ]
then
    echo "downloading dsp-test-images set from github"
    echo "================================================================"
    echo
    wget https://github.com/johnMamish/dsp-test-images/archive/master.zip -O dsp-test-images.zip
    unzip -o dsp-test-images.zip && mv dsp-test-images-master dsp-test-images
    echo
fi

IMAGE_COUNT=$(ls -1q ./dsp-test-images/ | wc -l)
echo $IMAGE_COUNT " images downloaded"
echo

PROJECT_BASE=$(git rev-parse --show-toplevel)

for f in ./dsp-test-images/*.tiff; do
    rm output.jpg 2> /dev/null

    # For all of the images, convert them to 320x240 grayscale pgm for comparison purposes.
    # echo "converting " $f
    newpgm=$(basename ${f%.tiff})
    convert "$f" "${newpgm}.pgm"
    convert -gravity center -crop 320x240+0+0 "${newpgm}.pgm" "${newpgm}_320x240.pgm"

    # Convert the image to a hex file
    $PROJECT_BASE/tools/image_to_hex.py "${newpgm}_320x240.pgm" > testimg.hex
    if [ "$?" -ne 0 ]; then exit 1; fi

    # Run verilog
    ./jfpjc_tb.vvp

    # Compare input and output image, providing a similarity score
    echo "Image ${newpgm}.pgm compressed to size" $(ls -l "output.jpg"  | awk '{print $5}')
    echo "output.jpg difference score to baseline"
    $PROJECT_BASE/tools/image_error.py "${newpgm}_320x240.pgm" "output.jpg"
    if [ "$?" -ne 0 ]; then exit 1; fi
    echo "imagemagick difference score to baseline"
    convert -quality 100 "${newpgm}_320x240.pgm" "${newpgm}_320x240_q100.jpg"
    $PROJECT_BASE/tools/image_error.py "${newpgm}_320x240.pgm" "${newpgm}_320x240_q100.jpg"
    if [ "$?" -ne 0 ]; then exit 1; fi
    echo
    echo "================================================================"
    echo

    rm output.jpg 2> /dev/null
    rm "${newpgm}.pgm"
    rm "${newpgm}_320x240.pgm"
    rm "${newpgm}_320x240_q100.jpg"

    # Also make a 100 and 90 quality jpeg conversion of the pnm images for
done
