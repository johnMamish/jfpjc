#include "./jpeg.h"
#include "bit_packer.h"
#include <math.h>
#include <string.h>

// jpeg util functions
// --------------------------------

static int count_non_null_elements(const void** array, int numel)
{
    int count = 0;
    for (int i = 0; i < numel; i++) {
        if (array[i])
            count++;
    }

    return count;
}


static void get_sampling_min_max(const component_params_t** params,
                                 int ncomponents,
                                 int* H_min,
                                 int* H_max,
                                 int* V_min,
                                 int* V_max)
{
    *H_min = params[0]->H_sample_factor;
    *H_max = params[0]->H_sample_factor;
    *V_min = params[0]->V_sample_factor;
    *V_max = params[0]->V_sample_factor;
    for (int i = 1; i < ncomponents; i++) {
        *H_min = (params[i]->H_sample_factor < *H_min) ? (params[i]->H_sample_factor) : *H_min;
        *H_max = (params[i]->H_sample_factor > *H_max) ? (params[i]->H_sample_factor) : *H_max;
        *V_min = (params[i]->V_sample_factor < *V_min) ? (params[i]->V_sample_factor) : *V_min;
        *V_max = (params[i]->V_sample_factor > *V_max) ? (params[i]->V_sample_factor) : *V_max;
    }
}


/**
 * If HV_squeeze is 1, each pixel is one sample. If one of its elements is 2, the corresponding
 * dimension in the image has 2 pixels per sample.
 */
static void component_take_dct(jpeg_dct_component_t* component,
                               int component_number,
                               const component_params_t* params,
                               int HV_squeeze[2],
                               const image_t* image)
{
    int pix_per_samp = HV_squeeze[0] * HV_squeeze[1];

    // initialize dct component
    component->H_sample_factor = params->H_sample_factor;
    component->V_sample_factor = params->V_sample_factor;
    component->quant_table_selector = params->quant_table_selector;
    component->entropy_coding_table = params->entropy_coding_table;

    component->num_blocks = ((((image->width + 7) / 8) * ((image->height + 7) / 8)) / pix_per_samp);
    component->blocks = calloc(component->num_blocks, sizeof(dct_block_t));

    // run DCT
    int data_in[64];

    // iterate over MCUs
    const int MCU_width_pixels = 8 * HV_squeeze[0];
    const int MCU_height_pixels = 8 * HV_squeeze[1];

    printf("HV_squeeze = {%i %i}\n", HV_squeeze[0], HV_squeeze[1]);

    component->mcu_width = image->width / MCU_width_pixels;
    component->mcu_height = image->height / MCU_height_pixels;

    for (int y = 0; y < (image->height / MCU_height_pixels); y++) {
        for (int x = 0; x < (image->width / MCU_width_pixels); x++) {
            int mcu_idx = (y * MCU_height_pixels * image->width) + (x * MCU_width_pixels);

            // iterate over 8x8 MCU
            for (int mcu_x = 0; mcu_x < 8; mcu_x++) {
                for (int mcu_y = 0; mcu_y < 8; mcu_y++) {
                    int samp_idx = (mcu_idx + (mcu_y * HV_squeeze[1] * image->width)
                                    + (mcu_x * HV_squeeze[0]));

                    // do pixel averaging for blocks with sampling factors.
                    int accum = 0;
                    for (int sample_x = 0; sample_x < HV_squeeze[0]; sample_x++) {
                        for (int sample_y = 0; sample_y < HV_squeeze[1]; sample_y++) {
                            int idx = samp_idx + sample_y * image->width + sample_x;
                            //int idx = samp_idx + 0 * image->width + sample_x;
                            accum += image->components[idx][component_number];
                        }
                    }

                    data_in[mcu_y * 8 + mcu_x] = accum / pix_per_samp;
                }
            }

            // do DCT
            int outidx = (y * (image->width / MCU_width_pixels)) + x;
            float temp[64];
            for (int i = 0; i < 64; i++)
                temp[i] = data_in[i];
            loeffler_fdct_8x8_inplace(temp);
            for (int i = 0; i < 64; i++)
                component->blocks[outidx].values[i] = (int)round(temp[i]);
            //mcu_fdct_floats(data_in, component->blocks[mcuidx].values);
            //mcu_fdct_fixedpoint(data_in, component->blocks[mcuidx].values);
        }
    }
}

