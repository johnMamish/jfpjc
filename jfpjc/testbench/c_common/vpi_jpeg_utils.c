/**
 * This file contains some C helper functions that can be used to test some fundamental
 * jpeg compression functionality.
 */

#include <stdlib.h>
#include <stdio.h>
#include <string.h>

#include "vpi_user.h"

#include "dct_utils.h"


/**
 * This convenience struct holds args for the image_take_dcts System Task.
 */
typedef struct image_take_dcts_args
{
    vpiHandle array_in_handle;
    vpiHandle array_out_handle;
    vpiHandle image_width_handle;
    vpiHandle image_height_handle;

    int32_t image_width;
    int32_t image_height;
} image_take_dcts_args_t;


static PLI_INT32 vpi_get_value_integer(vpiHandle h);
int count_vpi_args(vpiHandle systf_handle);
int check_arg_types(vpiHandle systf_handle, const PLI_INT32* expected_arg_types, int numargs);
static image_take_dcts_args_t* image_take_dcts_args_create(void);
static void image_take_dcts_args_destroy(image_take_dcts_args_t* args);
static int image_take_dcts_check_arg_dims(image_take_dcts_args_t* args);
int vpi_memory_to_uint8_array(uint8_t** target, vpiHandle mem);
void int16_array_to_vpi_memory(vpiHandle mem, int16_t* src, int len);
static void image_subtract_dc(int8_t* image, int len);
void image_reshape_to_mcus(uint8_t* image, int width, int height);


PLI_INT32 image_take_dcts_calltf(void);
PLI_INT32 image_take_dcts_compiletf(void);
void image_take_dcts_register(void);

/**
 * Helper function that returns the integer value of a vpi object.
 *
 * This function only works properly for some objects (integer constants, integer variables,
 * registers with length less than 33, etc). IEEE 1364-2005 isn't very clear on what happens if
 * you try to retrieve the integer value of a vpi object that doesn't have a sensible integer
 * value; in those cases, this function's behavior is undefined.n
 */
static PLI_INT32 vpi_get_value_integer(vpiHandle h)
{
    s_vpi_value sv;
    sv.format = vpiIntVal;
    vpi_get_value(h, &sv);
    return sv.value.integer;
}

/**
 * Given a handle to a vpiSysTfCall, counts the number of arguments passed to that sysTfCall.
 */
int count_vpi_args(vpiHandle systf_handle)
{
    vpiHandle arg_iterator = vpi_iterate(vpiArgument, systf_handle);
    if (arg_iterator == NULL) {
        return 0;
    } else {
        int argcount = 0;
        while (vpi_scan(arg_iterator) != NULL) {
            argcount++;
        }
        return argcount;
    }
}

/**
 * This convenience function checks the vpiType of all of the arguments against a list of expected
 * types. It prints out an error and returns nonzero if any of the arguments don't match up.
 *
 * This function assumes that there is at least one argument and that numargs matches the number of
 * arguments actually provided. It shouldn't be used to check number of args.
 */
int check_arg_types(vpiHandle systf_handle, const PLI_INT32* expected_arg_types, int numargs)
{
    int retval = 0;

    vpiHandle arg_iterator = vpi_iterate(vpiArgument, systf_handle);
    vpiHandle arg;
    int i = 0;
    while(((arg = vpi_scan(arg_iterator)) != NULL) && (i < numargs)) {
        PLI_INT32 arg_type = vpi_get(vpiType, arg);
        if (arg_type != expected_arg_types[i]) {
            retval = -1;
            vpi_printf("ERROR: arg %i is of type %s, which is invalid.\n",
                       i, vpi_get_str(vpiType, arg));
        }
        i++;
    }

    return retval;
}

/**
 * Creates a new image_take_dcts_args struct and then fills it out with handles to the VPI objects
 * that were passed in to the present Verilog System Task.
 *
 * This function takes no arguments, it implicitly gets a handle to the current vpiSysTfCall by
 *     vpi_handle(vpiSysTfCall, NULL);
 */
