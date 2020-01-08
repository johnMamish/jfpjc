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

void image_jfif_RGB_to_YCbCr(image_t* im)
{
    for (int y = 0; y < im->height; y++) {
        for (int x = 0; x < im->width; x++) {
            int idx = y * im->width + x;

            int temp[3];
            memcpy(temp, im->components[idx], 3 * sizeof(int));
            im->components[idx][0] = ((76 * temp[0]) + (150 * temp[1]) + (29 * temp[2])) / 256;
            im->components[idx][1] = ((-43 * temp[0]) + (-85 * temp[1]) + (128 * temp[2]) + 128) / 256;
            im->components[idx][2] = ((128 * temp[0]) + (-107* temp[1]) + (-21 * temp[2]) + 128) / 256;
        }
    }
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


/**
 * data_in is 24q7, but should be treated as if it's just q7.
 * data_out is in 24q7, but should be treated as if it's just 8q7.
 */
#if 0
void mcu_fdct_fixedpoint(int* data_in, int* data_out)
{
    memset(data_out, 0, sizeof(data_out));

    // input data is  output data is in 16q15
    for (int v = 0; v < 8; v++) {
        for (int u = 0; u < 8; u++) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int data_in_idx = y * 8 + x;
                    float coeff = (((int)floor(128.f * cos(((2.f * (float)x + 1.f) * u * PI) / 16))) *
                                   ((int)floor(128.f * cos(((2.f * (float)y + 1.f) * v * PI) / 16)))) / 128;
                    data_out[v * 8 + u] += ((data_in[data_in_idx]) * coeff) / 128;
                }
            }
            data_out[v * 8 + u] /= 4.f;
        }
    }

    for (int j = 0; j < 8; j++) {
        for (int i = 0; i < 8; i++) {
            // for u, v = 0, component is scaled by (1 / sqrt(2))
            float Cv = (j == 0) ? (int)floor(128.f * (1 / sqrt(2))) : 1;
            float Cu = (i == 0) ? (int)floor(128.f * (1 / sqrt(2))) : 1;

            int data_out_idx = j * 8 + i;
            data_out[data_out_idx] = (data_out[j][i] * Cu * Cv) / (128 * 128);
        }
    }
}
#endif


/**
 * According to Loeffler et al, 1989
 *
 * NB: there's an error in the Stage 3 sqrt(2)c1 block. It should be sqrt(2)c6
 */
void loeffler_fdct_horizontal_inplace(float* data_in, float* data_out)
{
    const float N = 8.;
    float stages[4][8];

    stages[0][0] = (data_in[0] + data_in[7]);
    stages[0][1] = (data_in[1] + data_in[6]);
    stages[0][2] = (data_in[2] + data_in[5]);
    stages[0][3] = (data_in[3] + data_in[4]);
    stages[0][4] = (data_in[3] - data_in[4]);
    stages[0][5] = (data_in[2] - data_in[5]);
    stages[0][6] = (data_in[1] - data_in[6]);
    stages[0][7] = (data_in[0] - data_in[7]);

    const float block_1c3_cos = 0.8314696123 * 0.35355339059;     // k * cos((n * pi) / 16) for 1c3
    const float block_1c3_sin = 0.5555702330 * 0.35355339059;     // k * sin((n * pi) / 16) for 1c3
    const float block_1c1_cos = 0.9807852804 * 0.35355339059;     // k * cos((n * pi) / 16) for 1c1
    const float block_1c1_sin = 0.1950903220 * 0.35355339059;     // k * sin((n * pi) / 16) for 1c1
    stages[1][0] = stages[0][0] + stages[0][3];
    stages[1][1] = stages[0][1] + stages[0][2];
    stages[1][2] = stages[0][1] - stages[0][2];
    stages[1][3] = stages[0][0] - stages[0][3];
    stages[1][4] =  stages[0][4] * block_1c3_cos + stages[0][7] * block_1c3_sin;      // 1c3
    stages[1][7] = -stages[0][4] * block_1c3_sin + stages[0][7] * block_1c3_cos;
    stages[1][5] =  stages[0][5] * block_1c1_cos + stages[0][6] * block_1c1_sin;      // 1c1
    stages[1][6] = -stages[0][5] * block_1c1_sin + stages[0][6] * block_1c1_cos;

    const float block_r2c1_cos = 0.54119610014 * 0.35355339059;   // k * cos((n * pi) / 16) for sqrt(2)c1
    const float block_r2c1_sin = 1.30656296488 * 0.35355339059;   // k * sin((n * pi) / 16) for sqrt(2)c1
    data_out[0]  = (stages[1][0] + stages[1][1]) * 0.25 * 1.41421356237;
    data_out[4]  = (stages[1][0] - stages[1][1]) * 0.35355339059;
    data_out[2]  =  stages[1][2] * block_r2c1_cos + stages[1][3] * block_r2c1_sin;   // sqrt2 c6
    data_out[6]  = -stages[1][2] * block_r2c1_sin + stages[1][3] * block_r2c1_cos;
    stages[2][4] = stages[1][4] + stages[1][6];
    stages[2][5] = -stages[1][5] + stages[1][7];
    stages[2][6] = stages[1][4] - stages[1][6];
    stages[2][7] = stages[1][5] + stages[1][7];

    data_out[7] = -stages[2][4] + stages[2][7];
    data_out[3] = 1.41421356237f * stages[2][5];
    data_out[5] = 1.41421356237f * stages[2][6];
    data_out[1] = stages[2][4] + stages[2][7];
}