static int jpeg_write_segment_header(const jpeg_segment_t* header, bytearray_t* ba)
{
    bytearray_add_bytes(ba, (uint8_t[]) { 0xff }, 1);
    bytearray_add_bytes(ba, &header->segment_marker, 1);

    uint8_t Lshton[] = { (header->Ls >> 8) & 0xff, (header->Ls & 0xff) };
    bytearray_add_bytes(ba, Lshton, 2);

    return 0;
}


static int jpeg_write_huffman_table(const jpeg_huffman_table_t* table, bytearray_t* ba)
{
    int retval = -1;
    if ((retval = jpeg_write_segment_header(&table->header, ba))) {
        return retval;
    }

    bytearray_add_bytes(ba, &table->tc_td, 1);

    bytearray_add_bytes(ba, &table->number_of_codes_with_length[0], 16);

    int tableidx = 0;
    for (int i = 0; i < 16; i++) {
        int num_to_write = table->number_of_codes_with_length[i];
        bytearray_add_bytes(ba, &table->huffman_codes[tableidx], num_to_write);
        tableidx += num_to_write;
    }

    return 0;
}

typedef struct huffman_reverse_lookup_entry
{
    // bit length of 0 means that there is no entry for that value.
    int bit_length;
    uint32_t value;
} huffman_reverse_lookup_entry_t;

typedef struct huffman_reverse_lookup_table
{
    huffman_reverse_lookup_entry_t entries[256];
} huffman_reverse_lookup_table_t;

/**
 * The huffman table returned by this function can be safely destroyed with free().
 */
huffman_reverse_lookup_table_t* huffman_reverse_lookup_table_create(const jpeg_huffman_table_t* t)
{
    huffman_reverse_lookup_table_t* hrlt = calloc(1, sizeof(huffman_reverse_lookup_table_t));

    uint32_t codedval = 0;
    int entryidx = 0;
    for (int bits = 0; bits < 16; bits++) {
        codedval <<= 1;
        for (int i = 0; i < t->number_of_codes_with_length[bits]; i++, entryidx++) {
            uint8_t uncodedval = t->huffman_codes[entryidx];

            hrlt->entries[uncodedval].bit_length = bits + 1;
            hrlt->entries[uncodedval].value = codedval;
            codedval++;
        }
    }

    return hrlt;
}

static uint16_t coefficient_value_to_coded_value(int16_t coefficient_value, int* bitlen)
{
    uint16_t result = 0;
    if (coefficient_value == 0) {
        *bitlen = 0;
        return 0;
    }

    // there's definately a faster way to do this, but I didn't want to prematurely optimize.
    // look into __builtin_ffs when the time comes.
    int min_less1 = 0;
    int max       = 1;
    *bitlen = 1;
    int16_t coeff_abs = (coefficient_value < 0) ? (-coefficient_value) : (coefficient_value);
    for (; *bitlen < 13; (*bitlen)++) {
        if ((coeff_abs > min_less1) && (coeff_abs <= max)) {
            break;
        }
        min_less1 = max;
        max <<= 1;
        max |= 1;
    }

    if (*bitlen == 13) {
        return 0;
    }

    if (coefficient_value < 0) {
        result = coefficient_value + max;
    } else {
        result = coefficient_value;
    }

    return result;
}

