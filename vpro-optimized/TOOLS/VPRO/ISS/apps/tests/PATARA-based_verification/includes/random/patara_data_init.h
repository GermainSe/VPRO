//
// Created by gesper on 15.02.24.
//

#ifndef PATARA_BASED_VERIFICATION_PATARA_DATA_INIT_H
#define PATARA_BASED_VERIFICATION_PATARA_DATA_INIT_H

#include "stdint.h"

void gen_random_mm_data(bool init_seed_const = true);

static const uint64_t init_seed = 8955458308048543928;

void gen_incremented_mm_data();

#endif  //PATARA_BASED_VERIFICATION_PATARA_DATA_INIT_H
