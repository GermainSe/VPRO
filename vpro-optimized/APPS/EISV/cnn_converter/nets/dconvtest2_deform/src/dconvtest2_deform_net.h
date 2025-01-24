#ifndef DCONVTEST2_DEFORM_H
#define DCONVTEST2_DEFORM_H

#include "layers.h"
#include "base_net.h"

// TODO(Jasper): Load net parameters dynamically at netgen runtime
#include "../params/dconvtest_params.h"

class DConvTest2DeformNet : public CNN_NET::Net {

public:

  DConvTest2DeformNet() : CNN_NET::Net("DCONVTEST_2_DEFORM") {}

  virtual void instantiateLayers() {

    // input layer
    auto in = new CNN_LAYER::Input;
    in->name = "input";
    in->number = -1;
    in->out_dim.x = DCONVTEST_INPUT_WIDTH;
    in->out_dim.y = DCONVTEST_INPUT_HEIGHT;
    in->out_dim.ch = DCONVTEST_INPUT_CHANNELS;
    addLayer(in);

    // offsetconv output
    auto offset = new CNN_LAYER::Input;
    offset->name = "offset";
    offset->number = -2;
    offset->out_dim.x = DCONVTEST_INPUT_WIDTH;
    offset->out_dim.y = DCONVTEST_INPUT_HEIGHT;
    offset->out_dim.ch = 27;
    addLayer(offset);

    //// Layer 0
    auto l0 = new CNN_LAYER::DConvDeform;
    l0->name = "L0";
    l0->number = 0;
    l0->setSrcLayers(in, offset);
    l0->kernel_size = 9;
    l0->max_offset_x = MAX_OFFSET_X;
    l0->max_offset_y = MAX_OFFSET_Y;
    l0->out_is_result = true;
    l0->processParams();
    l0->loadQuantData();
    addLayer(l0);

  }

}; // class DConvTest2DeformNet

#endif // DCONVTEST2_DEFORM_H
