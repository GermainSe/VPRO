#ifndef DCONVTEST3_CONV_H
#define DCONVTEST3_CONV_H

#include "layers.h"
#include "base_net.h"

// TODO(Jasper): Load net parameters dynamically at netgen runtime
#include "../params/dconvtest_params.h"

class DConvTest3ConvNet : public CNN_NET::Net {

public:

  DConvTest3ConvNet() : CNN_NET::Net("DCONVTEST_3_CONV") {}

  virtual void instantiateLayers() {

    // input layer (deform output)
    auto in = new CNN_LAYER::Input;
    in->name = "input";
    in->number = -1;
    in->out_dim.x = DCONVTEST_INPUT_WIDTH * 9;
    in->out_dim.y = DCONVTEST_INPUT_HEIGHT;
    in->out_dim.ch = DCONVTEST_INPUT_CHANNELS;
    addLayer(in);

    //// Layer 0
    auto l0 = new CNN_LAYER::DConvConv;
    l0->name = "L0";
    l0->number = 0;
    l0->addSrcLayers({in});
    l0->out_dim.ch = DCONVTEST_OUTPUT_CHANNELS;
    l0->kernel_length = 9;
    l0->use_bias = true;
    l0->out_is_result = true;
    l0->result_shift_right = L0_RESULT_SHIFT_RIGHT;
    l0->bias_shift_right = L0_BIAS_SHIFT_RIGHT;
    l0->store_shift_right = L0_STORE_SHIFT_RIGHT;
    l0->processParams();
    l0->loadQuantData();
    addLayer(l0);

  }

}; // class DConvTest3ConvNet

#endif // DCONVTEST3_CONV_H
