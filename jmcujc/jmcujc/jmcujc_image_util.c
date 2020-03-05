#include "jmcujc_image_util.h"

#include <stdio.h>

void jmcujc_component_initialize_from_source_image_slice(jmcujc_component_t* component,
                                                         const jmcujc_source_image_slice_t* source,
                                                         float* storage,
                                                         const int offset,
                                                         const int height)
{
    component->samples = storage;
    component->width = source->width;
    component->height = height;

    component->subsampling_factors.horizontal_sampling_factor = 1;
    component->subsampling_factors.vertical_sampling_factor = 1;

    component->_dirty = false;


    // TODO: does the compiler actually optimize this well???
    const int width_in_MCUs = component->width / 8;
    const int height_in_MCUs = component->height / 8;
    int idx = 0;
    for (int MCU_y = 0; MCU_y < height_in_MCUs; MCU_y++) {
        for (int MCU_x = 0; MCU_x < width_in_MCUs; MCU_x++) {
            for (int block_y = 0; block_y < 8; block_y++) {
                for (int block_x = 0; block_x < 8; block_x++) {
                    const int src_idx = (((MCU_y * 8 * 8 * width_in_MCUs) + (MCU_x * 8)) +
                                         (((block_y + offset) * component->width) + block_x));
                    //printf("%i -> %i\n", src_idx, idx);
                    component->samples[idx++] = ((int)source->pixels[src_idx]) - 128;
                }
            }
        }
    }
}
