#ifndef _JMCUJC_UTILS_H
#define _JMCUJC_UTILS_H

#include <stdint.h>

/**
 * This is basically just a utility struct that holds a pointer to a memory region and an index into
 * that region. It's used by functions here to pack bytes.
 */
typedef struct jmcujc_bytearray
{
    uint8_t* base;
    int      len;
    int      index;
} jmcujc_bytearray_t;

/**
 * This function transforms an 8x8 array of uint8_t into a 1x64 array according to the "zig-zag"
 * procedure described in figure 5 of T.81.
 */
void jmcujc_util_zigzag_data_inplace_u8(uint8_t* temp);
void jmcujc_util_zigzag_data_inplace_f32(float* temp);

void bytearray_add_byte(jmcujc_bytearray_t* arr, uint8_t byte);
void bytearray_add_bytes(jmcujc_bytearray_t* arr, const uint8_t* bytes, int len);
void bytearray_add_bytes_reverse(jmcujc_bytearray_t* arr, const uint8_t* bytes, int len);

#endif
