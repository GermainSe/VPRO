//
// Created by gesper on 15.02.24.
//

#include "random/random_lib.h"
#include <float.h>
#include <math.h>
#include <cfenv>
#include "random/xoroshiro128plus.h"

using namespace RANDOM_XOR;

/*
 * Initializes the PRNG. Uses the current time to seed
 * it. It's expected resolution is in microseconds.
 */
void init_rand()
{
    xoroshiro128plus_seed_auto();
}

/*
 * Initializes the PRNG with a given seed.
 */
void init_rand_seed(uint64_t x)
{
    xoroshiro128plus_seed_with(x);
}

/*
 * Returns a random integer in the range 0 (inclusive)
 * and limit (exclusive). The integers generated are uniformly
 * distributed.
 */
uint64_t next_uint64(const uint64_t limit)
{
    return xoroshiro128plus_next() % limit;
}

uint64_t next_uint64()
{
    return xoroshiro128plus_next();
}

static uint32_t next_uint32_temp;
static bool has_next_uint32 = false;

/*
 * Returns a 32-bit unsigned integer.
 */
uint32_t next_uint32()
{
    // Generate 2 ints at a time out of one call to next()
    // This makes use of both halves of the 64 bits generated

    uint32_t val;
    if (has_next_uint32) {
        val = next_uint32_temp;
    } else {
        uint64_t full = xoroshiro128plus_next();
        val = full >> 32;                    // The upper half
        next_uint32_temp = (uint32_t)(full); // The lower half
    }
    // quick flip
    has_next_uint32 ^= true;
    return val;
}

/*
 * Returns a boolean value. The expected probability of
 * both values is 50%.
 */
bool next_bool()
{
    // Sign test as per the recommendation
    // We check if the highest bit is on
    return xoroshiro128plus_next() & 1;
}

/*
 * Returns a uniformly distributed double between 0
 * (inclusive) and 1 (exclusive).
 */
//double next_double()
//{
//    // return ((double) next()) / ((double) UINT64_MAX);
//    // return (next() >> 11) * (1. / (UINT64_C(1) << 53));
//    static_assert(DBL_EPSILON/2 == 0x1.0p-53);
//    return (xoroshiro128plus_next() >> 11) * 0x1.0p-53;
//}
double next_double() {
#define DBL_UINT64_MAX_P1 ((UINT64_MAX/2 + 1)*2.0)
    int save_round = fegetround();
    fesetround(FE_DOWNWARD);
    double d = xoroshiro128plus_next() / DBL_UINT64_MAX_P1;
    fesetround(save_round);
    return d;
}

/*
 * Returns a normally distributed double between -1.0
 * and +1.0
 */
double next_gaussian()
{
    static double next_gaussian;
    static bool has_next_gaussian = false;

    double val;
    if (has_next_gaussian) {
        val = next_gaussian;
    } else {
        double u, v, s;
        do {
            // Limit u and v to the range [-1, 1]
            u = next_double() * 2 - 1;
            v = next_double() * 2 - 1;
            s = u * u + v * v;
        } while(s > 1);

        double scale = 0;
        if (s != 0)
            sqrt(-2.0 * log(s) / s);
        next_gaussian = v * scale;
        val = u * scale;
    }
    // Quick flip
    has_next_gaussian ^= true;
    return val;
}