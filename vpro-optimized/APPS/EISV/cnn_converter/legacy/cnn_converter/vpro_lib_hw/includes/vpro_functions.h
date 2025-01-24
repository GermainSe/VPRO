

#ifndef vpro_functions
#define vpro_functions

#include <cnn_struct_reduced.h>

namespace VPRO_CONST {
    constexpr int32_t leak[25] = {0,     0,      0,      1,     2,      3,
                                  6,     13,     26,     51,    102,    205,
                                  410,   819,    1638,   3277,  6554,   13107,
                                  26214, 52429,  104858, 209715,419430, 838861,
                                  1677722};
}

extern uint32_t RF_KERNEL_BASE;
extern uint32_t RF_BIAS_BASE;
extern uint32_t RF_RELU_6_BASE;
extern uint32_t kernel_x, kernel_y;
extern uint32_t vector_length, vector_length_compensate;



#ifndef SIMULATION
void create_conv_template_functions(const LAYER_WRAPPER &layer);
#endif

#endif
