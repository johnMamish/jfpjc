#include "./jpeg.h"

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
                            accum += image->components[idx][component_number];
                        }
                    }

                    data_in[mcu_y * 8 + mcu_x] = accum / pix_per_samp;
                }
            }

            // do DCT
            int mcuidx = (y * (image->width / MCU_width_pixels)) + x;
            mcu_fdct_floats(data_in, component->blocks[mcuidx].values);
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

#if 0
bytearray_t* jpeg_write_image(const jpeg_image_t* jpeg)
{
    bytearray_t* ba = bytearray_create();

    // start by writing SOI
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, SOI }, 2);

    // write all random segments
    for (int i = 0; i < jpeg->num_misc_segments; i++) {
        if ((retval = jpeg_write_segment_header(&jpeg->misc_segments[i]->header, fp))) {
            goto cleanup;
        }
        if (fwrite(jpeg->misc_segments[i]->data, 1, jpeg->misc_segments[i]->header.Ls - 2, fp) !=
            jpeg->misc_segments[i]->header.Ls - 2) {
            retval = -1;
            goto cleanup;
        }
    }

    // write quantization tables
    if (fwrite((uint8_t[]){ 0xff, DQT }, 2, 1, fp) != 1) {
        retval = -1;
        goto cleanup;
    }

    // calculate length of quantization tables. assume they are all 8-bit.
    int num_valid_qtables = 0;
    for (int i = 0; i < 4; i++) {
        if (jpeg->jpeg_write_quantization_tables[i].table_valid) {
            num_valid_qtables++;
        }
    }
    uint16_t qtLs = 65 * num_valid_qtables + 2;
    uint8_t Lshton[] = { ((qtLs >> 8) & 0xff), qtLs & 0xff };
    fwrite(Lshton, 1, 2, fp);

    for (int i = 0; i < 4; i++) {
        const jpeg_quantization_table_t* qt = &jpeg->jpeg_quantization_tables[i];
        if (qt->table_valid) {
            if (fwrite(&qt->pq_tq, 1, 1, fp) != 1) {
                retval = -1;
                goto cleanup;
            }

            for (int i = 0; i < 64; i++) {
                if (((qt->pq_tq >> 4) & 0x0f) == 0) {
                    // 8-bit quant table
                    if (fwrite(&qt->Q[i]._8, 1, 1, fp) != 1) {
                        retval = -1;
                        goto cleanup;
                    }
                } else {
                    // 16-bit quant table
                    // TODO WRONG BIT ORDER.
                    if (fwrite(&qt->Q[i]._16, 2, 1, fp) != 1) {
                        retval = -1;
                        goto cleanup;
                    }
                }
            }
        }
    }

    // write huffman tables
    for (int i = 0; i < 4; i++) {
        const jpeg_huffman_table_t* table = &jpeg->dc_huffman_tables[i];
        if (table->header.segment_marker == DHT) {
            if ((retval = jpeg_write_huffman_table(table, fp))) {
                goto cleanup;
            }
        }
    }
    for (int i = 0; i < 4; i++) {
        const jpeg_huffman_table_t* table = &jpeg->ac_huffman_tables[i];
        if (table->header.segment_marker == DHT) {
            if ((retval = jpeg_write_huffman_table(table, fp))) {
                goto cleanup;
            }
        }
    }

    // write SOF
    jpeg_write_segment_header(&jpeg->frame_header.header, fp);
    fwrite(&jpeg->frame_header.sample_precision, 1, 1, fp);
    uint8_t nlhton[] = { (jpeg->frame_header.number_of_lines >> 8) & 0xff,
                         (jpeg->frame_header.number_of_lines) & 0xff };
    fwrite(nlhton, 2, 1, fp);
    uint8_t splhton[] = { (jpeg->frame_header.samples_per_line >> 8) & 0xff,
                          (jpeg->frame_header.samples_per_line) & 0xff };
    fwrite(splhton, 2, 1, fp);
    fwrite(&jpeg->frame_header.num_components, 1, 1, fp);
    for (int i = 0; i < jpeg->frame_header.num_components; i++) {
        frame_component_specification_parameters_t* csp = &jpeg->frame_header.csps[i];
        fwrite(&csp->component_identifier, 1, 1, fp);
        uint8_t hi_vi = (csp->horizontal_sampling_factor << 4) | csp->vertical_sampling_factor;
        fwrite(&hi_vi, 1, 1, fp);
        fwrite(&csp->quantization_table_selector, 1, 1, fp);
    }

    // write SOS
    jpeg_write_segment_header(&jpeg->scan.jpeg_scan_header.header, fp);
    fwrite(&jpeg->scan.jpeg_scan_header.num_components, 1, 1, fp);
    for (int i = 0; i < jpeg->scan.jpeg_scan_header.num_components; i++) {
        fwrite(&jpeg->scan.jpeg_scan_header.csps[i].scan_component_selector, 1, 1, fp);
        fwrite(&jpeg->scan.jpeg_scan_header.csps[i].dc_ac_entropy_coding_table, 1, 1, fp);
    }
    fwrite(&jpeg->scan.jpeg_scan_header.selection_start, 1, 1, fp);
    fwrite(&jpeg->scan.jpeg_scan_header.selection_end, 1, 1, fp);
    fwrite(&jpeg->scan.jpeg_scan_header.approximation_high_approximation_low, 1, 1, fp);

    // write ecs.
    // do it byte by byte in case any byte-stuffing needs to happen.
    for (int i = 0; i < jpeg->scan.entropy_coded_segments[0]->size; i++) {
        uint8_t writebyte = jpeg->scan.entropy_coded_segments[0]->data[i];
        fwrite(&writebyte, 1, 1, fp);

        if (writebyte == 0xff) {
            fwrite((uint8_t[]) {0x00}, 1, 1, fp);
        }
    }


    retval = 0;

