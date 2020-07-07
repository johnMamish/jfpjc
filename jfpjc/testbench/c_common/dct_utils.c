#include "dct_utils.h"

#include "vpi_user.h"

// k * cos((n * pi) / 16) for 1c3 = 0.8314696123 * 0.35355339059
// 75.2560385539
const int16_t _1C3_COS_7Q8 = (75);

// k * sin((n * pi) / 16) for 1c3 = 0.5555702330 * 0.35355339059
// 50.2844773345
const int16_t _1C3_SIN_7Q8 = (50);

// k * cos((n * pi) / 16) for 1c1 = 0.9807852804 * 0.35355339059
// 88.7705500995
const int16_t _1C1_COS_7Q8 = (89);

// k * sin((n * pi) / 16) for 1c1 = 0.1950903220 * 0.35355339059
// 17.6575602725
const int16_t _1C1_SIN_7Q8 = (18);

// k * cos((n * pi) / 16) for sqrt= (2);c1 = 0.54119610014 * 0.35355339059
// 48.9834793417
const int16_t _R2C1_COS_7Q8 = (49);

// k * sin((n * pi) / 16) for sqrt(2)c1 = 1.30656296488 * 0.35355339059
// 118.256580161
const int16_t _R2C1_SIN_7Q8 = (118);

// 1.41421356237
// 362.038671967
const int16_t _SQRT2_7Q8 = (362);

// 1.41421356237 * 0.25
// 90.5096679917
const int16_t _SQRT2_OVER4_7Q8 = (90);


static int16_t _8q7_multiply(int16_t a, int16_t b)
{
    int32_t result = (((int32_t)a) * ((int32_t)b));

    return (int16_t)((((uint32_t)result) & (0x00ffff00ul)) >> 8);
}

/**
 * input is q8, ranging from -0.5 to 0.49609375 (127 / 256).
 *
 * output is 7q8.
 */
static void dct8_q8(const int8_t* input, int16_t* output)
{
    int16_t scratchpad[4][8];

    // stage 1
    scratchpad[0][0] = (((int16_t)input[0]) + ((int16_t)input[7]));
    scratchpad[0][1] = (((int16_t)input[1]) + ((int16_t)input[6]));
    scratchpad[0][2] = (((int16_t)input[2]) + ((int16_t)input[5]));
    scratchpad[0][3] = (((int16_t)input[3]) + ((int16_t)input[4]));
    scratchpad[0][4] = (((int16_t)input[3]) - ((int16_t)input[4]));

    scratchpad[0][5] = (((int16_t)input[2]) - ((int16_t)input[5]));
    scratchpad[0][6] = (((int16_t)input[1]) - ((int16_t)input[6]));
    scratchpad[0][7] = (((int16_t)input[0]) - ((int16_t)input[7]));

    // stage 2
    scratchpad[1][0] = scratchpad[0][0] + scratchpad[0][3];
    scratchpad[1][1] = scratchpad[0][1] + scratchpad[0][2];
    scratchpad[1][2] = scratchpad[0][1] - scratchpad[0][2];
    scratchpad[1][3] = scratchpad[0][0] - scratchpad[0][3];
    scratchpad[1][4] = (_8q7_multiply(scratchpad[0][4], _1C3_COS_7Q8) +
                        _8q7_multiply(scratchpad[0][7], _1C3_SIN_7Q8));
    scratchpad[1][7] = (_8q7_multiply(scratchpad[0][7], _1C3_COS_7Q8) -
                        _8q7_multiply(scratchpad[0][4], _1C3_SIN_7Q8));
    scratchpad[1][5] = (_8q7_multiply(scratchpad[0][5], _1C1_COS_7Q8) +
                        _8q7_multiply(scratchpad[0][6], _1C1_SIN_7Q8));
    scratchpad[1][6] = (_8q7_multiply(scratchpad[0][6], _1C1_COS_7Q8) -
                        _8q7_multiply(scratchpad[0][5], _1C1_SIN_7Q8));

    // stage 3
    output[0] = (_8q7_multiply(scratchpad[1][0], _SQRT2_OVER4_7Q8) +
                 _8q7_multiply(scratchpad[1][1], _SQRT2_OVER4_7Q8));
    output[4] = (_8q7_multiply(scratchpad[1][0], _SQRT2_OVER4_7Q8) -
                 _8q7_multiply(scratchpad[1][1], _SQRT2_OVER4_7Q8));
    output[2] = (_8q7_multiply(scratchpad[1][2], _R2C1_COS_7Q8) +
                 _8q7_multiply(scratchpad[1][3], _R2C1_SIN_7Q8));
    output[6] = (_8q7_multiply(scratchpad[1][3], _R2C1_COS_7Q8) -
                 _8q7_multiply(scratchpad[1][2], _R2C1_SIN_7Q8));
    scratchpad[2][4] = scratchpad[1][4] + scratchpad[1][6];
    scratchpad[2][5] = -scratchpad[1][5] + scratchpad[1][7];
    scratchpad[2][6] = scratchpad[1][4] - scratchpad[1][6];
    scratchpad[2][7] = scratchpad[1][5] + scratchpad[1][7];

    // output
    output[7] = scratchpad[2][7] - scratchpad[2][4];
    output[3] = _8q7_multiply(scratchpad[2][5], _SQRT2_7Q8);
    output[5] = _8q7_multiply(scratchpad[2][6], _SQRT2_7Q8);
    output[1] = scratchpad[2][4] + scratchpad[2][7];
}

