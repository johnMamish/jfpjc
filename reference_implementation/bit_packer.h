#ifndef BIT_PACKER_H
#define BIT_PACKER_H

#include <stdint.h>

// exposed to make it easier for users to get at the data and length.
typedef struct bit_packer bit_packer_t;
struct bit_packer
{
    int capacity;
    uint8_t* data;

    uint8_t currval;
    int bitcount;
    int curidx;
};

bit_packer_t* bit_packer_create();
void bit_packer_destroy(bit_packer_t* bp);

/**
 * If the currently pending byte has unfilled bits, fills it with ones and moves up to the next
 * byte.
 *
 * Should be called before "harvesting" bp->data.
 */
void bit_packer_fill_endbits(bit_packer_t* bp);

/**
 * Consumes bits < n-1 : 0 > from the given number and right-shifts them into the given target.
 *
 * for example, consuming 13 bits from
 *
 *     1101 1001  0001 1111
 *        ^
 *        |-------- This bit and lower are the lower 13 bits.
 *
 * into a packer starting with:
 *
 *     byte 0          byte 1
 *     MSB   LSB    MSB   LSB
 *     1010 1111    0111 zzzz
 *
 * where the 'z's represent not-yet-packed bytes
 * will yield
 *
 *     byte 0                                  byte n
 *     MSB   LSB    MSB   LSB    MSB   LSB  MSB   LSB
 *     1010 1111    0111 1100    1000 1111  1zzz zzzz
 *
 * putting them back in after taking them out is a little more complicated because we don't know
 * about bit-alignment before re-packing, so we don't want to go back to front, we still want to
 * go front-to-back.
 */
void bit_packer_pack_u8(uint8_t   src, int n, bit_packer_t* packer);
void bit_packer_pack_u16(uint16_t src, int n, bit_packer_t* packer);
void bit_packer_pack_u32(uint32_t src, int n, bit_packer_t* packer);

#endif
