#ifndef _JMCUJC_CLI_EXAMPLE_UTIL_H
#define _JMCUJC_CLI_EXAMPLE_UTIL_H

#include <pam.h>

#include "jmcujc.h"
#include "jmcujc_utils.h"

#define PAM_MEMBER_OFFSET(mbrname)                    \
    ((unsigned long int)(char*)&((struct pam *)0)->mbrname)
#define PAM_MEMBER_SIZE(mbrname) \
    sizeof(((struct pam *)0)->mbrname)
#define PAM_STRUCT_SIZE(mbrname) \
    (PAM_MEMBER_OFFSET(mbrname) + PAM_MEMBER_SIZE(mbrname))



/**
 * This utility function reads in an entire PAM image and stores it as a jmcujc image slice.
 */
jmcujc_source_image_slice_t* grayscale_source_image_from_pam(const char* file, const char* argv0);

#endif