#if 1
int jpeg_huffman_code(const uncoded_jpeg_scan_t* scan,
                      const jpeg_huffman_table_t* dc_huffman_tables[2],
                      const jpeg_huffman_table_t* ac_huffman_tables[2],
                      uint8_t** result)
{
    *result = NULL;

    // make huffman reverse lookup tables.
    huffman_reverse_lookup_table_t* dc_hrlts[2] = { 0 };
    huffman_reverse_lookup_table_t* ac_hrlts[2] = { 0 };
    for (int i = 0; i < 2; i++) {
        if (dc_huffman_tables[i])
            dc_hrlts[i] = huffman_reverse_lookup_table_create(dc_huffman_tables[i]);
        if (ac_huffman_tables[i])
            ac_hrlts[i] = huffman_reverse_lookup_table_create(ac_huffman_tables[i]);
    }

    // huffman code
    // num of MCUs is the min of the number of blocks
    int num_mcus = scan->components[0].num_blocks;
    for (int i = 1; i < scan->num_components; i++) {
        if (scan->components[i].num_blocks < num_mcus) {
            num_mcus = scan->components[i].num_blocks;
        }
    }

    bit_packer_t* bp = bit_packer_create();

    for (int i = 0; i < num_mcus; i++) {
        for (int j = 0; j < scan->num_components; j++) {
            int blocks_per_line = scan->width / (8);
            int mcus_per_line   = scan->width / (8 * scan->components[j].H_sample_factor);
            int blocks_per_mcu = (scan->components[j].H_sample_factor *
                                  scan->components[j].V_sample_factor);
            //int block_idx      = blocks_per_mcu * i;
            int block_idx = blocks_per_mcu * ((i / mcus_per_line) * mcus_per_line) + scan->components[j].H_sample_factor * (i % mcus_per_line);
            uint8_t huff_tables = scan->components[j].entropy_coding_table;
            int dc_huff_idx = huff_tables;
            int ac_huff_idx = huff_tables;
            const huffman_reverse_lookup_table_t* dc_hrlt = (dc_hrlts[dc_huff_idx]);
            const huffman_reverse_lookup_table_t* ac_hrlt = (ac_hrlts[ac_huff_idx]);

            // huffman encode!
            for (int ky = 0; ky < scan->components[j].V_sample_factor; ky++) {
                for (int kx = 0; kx < scan->components[j].H_sample_factor; kx++) {
                    printf("(%i, %i) %i\n", kx, ky, block_idx + (ky * blocks_per_line) + kx);
                    int* source_block = scan->components[j].blocks[block_idx + (ky * blocks_per_line) + kx].values;

                    // ======= DC length and DC coefficient =======
                    int dc_raw_length;
                    uint16_t coded_coefficient_value =
                        coefficient_value_to_coded_value(source_block[0], &dc_raw_length);
                    //printf("jpeg recoding trace:    Coding %i bits for DC value %i.\n", dc_raw_length,
                    //source_block->dc_value);

                    if ((dc_raw_length < 0) || (dc_raw_length > 11)) {
                        printf("jpeg recoding error:    Trying to pack dc coefficient with length of "
                               "%i bits.\n", dc_raw_length);
                        return -1;
                    }

                    const huffman_reverse_lookup_entry_t* huffman_code = &dc_hrlt->entries[dc_raw_length];
                    if (huffman_code->bit_length == 0) {
                        printf("jpeg recoding error:    No huffman code found for %02x.\n",
                               dc_raw_length);
                        return -1;
                    }
                    bit_packer_pack_u32(huffman_code->value, huffman_code->bit_length, bp);
                    bit_packer_pack_u16(coded_coefficient_value, dc_raw_length, bp);

                    // ======= AC coefficients =======
                    unsigned int ac_coeff_idx = 1;

                    while (ac_coeff_idx < 64) {
                        // find next non-zero coefficient
                        unsigned int l;
                        for (l = ac_coeff_idx; (source_block[l] == 0) && (l < 64); l++);

                        int zeroes_to_rle = l - ac_coeff_idx;

                        if (l == 64) {
                            // we made it all the way to the end; slap an EOB in there.
                            const huffman_reverse_lookup_entry_t* huffman_code = &ac_hrlt->entries[0];
                            if (huffman_code->bit_length == 0) {
                                //printf("jpeg recoding error:    No huffman code found for %02x.\n", 0);
                                return -1;
                            }
                            bit_packer_pack_u32(huffman_code->value, huffman_code->bit_length, bp);
                        } else if ((zeroes_to_rle >= 0) && (zeroes_to_rle < 16)) {
                            // pack AC coefficient normally
                            int cidx = ac_coeff_idx + zeroes_to_rle;
                            int ac_raw_length;
                            uint16_t coded_coefficient_value =
                                coefficient_value_to_coded_value(source_block[cidx],
                                                                 &ac_raw_length);

                            if ((ac_raw_length < 0) || (ac_raw_length > 10)) {
                                //printf("jpeg recoding error:    "
                                //"Trying to pack ac coefficient with length of %i bits.\n",
                                //ac_raw_length);
                                return -1;
                            }
                            //printf("jpeg recoding trace:    Coding %i bits for AC value.\n",
                            //ac_raw_length);

                            uint8_t rrrrssss = ((uint8_t)zeroes_to_rle << 4) | (ac_raw_length);
                            const huffman_reverse_lookup_entry_t* huffman_code =
                                &ac_hrlt->entries[rrrrssss];
                            if (huffman_code->bit_length == 0) {
                                printf("jpeg recoding error:    No huffman code found for %02x.\n", 0);
                                return -1;
                            }
                            bit_packer_pack_u32(huffman_code->value, huffman_code->bit_length, bp);
                            bit_packer_pack_u16(coded_coefficient_value, ac_raw_length, bp);
                        } else {
                            // if there are 17 or more zeroes that need to be RLE'd before another
                            // coefficient is reached, we may only pack only 16 of them.
                            uint8_t rrrrssss = 0xf0;
                            const huffman_reverse_lookup_entry_t* huffman_code =
                                &ac_hrlt->entries[rrrrssss];
                            if (huffman_code->bit_length == 0) {
                                printf("jpeg recoding error:    No huffman code found for %02x.\n", 0);
                                return -1;
                            }
                            bit_packer_pack_u32(huffman_code->value, huffman_code->bit_length, bp);

                            l = ac_coeff_idx + 15;
                        }

                        ac_coeff_idx = l + 1;
                    }
                    //printf("jpeg recoding trace:    ========================================\n");
                }
            }

            printf("\n");
        }
    }

    bit_packer_fill_endbits(bp);

    *result = malloc(bp->curidx);
    int len = bp->curidx;
    memcpy(*result, bp->data, bp->curidx);

    bit_packer_destroy(bp);

    for (int i = 0; i < 2; i++) {
        free(dc_hrlts[i]);
        free(ac_hrlts[i]);
    }

    return len;
}
#endif

