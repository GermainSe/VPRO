#ifndef DCONVTEST1_OFFSETCONV_H
#define DCONVTEST1_OFFSETCONV_H

#include "layers.h"
#include "base_net.h"

// TODO(Jasper): Load net parameters dynamically at netgen runtime
#include "../params/dconvtest_params.h"

class DConvTest1OffsetconvNet : public CNN_NET::Net {

public:

  DConvTest1OffsetconvNet() : CNN_NET::Net("DCONVTEST_1_OFFSETCONV") {}

  virtual void instantiateLayers() {

    // input layer
    auto in = new CNN_LAYER::Input;
    in->name = "input";
    in->number = -1;
    in->out_dim.x = DCONVTEST_INPUT_WIDTH;
    in->out_dim.y = DCONVTEST_INPUT_HEIGHT;
    in->out_dim.ch = DCONVTEST_INPUT_CHANNELS;
    addLayer(in);

    //// Layer 0
    auto l0 = new CNN_LAYER::Conv2D;
    l0->name = "L0";
    l0->number = 0;
    l0->addSrcLayers({in});
    l0->out_dim.ch = 27;
    l0->kernel_length = 3;
    l0->stride = 1;
    l0->use_bias = true;
    l0->out_is_result = true;
    l0->result_shift_right = L0_RESULT_SHIFT_RIGHT;
    l0->bias_shift_right = L0_BIAS_SHIFT_RIGHT;
    l0->store_shift_right = L0_STORE_SHIFT_RIGHT;
    l0->processParams();
    l0->loadQuantData();
    addLayer(l0);

  }

}; // class DConvTest1OffsetconvNet

#endif // DCONVTEST1_OFFSETCONV_H
