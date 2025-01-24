//
// Created by gesper on 11.01.24.
//

#include "addressing/chain_memory.h"
#include <assert.h>
#include <cstdio>

void ChainMemory::push(int data) {
    assert(full == false);
    assert(empty == true);

    fifo_data = data;
    fifo_zflag = (fifo_data == 0);
    fifo_nflag = (fifo_data < 0);

    was_written = true;
}

int ChainMemory::get() {
    assert(full == true);
    assert(empty == false);

    was_read = true;

    return fifo_data;
}

bool ChainMemory::get_zflag() const {
    assert(full == true);
    assert(empty == false);
    assert(was_read == true);

    return fifo_zflag;
}
bool ChainMemory::get_nflag() const {
    assert(full == true);
    assert(empty == false);
    assert(was_read == true);

    return fifo_nflag;
}

void ChainMemory::tick() {
    // never both at same time (TODO)
    assert(!(was_read && was_written));

    if (was_read) {
        empty = true;
        full = false;
        was_read = false;
        if (verbose) printf("%s was read: %i | %x!\n", name, fifo_data, fifo_data);
    }
    if (was_written) {
        full = true;
        empty = false;
        was_written = false;
        if (verbose) printf("%s was written: %i | %x!\n", name, fifo_data, fifo_data);
    }
}