static void uncoded_jpeg_scan_quantize(jpeg_dct_component_t* component,
                                       const jpeg_quantization_table_t* quant)
{
    for (int i = 0; i < component->num_blocks; i++) {
        for (int j = 0; j < 64; j++) {
            component->blocks[i].values[j] /= quant->Q[j];
        }
    }
}

static void component_differentially_code(jpeg_dct_component_t* component)
{
    int pred = 0;
    for (int y = 0; y < component->mcu_height; y += component->V_sample_factor) {
        for (int x = 0; x < component->mcu_width; x += component->H_sample_factor) {
            for (int sub_y = 0; sub_y < component->V_sample_factor; sub_y++) {
                for (int sub_x = 0; sub_x < component->H_sample_factor; sub_x++) {
                    int idx = (y + sub_y) * component->mcu_width + x + sub_x;

                    int diff = component->blocks[idx].values[0] - pred;
                    pred = component->blocks[idx].values[0];
                    component->blocks[idx].values[0] = diff;
                }
            }
        }
    }


    /*for (int i = 0; i < component->num_blocks; i++) {
        int diff = component->blocks[i].values[0] - pred;
        pred = component->blocks[i].values[0];
        component->blocks[i].values[0] = diff;
    }*/
}

uncoded_jpeg_scan_t* uncoded_jpeg_scan_create(const image_t* image,
                                              const component_params_t** params,
                                              int ncomponents,
                                              const jpeg_quantization_table_t** tables)
{
    uncoded_jpeg_scan_t* scan = calloc(1, sizeof(uncoded_jpeg_scan_t));

    scan->num_components = ncomponents;
    scan->width = image->width;
    scan->height = image->height;

    // The frustrating question is: how do we know the amount by which to average the pixels? The
    // subsampling factor by itself doesn't tell us... we really need to know the max / min
    // subsampling factors
    int H_ranges[2];
    int V_ranges[2];
    get_sampling_min_max(params, ncomponents, &H_ranges[0], &H_ranges[1], &V_ranges[0], &V_ranges[1]);

    for (int i = 0; i < ncomponents; i++) {
        int HV_squeeze[2];
        HV_squeeze[0] = H_ranges[1] / params[i]->H_sample_factor;
        HV_squeeze[1] = V_ranges[1] / params[i]->V_sample_factor;

        // initialize dct component
        component_take_dct(&scan->components[i], i, params[i], HV_squeeze, image);

        // quantize, zigzag, and differentially encode DC component
        int quant_table = scan->components[i].quant_table_selector;
        uncoded_jpeg_scan_quantize(&scan->components[i], tables[quant_table]);
        for (int j = 0; j < scan->components[i].num_blocks; j++)
            jpeg_zigzag_data_inplace(scan->components[i].blocks[j].values);
        component_differentially_code(&scan->components[i]);
    }

    return scan;
}