static void dct8_7q8(const int16_t* input, int16_t* output)
{
    int16_t scratchpad[4][8];

    // stage 1
    scratchpad[0][0] = (((int16_t)input[0]) + ((int16_t)input[7]));
    scratchpad[0][1] = (((int16_t)input[1]) + ((int16_t)input[6]));
    scratchpad[0][2] = (((int16_t)input[2]) + ((int16_t)input[5]));
    scratchpad[0][3] = (((int16_t)input[3]) + ((int16_t)input[4]));
    scratchpad[0][4] = (((int16_t)input[3]) - ((int16_t)input[4]));
    scratchpad[0][5] = (((int16_t)input[2]) - ((int16_t)input[5]));
    scratchpad[0][6] = (((int16_t)input[1]) - ((int16_t)input[6]));
    scratchpad[0][7] = (((int16_t)input[0]) - ((int16_t)input[7]));

    // stage 2
    scratchpad[1][0] = scratchpad[0][0] + scratchpad[0][3];
    scratchpad[1][1] = scratchpad[0][1] + scratchpad[0][2];
    scratchpad[1][2] = scratchpad[0][1] - scratchpad[0][2];
    scratchpad[1][3] = scratchpad[0][0] - scratchpad[0][3];
    scratchpad[1][4] = (_8q7_multiply(scratchpad[0][4], _1C3_COS_7Q8) +
                        _8q7_multiply(scratchpad[0][7], _1C3_SIN_7Q8));
    scratchpad[1][7] = (_8q7_multiply(scratchpad[0][7], _1C3_COS_7Q8) -
                        _8q7_multiply(scratchpad[0][4], _1C3_SIN_7Q8));
    scratchpad[1][5] = (_8q7_multiply(scratchpad[0][5], _1C1_COS_7Q8) +
                        _8q7_multiply(scratchpad[0][6], _1C1_SIN_7Q8));
    scratchpad[1][6] = (_8q7_multiply(scratchpad[0][6], _1C1_COS_7Q8) -
                        _8q7_multiply(scratchpad[0][5], _1C1_SIN_7Q8));

    // stage 3
    output[0] = (_8q7_multiply(scratchpad[1][0], _SQRT2_OVER4_7Q8) +
                 _8q7_multiply(scratchpad[1][1], _SQRT2_OVER4_7Q8));
    output[4] = (_8q7_multiply(scratchpad[1][0], _SQRT2_OVER4_7Q8) -
                 _8q7_multiply(scratchpad[1][1], _SQRT2_OVER4_7Q8));
    output[2] = (_8q7_multiply(scratchpad[1][2], _R2C1_COS_7Q8) +
                 _8q7_multiply(scratchpad[1][3], _R2C1_SIN_7Q8));
    output[6] = (_8q7_multiply(scratchpad[1][3], _R2C1_COS_7Q8) -
                 _8q7_multiply(scratchpad[1][2], _R2C1_SIN_7Q8));
    scratchpad[2][4] = scratchpad[1][4] + scratchpad[1][6];
    scratchpad[2][5] = -scratchpad[1][5] + scratchpad[1][7];
    scratchpad[2][6] = scratchpad[1][4] - scratchpad[1][6];
    scratchpad[2][7] = scratchpad[1][5] + scratchpad[1][7];

    // output
    output[7] = scratchpad[2][7] - scratchpad[2][4];
    output[3] = _8q7_multiply(scratchpad[2][5], _SQRT2_7Q8);
    output[5] = _8q7_multiply(scratchpad[2][6], _SQRT2_7Q8);
    output[1] = scratchpad[2][4] + scratchpad[2][7];
}

void print_88(int16_t* dat)
{
    for (int i = 0; i < 8; i++) {
        for (int j = 0; j < 8; j++) {
            vpi_printf("%04x, ", *(uint16_t*)(dat + (i * 8) + j));
        }
        vpi_printf("\n");
    }
    vpi_printf("\n");
}

void dct88_q8(const int8_t* input, int16_t* output)
{
    int16_t intermediate[64];

    for (int i = 0; i < 8; i++) {
        dct8_q8(input + (i * 8), intermediate + (i * 8));
    }

    //printf("intermediate\r\n");
    //print_88(intermediate);

    for (int i = 0; i < 8; i++) {
        int16_t input_buf[8];
        int16_t output_buf[8];
        for (int j = 0; j < 8; j++) {
            input_buf[j] = *(intermediate + (j * 8) + i);
        }
        dct8_7q8(input_buf, output_buf);
        for (int j = 0; j < 8; j++) {
            *(output + (j * 8) + i) = output_buf[j];
        }
    }
}
