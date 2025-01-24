//
// Created by gesper on 10.09.19.
//

#ifndef CNN_YOLO_LITE_DEFINES_H
#define CNN_YOLO_LITE_DEFINES_H


/**
 * Whether to run c code for conv and creation of .png with reference results. also compares to the output of vpro calc woth those results
 */
//#define DO_VERIFICATION
#define DO_VERIFICATION_VISUALIZED	// whether to open cv windows...  / only affects if DO_VERIFICATION is defined

/**
 * Whether to run compare with tf included library (includes softmax...)
 */
//#define DO_TF_VERIFICATION


/**
 * Whether to run layer execution or load last results
 */
#define CALC_VPRO


/**
  * Whether the referece should be calculated (again). else the files out_#.bin are loaded and used as reference
  */
//#define CALC_REFERENCE


/**
 * Whether the binary and image files for reference are written out
 */
#define WRITEOUT_REF
/**
  * Whether the results should be saved in .png/.bin files
  */
//#define WRITEOUT_VPRO_RESULTS



/**
  * Whether the file output.cfg is created. contains layer x output
  */
//#define CREATE_INPUT_CFG
/**
  * Whether the file input.cfg is created. contains layer 0. input addresses
  */
//#define CREATE_OUTPUT_CFG




/**
 * USE 60x60x1 input
 * requires inputfile with test_img_in... (will be generated if CREATE_INPT_CFG is set)
 */
//#define TEST



#endif //CNN_YOLO_LITE_DEFINES_H