static image_take_dcts_args_t* image_take_dcts_args_create()
{
    image_take_dcts_args_t* args = calloc(1, sizeof(image_take_dcts_args_t));

    vpiHandle systf_handle = vpi_handle(vpiSysTfCall, NULL);
    vpiHandle arg_iterator = vpi_iterate(vpiArgument, systf_handle);
    args->array_in_handle = vpi_scan(arg_iterator);
    args->array_out_handle = vpi_scan(arg_iterator);
    args->image_width_handle = vpi_scan(arg_iterator);
    args->image_height_handle = vpi_scan(arg_iterator);
    vpi_free_object(arg_iterator);

    // get values for width and height
    args->image_width = vpi_get_value_integer(args->image_width_handle);
    args->image_height = vpi_get_value_integer(args->image_height_handle);

    return args;
}

/**
 * Destroys a image_take_dcts_args_t struct.
 */
static void image_take_dcts_args_destroy(image_take_dcts_args_t* args)
{
    free(args);
}

/**
 * Checks that the dimensions of all the arguments are correct.
 *
 * If some don't make sense, prints an error and returns nonzero.
 */
static int image_take_dcts_check_arg_dims(image_take_dcts_args_t* args)
{
    PLI_INT32 in_size = vpi_get(vpiSize, args->array_in_handle);
    PLI_INT32 out_size = vpi_get(vpiSize, args->array_out_handle);

    int retval = 0;

    if (in_size != out_size) {
        vpi_printf("ERROR: size of input memory and output memory are not equal.\n");
        retval = -1;
    }

    if (((args->image_width % 8) != 0) || ((args->image_height % 8) != 0)) {
        vpi_printf("ERROR: image width and height must both be multiples of 8.\n");
        retval = -1;
    }

    if ((args->image_width * args->image_height) != in_size) {
        vpi_printf("ERROR: size of input memory does not match given image width and height.\n");
        retval = -1;
    }

    vpiHandle mem_in_iter = vpi_iterate(vpiMemoryWord, args->array_in_handle);
    vpiHandle reg_in = vpi_scan(mem_in_iter);
    if (vpi_get(vpiSize, reg_in) != 8) {
        vpi_printf("ERROR: elements of input memory array must have length of 8 bits.\n");
        retval = -1;
    }
    vpi_free_object(mem_in_iter);

    vpiHandle mem_out_iter = vpi_iterate(vpiMemoryWord, args->array_out_handle);
    vpiHandle reg_out = vpi_scan(mem_out_iter);
    if (vpi_get(vpiSize, reg_out) != 16) {
        vpi_printf("ERROR: elements of output memory array must have length of 16 bits.\n");
        retval = -1;
    }
    vpi_free_object(mem_out_iter);

    return retval;
}

int vpi_memory_to_uint8_array(uint8_t** target, vpiHandle mem)
{
    PLI_INT32 in_size = vpi_get(vpiSize, mem);
    *target = calloc(in_size, sizeof(int8_t));
    vpiHandle reg;
    vpiHandle iter = vpi_iterate(vpiMemoryWord, mem);
    int i = 0;
    while ((reg = vpi_scan(iter)) != NULL) {
        s_vpi_value reg_value;
        reg_value.format = vpiIntVal;
        vpi_get_value(reg, &reg_value);
        (*target)[i++] = (uint8_t)reg_value.value.integer;
    }

    return (int)in_size;
}

void int16_array_to_vpi_memory(vpiHandle mem, int16_t* src, int len)
{
    vpiHandle iter = vpi_iterate(vpiMemoryWord, mem);
    for (int i = 0; i < len; i++) {
        vpiHandle reg;
        reg = vpi_scan(iter);

        s_vpi_value reg_value;
        reg_value.format = vpiIntVal;
        reg_value.value.integer = (int32_t)src[i];   // NB: will sign-extend
        vpi_put_value(reg, &reg_value, NULL, vpiNoDelay);
    }
}


static void image_subtract_dc(int8_t* image, int len)
{
    for (int i = 0; i < len; i++) {
        image[i] -= 128;
    }
}