int jpeg_compress(const uncoded_jpeg_scan_t* scan,
                  const jpeg_huffman_table_t* dc_huffman_tables[2],
                  const jpeg_huffman_table_t* ac_huffman_tables[2],
                  const jpeg_quantization_table_t* quant_tables[4],
                  uint8_t** result)
{
    bytearray_t* ba = bytearray_create();

    // ======= SOI / JFIF =======
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xd8 }, 2);
    const char* jfifseg = "\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00";
    bytearray_add_bytes(ba, (const uint8_t*)jfifseg, 18);

    // ======= quant tables =======
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xdb }, 2);

    int num_valid_qtables = count_non_null_elements((const void**)quant_tables, 4);
    uint16_t qtLs = 65 * num_valid_qtables + 2;
    bytearray_add_bytes(ba, (uint8_t[]){ ((qtLs >> 8) & 0xff), qtLs & 0xff }, 2);

    for (int i = 0; i < 4; i++) {
        if (quant_tables[i] != NULL) {
            bytearray_add_bytes(ba, &quant_tables[i]->pq_tq, 1);
            static uint8_t temp[64];
            memcpy(temp, quant_tables[i]->Q, sizeof(temp));
            jpeg_zigzag_data_inplace_u8(temp);
            //bytearray_add_bytes(ba, quant_tables[i]->Q, 64);
            bytearray_add_bytes(ba, temp, 64);
        }
    }

    // ======= huff tables =======
    for (int i = 0; i < 2; i++)
        if (dc_huffman_tables[i])
            jpeg_write_huffman_table(dc_huffman_tables[i], ba);
    for (int i = 0; i < 2; i++)
        if (ac_huffman_tables[i])
            jpeg_write_huffman_table(ac_huffman_tables[i], ba);

    // ======= SOF =======
    // quantization table is selected here.
    int SOF_len = 8 + (3 * scan->num_components);
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xc0, 0x00, SOF_len, 0x08 }, 5);
    uint8_t nlhton[] = { (scan->height >> 8) & 0xff,
                         (scan->height) & 0xff };
    bytearray_add_bytes(ba, nlhton, 2);
    uint8_t splhton[] = { (scan->width >> 8) & 0xff,
                          (scan->width) & 0xff };
    bytearray_add_bytes(ba, splhton, 2);
    bytearray_add_bytes(ba, (uint8_t[]){ scan->num_components }, 1);
    for (int i = 0; i < scan->num_components; i++) {
        bytearray_add_bytes(ba, (uint8_t[]){ i }, 1);   // component identifier
        uint8_t hi_vi = ((scan->components[i].H_sample_factor << 4) |
                         scan->components[i].V_sample_factor);
        bytearray_add_bytes(ba, &hi_vi, 1);
        bytearray_add_bytes(ba, (uint8_t[]) {scan->components[i].quant_table_selector}, 1);
    }

    // ======= SOS =======
    // entropy / huffman table is selected here.
    int SOS_len = 6 + (2 * scan->num_components);
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xda, 0x00, SOS_len }, 4);
    bytearray_add_bytes(ba, (uint8_t[]){ scan->num_components }, 1);
    for (int i = 0; i < scan->num_components; i++) {
        bytearray_add_bytes(ba, (uint8_t[]){ i }, 1);
        uint8_t ect_sel = scan->components[i].entropy_coding_table | (scan->components[i].entropy_coding_table << 4);
        bytearray_add_bytes(ba, (uint8_t[]){ ect_sel }, 1);
    }
    // start and end of spectral selection. constant for sequential mode.
    bytearray_add_bytes(ba, (uint8_t[]){ 0, 63 }, 2);

    // successive approximation bit positions: another technique for progressive decode. As we are
    // doing sequential, not progressive, this stays at 0.
    bytearray_add_bytes(ba, (uint8_t[]){ 0 }, 1);

    // write entropy-coded segment.
    // in this crappy reference implementation, bitstuffing happens here. However in the "real"
    // embedded impl (jmcumc), the improved bytepacking code I recently came up with might shift
    // where I do this.
    //uncoded_jpeg_scan_t* scan = uncoded_jpeg_scan_create(image,

    uint8_t* ecs = NULL;
    int ecs_len = jpeg_huffman_code(scan, dc_huffman_tables, ac_huffman_tables, &ecs);
    for (int i = 0; i < ecs_len; i++) {
        uint8_t writebyte = ecs[i];
        bytearray_add_bytes(ba, &writebyte, 1);

        if (writebyte == 0xff) {
            bytearray_add_bytes(ba, (uint8_t[]){ 0 }, 1);
        }
    }

    free(ecs);

    // write EOI
    bytearray_add_bytes(ba, (uint8_t[]) {0xff, 0xd9}, 2);

    *result = ba->data;
    int ret = ba->size;
    free(ba);
    return ret;
}


