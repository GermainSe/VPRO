#ifndef CNN_WEIGHTS
#define CNN_WEIGHTS

#include <stdint.h>

// Creation:  07/12/2022, 10:30:50

namespace  Layer_0 {

	// Input-Shape: (1, 224, 224, 3) 
	//           FPF:  2.12
	//           Data Range: Min = 0, Max = 4096
	//
	// Weight-Shape: (3, 16, 9) 
	//           FPF:  2.12
	//           Data Range: Min = -6711, Max = 6757
	//
	// Bias-Shape: (16,) 
	//           FPF:  2.12
	//           Data Range: Min = -2950, Max = 4929
	//
	// Conv-Relu Output-Shape: (1, 112, 112, 16) 
	//           FPF:  5.9
	//           Data Range: Min = -490, Max = 4166
	//

	extern int16_t conv_result_shift_right; 	// =  7
	extern int16_t bias_store_shift_right; 	// =  8
	extern int16_t bias_load_shift_right; 	// =  -5

	extern int16_t result_fractional_bit;
	extern int16_t result_integer_bit;

	//Data Format is (# in channels)(# out channels)(# kernel W*H)
	//Coeff fpf:  2.12
	extern int16_t conv_weights[3][16][9];

	//Data Format is (# out channels)
	//Bias fpf:  2.12
	extern int16_t bias[16];

}; // namespace  Layer_0 

namespace  Layer_1 {

	// Input-Shape: (1, 112, 112, 16) 
	//           FPF:  5.9
	//           Data Range: Min = -490, Max = 4166
	//
	// Weight-Shape: (16, 32, 9) 
	//           FPF:  2.12
	//           Data Range: Min = -4161, Max = 4264
	//
	// Bias-Shape: (32,) 
	//           FPF:  2.12
	//           Data Range: Min = -3849, Max = 6030
	//
	// Conv-Relu Output-Shape: (1, 56, 56, 32) 
	//           FPF:  6.8
	//           Data Range: Min = -497, Max = 4099
	//

	extern int16_t conv_result_shift_right; 	// =  6
	extern int16_t bias_store_shift_right; 	// =  7
	extern int16_t bias_load_shift_right; 	// =  -3

	extern int16_t result_fractional_bit;
	extern int16_t result_integer_bit;

	//Data Format is (# in channels)(# out channels)(# kernel W*H)
	//Coeff fpf:  2.12
	extern int16_t conv_weights[16][32][9];

	//Data Format is (# out channels)
	//Bias fpf:  2.12
	extern int16_t bias[32];

}; // namespace  Layer_1 

namespace  Layer_2 {

	// Input-Shape: (1, 56, 56, 32) 
	//           FPF:  6.8
	//           Data Range: Min = -497, Max = 4099
	//
	// Weight-Shape: (32, 64, 9) 
	//           FPF:  1.13
	//           Data Range: Min = -6664, Max = 6943
	//
	// Bias-Shape: (64,) 
	//           FPF:  3.11
	//           Data Range: Min = -2970, Max = 5310
	//
	// Conv-Relu Output-Shape: (1, 28, 28, 64) 
	//           FPF:  6.8
	//           Data Range: Min = -816, Max = 5027
	//

	extern int16_t conv_result_shift_right; 	// =  6
	extern int16_t bias_store_shift_right; 	// =  7
	extern int16_t bias_load_shift_right; 	// =  -4

	extern int16_t result_fractional_bit;
	extern int16_t result_integer_bit;

	//Data Format is (# in channels)(# out channels)(# kernel W*H)
	//Coeff fpf:  1.13
	extern int16_t conv_weights[32][64][9];

	//Data Format is (# out channels)
	//Bias fpf:  3.11
	extern int16_t bias[64];

}; // namespace  Layer_2 

namespace  Layer_3 {

	// Input-Shape: (1, 28, 28, 64) 
	//           FPF:  6.8
	//           Data Range: Min = -816, Max = 5027
	//
	// Weight-Shape: (64, 128, 9) 
	//           FPF:  1.13
	//           Data Range: Min = -3355, Max = 4224
	//
	// Bias-Shape: (128,) 
	//           FPF:  2.12
	//           Data Range: Min = -3389, Max = 4702
	//
	// Conv-Relu Output-Shape: (1, 14, 14, 128) 
	//           FPF:  6.8
	//           Data Range: Min = -821, Max = 4123
	//

