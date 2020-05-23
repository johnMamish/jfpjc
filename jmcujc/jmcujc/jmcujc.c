#include <stdbool.h>
#include <string.h>
#include <math.h>

#include "jmcujc.h"
#include "jmcujc_utils.h"

#include "bit_dispenser.h"

/**
 * According to Loeffler et al, 1989
 *
 * NB: there's an error in the Stage 3 sqrt(2)c1 block. It should be sqrt(2)c6
 */
static void loeffler_fdct_horizontal_inplace(float* data_in, float* data_out)
{
    static float stages[4][8];

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
    data_out[4]  = (stages[1][0] - stages[1][1]) * 0.25 * 1.41421356237;
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

static void loeffler_fdct_vertical_inplace(float* data_in, float* data_out)
{
    static float stages[4][8];

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

static void loeffler_fdct_8x8_inplace(float* data)
{
    // TODO: can this static array be removed? I think so.
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
        data[i] = data_f[i];
    }
}

static void huffman_reverse_lookup_table_init(const jmcujc_huffman_table_t* t,
                                              huffman_reverse_lookup_table_t* hrlt)
{
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
}


/**
 * This function takes a jpeg component and overwrites the data in it with its DCT.
 */
static void jpeg_component_DCT(jmcujc_jpeg_params_t* params, jmcujc_component_t* component)
{
    const int qt = params->component_quant_table_selectors[0];
    for (int MCU_idx = 0; MCU_idx < ((component->width / 8) * (component->height / 8)); MCU_idx++) {
        loeffler_fdct_8x8_inplace(component->samples + (MCU_idx * 64));

        for (int j = 0; j < 64; j++) {
            component->samples[(MCU_idx * 64) + j] /= params->jpeg_quantization_tables[qt]->values[j];
        }

        jmcujc_util_zigzag_data_inplace_f32(component->samples + (MCU_idx * 64));
    }
}


static void jpeg_write_huffman_table(const jmcujc_huffman_table_t* table, jmcujc_bytearray_t* ba)
{
    bytearray_add_bytes(ba, (const uint8_t[]) {0xff, 0xc4, 0x00, table->Ls}, 4);

    bytearray_add_bytes(ba, &table->tc_td, 1);

    bytearray_add_bytes(ba, &table->number_of_codes_with_length[0], 16);

    int tableidx = 0;
    for (int i = 0; i < 16; i++) {
        int num_to_write = table->number_of_codes_with_length[i];
        bytearray_add_bytes(ba, &table->huffman_codes[tableidx], num_to_write);
        tableidx += num_to_write;
    }
}

static void jpeg_write_sof_component_specification_parameters(const jmcujc_component_t* c,
                                                              int identifier,
                                                              jmcujc_jpeg_params_t* params,
                                                              jmcujc_bytearray_t* ba)
{
    bytearray_add_bytes(ba, (uint8_t[]){ identifier }, 1);   // component identifier
    uint8_t hi_vi = ((c->subsampling_factors.horizontal_sampling_factor << 4) |
                     c->subsampling_factors.vertical_sampling_factor);
    bytearray_add_bytes(ba, &hi_vi, 1);
    bytearray_add_bytes(ba, (uint8_t[]) {params->component_quant_table_selectors[identifier]}, 1);
}

int jmcujc_write_headers(jmcujc_component_t* components,
                         int ncomponents,
                         jmcujc_jpeg_params_t* params,
                         jmcujc_bytearray_t* ba)
{
    // ======= SOI / JFIF =======
    bytearray_add_bytes(ba, (const uint8_t[]){ 0xff, 0xd8 }, 2);
    const char* jfifseg = "\xff\xe0\x00\x10JFIF\x00\x01\x01\x00\x00\x01\x00\x01\x00\x00";
    bytearray_add_bytes(ba, (const uint8_t*)jfifseg, 18);

    // ======= quant tables =======
    bytearray_add_bytes(ba, (const uint8_t[]) { 0xff, 0xdb }, 2);
    uint16_t qtLs = 65 * (params->num_quantization_tables) + 2;
    bytearray_add_bytes(ba, (const uint8_t[]) { ((qtLs >> 8) & 0xff), qtLs & 0xff }, 2);

    for (int i = 0; i < params->num_quantization_tables; i++) {
        const uint8_t pq_tq = i;
        bytearray_add_bytes(ba, &pq_tq, 1);

        // need to zig-zag quant table
        static uint8_t temp[64];
        memcpy(temp, (&params->jpeg_quantization_tables[i]->values), 64);
        jmcujc_util_zigzag_data_inplace_u8(temp);
        bytearray_add_bytes(ba, (const uint8_t*)(&temp), 64);
    }

    // ======== huff tables ========
    for (int i = 0; i < params->num_dc_huffman_tables; i++) {
        jpeg_write_huffman_table(params->dc_huffman_tables[i], ba);
    }
    for (int i = 0; i < params->num_ac_huffman_tables; i++) {
        jpeg_write_huffman_table(params->ac_huffman_tables[i], ba);
    }

    // ======= SOF =======
    // quantization table is selected here.
    int SOF_len = 8 + (3 * ncomponents);
    bytearray_add_bytes(ba, (const uint8_t[]){ 0xff, 0xc0, 0x00, SOF_len, 0x08 }, 5);
    bytearray_add_bytes_reverse(ba, (const uint8_t*)(&params->height), 2);
    bytearray_add_bytes_reverse(ba, (const uint8_t*)(&params->width), 2);
    bytearray_add_bytes(ba, (const uint8_t[]){ ncomponents }, 1);
    for (int i = 0; i < ncomponents; i++) {
        jpeg_write_sof_component_specification_parameters(&components[i], i, params, ba);
    }

    // ======= SOS =======
    int SOS_len = 6 + (2 * ncomponents);
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xda, 0x00, SOS_len }, 4);
    bytearray_add_bytes(ba, (uint8_t[]){ ncomponents }, 1);
    for (int i = 0; i < ncomponents; i++) {
        bytearray_add_bytes(ba, (uint8_t[]){ i }, 1);
        // assuming that both DC and AC Huffman coding tables are the same index, for instance if
        // this component uses DC Huffman table #0, we would assume that it also uses AC table #0.
        uint8_t ect_sel = (params->component_huffman_table_selectors[i] |
                           (params->component_huffman_table_selectors[i] << 4));
        bytearray_add_bytes(ba, (uint8_t[]){ ect_sel }, 1);
    }
    // start and end of spectral selection. constant for sequential mode.
    bytearray_add_bytes(ba, (uint8_t[]){ 0, 63 }, 2);

    // successive approximation bit positions: another technique for progressive decode. As we are
    // doing sequential, not progressive, this stays at 0.
    bytearray_add_bytes(ba, (uint8_t[]){ 0 }, 1);


    // initialize jpeg params's bit packer.
    // probably would be better if we just used the bit packer directly instead of maintaining a
    // byte array and a bitpacker, but here we are.
    params->bp.data = ba->base;
    params->bp.bitcount = 0;
    params->bp.datalen = ba->len;
    params->bp.idx = ba->index;

    return 0;
}

