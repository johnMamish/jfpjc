#include "util.h"

#include <math.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// normally there's a different quant table for each component, but because we are starting with
// single-component grayscale images, we just need one quant table.
// of course, the different quant table for each component isn't a hard and fast rule.
const int quant_table_high_quality[64] =
{
    3,  2,  2,  3,  4,  6,  8, 10,
    2,  2,  2,  3,  4,  9, 10,  9,
    2,  2,  3,  4,  6,  9, 11,  9,
    2,  3,  4,  5,  8, 14, 13, 10,
    3,  4,  6,  9, 11, 17, 16, 12,
    4,  6,  9, 10, 13, 17, 18, 15,
    8, 10, 12, 14, 16, 19, 19, 16,
    12, 15, 15, 16, 18, 16, 16, 16,
};


// TODO improve
const int quant_table_low_quality[64] =
{
    24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24,
    24, 24, 24, 24, 24, 24, 24, 24
};

bytearray_t* bytearray_create()
{
    bytearray_t* res = calloc(1, sizeof(bytearray_t));
    res->capacity = 128;
    res->size = 0;
    res->data = malloc(res->capacity);
    return res;
}

void bytearray_add_byte(bytearray_t* arr, uint8_t byte)
{
    if (arr->size == arr->capacity) {
        arr->capacity *= 2;
        arr->data = realloc(arr->data, arr->capacity);
    }

    arr->data[arr->size++] = byte;
}

void bytearray_add_bytes(bytearray_t* arr, const uint8_t* bytes, int len)
{
    if ((arr->size + len) > arr->capacity) {
        arr->capacity *= 2;
        arr->data = realloc(arr->data, arr->capacity);
    }

    memcpy(arr->data + arr->size, bytes, len);
    arr->size += len;
}

image_t* image_create_from_pam(const char* file, char* argv0)
{
    image_t* result = calloc(1, sizeof(image_t*));

    pm_init(argv0, 0);

    struct pam image;
    tuple * tuplerow;
    unsigned int row;

    FILE* fp = fopen(file, "r");
    pnm_readpaminit(fp, &image, PAM_STRUCT_SIZE(tuple_type));

    result->height = image.height;
    result->width  = image.width;
    result->depth  = image.depth;
    if (result->depth > 4) {
        goto _fail_cleanup1;
    }

    result->components = calloc(result->height * result->width, 4 * sizeof(int));
    tuplerow = pnm_allocpamrow(&image);
    for (row = 0; row < image.height; row++) {
        unsigned int column;
        pnm_readpamrow(&image, tuplerow);
        for (column = 0; column < image.width; ++column) {
            unsigned int plane;
            for (plane = 0; plane < image.depth; ++plane) {
                result->components[(row * result->width) + column][plane] = tuplerow[column][plane];
            }
        }
    }
    pnm_freepamrow(tuplerow);

    return result;

//_fail_cleanup0:
//    free(result->components);
//    pnm_freepamrow(tuplerow);

_fail_cleanup1:
    free(result);
    return NULL;
}

void image_destroy(image_t* image)
{
    free(image->components);
    free(image);
}

void image_level_shift(image_t* im)
{
    for (int y = 0; y < im->height; y++) {
        for (int x = 0; x < im->width; x++) {
            int idx = y * im->width + x;
            for (int i = 0; i < 4; i++) {
                im->components[idx][i] -= 128;
            }
        }
    }
}

void image_pad_out(image_t* im)
{
    fprintf(stderr, "image_pad_out() unimplemented\n");
}

int* image_copy_mcu(image_t* im, int xstart, int ystart)
{
    int* result = calloc(64, sizeof(int));

    for (int y = ystart; y < (ystart + 8); y++) {
        for (int x = xstart; x < (xstart + 8); x++) {
            int im_idx = (y * im->width) + x;
            int res_idx = (y - ystart) * 8 + (x - xstart);

            result[res_idx] = im->components[im_idx][0];
        }
    }

    return result;
}


void mcu_fdct_floats(int* data_in, int* data_out)
{
    float data_out_f[8][8];
    memset(data_out_f, 0, sizeof(data_out_f));

    for (int v = 0; v < 8; v++) {
        for (int u = 0; u < 8; u++) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int data_in_idx = y * 8 + x;
                    float coeff = (cos(((2.f * (float)x + 1.f) * u * PI) / 16.f) *
                                   cos(((2.f * (float)y + 1.f) * v * PI) / 16.f));
                    data_out_f[v][u] += ((float)data_in[data_in_idx]) * coeff;
                }
            }
            data_out_f[v][u] /= 4.f;
        }
    }

    for (int j = 0; j < 8; j++) {
        for (int i = 0; i < 8; i++) {
            // for u, v = 0, component is scaled by (1 / sqrt(2))
            float Cv = (j == 0) ? (1 / sqrt(2)) : 1;
            float Cu = (i == 0) ? (1 / sqrt(2)) : 1;


            int data_out_idx = j * 8 + i;
            data_out[data_out_idx] = (int)round(data_out_f[j][i] * Cu * Cv);
        }
    }
}


void jpeg_zigzag_data_inplace(int* data)
{
    int temp[64];
    memcpy(temp, data, sizeof(temp));

    // zigzag starts on [1, 0] and moves in the downwards direction
    int zigdir = -1;
    int zig_x = 1;
    int zig_y = 0;

    for (int i = 1; i < 64; i++) {
        // copy data over
        int zigidx = (zig_x + (8 * zig_y));
        data[i] = temp[zigidx];

        // update zig coordinates
        // check and see if moving in the zig direction would put us out of bounds
        int nx = zig_x + zigdir;
        int ny = zig_y - zigdir;
        if ((nx < 0) && (ny > 7)) {
            zig_x++;
            zigdir = -zigdir;
        } else if ((nx < 0) && (zigdir == -1)) {
            zig_y++;
            zigdir = -zigdir;
        } else if ((ny < 0) && (zigdir == 1)) {
            zig_x++;
            zigdir = -zigdir;
        } else if ((nx > 7) && (zigdir == 1)) {
            zig_y++;
            zigdir = -zigdir;
        } else if ((ny > 7) && (zigdir == -1)) {
            zig_x++;
            zigdir = -zigdir;
        } else {
            zig_x = nx;
            zig_y = ny;
        }
    }

    data[0] = temp[0];
}
