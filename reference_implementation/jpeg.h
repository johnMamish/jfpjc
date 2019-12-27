/**
 * A lot of this code is copied from my jpeg-requantizer project
 */

#ifndef JPEG_H
#define JPEG_H

#include <stdbool.h>
#include <stdint.h>

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
    bool table_valid;

    // pq_tq<7:4> specify the bit-depth of samples. 0 for 8-bit, 1 for 16-bit.
    // pq_tq<3:0> specify the quantization table destination identifier.
    uint8_t pq_tq;
    union {
        uint8_t _8;
        uint16_t _16;
    } Q[64];
} jpeg_quantization_table_t;

typedef struct frame_component_specification_parameters
{
    uint8_t component_identifier;
    uint8_t horizontal_sampling_factor;
    uint8_t vertical_sampling_factor;
    uint8_t quantization_table_selector;
} frame_component_specification_parameters_t;

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

/**
 * Container for a jpeg image.
 *
 * In order to make porting to an embedded system simpler, this software only supports a single
 * scan.
 */
typedef struct jpeg_image
{
    // An array holding misc. segments.
    uint32_t num_misc_segments;
    jpeg_generic_segment_t** misc_segments;

    // no jpeg can have more than 4 huffman tables for either AC or DC.
    jpeg_huffman_table_t dc_huffman_tables[4];
    jpeg_huffman_table_t ac_huffman_tables[4];
    jpeg_quantization_table_t jpeg_quantization_tables[4];

    jpeg_frame_header_t frame_header;

    // This software only supports a single scan
    jpeg_scan_t scan;
} jpeg_image_t;

typedef struct dct_block
{
    int16_t values[64];
} dct_block_t;

typedef struct jpeg_dct_component
{
    uint32_t num_blocks;
    dct_block_t* blocks;
} jpeg_dct_component_t;

typedef struct uncoded_jpeg_scan
{
    // for now, only 1 is supported.
    int num_components;
    huffman_decoded_jpeg_component_t components[4];

    // for now, only values of 1 and 1 are supported.
    int H_max;
    int V_max;
} uncoded_jpeg_scan_t;


/**
 * Compresses a given uncoded jpeg scan into a bytestream. Requires that you provide huffman tables
 * and quantization tables. The given huffman and quantization tables will be included in the output
 * bytestream.
 *
 * huffman_tables[0] are used for the first component, huffman_tables[1] are used for all other
 * components.
 *
 * The number of quanitzation tables is expected to be the same as the number of components.
 *
 * returns the length of the bytestream.
 */
int jpeg_compress(const uncoded_jpeg_scan_t* jpeg,
                  const jpeg_huffman_table_t dc_huffman_tables[2],
                  const jpeg_huffman_table_t ac_huffman_tables[2],
                  const jpeg_quantization_table_t* quant_tables,
                  uint8_t** dest);

#endif
