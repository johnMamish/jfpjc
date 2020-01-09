/**
 * Copyright 2020, John Mamish
 */

#include <math.h>
#include <pam.h>
#include <stdio.h>
#include <stdbool.h>
#include <string.h>

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

static void fdct_8(float* data_in, float* data_out)
{
    float temp[8];
    for (int i = 0; i < 8; i++) {
        temp[i] = 0.f;
        for (int j = 0; j < 8; j++) {
            float coeff = cos((2.f * PI * (float)(2 * j + 1) * (float)i) / (4 * 8));
            temp[i] += coeff * data_in[j];
        }
    }

    for (int i = 0; i < 8; i++) {
        data_out[i] = temp[i] / 2.f;
    }
    data_out[0] /= 1.41421356237f;
}

float fdct_8x8_test[] = {
    0,  0,  0,  0,  0,  0,  0,  0,
    0, -1, -1, -1, -1, -1, -1,  1,
    0, -1,  2,  2,  2,  2, -1,  2,
    0, -1,  2, -3, -3,  2, -1,  3,
    0, -1,  2, -3, -3,  2, -1,  4,
    0, -1,  2,  2,  2,  2, -1,  5,
    0, -1, -1, -1, -1, -1, -1,  6,
    0,  0,  0,  0,  0,  0,  0,  9
};

void do_fdct_tests()
{
#if 0
    float dcttest[8] = {1, 2, -3, -4, 5, 6, -7, -8};
    float dctout[8] = { 0 };
    loeffler_fdct_horizontal_inplace(dcttest, dcttest);
    //dctout[0] /= 1.41421356237f;
    for (int i = 0; i < 8; i++) {
        //dctout[i] /= 2.f * 1.41421356237f;
        printf("%3.5f ", dcttest[i]);
    }
    printf("\r\n");
#endif


    float regular[64];
    memcpy(regular, fdct_8x8_test, sizeof(float) * 64);

    // do horizontal
    for (int i = 0; i < 8; i++) {
        fdct_8(&regular[8 * i], &regular[8 * i]);
    }

    // do vertical
    for (int i = 0; i < 8; i++) {
        float temp[8];
        for (int j = 0; j < 8; j++) {
            temp[j] = regular[j * 8 + i];
        }
        fdct_8(temp, temp);
        for (int j = 0; j < 8; j++) {
            regular[j * 8 + i] = temp[j];
        }
    }

    // print results
    for (int i = 0; i < 64; i++) {
        printf("%+3.6f ", regular[i]);
        if ((i % 8) == 7) {
            printf("\n");
        }
    }
    printf("\n");

    float loeffler[64];
    memcpy(loeffler, fdct_8x8_test, sizeof(float) * 64);

    loeffler_fdct_8x8_inplace(loeffler);

    // horizontal
    /*for (int i = 0; i < 8; i++)
        loeffler_fdct_horizontal_inplace(&loeffler[8 * i], &loeffler[8 * i]);
    for (int i = 0; i < 8; i++)
    loeffler_fdct_vertical_inplace(&loeffler[i], &loeffler[i]);*/

    // print results
    for (int i = 0; i < 64; i++) {
        printf("%+3.6f ", loeffler[i]);
        if ((i % 8) == 7) {
            printf("\n");
        }
    }
    for (int i = 0; i < 64; i++) {
        if (fabs(loeffler[i] - regular[i]) > 0.001) {
            printf("error at index (%i, %i)\n", i % 8, i / 8);
        }
    }
}

int main(int argc, char** argv)
{
    //do_fdct_tests();

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

    const component_params_t lum_params = {2, 2, 0, 0};
    const component_params_t chrom_params1 = {1, 1, 1, 1};
    const component_params_t chrom_params2 = {1, 1, 1, 1};
    const component_params_t* component_params[] = { &lum_params, &chrom_params1, &chrom_params2 };

    const jpeg_quantization_table_t* quant_tables[] = { &lum_quant_table_high, &chrom_quant_table_medium, NULL, NULL };

    uint8_t* jpeg_out;
    //uncoded_jpeg_scan_t* scan = uncoded_jpeg_scan_create(image, component_params, 1, quant_tables);
    image_jfif_RGB_to_YCbCr(image);
    uncoded_jpeg_scan_t* scan = uncoded_jpeg_scan_create(image, component_params, 3, quant_tables);

    for (int x = 0; x < 0; x++) {
        printf("MCU (X, Y) (%i, 3) DC diff = %i\n", x,
               scan->components[0].blocks[3 * scan->components[0].mcu_width + x].values[0] *
               quant_tables[scan->components[0].quant_table_selector]->Q[0]);
        //image_dct_printblock(scan->components[0].blocks[3 * scan->components[0].mcu_width + x].values);
        //printf("MCU (X, Y) (1, 3)\n");
        //image_dct_printblock(scan->components[0].blocks[3 * scan->components[0].mcu_width + x].values);
    }

    const jpeg_huffman_table_t* dc_huffs[] = { &lum_dc_huffman_table, &chrom_dc_huffman_table };
    const jpeg_huffman_table_t* ac_huffs[] = { &lum_ac_huffman_table, &chrom_ac_huffman_table };

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
