#ifndef _JMCUJC_H
#define _JMCUJC_H

#include <stdint.h>
#include <stdbool.h>

/**
 * This holds a single horizontal stripe of data in an image of the smallest height possible. For
 * instance, if this component has a vertical sampling factor of 2, its height shall be 16 samples.
 *
 *
 */
typedef struct jmcujc_component
{
    // points to
    uint8_t* samples;

    // Width and height of this component in samples.
    int width;
    int height;

    // The horizontal and vertical sampling factors are described in definitions 3.1.68 and 3.1.129
    // of ITU T.81. The larger these values are, the higher the resolution of this component is
    // relative to other components. These should be multiples of 2 and are generally not more than
    // 4. I guess it doesn't really matter what the exact values are as long as they aren't
    // relatively prime. If you stay under '4', this means that powers of 2 make the most sense,
    // cause you can either choose {1, 2, 4} or {1, 3}.
    int horizontal_sampling_factor;
    int vertical_sampling_factor;

    // the internal code sets this to clean once the data has been put into a huffman stream.
    bool _dirty;
} jmcujc_component_t;

/**
 *
 */
typedef struct jmcujc_huffman_table
{
    uint8_t number_of_codes_with_length[16];
    uint8_t huffman_codes[256];
} jmcujc_huffman_table_t;

/**
 *
 */
typedef struct jmcujc_quantization_table
{
    // jmcujc only supports 8-bit quantization tables.
    uint8_t values[64];
} jmcujc_quantization_table_t;

/**
 * jmcujc_jpeg_params contains all of the options and tables needed to compress image components
 * into a jpeg bytestream. These parameters are also used to generate jpeg headers.
 *
 * For most users, one of the preset defaults will work best.
 */
typedef struct jmcujc_jpeg_params
{
    int num_dc_huffman_tables;
    const jmcujc_huffman_table_t** dc_huffman_tables;
    int num_ac_huffman_tables;
    const jmcujc_huffman_table_t** ac_huffman_tables;

    // Idea: we could have a multiplication factor parameter here in addition to just a bunch of
    // quant tables.
    int num_quantization_tables;
    const jpeg_quantization_table_t** jpeg_quantization_tables;
} jmcujc_jpeg_params_t;


// constants
// --------------------------------
const extern jmcujc_huffman_table_t lum_dc_huffman_table;
const extern jmcujc_huffman_table_t lum_ac_huffman_table;
const extern jmcujc_huffman_table_t chrom_dc_huffman_table;
const extern jmcujc_huffman_table_t chrom_ac_huffman_table;


const extern jpeg_quantization_table_t lum_quant_table_best;
const extern jpeg_quantization_table_t lum_quant_table_high;
const extern jpeg_quantization_table_t lum_quant_table_medium;
const extern jpeg_quantization_table_t lum_quant_table_low;
const extern jpeg_quantization_table_t lum_quant_table_lowest;

const extern jpeg_quantization_table_t chrom_quant_table_best;
const extern jpeg_quantization_table_t chrom_quant_table_high;
const extern jpeg_quantization_table_t chrom_quant_table_medium;
const extern jpeg_quantization_table_t chrom_quant_table_low;
const extern jpeg_quantization_table_t chrom_quant_table_lowest;

const jmcujc_jpeg_params_t bw_defaults =
{
    .num_dc_huffman_tables = 1;
    .dc_huffman_tables = {&lum_dc_huffman_table};

    .num_ac_huffman_tables = 1;
    .ac_huffman_tables = {&lum_ac_huffman_table};

    .num_quantization_tables = 1;
    .jpeg_quantization_tables = {&lum_quant_table_medium};
};

const jmcujc_jpeg_params_t rgb_defaults =
{
    .num_dc_huffman_tables = 2;
    .dc_huffman_tables = {&lum_dc_huffman_table, &chrom_dc_huffman_table};

    .num_ac_huffman_tables = 2;
    .ac_huffman_tables = {&lum_ac_huffman_table, &chrom_ac_huffman_table};

    .num_quantization_tables = 2;
    .jpeg_quantization_tables = {&lum_quant_table_medium, &chrom_quant_table_medium};
};


/**
 * NB: These are just proto-prototypes (lol)
 */

/**
 * Given jpeg parameters and components with filled-out component parameters, puts all necessary
 * jpeg header information into the given bytestream. After calling this function, we're ready to
 * start compressing the components into the bytestream.
 */
int jmcujc_write_headers(const jmcujc_component_t* components,
                         const int ncomponents,
                         const jmcujc_jpeg_params_t* params,
                         bytearray_t* bytestream);


/**
 * Takes an array of components and appends them to the bytestream with components[0] interlaved
 * first, then components[1], ... components[n].
 *
 * @param[in]     components    Array of components to write to the bytestream. These components
 *                              can be part or all of an image, as long as they contain complete
 *                              lines and are at least one Minimum-Coded-Unit tall. All components
 *                              in the array must be the same length.
 * @param[in]     ncomponents   Number of components in the array that should be encoded.
 * @param[in]     params        Contains huffman and quantization tables to use.
 * @param[out]    bytestream
 * @return  returns 0 on success, < 0 on failure.
 */
int jmcujc_compress_components_to_bytestream(const jmcujc_component_t* components,
                                             const int ncomponents,
                                             const jmcujc_jpeg_params_t* params,
                                             bytearray_t* bytestream);



#endif
