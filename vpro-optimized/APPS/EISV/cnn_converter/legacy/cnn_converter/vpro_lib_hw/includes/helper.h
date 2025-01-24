


#ifndef helper
#define helper

#ifdef SIMULATION
    #include <iostream>
    #include <fstream>
    #include "cnn_struct.h"
    #include <list>
    #include <vector>
    #include <QFile>
    #include <simulator/helper/typeConversion.h>
    #include <core_wrapper.h>
#else
    #include "cnn_struct_reduced.h"
    #include <vpro.h>
    #include <eisv.h>
    typedef unsigned int size_t;
#endif

const char* print(LAYERTYPE::LAYERTYPE type);
const char* print(RELUTYPE::RELUTYPE type);
const char* print(POOLTYPE::POOLTYPE type);
const char* print(BUFFER type);
const char* print(COMMAND_SEGMENT_TYPE type);
const char* print(VPRO_TYPE type);

#ifdef SIMULATION
/**
 * appends all relevant layers to the given list
 *    implemented in mobilenet_structure.cpp
 * @param layer starting layer (input)
 * @param layers list to append layers to
 */
std::list<LAYER *>  createLayers(LAYER *layer, std::list<LAYER> &layers);

/**
 * prints Layer intel to console.
 * creates input.cfg and output.cfg
 * @param layer
 */
void printLayer(const LAYER &layer);

/**
 * prints intel about one specific kernel element (values and corresponding channel)
 * @param kernel
 */
void printKernel(const KERNEL &kernel);

/**
 * prints intel about one specific segment element
 * @param layer
 * @param segment
 */
void printSegment(const LAYER &layer, const SEGMENT &segment);


/**
 * prints colored list of all segments to be processed
 * @param list
 * @param LANES HW number of lanes (for coloring)
 * @param layer
 */
void printSegmentList(const std::list<SEGMENT *> &list, int LANES, const LAYER &layer);

#endif

/**
 * prints Layer intel to console.
 * creates input.cfg and output.cfg
 * @param layer
 */
template<typename LAYER>
void printLayer(const LAYER &layer);

/**
 * prints intel about one specific kernel element (values and corresponding channel)
 * @param kernel
 */
template<typename KERNEL>
void printKernel(const KERNEL &kernel);

/**
 * prints intel about one specific segment element
 * @param layer
 * @param segment
 */
template<typename LAYER>
void printSegment(const LAYER &layer, const SEGMENT &segment);


// Helper to translate main memory 2d array to main memory 1d array
void dma_linearize2d(uint32_t cluster, uint32_t ext_src, uint32_t ext_dst, uint32_t loc_temp, uint32_t src_x_stride,
                     uint32_t src_x_size, uint32_t src_y_size);


//assumes little endian
void printBits(size_t const size, void const * const ptr);
void printProgress(double percent, int size);
#endif