cleanup:
    fclose(fp);
    return retval;
}
#endif

int jpeg_huffman_code(const uncoded_jpeg_scan_t* scan,
                      const jpeg_huffman_table_t* dc_huffman_tables[2],
                      const jpeg_huffman_table_t* ac_huffman_tables[2],
                      uint8_t** result)
{
    *result = malloc(100);

    return 0;
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
    bytearray_add_bytes(ba, (const uint8_t*)jfifseg, 16);

    // ======= quant tables =======
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xdb }, 1);

    int num_valid_qtables = count_non_null_elements((const void**)quant_tables, 4);
    uint16_t qtLs = 65 * num_valid_qtables + 2;
    bytearray_add_bytes(ba, (uint8_t[]){ ((qtLs >> 8) & 0xff), qtLs & 0xff }, 2);

    for (int i = 0; i < 4; i++) {
        if (quant_tables[i] != NULL) {
            bytearray_add_bytes(ba, &quant_tables[i]->pq_tq, 1);
            bytearray_add_bytes(ba, quant_tables[i]->Q, 64);
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
    }

    // ======= SOS =======
    // entropy / huffman table is selected here.
    int SOS_len = 6 + (2 * scan->num_components);
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, 0xda, 0x00, SOS_len }, 4);
    bytearray_add_bytes(ba, (uint8_t[]){ scan->num_components }, 1);
    for (int i = 0; i < scan->num_components; i++) {
        bytearray_add_bytes(ba, (uint8_t[]){ i }, 1);
        bytearray_add_bytes(ba, (uint8_t[]){ scan->components[i].entropy_coding_table }, 1);
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

    uint8_t* ecs;
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


#warning "huffman tables not done!"
#if 0
const jmcujc_huffman_table_t lum_dc_huffman_table = { 0 };
const jmcujc_huffman_table_t lum_ac_huffman_table = { 0 };
const jmcujc_huffman_table_t chrom_dc_huffman_table = { 0 };
const jmcujc_huffman_table_t chrom_ac_huffman_table = { 0 };
#endif

//const jpeg_quantization_table_t lum_quant_table_best;
//const jpeg_quantization_table_t lum_quant_table_high;
const jpeg_quantization_table_t lum_quant_table_medium =
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
//const jpeg_quantization_table_t lum_quant_table_low;
//const jpeg_quantization_table_t lum_quant_table_lowest;

//const jpeg_quantization_table_t chrom_quant_table_best;
//const jpeg_quantization_table_t chrom_quant_table_high;
const jpeg_quantization_table_t chrom_quant_table_medium =
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
//const jpeg_quantization_table_t chrom_quant_table_low;
//const jpeg_quantization_table_t chrom_quant_table_owest;