void loeffler_fdct_vertical_inplace(float* data_in, float* data_out)
{
    const float N = 8.;
    float stages[4][8];

    stages[0][0] = (data_in[0 * 8] + data_in[7 * 8]);
    stages[0][1] = (data_in[1 * 8] + data_in[6 * 8]);
    stages[0][2] = (data_in[2 * 8] + data_in[5 * 8]);
    stages[0][3] = (data_in[3 * 8] + data_in[4 * 8]);
    stages[0][4] = (data_in[3 * 8] - data_in[4 * 8]);
    stages[0][5] = (data_in[2 * 8] - data_in[5 * 8]);
    stages[0][6] = (data_in[1 * 8] - data_in[6 * 8]);
    stages[0][7] = (data_in[0 * 8] - data_in[7 * 8]);

    const float block_1c3_cos = 0.8314696123 * 0.35355339059;     // k * cos((n * pi) / 16) for 1c3
    const float block_1c3_sin = 0.5555702330 * 0.35355339059;     // k * sin((n * pi) / 16) for 1c3
    const float block_1c1_cos = 0.9807852804 * 0.35355339059;     // k * cos((n * pi) / 16) for 1c1
    const float block_1c1_sin = 0.1950903220 * 0.35355339059;     // k * sin((n * pi) / 16) for 1c1
    stages[1][0] = stages[0][0] + stages[0][3];
    stages[1][1] = stages[0][1] + stages[0][2];
    stages[1][2] = stages[0][1] - stages[0][2];
    stages[1][3] = stages[0][0] - stages[0][3];
    stages[1][4] =  stages[0][4] * block_1c3_cos + stages[0][7] * block_1c3_sin;      // 1c3
    stages[1][7] = -stages[0][4] * block_1c3_sin + stages[0][7] * block_1c3_cos;
    stages[1][5] =  stages[0][5] * block_1c1_cos + stages[0][6] * block_1c1_sin;      // 1c1
    stages[1][6] = -stages[0][5] * block_1c1_sin + stages[0][6] * block_1c1_cos;

    const float block_r2c1_cos = 0.54119610014 * 0.35355339059;   // k * cos((n * pi) / 16) for sqrt(2)c1
    const float block_r2c1_sin = 1.30656296488 * 0.35355339059;   // k * sin((n * pi) / 16) for sqrt(2)c1
    data_out[0 * 8]  = (stages[1][0] + stages[1][1]) * 0.25 * 1.41421356237;
    data_out[4 * 8]  = (stages[1][0] - stages[1][1]) * 0.35355339059;
    data_out[2 * 8]  =  stages[1][2] * block_r2c1_cos + stages[1][3] * block_r2c1_sin;   // sqrt2 c6
    data_out[6 * 8]  = -stages[1][2] * block_r2c1_sin + stages[1][3] * block_r2c1_cos;
    stages[2][4] = stages[1][4] + stages[1][6];
    stages[2][5] = -stages[1][5] + stages[1][7];
    stages[2][6] = stages[1][4] - stages[1][6];
    stages[2][7] = stages[1][5] + stages[1][7];

    data_out[7 * 8] = -stages[2][4] + stages[2][7];
    data_out[3 * 8] = 1.41421356237f * stages[2][5];
    data_out[5 * 8] = 1.41421356237f * stages[2][6];
    data_out[1 * 8] = stages[2][4] + stages[2][7];
}

void loeffler_fdct_8x8_inplace(float* data)
{
    static float data_f[64];
    for (int i = 0; i < 64; i++)
        data_f[i] = (float)data[i];

    // horizontal
    for (int i = 0; i < 8; i++) {
        loeffler_fdct_horizontal_inplace(&data_f[i * 8], &data_f[i * 8]);
    }

    // vertical
    for (int i = 0; i < 8; i++) {
        loeffler_fdct_vertical_inplace(&data_f[i], &data_f[i]);
    }

    for (int i = 0; i < 64; i++) {
        //data[i] = (int)round(data_f[i]);
        data[i] = data_f[i];
    }
}

#if 0
static void fdct_8_fast(int* data_in, int* data_out)
{

}

void mcu_fdct_fast(int* data_in, int* data_out)
{

}
#endif

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

void jpeg_zigzag_data_inplace_u8(uint8_t* data)
{
    uint8_t temp[64];
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
