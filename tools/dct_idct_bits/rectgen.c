/**
 * This generates pixels for an image that should result in high-magnitude DCT coefficients,
 * leading to an image that gets very bad compression.
 */

#include <stdlib.h>
#include <stdio.h>
#include <math.h>
#include <string.h>

#define PI ((float)3.14159265358)

static void mcu_fdct_floats(float* data_in, float* data_out)
{
    memset(data_out, 0, sizeof(float) * 64);
    for (int v = 0; v < 8; v++) {
        for (int u = 0; u < 8; u++) {
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    int data_in_idx = y * 8 + x;
                    float coeff = (cos(((2.f * (float)x + 1.f) * u * PI) / 16.f) *
                                   cos(((2.f * (float)y + 1.f) * v * PI) / 16.f));
                    *(data_out + (v * 8) + u) += ((float)data_in[data_in_idx]) * coeff;
                }
            }
            //data_out[v*8 + u] /= 4.f;
        }
    }

    for (int j = 0; j < 8; j++) {
        for (int i = 0; i < 8; i++) {
            // for u, v = 0, component is scaled by (1 / sqrt(2))
            float Cv = (j == 0) ? (1 / sqrt(2)) : 1;
            float Cu = (i == 0) ? (1 / sqrt(2)) : 1;


            int data_out_idx = j * 8 + i;
            data_out[data_out_idx] = data_out[data_out_idx] * Cu * Cv * 0.25f;
        }
    }
}

static void mcu_idct_floats(float* data_in, float* data_out)
{
    memset(data_out, 0, sizeof(float) * 64);
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
            for (int v = 0; v < 8; v++) {
                for (int u = 0; u < 8; u++) {
                    int data_in_idx = v * 8 + u;
                    float coeff = (cos(((2.f * (float)x + 1.f) * u * PI) / 16.f) *
                                   cos(((2.f * (float)y + 1.f) * v * PI) / 16.f));
                    float accum = ((float)data_in[data_in_idx]) * coeff;
                    float Cv = (v == 0) ? (1.f / sqrt(2)) : 1.f;
                    float Cu = (u == 0) ? (1.f / sqrt(2)) : 1.f;
                    *(data_out + (y * 8) + x) += Cv * Cu * accum;
                }
            }
        }
    }

    for (int i = 0; i < 64; i++) {
        data_out[i] /= 4.f;
    }
}

void print_8x8(float* nums)
{
    for (int y = 0; y < 8; y++) {
        for (int x = 0; x < 8; x++) {
            printf("%+8.2f ", nums[y * 8 + x]);
        }
        printf("\n");
    }
}

static float sgn(float x)
{
    if (x < 0)
        return -1.f;
    else if (x > 0)
        return 1.f;
    else
        return 0.f;
}



void main()
{
    float* data_in = calloc(64, sizeof(float));
    float* data_out = calloc(64, sizeof(float));

    for (int i = 0; i < 64; i++) {
        data_in[i] = 1023.f;
    }

    printf("data_in\n");
    print_8x8(data_in);
    printf("\n\n");

    printf("idct(data_in)\n");
    mcu_idct_floats(data_in, data_out);
    print_8x8(data_out);
    printf("\n\n");

    float scale = (128. / data_out[0]);
    for (int i = 0; i < 64; i++) {
        //data_out[i] = data_out[i] * scale;
        if (abs(data_out[i]) > 127) {
            data_out[i] = 127 * sgn(data_out[i]);
        }
    }
    print_8x8(data_out);
    printf("\n\n");
    printf("fdct(idct(data_in))\n");
    mcu_fdct_floats(data_out, data_in);
    print_8x8(data_in);
    printf("\n\n");

}