const jpeg_huffman_table_t lum_dc_huffman_table =
{
    .header = { .segment_marker = 0xc4, .Ls = 0x1f },
    .tc_td  = 0x00,
    .number_of_codes_with_length = { 0, 1, 5, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0, 0, 0 },

    .huffman_codes = {

        0x00,
        0x01, 0x02, 0x03, 0x04, 0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0a,
        0x0b







    }
};
const jpeg_huffman_table_t lum_ac_huffman_table =
{
    .header = { .segment_marker = 0xc4, .Ls = 0xb5 },
    .tc_td  = 0x10,
    .number_of_codes_with_length = { 0, 2, 1, 3, 3, 2, 4, 3, 5, 5, 4, 4, 0, 0, 1, 125},
    .huffman_codes = {

        0x01, 0x02,
        0x03,
        0x00, 0x04, 0x11,
        0x05, 0x12, 0x21,
        0x31, 0x41,
        0x06, 0x13, 0x51, 0x61,
        0x07, 0x22, 0x71,
        0x14, 0x32, 0x81, 0x91, 0xa1,
        0x08, 0x23, 0x42, 0xb1, 0xc1,
        0x15, 0x52, 0xd1, 0xf0,
        0x24, 0x33, 0x62, 0x72,


        0x82,
        0x09, 0x0A, 0x16, 0x17, 0x18, 0x19, 0x1A, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x34, 0x35, 0x36,
        0x37, 0x38, 0x39, 0x3A, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56,
        0x57, 0x58, 0x59, 0x5A, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76,
        0x77, 0x78, 0x79, 0x7A, 0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95,
        0x96, 0x97, 0x98, 0x99, 0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3,
        0xB4, 0xB5, 0xB6, 0xB7, 0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA,
        0xD2, 0xD3, 0xD4, 0xD5, 0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE1, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7,
        0xE8, 0xE9, 0xEA, 0xF1, 0xF2, 0xF3, 0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA
    }
};

const jpeg_huffman_table_t chrom_dc_huffman_table =
{
    .header = { .segment_marker = 0xc4, .Ls = 0x1f },
    .tc_td  = 0x01,
    .number_of_codes_with_length = { 0, 3, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 0, 0 },

    .huffman_codes = {

        0x00, 0x01, 0x02,
        0x03,
        0x04,
        0x05,
        0x06,
        0x07,
        0x08,
        0x09,
        0x0a,
        0x0b,





    }
};

const jpeg_huffman_table_t chrom_ac_huffman_table =
{
    .header = { .segment_marker = 0xc4, .Ls = 0xb5 },
    .tc_td  = 0x11,
    .number_of_codes_with_length = { 0, 2, 1, 2, 4, 4, 3, 4, 7, 5, 4, 4, 0, 1, 2, 119},
    .huffman_codes = {

        0x00, 0x01,
        0x02,
        0x03, 0x11,
        0x04, 0x05, 0x21, 0x31,
        0x06, 0x12, 0x41, 0x51,
        0x07, 0x61, 0x71,
        0x13, 0x22, 0x32, 0x81,
        0x08, 0x14, 0x42, 0x91, 0xa1, 0xb1, 0xc1,
        0x09, 0x23, 0x33, 0x52, 0xf0,
        0x15, 0x62, 0x72, 0xd1,
        0x0a, 0x16, 0x24, 0x34,

        0xe1,
        0x25, 0xf1,
        0x17, 0x18, 0x19, 0x1A, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x43,
        0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0x63,
        0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0x82,
        0x83, 0x84, 0x85, 0x86, 0x87, 0x88, 0x89, 0x8A, 0x92, 0x93, 0x94, 0x95, 0x96, 0x97, 0x98, 0x99,
        0x9A, 0xA2, 0xA3, 0xA4, 0xA5, 0xA6, 0xA7, 0xA8, 0xA9, 0xAA, 0xB2, 0xB3, 0xB4, 0xB5, 0xB6, 0xB7,
        0xB8, 0xB9, 0xBA, 0xC2, 0xC3, 0xC4, 0xC5, 0xC6, 0xC7, 0xC8, 0xC9, 0xCA, 0xD2, 0xD3, 0xD4, 0xD5,
        0xD6, 0xD7, 0xD8, 0xD9, 0xDA, 0xE2, 0xE3, 0xE4, 0xE5, 0xE6, 0xE7, 0xE8, 0xE9, 0xEA, 0xF2, 0xF3,
        0xF4, 0xF5, 0xF6, 0xF7, 0xF8, 0xF9, 0xFA
    }
};

