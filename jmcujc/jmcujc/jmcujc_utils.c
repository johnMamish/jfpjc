#include "jmcujc_utils.h"

#include <string.h>

void bytearray_add_byte(jmcujc_bytearray_t* arr, uint8_t byte)
{
    arr->base[arr->index++] = byte;
}

void bytearray_add_bytes(jmcujc_bytearray_t* arr, const uint8_t* bytes, int len)
{
    memcpy(arr->base + arr->index, bytes, len);
    arr->index += len;
}

void bytearray_add_bytes_reverse(jmcujc_bytearray_t* arr, const uint8_t* bytes, int len)
{
    for (int i = 0; i < len; i++) {
        arr->base[arr->index + i] = bytes[len - 1 - i];
    }
    arr->index += len;
}

void jmcujc_util_zigzag_data_inplace_u8(uint8_t* data)
{
    static uint8_t temp[64];
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

void jmcujc_util_zigzag_data_inplace_f32(float* data)
{
    static float temp[64];
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