/**
 * The values coded into the file need to be converted as described in tables F.1 and F.2 of T.81.
 *
 * @param[in]     coefficient_value
 * @param[out]    bitlen              Bitlength of the returned coded value. Should be in [0, 11]
 */
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

static int huffman_encode_component(jmcujc_component_t* component,
                                    jmcujc_jpeg_params_t* params,
                                    jmcujc_bytearray_t* bytestream)
{
    int retval = 0;

    // temp code for monochrome images
    const int component_num = 0;

    // huffman code
    const int num_mcus = (component->width * component->height) / 64;
    for (int i = 0; i < num_mcus; i++) {
        uint8_t huff_tables = params->component_huffman_table_selectors[0];
        int dc_huff_idx = huff_tables;
        int ac_huff_idx = huff_tables;
        const huffman_reverse_lookup_table_t* dc_hrlt = &(params->dc_hrlts[dc_huff_idx]);
        const huffman_reverse_lookup_table_t* ac_hrlt = &(params->ac_hrlts[ac_huff_idx]);

        // huffman encode!
        float* source_block = component->samples + (i * 64);

        // ======= DC length and DC coefficient =======
        int dc_raw_length;
        int dc_diff = (int)roundf(source_block[0] - params->dc_prev[component_num]);
        params->dc_prev[component_num] = source_block[0];
        uint16_t coded_coefficient_value =
            coefficient_value_to_coded_value(dc_diff, &dc_raw_length);

        if ((dc_raw_length < 0) || (dc_raw_length > 11)) {
            retval = -1;
            goto _end;
        }

        const huffman_reverse_lookup_entry_t* huffman_code = &dc_hrlt->entries[dc_raw_length];
        if (huffman_code->bit_length == 0) {
            retval = -2;
            goto _end;
        }
        bit_packer_pack_u16(&params->bp, huffman_code->value, huffman_code->bit_length);
        bit_packer_pack_u16(&params->bp, coded_coefficient_value, dc_raw_length);

        // ======= AC coefficients =======
        unsigned int ac_coeff_idx = 1;

        static int16_t source_block_i16[64];
        for (int i = 1; i < 64; i++) {
            source_block_i16[i] = (int)roundf(source_block[i]);
        }
        while (ac_coeff_idx < 64) {
            // find next non-zero coefficient
            // I wonder if theres a more optimized way to do this?
            unsigned int l;
            for (l = ac_coeff_idx; (source_block_i16[l] == 0) && (l < 64); l++);

            int zeroes_to_rle = l - ac_coeff_idx;

            if (l == 64) {
                // we made it all the way to the end; slap an EOB in there.
                const huffman_reverse_lookup_entry_t* huffman_code = &ac_hrlt->entries[0];
                if (huffman_code->bit_length == 0) {
                    retval = -4;
                    goto _end;
                }
                bit_packer_pack_u16(&params->bp, huffman_code->value, huffman_code->bit_length);
            } else if ((zeroes_to_rle >= 0) && (zeroes_to_rle < 16)) {
                // pack AC coefficient normally
                int cidx = ac_coeff_idx + zeroes_to_rle;
                int ac_raw_length;
                uint16_t coded_coefficient_value =
                    coefficient_value_to_coded_value((int16_t)source_block_i16[cidx],
                                                     &ac_raw_length);

                if ((ac_raw_length < 0) || (ac_raw_length > 10)) {
                    retval = -3;
                    goto _end;
                }

                uint8_t rrrrssss = ((uint8_t)zeroes_to_rle << 4) | (ac_raw_length);
                const huffman_reverse_lookup_entry_t* huffman_code =
                    &ac_hrlt->entries[rrrrssss];
                if (huffman_code->bit_length == 0) {
                    retval = -4;
                    goto _end;
                }
                bit_packer_pack_u16(&params->bp, huffman_code->value, huffman_code->bit_length);
                bit_packer_pack_u16(&params->bp, coded_coefficient_value, ac_raw_length);
            } else {
                // if there are 17 or more zeroes that need to be RLE'd before another
                // coefficient is reached, we may only pack only 16 of them.
                uint8_t rrrrssss = 0xf0;
                const huffman_reverse_lookup_entry_t* huffman_code =
                    &ac_hrlt->entries[rrrrssss];
                if (huffman_code->bit_length == 0) {
                    retval = -4;
                    goto _end;
                }
                bit_packer_pack_u16(&params->bp, huffman_code->value, huffman_code->bit_length);

                l = ac_coeff_idx + 15;
            }

            ac_coeff_idx = l + 1;
        }
    }

_end:
    return retval;
}

