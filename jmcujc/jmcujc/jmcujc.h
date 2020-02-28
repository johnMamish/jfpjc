#ifndef _JMCUJC_H
#define _JMCUJC_H

#include <stdbool.h>
#include <stdint.h>

typedef struct jmcujc_component jmcujc_component_t;

#include "jmcujc_image_util.h"
#include "jmcujc_utils.h"

typedef struct jmcujc_subsampling_factors
{
    int horizontal_sampling_factor;
    int vertical_sampling_factor;
} jmcujc_subsampling_factors_t;

/**
 * This holds a single horizontal stripe of data in an image of the smallest height possible. For
 * instance, if this component has a vertical sampling factor of 2, its height shall be 16 samples.
 *
 * XXX TODO: do I gain anything with the restriction that components must be "as short as possible"?
 * I don't think so; the "height restriction" was just in the spirit of keeping the memory footprint
 * as small as possible... For platforms with enough memory to afford it, it doesn't really help
 * simplify software development in a meaningful way.
 *
 * I think the restriction should be that components have a height that's a multiple of the largest
 * sampling factor in the image's components.
 *
 * The data pointed by this struct should be ready for compression. In the color image case, it
 * should be debayered and - if appropriate - transformed according to the JFIF spec.
 */
struct jmcujc_component
{
    // points to data to be directly encoded into DCT MCU blocks
    float* samples;

    // Width and height of this component in samples (not pixels).
    int width;
    int height;

    // The horizontal and vertical sampling factors are described in definitions 3.1.68 and 3.1.129
    // of ITU T.81. The larger these values are, the higher the resolution of this component is
    // relative to other components. These should be multiples of 2 and are generally not more than
    // 4. I guess it doesn't really matter what the exact values are as long as they aren't
    // relatively prime. If you stay under '4', this means that powers of 2 make the most sense,
    // cause you can either choose {1, 2, 4} or {1, 3}.
    jmcujc_subsampling_factors_t subsampling_factors;

    // the internal code sets this to clean once the data has been put into a huffman stream.
    bool _dirty;
};

/**
 *
 */
typedef struct jmcujc_huffman_table
{
    uint8_t Ls;
    uint8_t tc_td;
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
    const jmcujc_huffman_table_t* dc_huffman_tables[4];
    int num_ac_huffman_tables;
    const jmcujc_huffman_table_t* ac_huffman_tables[4];

    // Idea: we could have a multiplication factor parameter here in addition to just a bunch of
    // quant tables.
    int num_quantization_tables;
    const jmcujc_quantization_table_t* jpeg_quantization_tables[4];

    // Takes the highest value for both horizontal and vertical subsampling factors from all
    // components
    jmcujc_subsampling_factors_t max_subsampling_factors;

    // width and height of image in pixels.
    int width;
    int height;

    // These table selectors map sequentially to components. selector #0 is used for
    // component 0, selector #1 is used for component 1, etc.
    // These arrays need to be filled out with valid values for as many components as there are.
    // Values beyond the number of components are don't care.
    int component_huffman_table_selectors[4];
    int component_quant_table_selectors[4];
} jmcujc_jpeg_params_t;

// constants
// --------------------------------
const extern jmcujc_huffman_table_t lum_dc_huffman_table;
const extern jmcujc_huffman_table_t lum_ac_huffman_table;
const extern jmcujc_huffman_table_t chrom_dc_huffman_table;
const extern jmcujc_huffman_table_t chrom_ac_huffman_table;


const extern jmcujc_quantization_table_t lum_quant_table_best;
const extern jmcujc_quantization_table_t lum_quant_table_high;
const extern jmcujc_quantization_table_t lum_quant_table_medium;
//const extern jmcujc_quantization_table_t lum_quant_table_low;
//const extern jmcujc_quantization_table_t lum_quant_table_lowest;

//const extern jmcujc_quantization_table_t chrom_quant_table_best;
const extern jmcujc_quantization_table_t chrom_quant_table_high;
const extern jmcujc_quantization_table_t chrom_quant_table_medium;
const extern jmcujc_quantization_table_t chrom_quant_table_low;
//const extern jmcujc_quantization_table_t chrom_quant_table_lowest;

const extern jmcujc_jpeg_params_t bw_defaults;

const extern jmcujc_jpeg_params_t rgb_defaults;


/**
 * NB: These are just proto-prototypes
 */

/**
 * Given jpeg parameters and components with filled-out component parameters, puts all necessary
 * jpeg header information into the given bytestream. After calling this function, we're ready to
 * start compressing the components into the bytestream.
 */
int jmcujc_write_headers(const jmcujc_component_t* components,
                         const int ncomponents,
                         const jmcujc_jpeg_params_t* params,
                         jmcujc_bytearray_t* bytestream);


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
                                             jmcujc_bytearray_t* bytestream);



#endif
