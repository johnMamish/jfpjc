#include "jpeg.h"

#include "util.h"

static int jpeg_segment_header_store_to_file(const jpeg_segment_t* header, bytearray_t* ba)
{
    bytearray_add_bytes(ba, (uint8_t[]) { 0xff }, 1);
    bytearray_add_bytes(ba, &header->segment_marker, 1);

    uint8_t Lshton[] = { (header->Ls >> 8) & 0xff, (header->Ls & 0xff) };
    bytearray_add_bytes(ba, Lshton, 2);

    return 0;
}


static int jpeg_huffman_table_store_to_file(const jpeg_huffman_table_t* table, bytearray_t* ba)
{
    int retval = -1;
    if ((retval = jpeg_segment_header_store_to_file(&table->header, fp))) {
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


int jpeg_image_store_to_file(const char* filepath, const jpeg_image_t* jpeg)
{
    bytearray_t* ba = bytearray_create();

    // start by writing SOI
    bytearray_add_bytes(ba, (uint8_t[]){ 0xff, SOI }, 2);

    // write all random segments
    for (int i = 0; i < jpeg->num_misc_segments; i++) {
        if ((retval = jpeg_segment_header_store_to_file(&jpeg->misc_segments[i]->header, fp))) {
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
        if (jpeg->jpeg_quantization_tables[i].table_valid) {
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
            if ((retval = jpeg_huffman_table_store_to_file(table, fp))) {
                goto cleanup;
            }
        }
    }
    for (int i = 0; i < 4; i++) {
        const jpeg_huffman_table_t* table = &jpeg->ac_huffman_tables[i];
        if (table->header.segment_marker == DHT) {
            if ((retval = jpeg_huffman_table_store_to_file(table, fp))) {
                goto cleanup;
            }
        }
    }

    // write SOF
    jpeg_segment_header_store_to_file(&jpeg->frame_header.header, fp);
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
    jpeg_segment_header_store_to_file(&jpeg->scan.jpeg_scan_header.header, fp);
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

    // write EOI
    fwrite((uint8_t[]) {0xff, EOI}, 1, 2, fp);


    retval = 0;

cleanup:
    fclose(fp);
    return retval;
}


int jpeg_compress(const uncoded_jpeg_scan_t* jpeg,
                  const jpeg_huffman_table_t dc_huffman_tables[2],
                  const jpeg_huffman_table_t ac_huffman_tables[2],
                  const jpeg_quantization_table_t* quant_tables)
{

}
