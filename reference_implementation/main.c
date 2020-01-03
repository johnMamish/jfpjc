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
    if (argc != 3) {
        printf("Usage: %s <image name> <output file name>\r\n", argv[0]);
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

    const jpeg_quantization_table_t* quant_tables[] = { &lum_quant_table_medium, NULL, NULL, NULL };

    uint8_t* jpeg_out;
    uncoded_jpeg_scan_t* scan = uncoded_jpeg_scan_create(image, component_params, 1, quant_tables);

    for (int x = 0; x < 0; x++) {
        printf("MCU (X, Y) (%i, 3) DC diff = %i\n", x,
               scan->components[0].blocks[3 * scan->components[0].mcu_width + x].values[0] *
               quant_tables[scan->components[0].quant_table_selector]->Q[0]);
        //image_dct_printblock(scan->components[0].blocks[3 * scan->components[0].mcu_width + x].values);
        //printf("MCU (X, Y) (1, 3)\n");
        //image_dct_printblock(scan->components[0].blocks[3 * scan->components[0].mcu_width + x].values);
    }

    const jpeg_huffman_table_t* dc_huffs[] = { &lum_dc_huffman_table, NULL };
    const jpeg_huffman_table_t* ac_huffs[] = { &lum_ac_huffman_table, NULL };

    int jpeg_len = jpeg_compress(scan, dc_huffs, ac_huffs, quant_tables, &jpeg_out);

    FILE* outfile = fopen(argv[2], "wb");
    if (outfile == NULL) {
        printf("failed to open %s for writing\n", argv[2]);
        return -1;
    }
    printf("writing %i bytes to file %s... ", jpeg_len, argv[2]);
    if (fwrite(jpeg_out, jpeg_len, 1, outfile) != 1) {
        printf("failed.\n");
        return -1;
    } else {
        printf("done.\n");
    }

    fclose(outfile);

    image_destroy(image);

    return 0;
}
