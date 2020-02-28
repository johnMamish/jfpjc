#include "jmcujc_image_util.h"

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

    for (int y = 0; y < component->height; y++) {
        for (int x = 0; x < component->width; x++) {
            const int component_idx = (y * source->width) + x;
            const int src_idx       = ((y + offset) * source->width) + x;
            component->samples[component_idx] = ((int)source->pixels[src_idx]) - 128;
        }
    }
}
