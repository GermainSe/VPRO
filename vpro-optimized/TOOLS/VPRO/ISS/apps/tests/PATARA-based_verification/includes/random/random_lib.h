//
// Created by gesper on 15.02.24.
//

#ifndef PATARA_BASED_VERIFICATION_RANDOM_LIB_H
#define PATARA_BASED_VERIFICATION_RANDOM_LIB_H

#include <stdint.h>
#include <inttypes.h>

/*
 * Initializes the PRNG. Uses the current time to seed
 * it. It's expected resolution is in microseconds.
 */
void init_rand();

/*
 * Initializes the PRNG with a given seed.
 */
void init_rand_seed(uint64_t x);

/*
 * Returns a random integer in the range 0 (inclusive)
 * and limit (exclusive). The integers generated are uniformly
 * distributed.
 */
uint64_t next_uint64(uint64_t limit);
uint64_t next_uint64();

/*
 * Returns a 32-bit unsigned integer.
 */
uint32_t next_uint32();

/*
 * Returns a boolean value. The expected probability of
 * both values is 50%.
 */
bool next_bool();

/*
 * Returns a uniformly distributed double between 0
 * (inclusive) and 1 (exclusive).
 */
double next_double();

/*
 * Returns a normally distributed double between -1.0
 * and +1.0
 */
double next_gaussian();

#endif  //PATARA_BASED_VERIFICATION_RANDOM_LIB_H
