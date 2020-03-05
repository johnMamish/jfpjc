/**
 * This file contains utility functions for processing raw sensor data into components that are
 * ready to be compressed into jpegs. For instance, it has utility functions to do
 *
 *   * DC level removal
 *   * Debayering
 *   * JFIF
 *   * Image masking
 *
 * The above functions are planned, but not all are implemented yet.
 */

#ifndef _JMCUJC_COMPONENTS_H
#define _JMCUJC_COMPONENTS_H

#include "jmcujc.h"

/**
 * This structure contains pixel data for horizontal stripes of images that have not yet been
 * subsampled. It can be used in pre-subsampling steps for DC level removal, debayering, image
 * masking, and JFIF color transforms.
 *
 * It is assumed that one of these slices covers the source image horizontally; if a source image
 * is 320 pixels wide, the slice should be 320 pixels wide.
 *
 * XXX TODO; relevant functions unimplemented.
 */
typedef struct jmcujc_image_slice
{
    // Pointer to pixel data. Pixel values are in range [0, 255].
    float* pixels;

    // Width and height of this strip in pixels
    int width;
    int height;

    // Offset into source image. This can be used in case the system can't hold an entire frame in
    // its memory at once. If the entire frame is in memory, it's best to just keep this at 0.
    // Note that there's no "xstart" only "ystart"; "xstart" should always be 0.
    int yoffset;
} jmcujc_image_slice_t;

/**
 *
 */
typedef struct jmcujc_source_image_slice
{
    // Pointer to raw pixel data straight from image sensor
    uint8_t* pixels;

    // Width and height of the strip in pixels
    int width;
    int height;

    // Offset into full image.
    int yoffset;
} jmcujc_source_image_slice_t;

/**
 * Takes data directly from a source image buffer and converts it into a component ready for
 * processing by jmcujc. Basically all this means is that it fills out a component struct and
 * removes "DC bias" from the input image.
 *
 * This function is only appropriate for grayscale images; rgb images will require bayer and JFIF
 * preprocessing. Because this function is only used for images with one (grayscale) component,
 * we assume that the subsampling factors are {1, 1}.
 *
 * @param[out]   component     Target structure to be filled out.
 * @param[in]    source        Points to the raw pixel data to be put into the component struct.
 * @param[in]    storage       Space that has been allocated for the component structure
 * @param[in]    offset        Vertical offset in pixels into the source image that this component
 *                             starts at
 * @param[in]    height        Height of the output component. Note that the width comes from the
 *                             source image slice.
 */
void jmcujc_component_initialize_from_source_image_slice(jmcujc_component_t* component,
                                                         const jmcujc_source_image_slice_t* source,
                                                         float* storage,
                                                         const int offset,
                                                         const int height);

#endif