	extern int16_t conv_result_shift_right; 	// =  6
	extern int16_t bias_store_shift_right; 	// =  7
	extern int16_t bias_load_shift_right; 	// =  -3

	extern int16_t result_fractional_bit;
	extern int16_t result_integer_bit;

	//Data Format is (# in channels)(# out channels)(# kernel W*H)
	//Coeff fpf:  1.13
	extern int16_t conv_weights[64][128][9];

	//Data Format is (# out channels)
	//Bias fpf:  2.12
	extern int16_t bias[128];

}; // namespace  Layer_3 

namespace  Layer_4 {

	// Input-Shape: (1, 14, 14, 128) 
	//           FPF:  6.8
	//           Data Range: Min = -821, Max = 4123
	//
	// Weight-Shape: (128, 128, 9) 
	//           FPF:  1.13
	//           Data Range: Min = -2720, Max = 5737
	//
	// Bias-Shape: (128,) 
	//           FPF:  1.13
	//           Data Range: Min = -4673, Max = 5867
	//
	// Conv-Relu Output-Shape: (1, 7, 7, 128) 
	//           FPF:  5.9
	//           Data Range: Min = -1180, Max = 7090
	//

	extern int16_t conv_result_shift_right; 	// =  5
	extern int16_t bias_store_shift_right; 	// =  7
	extern int16_t bias_load_shift_right; 	// =  -3

	extern int16_t result_fractional_bit;
	extern int16_t result_integer_bit;

	//Data Format is (# in channels)(# out channels)(# kernel W*H)
	//Coeff fpf:  1.13
	extern int16_t conv_weights[128][128][9];

	//Data Format is (# out channels)
	//Bias fpf:  1.13
	extern int16_t bias[128];

}; // namespace  Layer_4 

namespace  Layer_5 {

	// Input-Shape: (1, 7, 7, 128) 
	//           FPF:  5.9
	//           Data Range: Min = -1180, Max = 7090
	//
	// Weight-Shape: (128, 256, 9) 
	//           FPF:  0.14
	//           Data Range: Min = -5978, Max = 4646
	//
	// Bias-Shape: (256,) 
	//           FPF:  0.14
	//           Data Range: Min = -4982, Max = 7306
	//
	// Conv-Relu Output-Shape: (1, 7, 7, 256) 
	//           FPF:  5.9
	//           Data Range: Min = -833, Max = 5797
	//

	extern int16_t conv_result_shift_right; 	// =  7
	extern int16_t bias_store_shift_right; 	// =  7
	extern int16_t bias_load_shift_right; 	// =  -2

	extern int16_t result_fractional_bit;
	extern int16_t result_integer_bit;

	//Data Format is (# in channels)(# out channels)(# kernel W*H)
	//Coeff fpf:  0.14
	extern int16_t conv_weights[128][256][9];

	//Data Format is (# out channels)
	//Bias fpf:  0.14
	extern int16_t bias[256];

}; // namespace  Layer_5 

namespace  Layer_6 {

	// Input-Shape: (1, 7, 7, 256) 
	//           FPF:  5.9
	//           Data Range: Min = -833, Max = 5797
	//
	// Weight-Shape: (256, 125, 1) 
	//           FPF:  1.13
	//           Data Range: Min = -4098, Max = 4841
	//
	// Bias-Shape: (125,) 
	//           FPF:  2.12
	//           Data Range: Min = -7090, Max = 6088
	//
	// Conv-Relu Output-Shape: (1, 7, 7, 125) 
	//           FPF:  5.9
	//           Data Range: Min = -5598, Max = 6721
	//

	extern int16_t conv_result_shift_right; 	// =  5
	extern int16_t bias_store_shift_right; 	// =  8
	extern int16_t bias_load_shift_right; 	// =  -5

	extern int16_t result_fractional_bit;
	extern int16_t result_integer_bit;

	//Data Format is (# in channels)(# out channels)(# kernel W*H)
	//Coeff fpf:  1.13
	extern int16_t conv_weights[256][125][1];

	//Data Format is (# out channels)
	//Bias fpf:  2.12
	extern int16_t bias[125];

}; // namespace  Layer_6 


#endif //CNN_WEIGHTS
