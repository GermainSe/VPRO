//
// Created by gesper on 11.01.24.
//

#ifndef PATARA_BASED_VERIFICATION_CHAIN_MEMORY_H
#define PATARA_BASED_VERIFICATION_CHAIN_MEMORY_H

#include <cstdint>

class ChainMemory {
   private:
    bool empty{true};
    bool full{false};

    int fifo_data{0};
    bool fifo_zflag{false};
    bool fifo_nflag{false};

    bool was_read{false};
    bool was_written{false};

    const char* name;
    bool verbose;

   public:
    ChainMemory(const char* name = "some FIFO", bool verbose = false)
        : name(name), verbose(verbose){};

    bool isEmpty() {
        return empty;
    }
    bool isFull() {
        return full;
    }

    void push(int data);
    int get();

    bool get_zflag() const;
    bool get_nflag() const;

    void tick();
};

#endif  //PATARA_BASED_VERIFICATION_CHAIN_MEMORY_H
