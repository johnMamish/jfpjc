/**
 * Copyright 2020, John Mamish
 */

#include <pam.h>
#include <stdio.h>
#include <stdbool.h>

#include "util.h"
#include "jpeg.h"

typedef struct image_dct
{
    int width;
    int height;

    // 8x8 blocks
    int** blocks;
} image_dct_t;

/**
 *
 */
image_dct_t* image_dct_create(image_t* image)
{
    image_dct_t* result = calloc(1, sizeof(image_dct_t));
    result->width  = (image->width + 7)/ 8;
    result->height = (image->height + 7) / 8;
    result->blocks = calloc(result->width * result->height, sizeof(int*));

    for (int block_y = 0; block_y < result->height; block_y++) {
        for (int block_x = 0; block_x < result->width; block_x++) {
            int blockidx = (block_y * result->width) + block_x;
            int* this_mcu = image_copy_mcu(image, block_x * 8, block_y * 8);
            result->blocks[blockidx] = calloc(64, sizeof(int));
            mcu_fdct_floats(this_mcu, result->blocks[blockidx]);
            free(this_mcu);
        }
    }

    return result;
}

void image_dct_destroy(image_dct_t* dct)
{
    for (int i = 0; i < dct->height * dct->width; i++) {
        free(dct->blocks[i]);
    }
    free(dct->blocks);
    free(dct);
}

void image_dct_printblock(int* block)
{
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            printf("% 5i ", block[i * 8 + j]);
        }
        printf("\n");
    }
}

int main(int argc, char** argv)
{
    if (argc != 2) {
        printf("Usage: %s <image name>\r\n", argv[0]);
        return -1;
    }

    image_t* image = image_create_from_pam(argv[1], argv[0]);
    image_level_shift(image);

    if (((image->width % 8) != 0) || ((image->height % 8) != 0)) {
        printf("This program only works on images with width and height that are multiples of 8.\n");
        printf("%s has dimensions %ix%i\n", argv[1], image->width, image->height);
        return -1;
    }

    const component_params_t lum_params = {1, 1, 0, 0};
    //const component_params_t chrom_params  {2, 1, 1, 1};
    const component_params_t* component_params[] = { &lum_params };

    const jpeg_quantization_table_t* quant_tables[] = { &chrom_quant_table_medium };

    uint8_t* jpeg_out;
    uncoded_jpeg_scan_t* scan = uncoded_jpeg_scan_create(image, component_params, 1, quant_tables);
    printf("MCU (X, Y) (0, 3)\n");
    image_dct_printblock(scan->components[0].blocks[3 * scan->components[0].mcu_width + 0].values);
    printf("MCU (X, Y) (1, 3)\n");
    image_dct_printblock(scan->components[0].blocks[3 * scan->components[0].mcu_width + 1].values);

    //int jpeg_len = jpeg_compress(scan, dc, ac, quant, &jpeg_out);

    image_destroy(image);
    return 0;
}
