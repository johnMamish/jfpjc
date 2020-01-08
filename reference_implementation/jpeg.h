/**
 * A lot of this code is copied from my jpeg-requantizer project
 */

#ifndef JPEG_H
#define JPEG_H

#include <stdint.h>
#include "util.h"

typedef struct jpeg_segment
{
    uint8_t segment_marker;

    // Length of the following segment
    uint16_t Ls;
} jpeg_segment_t;


////////////////////////////////////////////////////////////////
// jpeg frame members
////////////////////////////////////////////////////////////////
typedef struct jpeg_huffman_table
{
    jpeg_segment_t header;
    uint8_t tc_td;
    uint8_t number_of_codes_with_length[16];
    uint8_t huffman_codes[256];
} jpeg_huffman_table_t;

typedef struct jpeg_quanitzation_table
{
    // this structure doesn't have a header, as one header can hold several quantization tables.

    // table valid marker for my own use.
    //bool table_valid;

    // pq_tq<7:4> specify the bit-depth of samples. 0 for 8-bit, 1 for 16-bit.
    // pq_tq<3:0> specify the quantization table destination identifier.
    uint8_t pq_tq;
    uint8_t Q[64];
} jpeg_quantization_table_t;

typedef struct frame_component_specification_parameters
{
    uint8_t component_identifier;
    uint8_t horizontal_sampling_factor;
    uint8_t vertical_sampling_factor;
    uint8_t quantization_table_selector;
} frame_component_specification_parameters_t;

typedef struct scan_component_specification_parameters
{
    uint8_t scan_component_selector;

    // Specifies one of four possible DC and AC entropy coding table destinations from which the
    // entropy table needed for decoding of the coefficients of component Csj is retrieved. DC and
    // AC coding table indicies are packed into one byte, with the DC index occupying the most-
    // significant nibble.
    uint8_t dc_ac_entropy_coding_table;
} scan_component_specification_parameters_t;


typedef struct jpeg_scan_header
{
    jpeg_segment_t header;

    // in many (most?) images, this will be 3.
    uint8_t num_components;

    scan_component_specification_parameters_t csps[4];

    uint8_t selection_start;
    uint8_t selection_end;
    uint8_t approximation_high_approximation_low;
} jpeg_scan_header_t;

typedef struct jpeg_frame_header
{
    jpeg_segment_t header;

    // Precision in bits. For baseline, expected to be 8.
    uint8_t  sample_precision;

    // Essentially the height of the image in pixels.
    uint16_t number_of_lines;

    // Essentially the width of the image in pixels.
    uint16_t samples_per_line;

    // Expected to be 3 or 1; one for each color.
    uint8_t  num_components;

    // The number of component specification parameters is equal to "num_components".
    frame_component_specification_parameters_t* csps;
} jpeg_frame_header_t;


typedef struct dct_block
{
    int values[64];
} dct_block_t;

typedef struct jpeg_dct_component
{
    uint32_t num_blocks;
    dct_block_t* blocks;

    // for now, only values of 1 and 1 are supported?
    int H_sample_factor;
    int V_sample_factor;

    int quant_table_selector;
    int entropy_coding_table;

    // in MCUs. Not strictly necessary for impl, but may help with validation
    int mcu_width;
    int mcu_height;
} jpeg_dct_component_t;

typedef struct uncoded_jpeg_scan
{
    // for now, only 1 is supported.
    int num_components;
    jpeg_dct_component_t components[4];

    // in pixels
    int width;
    int height;
} uncoded_jpeg_scan_t;

typedef struct component_params
{
    int H_sample_factor;
    int V_sample_factor;

    int quant_table_selector;
    int entropy_coding_table;
} component_params_t;

/**
 *
 */
uncoded_jpeg_scan_t* uncoded_jpeg_scan_create(const image_t* image,
                                              const component_params_t** params,
                                              int ncomponents,
                                              const jpeg_quantization_table_t** tables);


/**
 * Compresses a given uncoded jpeg scan into a bytestream. Requires that you provide huffman tables
 * and quantization tables. The given huffman and quantization tables will be included in the output
 * bytestream.
 *
 * {huffman,quant}_tables[0] are used for the first component, {huffman,quant}_tables[1] are used
 * for all other components. Unused spots for huffman and quant tables should be NULL.
 *
 * returns the length of the bytestream.
 */
int jpeg_compress(const uncoded_jpeg_scan_t* jpeg,
                  const jpeg_huffman_table_t* dc_huffman_tables[2],
                  const jpeg_huffman_table_t* ac_huffman_tables[2],
                  const jpeg_quantization_table_t* quant_tables[2],
                  uint8_t** dest);


const extern jpeg_huffman_table_t lum_dc_huffman_table;
const extern jpeg_huffman_table_t lum_ac_huffman_table;
const extern jpeg_huffman_table_t chrom_dc_huffman_table;
const extern jpeg_huffman_table_t chrom_ac_huffman_table;

const extern jpeg_quantization_table_t lum_quant_table_best;
const extern jpeg_quantization_table_t lum_quant_table_high;
const extern jpeg_quantization_table_t lum_quant_table_medium;
//const extern jpeg_quantization_table_t lum_quant_table_low;
//const extern jpeg_quantization_table_t lum_quant_table_lowest;

//const extern jpeg_quantization_table_t chrom_quant_table_best;
//const extern jpeg_quantization_table_t chrom_quant_table_high;
const extern jpeg_quantization_table_t chrom_quant_table_medium;
//const extern jpeg_quantization_table_t chrom_quant_table_low;
//const extern jpeg_quantization_table_t chrom_quant_table_lowest;


#endif
