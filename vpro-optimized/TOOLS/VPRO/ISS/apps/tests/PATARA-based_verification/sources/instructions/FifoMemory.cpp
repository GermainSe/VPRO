//
// Created by gesper on 15.03.24.
//

#include "instructions/FifoMemory.h"

bool FifoMemory::FIFO_in(int in_data) {
    uint8_t next = ((buffer.write + 1) & BUFFER_MASK);
    if (buffer.read == next) return false;
    buffer.data[buffer.write] = in_data;
    buffer.write = next;
    return true;
}

bool FifoMemory::FIFO_pop() {
    if (buffer.read == buffer.write) return false;
    buffer.read = (buffer.read + 1) & BUFFER_MASK;
    return true;
}

bool FifoMemory::FIFO_contains(int val1, int val2) const {
    auto read = buffer.read;
    bool contains = false;
    while (read != buffer.write) {
        contains |= (val1 == buffer.data[read]) | (val2 == buffer.data[read]);
        read = (read + 1) & BUFFER_MASK;
    }
    return contains;
}

bool FifoMemory::FIFO_contains(int val1) const {
    auto read = buffer.read;
    bool contains = false;
    while (read != buffer.write) {
        contains |= (val1 == buffer.data[read]);
        read = (read + 1) & BUFFER_MASK;
    }
    return contains;
}

bool FifoMemory::FIFO_out(int* out_data) {
    if (buffer.read == buffer.write) return false;
    *out_data = buffer.data[buffer.read];
    buffer.read = (buffer.read + 1) & BUFFER_MASK;
    return true;
}

void FifoMemory::reset() {
    buffer = {{}, 0, 0};
}

unsigned int FifoMemory::count() const {
    if (buffer.read > buffer.write)
        return buffer.write - buffer.read;
    else if (buffer.write > buffer.read)
        return BUFFER_SIZE - (buffer.read - buffer.write);
    else // equal
        return 0;
}