int jmcujc_compress_component_to_bytestream(jmcujc_component_t* component,
                                            jmcujc_jpeg_params_t* params,
                                            jmcujc_bytearray_t* bytestream)
{
    /*
    for (int i = 0; i < ncomponents; i++) {
        jpeg_component_DCT(&components[i]);
    }
    */
    jpeg_component_DCT(params, component);
    // check and see if reverse huffman lookup tables have been initialized.
    if (!params->_hrlt_valid) {
        for (int i = 0; i < params->num_dc_huffman_tables; i++) {
            huffman_reverse_lookup_table_init(params->dc_huffman_tables[i],
                                              &params->dc_hrlts[i]);
        }
        for (int i = 0; i < params->num_ac_huffman_tables; i++) {
            huffman_reverse_lookup_table_init(params->ac_huffman_tables[i],
                                              &params->ac_hrlts[i]);
        }
    }

    //huffman_encode_component(&components[0], params, bytestream);
    huffman_encode_component(component, params, bytestream);

    return 0;
}

int jmcujc_add_eoi_marker(jmcujc_jpeg_params_t* params,
                          jmcujc_bytearray_t* ba)
{
    bit_packer_pad_end(&params->bp, 1);
    ba->index = params->bp.idx;
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xd9 }, 2);
    return 0;
}

