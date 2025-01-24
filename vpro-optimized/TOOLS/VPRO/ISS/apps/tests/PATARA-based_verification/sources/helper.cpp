#include "helper.h"

namespace DataFormat {

uint32_t unsigned5Bit(int32_t data){
    uint32_t result = data & 0b11111;
    return result;
}
int32_t unsigned8Bit(int32_t data) {
    int32_t result = data & 0xff;
    return result;
}
int32_t unsigned16Bit(int32_t data) {
    int32_t result = data & 0xffff;
    return result;
}
int32_t signed8Bit(int32_t data) {
    int32_t result = data & 0xff;
    if ((data & 0x80) != 0) {
        result = int32_t(data | 0xffffff00);  // the value is negative
    }
    return result;
}
int32_t signed16Bit(int32_t data) {
    int32_t result = data & 0xffff;
    if ((data & 0x8000) != 0) {
        result = int32_t(data | 0xffff0000);  // the value is negative
    }
    return result;
}
int32_t signed18Bit(int32_t data) {
    int32_t result = data & 0x3ffff;
    if ((data & 0x00020000) != 0) {
        result = int32_t(data | 0xfffc0000);  // the value is negative
    }
    return result;
}
int32_t signed24Bit(int32_t data) {
    int32_t result = data & 0xffffff;
    if ((data & 0x00800000) != 0) {
        result = int32_t(data | 0xff000000);  // the value is negative
    }
    return result;
}
int32_t signed24Bit(int64_t data) {
    auto result = int32_t(data & 0xffffff);
    if ((data & 0x00800000) != 0) {
        result = int32_t(data | 0xff000000);  // the value is negative
    }
    return result;
}
uint32_t unsigned24Bit(int32_t data){
    auto result = uint32_t(data & 0xffffff);
    return result;

}
int64_t signed48Bit(int64_t data) {
    auto result = int64_t(data & 0xffffffffffffL);
    if ((data & 0x800000000000L) != 0) {
        result = int64_t(uint64_t(data) | 0xffff000000000000L);  // the value is negative
    }
    return result;
}

int64_t signed24_to_48Bit(int32_t data){
    int64_t result = data & 0xffffff;
    if ((data & 0x00800000) != 0) {
        result = int64_t(uint64_t(data) | 0xffffffffff000000L);  // the value is negative
    }
    return result;
}

}  // namespace DataFormat
