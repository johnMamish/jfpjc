#include <pam.h>
#include "util.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

jmcujc_source_image_slice_t* grayscale_source_image_from_pam(const char* file, const char* argv0)
{
    jmcujc_source_image_slice_t* result = calloc(1, sizeof(jmcujc_source_image_slice_t));

    pm_init(argv0, 0);

    struct pam image;
    tuple * tuplerow;
    unsigned int row;

    FILE* fp = fopen(file, "r");
    pnm_readpaminit(fp, &image, PAM_STRUCT_SIZE(tuple_type));
    if (image.depth != 1) {
        printf("PAM image depth is not 1; not a grayscale image. This example only works with "
               "grayscale images.\n");
        goto _fail_cleanup1;
    }

    result->height = image.height;
    result->width  = image.width;
    result->yoffset = 0;

    result->pixels = calloc(result->height * result->width, sizeof(uint8_t));
    tuplerow = pnm_allocpamrow(&image);
    for (row = 0; row < image.height; row++) {
        unsigned int column;
        pnm_readpamrow(&image, tuplerow);
        for (column = 0; column < image.width; ++column) {
            unsigned int plane;
            for (plane = 0; plane < image.depth; ++plane) {
                result->pixels[(row * result->width) + column] = tuplerow[column][plane];
            }
        }
    }
    pnm_freepamrow(tuplerow);

    return result;

//_fail_cleanup0:
//    free(result->);
//    pnm_freepamrow(tuplerow);

_fail_cleanup1:
    free(result);
    return NULL;
}
