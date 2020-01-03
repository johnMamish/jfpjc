#include "bit_packer.h"

#include <stdlib.h>

bit_packer_t* bit_packer_create()
{
    bit_packer_t* bp = calloc(1, sizeof(bit_packer_t));

    bp->capacity = 2048;
    bp->data = calloc(1, bp->capacity);
    bp->bitcount = 7;

    return bp;
}

void bit_packer_destroy(bit_packer_t* bp)
{
    free(bp->data);
    free(bp);
}

void bit_packer_fill_endbits(bit_packer_t* bp)
{
    while (bp->bitcount != 7) {
        bit_packer_pack_u8(0x01, 1, bp);
    }
}

static void bit_packer_pack_u1(uint8_t src, bit_packer_t* bp)
{
    // src should be either 0 or 1.
    bp->currval |= (src << bp->bitcount);
    bp->bitcount -= 1;
    if (bp->bitcount == -1) {
        bp->data[bp->curidx] = bp->currval;

        bp->currval = 0;
        bp->bitcount = 7;

        bp->curidx += 1;
        if (bp->curidx == bp->capacity) {
            bp->capacity *= 2;
            bp->data = realloc(bp->data, bp->capacity);
        }
    }
}

void bit_packer_pack_u8(uint8_t src, int n, bit_packer_t* packer)
{
    // start by left-aligning the data.
    src <<= (8 - n);

    // pack
    for (int i = 0; i < n; i++) {
        if (src & 0x80) {
            bit_packer_pack_u1(0x01, packer);
        } else {
            bit_packer_pack_u1(0x00, packer);
        }

        src <<= 1;
    }
}

void bit_packer_pack_u16(uint16_t src, int n, bit_packer_t* packer)
{
    // start by left-aligning the data.
    src <<= (16 - n);

    // pack
    for (int i = 0; i < n; i++) {
        if (src & 0x8000) {
            bit_packer_pack_u1(0x01, packer);
        } else {
            bit_packer_pack_u1(0x00, packer);
        }

        src <<= 1;
    }
}

void bit_packer_pack_u32(uint32_t src, int n, bit_packer_t* packer)
{
    // start by left-aligning the data.
    src <<= (32 - n);

    // pack
    for (int i = 0; i < n; i++) {
        if (src & 0x80000000) {
            bit_packer_pack_u1(0x01, packer);
        } else {
            bit_packer_pack_u1(0x00, packer);
        }

        src <<= 1;
    }
}