const jpeg_quantization_table_t lum_quant_table_best =
{
    //.table_valid = true,
    .pq_tq = 0x00,
    .Q = {
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,
        1, 1, 1, 1, 1, 1, 1, 1,

    }
};

const jpeg_quantization_table_t lum_quant_table_high =
{
    //.table_valid = true,
    .pq_tq = 0x00,
    .Q = {
        3,   2,   2,   3,  4,  6,  8, 10,
        2,   2,   2,   3,  4,  9, 10,  9,
        2,   2,   3,   4,  6,  9, 11,  9,
        2,   3,   4,   5,  8, 14, 13, 10,
        3,   4,   6,   9, 11, 17, 16, 12,
        4,   6,   9,  10, 13, 17, 18, 15,
        8,  10,  12,  14, 16, 19, 19, 16,
        12, 15,  15,  16, 18, 16, 16, 16
    }
};

const jpeg_quantization_table_t lum_quant_table_medium =
{
    //.table_valid = true,
    .pq_tq = 0x00,
    .Q = {
        3 * 2,   2 * 2,   2 * 2,   3 * 2,  4 * 2,  6 * 2,  8 * 2, 10 * 2,
        2 * 2,   2 * 2,   2 * 2,   3 * 2,  4 * 2,  9 * 2, 10 * 2,  9 * 2,
        2 * 2,   2 * 2,   3 * 2,   4 * 2,  6 * 2,  9 * 2, 11 * 2,  9 * 2,
        2 * 2,   3 * 2,   4 * 2,   5 * 2,  8 * 2, 14 * 2, 13 * 2, 10 * 2,
        3 * 2,   4 * 2,   6 * 2,   9 * 2, 11 * 2, 17 * 2, 16 * 2, 12 * 2,
        4 * 2,   6 * 2,   9 * 2,  10 * 2, 13 * 2, 17 * 2, 18 * 2, 15 * 2,
        8 * 2,  10 * 2,  12 * 2,  14 * 2, 16 * 2, 19 * 2, 19 * 2, 16 * 2,
        12 * 2, 15 * 2,  15 * 2,  16 * 2, 18 * 2, 16 * 2, 16 * 2, 16 * 2
    }
};

//const jpeg_quantization_table_t lum_quant_table_low;
//const jpeg_quantization_table_t lum_quant_table_lowest;

//const jpeg_quantization_table_t chrom_quant_table_best;
const jpeg_quantization_table_t chrom_quant_table_high =
{
    //.table_valid = true,
    .pq_tq = 0x01,
    .Q = {
        3,  3,  4,  8, 16, 16, 16, 16,
        3,  3,  4, 11, 16, 16, 16, 16,
        4,  4,  9, 16, 16, 16, 16, 16,
        8, 11, 16, 16, 16, 16, 16, 16,
       16, 16, 16, 16, 16, 16, 16, 16,
       16, 16, 16, 16, 16, 16, 16, 16,
       16, 16, 16, 16, 16, 16, 16, 16,
       16, 16, 16, 16, 16, 16, 16, 16,
    }
};

const jpeg_quantization_table_t chrom_quant_table_medium =
{
    //.table_valid = true,
    .pq_tq = 0x01,
    .Q = {
        13, 14, 18, 35, 74, 74, 74, 74,
        14, 16, 20, 50, 74, 74, 74, 74,
        18, 20, 42, 74, 74, 74, 74, 74,
        35, 50, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74
    }
};

const jpeg_quantization_table_t chrom_quant_table_low =
{
    //.table_valid = true,
    .pq_tq = 0x01,
    .Q = {
        13, 14, 18, 35, 74, 74, 74, 74,
        14, 16, 20, 50, 74, 74, 74, 74,
        18, 20, 42, 74, 74, 74, 74, 74,
        35, 50, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74,
        74, 74, 74, 74, 74, 74, 74, 74
    }
};

//const jpeg_quantization_table_t chrom_quant_table_lowest;
