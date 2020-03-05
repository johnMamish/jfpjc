#ifndef _BIT_DISPENSER_H
#define _BIT_DISPENSER_H

typedef struct bit_dispenser
{
    int datalen;
    const uint8_t* restrict data;

    int bitcount;
    int idx;
} bit_dispenser_t;

typedef struct bit_packer
{
    // how many bytes are allocated to the data storage space?
    int datalen;
    // pointer to the start of the
    uint8_t* data;

    int bitcount;
    int idx;
} bit_packer_t;


#if ARM
#include "cmsis_gcc.h"
/*
__attribute__((always_inline)) static inline  uint32_t __RBIT(uint32_t value)
{
    uint32_t result;
    __asm volatile ("rbit %0, %1" : "=r" (result) : "r" (value) );
    return result;
}
*/
#else
static inline uint32_t __RBIT(uint32_t value)
{
    value = (((value & 0xaaaaaaaa) >> 1) | ((value & 0x55555555) << 1));
    value = (((value & 0xcccccccc) >> 2) | ((value & 0x33333333) << 2));
    value = (((value & 0xf0f0f0f0) >> 4) | ((value & 0x0f0f0f0f) << 4));
    value = (((value & 0xff00ff00) >> 8) | ((value & 0x00ff00ff) << 8));
    return((value >> 16) | (value << 16));
}
#endif

// peeks at the top u16 in the bit dispenser, as if 16 bits had been shifted out.
static inline uint16_t bit_dispenser_peek_u16(bit_dispenser_t* restrict bd)
{
    uint32_t data = *((uint32_t*)(bd->data + bd->idx));
    uint32_t windowed = __RBIT(__builtin_bswap32(data)) >> bd->bitcount;
    return __RBIT(windowed) >> 16;
}

/**
 * just unceremoniously throws away nbits worth of bits.
 */
static inline void bit_dispenser_advance(bit_dispenser_t* restrict bd, int nbits)
{
    bd->bitcount += nbits;
    bd->idx += (bd->bitcount / 8);
    bd->bitcount &= 0x07;              // bd->bitcount %= 8;
}

static inline uint16_t bit_dispenser_dispense_bits(bit_dispenser_t* restrict bd, int nbits)
{
    uint16_t retval = bit_dispenser_peek_u16(bd);
    bit_dispenser_advance(bd, nbits);
    return retval >> (16 - nbits);
}

static inline void bit_packer_pack_u16(bit_packer_t* bp, uint16_t data, int nbits)
{
    int startidx = bp->idx;

    // bitmask new data in
    uint32_t flip_and_lalign = __RBIT(data) >> (32 - nbits);
    uint32_t data_to_pack = __builtin_bswap32(__RBIT(flip_and_lalign << bp->bitcount));

    uint32_t* targetaddr = ((uint32_t*)(bp->data + bp->idx));
    *targetaddr |= data_to_pack;

    // advance bitpacker
    bp->bitcount += nbits;
    bp->idx += (bp->bitcount / 8);
    bp->bitcount &= 0x07;

    // bitstuff, add a 0x00 after every 0xff that we create
    while(startidx < bp->idx) {
        if(bp->data[startidx] == 0xff) {
            // never need to copy more than 4 bytes; also it's ok to copy extra
            *((uint32_t*)(bp->data + startidx + 2)) = *((uint32_t*)(bp->data + startidx + 1));
            bp->data[startidx + 1] = 0x00;
            bp->idx++;
            startidx += 2;
        } else {
            startidx++;
        }
    }
}

/**
 * finishes the current byte with 1's or 0's. If the current byte is empty, this does nothing.
 */
static void bit_packer_pad_end(bit_packer_t* bp, int bit)
{
    int bits_to_pack = (8 - bp->bitcount) % 8;

    uint16_t padval = 0;

    if (bit) {
        padval = (((uint16_t)1) << bits_to_pack) - 1;
    }

    bit_packer_pack_u16(bp, padval, bits_to_pack);
}

#endif
