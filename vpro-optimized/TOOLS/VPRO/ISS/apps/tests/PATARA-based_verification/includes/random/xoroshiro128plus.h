//
// Created by gesper on 15.02.24.
//
#ifndef XORO_SHIRO_128_PLUS
#define XORO_SHIRO_128_PLUS

#include <stdint.h>
#include <inttypes.h>
#include <sys/time.h>
#include <eisv.h>
#include <vpro.h>

/* Only expose the method that is relevant */

namespace RANDOM_XOR{

__attribute__((unused)) static uint64_t s[2];
__attribute__((unused)) static const uint64_t SEED_SCRAMBLER = 0x37bc7dd1f3339a5fULL;

/**
 * Automatically initializes the seed vector for the xoroshiro128+
 * PRNG, using a part of the current time (in microseconds) and
 * a seed scrambler.
 */
void xoroshiro128plus_seed_auto();

/**
 * Initializes the seed vector with a starting value. This is useful
 * for debugging when reproducible scenarios are desirable.
 */
void xoroshiro128plus_seed_with(uint64_t x);

/**
 * Returns 64 randomly generated bits.
 */
uint64_t xoroshiro128plus_next();

/**
 * This is the jump function for the generator. It is equivalent
 * to 2^64 calls to next(); it can be used to generate 2^64
 * non-overlapping subsequences for parallel computations.
 */
void jump();


__attribute__((unused)) static uint64_t splitmix64next(const uint64_t x) {
    uint64_t z = (x + 0x9e3779b97f4a7c15);
    z = (z ^ (z >> 30)) * 0xbf58476d1ce4e5b9;
    z = (z ^ (z >> 27)) * 0x94d049bb133111eb;
    return z ^ (z >> 31);
}


__attribute__((unused)) static uint64_t time_based_x() {
    //    // Obtain the (relative, partial) time information
    //    // in microseconds
    //    struct timeval currentTime;
    //    gettimeofday(&currentTime, nullptr);
    //    uint64_t x = currentTime.tv_usec;
    //    // Combine and generate the seed.
    //    x *= 1000000; // us per s
    //    x += currentTime.tv_usec;
    //    x ^= (x << 32) ^ SEED_SCRAMBLER;
    //    return x;

    uint64_t cycles = aux_get_sys_time_lo();
    cycles += (uint64_t(aux_get_sys_time_hi()) << 32);

    uint64_t freq_k = get_gpr_risc_freq()/1000/1000;
    uint64_t time = cycles / freq_k; // us

    return (cycles << 32) ^ time ^ SEED_SCRAMBLER;
}

__attribute__((unused)) static inline uint64_t rotl(const uint64_t x, int k) {
    return (x << k) | (x >> (64 - k));
}

}

#endif