//
// Created by gesper on 01.06.23.
//

#ifndef TEMPLATE_DMABLOCKEXTRACTOR_H
#define TEMPLATE_DMABLOCKEXTRACTOR_H

// C std libraries
#include <unistd.h>
#include <cinttypes>
#include <cstdarg>
#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>

class ISS;

class DMABlockExtractor {
   public:
    explicit DMABlockExtractor(ISS* core) : core(core){};

    void newSize(const uint32_t size) {
        size_ff = size;
    };

    void newAddrTrigger(uint32_t addr, uint32_t offset_shift);

    [[nodiscard]] bool isBusy() const {
        return busy;
    };

    void tick();

   private:
    ISS* core;

    uint32_t size_ff{};
    uint64_t addr_ff{};

    bool busy{false};
};

#endif  //TEMPLATE_DMABLOCKEXTRACTOR_H
