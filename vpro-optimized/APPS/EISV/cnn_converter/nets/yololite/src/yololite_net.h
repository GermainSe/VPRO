
#ifndef YOLOLITE_NET_H
#define YOLOLITE_NET_H

#include "layers.h"
#include "base_net.h"

using namespace CNN_LAYER;

class YoloLiteNet : public CNN_NET::Net {

public:
  
  YoloLiteNet() : CNN_NET::Net("YOLO-LITE") {}
  virtual void instantiateLayers() {

    // input layer
    auto l000 = new CNN_LAYER::Input;
    l000->name = "input";
    l000->number = 0;
    l000->out_dim.x = 224;
    l000->out_dim.y = 224;
    l000->out_dim.ch = 3;
    addLayer(l000);

    //// Layer 1
    auto l001 = new CNN_LAYER::Conv2D;
    l001->name = "Layer_1 CONV2+BIAS+RELU";
    l001->number = 1;
    l001->addSrcLayers({l000});
    l001->out_dim.ch = 16;
    l001->padding_mode = SAME;
    l001->kernel_length = 3;
    l001->stride = 1;
    l001->pool_size = {2, 2};
    l001->pool_stride = {2, 2};
    l001->pool_type = MAX_POOLING;
    l001->activation = LEAKY;
    l001->use_bias = true;
    l001->processParams();
    l001->loadQuantData();
    addLayer(l001);

    //// Layer 2
    auto l002 = new CNN_LAYER::Conv2D;
    l002->name = "Layer_2 CONV2+BIAS+RELU";
    l002->number = 2;
    l002->addSrcLayers({l001});
    l002->out_dim.ch = 32;
    l002->padding_mode = SAME;
    l002->kernel_length = 3;
    l002->stride = 1;
    l002->pool_size = {2, 2};
    l002->pool_stride = {2, 2};
    l002->pool_type = MAX_POOLING;
    l002->activation = LEAKY;
    l002->use_bias = true;
    l002->processParams();
    l002->loadQuantData();
    addLayer(l002);

    //// Layer 3
    auto l003 = new CNN_LAYER::Conv2D;
    l003->name = "Layer_3 CONV2+BIAS+RELU";
    l003->number = 3;
    l003->addSrcLayers({l002});
    l003->out_dim.ch = 64;
    l003->padding_mode = SAME;
    l003->kernel_length = 3;
    l003->stride = 1;
    l003->pool_size = {2, 2};
    l003->pool_stride = {2, 2};
    l003->pool_type = MAX_POOLING;
    l003->activation = LEAKY;
    l003->use_bias = true;
    l003->processParams();
    l003->loadQuantData();
    addLayer(l003);

    //// Layer 4
    auto l004 = new CNN_LAYER::Conv2D;
    l004->name = "Layer_4 CONV2+BIAS+RELU";
    l004->number = 4;
    l004->addSrcLayers({l003});
    l004->out_dim.ch = 128;
    l004->padding_mode = SAME;
    l004->kernel_length = 3;
    l004->stride = 1;
    l004->pool_size = {2, 2};
    l004->pool_stride = {2, 2};
    l004->pool_type = MAX_POOLING;
    l004->activation = LEAKY;
    l004->use_bias = true;
    l004->processParams();
    l004->loadQuantData();
    addLayer(l004);

    //// Layer 5
    auto l005 = new CNN_LAYER::Conv2D;
    l005->name = "Layer_5 CONV2+BIAS+RELU";
    l005->number = 5;
    l005->addSrcLayers({l004});
    l005->out_dim.ch = 128;
    l005->padding_mode = SAME;
    l005->kernel_length = 3;
    l005->stride = 1;
    l005->pool_size = {2, 2};
    l005->pool_stride = {2, 2};
    l005->pool_type = MAX_POOLING;
    l005->activation = LEAKY;
    l005->use_bias = true;
    l005->processParams();
    l005->loadQuantData();
    addLayer(l005);

    //// Layer 6
    auto l006 = new CNN_LAYER::Conv2D;
    l006->name = "Layer_6 CONV2+BIAS+RELU";
    l006->number = 6;
    l006->addSrcLayers({l005});
    l006->out_dim.ch = 256;
    l006->padding_mode = SAME;
    l006->kernel_length = 3;
    l006->stride = 1;
    l006->pool_type = NO_POOLING;
    l006->activation = LEAKY;
    l006->use_bias = true;
    l006->processParams();
    l006->loadQuantData();
    addLayer(l006);

    //// Layer 7
    auto l007 = new CNN_LAYER::Conv2D;
    l007->name = "Layer_7 CONV2+BIAS+NONE";
    l007->number = 7;
    l007->addSrcLayers({l006});
    l007->out_dim.ch = 125;
    l007->padding_mode = SAME;
    l007->kernel_length = 1;
    l007->stride = 1;
    l007->pool_type = NO_POOLING;
    l007->activation = NO_ACTIVATION;
    l007->use_bias = true;
    l007->out_is_result = true;
    l007->processParams();
    l007->loadQuantData();
    addLayer(l007);

    // auto-generated by main()
    // FIXME read at runtime like weights
#include "../weights/yololite_quantparams.inc"

  }

//    virtual void generateLayerExecList() {
//      // default: execute layers in instantiation order
//      layer_execlist.clear();
//      //      layer_execlist.reserve(layers.size());
//      for (std::vector<CNN_LAYER::Layer>::size_type i = 0; i < layers.size(); i++) {
//          if (layers[i]->number != 6 && layers[i]->number != 5) continue;
//        if (layers[i]->produces_binary_data) {
//          layer_execlist.push_back(i);
//          // std::cout << "Pushing layer index " << i << " to execution list\n";
//        }
//      }
//      // std::cout << "Layer execution list: " << layer_execlist.size() << " entries\n";
//    }

}; // class YoloLiteNet

#endif // YOLOLITE_NET_H
