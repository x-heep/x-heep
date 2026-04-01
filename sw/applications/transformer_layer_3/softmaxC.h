//
// Created by alireza on 10/6/23.
//

#ifndef FVLLMONTITRANSFORMER_SOFTMAXC_H
#define FVLLMONTITRANSFORMER_SOFTMAXC_H

#include <stdint.h>
// #include <stdlib.h>
#include "param.h"
#include <math.h>
#if !HAVE_FPU
#include "integer_approx_fpops.h"
#endif

void computeSoftmax(int16_t* input, size_t seq_len);


#endif //FVLLMONTITRANSFORMER_SOFTMAXC_H
