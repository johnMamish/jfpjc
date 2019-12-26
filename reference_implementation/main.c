#include <pam.h>
#include <stdio.h>
#include <stdbool.h>

#include "util.h"

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

int main(int argc, char** argv)
{
    if (argc != 2) {
        printf("Usage: %s <image name>\r\n", argv[0]);
        return -1;
    }

    image_t* image = image_create_from_pam(argv[1], argv[0]);
    image_level_shift(image);
    image_dct_t* dcts = image_dct_create(image);

    printf("DCT block 0\n");
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            printf("% 5i ", dcts->blocks[0][i * 8 + j]);
        }
        printf("\n");
    }

    image_destroy(image);
    return 0;
}