const jmcujc_huffman_table_t lum_dc_huffman_table =
{
    .Ls = 0x1f,
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
const jmcujc_huffman_table_t lum_ac_huffman_table =
{
    .Ls = 0xb5,
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

const jmcujc_huffman_table_t chrom_dc_huffman_table =
{
    .Ls = 0x1f,
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

const jmcujc_huffman_table_t chrom_ac_huffman_table =
{
    .Ls = 0xb5,
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

const jmcujc_quantization_table_t lum_quant_table_best =
{
    .values = {
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

const jmcujc_quantization_table_t lum_quant_table_high =
{
    .values = {
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

const jmcujc_quantization_table_t lum_quant_table_medium =
{
    .values = {
        3    ,   2 * 2,   2 * 2,   3 * 2,  4 * 2,  6 * 2,  8 * 2, 10 * 2,
        2 * 2,   2 * 2,   2 * 2,   3 * 2,  4 * 2,  9 * 2, 10 * 2,  9 * 2,
        2 * 2,   2 * 2,   3 * 2,   4 * 2,  6 * 2,  9 * 2, 11 * 2,  9 * 2,
        2 * 2,   3 * 2,   4 * 2,   5 * 2,  8 * 2, 14 * 2, 13 * 2, 10 * 2,
        3 * 2,   4 * 2,   6 * 2,   9 * 2, 11 * 2, 17 * 2, 16 * 2, 12 * 2,
        4 * 2,   6 * 2,   9 * 2,  10 * 2, 13 * 2, 17 * 2, 18 * 2, 15 * 2,
        8 * 2,  10 * 2,  12 * 2,  14 * 2, 16 * 2, 19 * 2, 19 * 2, 16 * 2,
        12 * 2, 15 * 2,  15 * 2,  16 * 2, 18 * 2, 16 * 2, 16 * 2, 16 * 2
    }
};

const jmcujc_quantization_table_t lum_quant_table_low =
{
    .values = {
        3    ,   2 * 6,   2 * 6,   3 * 6,  4 * 6,  6 * 6,  8 * 6, 10 * 6,
        2 * 6,   2 * 6,   2 * 6,   3 * 6,  4 * 6,  9 * 6, 10 * 6,  9 * 6,
        2 * 6,   2 * 6,   3 * 6,   4 * 6,  6 * 6,  9 * 6, 11 * 6,  9 * 6,
        2 * 6,   3 * 6,   4 * 6,   5 * 6,  8 * 6, 14 * 6, 13 * 6, 10 * 6,
        3 * 6,   4 * 6,   6 * 6,   9 * 6, 11 * 6, 17 * 6, 16 * 6, 12 * 6,
        4 * 6,   6 * 6,   9 * 6,  10 * 6, 13 * 6, 17 * 6, 18 * 6, 15 * 6,
        8 * 6,  10 * 6,  12 * 6,  14 * 6, 16 * 6, 19 * 6, 19 * 6, 16 * 6,
        12 * 6, 15 * 6,  15 * 6,  16 * 6, 18 * 6, 16 * 6, 16 * 6, 16 * 6
    }
};

//const jmcujc_quantization_table_t lum_quant_table_lowest;

//const jmcujc_quantization_table_t chrom_quant_table_best;
const jmcujc_quantization_table_t chrom_quant_table_high =
{
    .values = {
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

const jmcujc_quantization_table_t chrom_quant_table_medium =
{
    .values = {
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

const jmcujc_quantization_table_t chrom_quant_table_low =
{
    .values = {
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

const jmcujc_jpeg_params_t bw_defaults =
{
    .num_dc_huffman_tables = 1,
    .dc_huffman_tables = {&lum_dc_huffman_table},

    .num_ac_huffman_tables = 1,
    .ac_huffman_tables = {&lum_ac_huffman_table},

    .num_quantization_tables = 1,
    .jpeg_quantization_tables = {&lum_quant_table_medium},

    .max_subsampling_factors = {1, 1},
    .width = 0,
    .height = 0,

    .component_huffman_table_selectors = {0},
    .component_quant_table_selectors = {0}
};

const jmcujc_jpeg_params_t rgb_defaults =
{
    .num_dc_huffman_tables = 2,
    .dc_huffman_tables = {&lum_dc_huffman_table, &chrom_dc_huffman_table},

    .num_ac_huffman_tables = 2,
    .ac_huffman_tables = {&lum_ac_huffman_table, &chrom_ac_huffman_table},

    .num_quantization_tables = 2,
    .jpeg_quantization_tables = {&lum_quant_table_medium, &chrom_quant_table_medium}
};
