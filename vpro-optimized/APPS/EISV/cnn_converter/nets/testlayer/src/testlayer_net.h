
#ifndef TESTLAYER_NET_H
#define TESTLAYER_NET_H

#include "conv_layer.h"
#include "base_net.h"

class TestlayerNet : public CNN_NET::Net {

public:
  
  TestlayerNet() : CNN_NET::Net("TESTLAYER") {}
    
  virtual void instantiateLayers() {

    // input layer
    auto in = new CNN_LAYER::Input;
    in->name = "input";
    in->number = -1;
    in->out_dim.x = 16;
    in->out_dim.y = 16;
    in->out_dim.ch = 2;
    addLayer(in);

    //// Layer 0
    auto l0 = new CNN_LAYER::Conv2D;
    l0->name = "L0";
    l0->number = 0;
    l0->addSrcLayers({in});
    l0->out_dim.ch = 3;
    l0->kernel_length = 3;
    l0->stride = 1;
    l0->pool_size = 1;
    l0->activation = NO_ACTIVATION;
    l0->use_bias = true;
    l0->out_is_result = true;
    l0->processParams();
    l0->loadQuantData();
    addLayer(l0);

  }
  
}; // class TestlayerNet

#endif // TESTLAYER_NET_H
