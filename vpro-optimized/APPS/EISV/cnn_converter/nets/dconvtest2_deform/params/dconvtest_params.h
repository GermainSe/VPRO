// Generated File
// Contains dynamic parameters, like input size and channel count

#ifndef DCONVTEST_PARAMS_H
#define DCONVTEST_PARAMS_H

// Input and Output dimensions
constexpr uint16_t DCONVTEST_INPUT_WIDTH = 32;
constexpr uint16_t DCONVTEST_INPUT_HEIGHT = 32;
constexpr uint16_t DCONVTEST_INPUT_CHANNELS = 16;
constexpr uint16_t DCONVTEST_OUTPUT_CHANNELS = 16;

// Quantization constants (shift values)
constexpr uint16_t L0_RESULT_SHIFT_RIGHT = 8;
constexpr uint16_t L0_BIAS_SHIFT_RIGHT = 0;
constexpr uint16_t L0_STORE_SHIFT_RIGHT = 0;

// Deform step constants
constexpr uint16_t MAX_OFFSET_X = 8;
constexpr uint16_t MAX_OFFSET_Y = 8;

#endif // DCONVTEST_PARAMS_H

