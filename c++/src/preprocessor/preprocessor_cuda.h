/*
 * preprocessor_cuda.h
 *
 *  Created on: Feb 14, 2017
 *      Author: sara
 */

#ifndef PREPROCESSOR_CUDA_H_
#define PREPROCESSOR_CUDA_H_
#include <iostream>

void preprocess_cuda(float *volume_cpu, unsigned char *segmentation_cpu,
		             unsigned int h, unsigned int w, unsigned int d,
		             bool change_direction,
                     float lower_threshold, float upper_threshold,
                     float minimum_value, float maximum_value);


#endif /* PREPROCESSOR_CUDA_H_ */