#!/bin/bash

# If we don't have images yet, get them.
IMAGE_COUNT=$(ls -1q ./dsp-test-images/ | wc -l)
>&2 echo $IMAGE_COUNT " images found"
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
>&2 echo $IMAGE_COUNT " images downloaded"
>&2 echo

PROJECT_BASE=$(git rev-parse --show-toplevel)

mask_rand_seed=0
for f in ./dsp-test-images/*.tiff; do
    rm output.jpg 2> /dev/null

    # Generate a mask and corresponding .bin file
    $PROJECT_BASE/tools/generate_test_obfuscation_mask.py obfuscation_mask.pbm --seed $mask_rand_seed
    $PROJECT_BASE/tools/mask_to_bin.py obfuscation_mask.pbm obfuscation_mask.bin --bitwidth 8 --lsbs-to-use 5

    # For all of the images, convert them to 320x240 masked grayscale pgm for comparison purposes.
    >&2 echo "converting " $f
    newpgm=$(basename ${f%.tiff})
    convert "$f" "${newpgm}.pgm"
    convert -gravity center -crop 320x240+0+0 "${newpgm}.pgm" "${newpgm}_crop.pgm"
    convert "${newpgm}_crop.pgm" -extent 320x240 -gravity NorthWest -background black "${newpgm}_320x240.pgm"
    $PROJECT_BASE/tools/mask_image.py "${newpgm}_320x240.pgm" obfuscation_mask.pbm "${newpgm}_320x240_obfuscated.pgm"
    rm "${newpgm}.pgm"
    rm "${newpgm}_crop.pgm"

    # Convert the image to a hex file
    $PROJECT_BASE/tools/image_to_hex.py "${newpgm}_320x240.pgm" > testimg.hex
    if [ "$?" -ne 0 ]; then exit 1; fi

    rm "${newpgm}_320x240.pgm"

    # Run verilog
    #     mask bin file ---------------- obfuscation_mask.bin
    #     image hex file --------------- testimg.hex
    #     mask pbm file ---------------- obfuscation_mask.pgm
    #     obfuscated image pgm file ---- ${newpgm}_320x240_obfuscated.pgm
    ./jfpjc_obfuscated_tb.vvp

    # Compare input and output image, providing a similarity score
    convert -quality 100 "${newpgm}_320x240_obfuscated.pgm" "${newpgm}_320x240_obfuscated_q100.jpg"
    echo "Image ${newpgm}.pgm compressed to size" $(ls -l "output.jpg"  | awk '{print $5}')
    SCORE1=$($PROJECT_BASE/tools/image_error.py "${newpgm}_320x240_obfuscated.pgm" "output.jpg")
    if [ "$?" -ne 0 ]; then exit 1; fi
    SCORE2=$($PROJECT_BASE/tools/image_error.py "${newpgm}_320x240_obfuscated.pgm" "${newpgm}_320x240_obfuscated_q100.jpg")
    if [ "$?" -ne 0 ]; then exit 1; fi
    >&2 echo "     jfpjc     imagemagick"
    printf "% 10.1f      % 10.1f" $SCORE1 $SCORE2

    THRESHOLD=000.0
    if (($(echo "sqrt(($SCORE1 - $SCORE2) * ($SCORE1 - $SCORE2)) > $THRESHOLD" | bc -l))); then
        >&2 printf " ************************"
        stdbuf -i0 -o0 -e0 echo
        >&2 echo "Scores for $f differ by more than $THRESHOLD. Retaining images."
        mv "output.jpg" "${newpgm}_320x240_obfuscated_jfpjc.jpg"
    else
        stdbuf -i0 -o0 -e0 echo
        rm output.jpg
        rm "${newpgm}_320x240_obfuscated.pgm"
        rm "${newpgm}_320x240_obfuscated_q100.jpg"
    fi

    # Also make a 100 and 90 quality jpeg conversion of the pnm images for


    mask_rand_seed=$(($mask_rand_seed + 1))
done
