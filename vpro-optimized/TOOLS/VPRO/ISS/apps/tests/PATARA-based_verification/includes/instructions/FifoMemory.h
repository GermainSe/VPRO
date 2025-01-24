//
// Created by gesper on 15.03.24.
//

#ifndef PATARA_BASED_VERIFICATION_FIFOMEMORY_H
#define PATARA_BASED_VERIFICATION_FIFOMEMORY_H

#include <cinttypes>

#define BUFFER_SIZE 16                 // muss 2^n betragen (8, 16, 32, 64 ...)
#define BUFFER_MASK (BUFFER_SIZE - 1)  // Klammern auf keinen Fall vergessen

class FifoMemory {
   public:
    struct Buffer {
        int data[BUFFER_SIZE];
        uint8_t read;   // zeigt auf das Feld mit dem ältesten Inhalt
        uint8_t write;  // zeigt immer auf leeres Feld
    } buffer;

    void reset();
    bool FIFO_in(int in_data);
    bool FIFO_pop();
    [[nodiscard]] bool FIFO_contains(int val1, int val2) const;
    [[nodiscard]] bool FIFO_contains(int val1) const;
    bool FIFO_out(int* out_data);

    unsigned int count() const;
};

#endif  //PATARA_BASED_VERIFICATION_FIFOMEMORY_H