/**
 * Given an image in row-major order, reshapes it so that it's in "MCU-major" order
 *
 * Assumes that both the width and height of the image are multiples of 8.
 */
void image_reshape_to_mcus(uint8_t* image, int width, int height)
{
    uint8_t* temp = malloc(width * height * sizeof(uint8_t));
    memcpy(temp, image, width * height * sizeof(uint8_t));

    int out_idx = 0;
    for (int mcu_y = 0; mcu_y < (height / 8); mcu_y++) {
        for (int mcu_x = 0; mcu_x < (width / 8); mcu_x++) {
            const int topleft_idx = ((mcu_y * 8) * width) + (mcu_x * 8);
            for (int y = 0; y < 8; y++) {
                for (int x = 0; x < 8; x++) {
                    const int idx = topleft_idx + (y * width) + x;
                    image[out_idx++] = temp[idx];
                }
            }
        }
    }

    free(temp);
}

/**
 * This System Task takes a register array holding a uint8_t image in row-major order, and outputs
 * a series of 8x8 DCT blocks into an int16_t memory.
 *
 * [0:63] of the output array hold the 8x8 DCT corresponding to the top, leftmost 8x8 tile in the
 * source image.
 * [64:127] of the output array hold the 8x8 DCT of the second 8x8 tile of the source image.
 * Subsequent 8x8 DCT tiles are arranged in row-major order.
 */
PLI_INT32 image_take_dcts_calltf()
{
    image_take_dcts_args_t* args = image_take_dcts_args_create();

    uint8_t* image;
    int image_size = vpi_memory_to_uint8_array(&image, args->array_in_handle);
    image_subtract_dc((int8_t*)image, image_size);
    image_reshape_to_mcus(image, args->image_width, args->image_height);

    int16_t* dcts_out = calloc(image_size, sizeof(int16_t));
    for (int i = 0; i < (image_size / 64); i++) {
        dct88_q8((int8_t*)image + (i * 64), dcts_out + (i * 64));
    }
    int16_array_to_vpi_memory(args->array_out_handle, dcts_out, image_size);

    image_take_dcts_args_destroy(args);
    free(image);
    free(dcts_out);
    return 0;
}

PLI_INT32 image_take_dcts_compiletf()
{
    vpiHandle systf_handle = vpi_handle(vpiSysTfCall, NULL);
    if (systf_handle == NULL) {
        vpi_printf("$loeffler_dct: ERROR: NULL systf handle\n");
        vpi_control(vpiFinish, 0);
        return 0;
    }

    int numargs = count_vpi_args(systf_handle);
    if (numargs != 4) {
        vpi_printf("$loeffler_dct: ERROR: 4 args required; %i args found.\n", numargs);
        vpi_control(vpiFinish, 0);
        return 0;
    }

    const PLI_INT32 expected_arg_types[] = { vpiMemory, vpiMemory, vpiConstant, vpiConstant };
    if (check_arg_types(systf_handle, expected_arg_types, 4) != 0) {
         vpi_control(vpiFinish, 0);
         return 0;
    }

    image_take_dcts_args_t* args = image_take_dcts_args_create();
    if (image_take_dcts_check_arg_dims(args) != 0) {
         vpi_control(vpiFinish, 0);
         return 0;
    }
    image_take_dcts_args_destroy(args);

    return 0;
}

void image_take_dcts_register()
{
    s_vpi_systf_data tfd;

    tfd.type = vpiSysTask;
    tfd.sysfunctype = 0;
    tfd.tfname = "$image_take_dcts";
    tfd.calltf = (PLI_INT32 (*)(PLI_BYTE8*))image_take_dcts_calltf;
    tfd.compiletf = (PLI_INT32 (*)(PLI_BYTE8*))image_take_dcts_compiletf;
    tfd.sizetf = NULL;
    tfd.user_data = NULL;

    vpi_register_systf(&tfd);
}

void (*vlog_startup_routines[])(void) =
{
    image_take_dcts_register,
    0
};
