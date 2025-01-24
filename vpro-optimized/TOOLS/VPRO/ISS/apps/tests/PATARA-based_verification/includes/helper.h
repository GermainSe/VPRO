#ifndef P_HELPER_H
#define P_HELPER_H

#include <cstdint>

namespace DataFormat {
/**
* @brief limit and extend data to 5-bit unsigned
*
* @param data 5-bit domain!
* @return unsign data in 32-bit format
*/
uint32_t unsigned5Bit(int32_t data);
/**
* @brief limit and extend data to 8-bit unsigned
* @param data 8-bit domain!
* @return unsign data in 32-bit format
*/
int32_t unsigned8Bit(int32_t data);
/**
* @brief limit and extend data to 8-bit signed
*
* @param data 8-bit domain!
* @return sign data in 32-bit format
*/
int32_t signed8Bit(int32_t data);
/**
* @brief limit and extend data to 16-bit unsigned
* @param data 16-bit domain!
* @return unsign data in 32-bit format
*/
int32_t unsigned16Bit(int32_t data);
/**
* @brief limit and extend data to 16-bit signed
*
* @param data 16-bit domain!
* @return sign data in 32-bit format
*/
int32_t signed16Bit(int32_t data);
/**
* @brief limit and extend data to 18-bit signed
*
* @param data 18-bit domain!
* @return sign data in 32-bit format
*/
int32_t signed18Bit(int32_t data);
/**
* @brief limit and extend data to 24-bit signed
*
* @param data 24-bit domain!
* @return sign data in 32-bit format
*/
int32_t signed24Bit(int32_t data);
/**
* @brief limit and extend data to 24-bit signed
*
* @param data 24-bit domain!
* @return sign data in 32-bit format
*/
uint32_t unsigned24Bit(int32_t data);
/**
* @brief limit and extend data to 48-bit signed
*
* @param data 48-bit domain!
* @return sign data in 64-bit format
*/
int64_t signed48Bit(int64_t data);


/**
* @brief limit and extend data to 48-bit signed
*
* @param data 24-bit domain!
* @return sign data in 64-bit format
*/
int64_t signed24_to_48Bit(int32_t data);
}  // namespace DataFormat

#endif