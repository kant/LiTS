#include "pre_and_post_processor.cuh"
#define MAX_THREADS 1024

#include <iostream>

/******************************************************************************
 * gpu_reorient: re-orientation and/or re-ordering of the axes
 *
 * Arguments:
 *      data: input data
 *      data_o: output data
 *      cord0: current ordinal number of the first axis
 *      cord1: current ordinal number of the second axis
 *      cord2: current ordinal number of the third axis
 *      dord0: desired ordinal number of the first axis
 *      dord1: desired ordinal number of the seconds axis
 *      dord2: desired ordinal number of the third axis
 *      corient0: current orientation of the first axis
 *      corient1: current orientation of the seconds axis
 *      corient2: current orientation of the third axis
 *      dorient0: desired orientation of the first axis
 *      dorient1: desired orientation of the seconds axis
 *      dorient2: desired orientation of the third axis
 *****************************************************************************/
template<typename T>
__global__ void gpu_reorient(T *data, T *data_o,
                             unsigned w, unsigned h, unsigned d,
                             unsigned cord0, unsigned cord1, unsigned cord2,
                             unsigned dord0, unsigned dord1, unsigned dord2,
                             short corient0, short corient1, short corient2,
                             short dorient0, short dorient1, short dorient2)
{
    unsigned int t = (cord0 == 0) * w + (cord1 == 0) * h + (cord2 == 0) * d;

    if(threadIdx.x < t)
    {
        unsigned int in_idx = blockIdx.y * gridDim.x * t +
                              blockIdx.x * t + threadIdx.x;
        unsigned int out_idx = 0;

        unsigned int crs[3] = {threadIdx.x, blockIdx.x, blockIdx.y};
        unsigned int dord[3] = {dord0, dord1, dord2};
        unsigned int s[3] = {w, h, d};
        unsigned int cord[3] = {cord0, cord1, cord2};

        if(corient0 == dorient0)
            out_idx += crs[cord[dord[0]]];
        else
            out_idx += (s[dord[0]] - 1 - crs[cord[dord[0]]]);

        if(corient1 == dorient1)
            out_idx += crs[cord[dord[1]]] * s[dord[0]];
        else
            out_idx += (s[dord[1]] - 1 - crs[cord[dord[1]]]) * s[dord[0]];

        if(corient2 == dorient2)
            out_idx += crs[dord[cord[2]]] * s[dord[0]] * s[dord[1]];
        else
            out_idx += (s[dord[2]] - 1 - crs[dord[cord[2]]]) *
                s[dord[0]] * s[dord[1]];

        data_o[out_idx] = data[in_idx];
    }
}

/******************************************************************************
 * gpu_normalize: clip and normalize input data
 *
 * Arguments:
 *      volume: input volume
 *      w: volume width
 *      h: volume height
 *      d: volume depth
 *      lower_th_: lower clip value
 *      upper_th_: upper clip value
 *      minimum_value_: minimum output value
 *      maximum_value_: maximum output value
 *****************************************************************************/
__global__ void gpu_normalize(float *volume,
                              unsigned w, unsigned h, unsigned d,
                              float lower_th_, float upper_th_,
                              float minimum_value_, float maximum_value_)
{

    unsigned int idx = blockIdx.y * gridDim.x * blockDim.x +
                       blockIdx.x * blockDim.x + threadIdx.x;

    if(idx < w * h * d)
    {
        if (volume[idx] < lower_th_)
            volume[idx] = minimum_value_;
        else if (volume[idx] > upper_th_)
            volume[idx] = maximum_value_;
        else
            volume[idx] = (volume[idx] - lower_th_) *
                          (maximum_value_ - minimum_value_) /
                          (upper_th_ - lower_th_) + minimum_value_;
    }
}

/******************************************************************************
 * gpu_median_filter_3: median filtering of slices with kernel size 3
 *
 * Arguments:
 *      volume: input volume
 *      volume_f: output filtered volume
 *      w: volume width
 *      h: volume height
 *      d: volume depth
 *****************************************************************************/
__global__ void gpu_median_filter_3(float *volume, float *volume_f,
                                    unsigned w, unsigned h, unsigned d)
{
    unsigned int idx = blockIdx.y * gridDim.x * blockDim.x +
                       blockIdx.x * blockDim.x + threadIdx.x;
    int k = 3;
    if(idx < w * h * d)
    {
        int d_idx = idx / (w * h);
        int r_idx = (idx - d_idx * w * h) / w;
        int c_idx = (idx - d_idx * w * h - r_idx * w);

        if((c_idx - k / 2) >= 0 and (c_idx + k / 2) < w and
           (r_idx - k / 2) >= 0 and (r_idx + k / 2) < h)
        {
            volume_f[idx] = volume[idx];
            float array_to_sort[9];
            for(short i = (- k / 2); i <= (k / 2); i++)
            {
                for(short j = (- k / 2); j <= (k / 2); j++)
                {
                    int idx_tmp = d_idx * w * h;
                    idx_tmp += (r_idx + i) * w;
                    idx_tmp += (c_idx + j);
                    array_to_sort[(i + k / 2) * k + j + k / 2] =\
                    		volume[idx_tmp];
                }
            }

            float min;
            unsigned min_idx;
            for(unsigned i = 0; i < (k * k - 1); i++)
            {
                min = array_to_sort[i];
                min_idx = i;
                for(unsigned j = (i+1); j < k * k; j++)
                {
                    if(array_to_sort[j] < min)
                    {
                        min = array_to_sort[j];
                        min_idx = j;
                    }
                }
                array_to_sort[min_idx] = array_to_sort[i];
                array_to_sort[i] = min;
            }
            volume_f[idx] = array_to_sort[4];
        }
        else
            volume_f[idx] = volume[idx];
    }
}

/******************************************************************************
 * gpu_median_filter_5: median filtering of slices with kernel size 5
 *
 * Arguments:
 *      volume: input volume
 *      volume_f: output filtered volume
 *      w: volume width
 *      h: volume height
 *      d: volume depth
 *****************************************************************************/
__global__ void gpu_median_filter_5(float *volume, float *volume_f,
                                    unsigned w, unsigned h, unsigned d)
{
    unsigned int idx = blockIdx.y * gridDim.x * blockDim.x +
                       blockIdx.x * blockDim.x + threadIdx.x;
    int k = 5;
    if(idx < w * h * d)
    {
        int d_idx = idx / (w * h);
        int r_idx = (idx - d_idx * w * h) / w;
        int c_idx = (idx - d_idx * w * h - r_idx * w);

        if((c_idx - k / 2) >= 0 and (c_idx + k / 2) < w and
           (r_idx - k / 2) >= 0 and (r_idx + k / 2) < h)
        {
            volume_f[idx] = volume[idx];
            float array_to_sort[25];
            for(short i = (- k / 2); i <= (k / 2); i++)
            {
                for(short j = (- k / 2); j <= (k / 2); j++)
                {
                    int idx_tmp = d_idx * w * h;
                    idx_tmp += (r_idx + i) * w;
                    idx_tmp += (c_idx + j);
                    array_to_sort[(i + k / 2) * k + j + k / 2] =\
                    		volume[idx_tmp];
                }
            }

            float min;
            unsigned min_idx;
            for(unsigned i = 0; i < (k * k - 1); i++)
            {
                min = array_to_sort[i];
                min_idx = i;
                for(unsigned j = (i+1); j < k * k; j++)
                {
                    if(array_to_sort[j] < min)
                    {
                        min = array_to_sort[j];
                        min_idx = j;
                    }
                }
                array_to_sort[min_idx] = array_to_sort[i];
                array_to_sort[i] = min;
            }
            volume_f[idx] = array_to_sort[12];
        }
        else
            volume_f[idx] = volume[idx];
    }
}

/******************************************************************************
 * reorient_permute: determine if there is a need to re-orient and/or permute
 * axes
 *
 * Arguments:
 * 		re-orient: flag whether to re-orient axis
 * 		permute: flag whether to permute axis
 * 		cord: current axis order
 * 		cornt: current axis orientations
 * 		dord: desired axis order
 * 		dornt: desired axis orientation
 *****************************************************************************/
void reorient_permute(bool &reorient, bool &permute,
                      unsigned *cord, short *cornt,
                      unsigned *dord, short *dornt)
{
    for(unsigned int i = 0; i < 3; i++)
    {
        if(cornt[i] != dornt[i])
            reorient = true;
        if(cord[i] != dord[i])
            permute = true;
    }
}

/******************************************************************************
 * preprocess_volume_cuda: normalize voxel intensities and re-orient volume
 * axes if necessary
 *
 * Arguments:
 * 		volume_cpu: volume to be processed
 * 		w: volume width
 * 		h: volume height
 * 		d: volume depth / number of slices
 * 		cord: current order of axis
 * 		cornt: current orientation of axis
 *      lower_threshold: lower limit for voxel intensity
 *      upper_threshold: upper limit for voxel intensity
 *      minimum_value: minimum voxel intensity value in the
 *          normalized voxel range
 *      maximum_value: maximum voxel intensity value in the
 *          normalized voxel range
 *****************************************************************************/
void preprocess_volume_cuda(float *in_volume,
                            unsigned int w, unsigned int h, unsigned int d,
                            unsigned int *cord, short *cornt,
                            float lower_threshold, float upper_threshold,
                            float minimum_value, float maximum_value)
{
    short dornt[3] = {1, 1, 1};
    unsigned dord[3] = {0, 1, 2};

    bool reorient = false;
    bool permute = false;
    reorient_permute(reorient, permute, cord, cornt, dord, dornt);

    float *volume_d;
    unsigned int volume_B = h * w * d * sizeof(float);

    cudaMalloc((void **) &volume_d, volume_B);
    cudaMemcpy(volume_d, in_volume, volume_B, cudaMemcpyHostToDevice);

    unsigned int i1, i2;
    i1 = (cord[1] == 0) * w + (cord[1] == 1) * h + (cord[1] == 2) * d;
    i2 = (cord[2] == 0) * w + (cord[2] == 1) * h + (cord[2] == 2) * d;

    dim3 grid(i1, i2);

    gpu_normalize<<<grid, MAX_THREADS>>>(volume_d,
                                         w, h, d,
                                         lower_threshold, upper_threshold,
                                         minimum_value, maximum_value);
    if(reorient or permute)
    {
        float *volume_o_d;
        cudaMalloc((void **) &volume_o_d, volume_B);
        gpu_reorient<float><<<grid, MAX_THREADS>>>
                (volume_d, volume_o_d, w, h, d,
                 cord[0], cord[1], cord[2], dord[0], dord[1], dord[2],
                 cornt[0], cornt[1], cornt[2], dornt[0], dornt[1], dornt[2]);
        cudaMemcpy(in_volume, volume_o_d, volume_B, cudaMemcpyDeviceToHost);
        cudaFree(volume_o_d);
    }
    else
        cudaMemcpy(in_volume, volume_d, volume_B, cudaMemcpyDeviceToHost);
    cudaFree(volume_d);
}

/******************************************************************************
 * normalize_volume_cuda: normalize voxel intensities
 *
 * Arguments:
 *      in_volume: volume to be processed
 *      w: volume width
 *      h: volume height
 *      d: volume depth / number of slices
 *      lower_threshold: lower limit for voxel intensity
 *      upper_threshold: upper limit for voxel intensity
 *      minimum_value: minimum voxel intensity value in the
 *          normalized voxel range
 *      maximum_value: maximum voxel intensity value in the
 *          normalized voxel range
 *****************************************************************************/
void normalize_volume_cuda(float *in_volume,
                           unsigned int w, unsigned int h, unsigned int d,
                           float lower_threshold, float upper_threshold,
                           float minimum_value, float maximum_value)
{

    float *volume_d;
    unsigned int volume_B = h * w * d * sizeof(float);

    cudaMalloc((void **) &volume_d, volume_B);
    cudaMemcpy(volume_d, in_volume, volume_B, cudaMemcpyHostToDevice);

    dim3 grid(h, d);

    gpu_normalize<<<grid, MAX_THREADS>>>(volume_d, w, h, d,
                                         lower_threshold, upper_threshold,
                                         minimum_value, maximum_value);
    cudaMemcpy(in_volume, volume_d, volume_B, cudaMemcpyDeviceToHost);
    cudaFree(volume_d);
}

/******************************************************************************
 * filter_with_median_cuda: de-noise volume with median filter
 *
 * Arguments:
 *      volume: volume to be processed
 *      w: volume width
 *      h: volume height
 *      d: volume depth / number of slices
 *      k: median kernel's size
 *****************************************************************************/
void filter_with_median_cuda(float *volume,
                             unsigned int w, unsigned int h, unsigned int d,
                             int k)
{

    float *volume_d;
    float *volume_f_d;
    unsigned int volume_B = h * w * d * sizeof(float);

    cudaMalloc((void **) &volume_d, volume_B);
    cudaMalloc((void **) &volume_f_d, volume_B);
    cudaMemcpy(volume_d, volume, volume_B, cudaMemcpyHostToDevice);

    dim3 grid(h, d);
    if(k == 3)
        gpu_median_filter_3<<<grid, MAX_THREADS>>>(volume_d, volume_f_d,
                                                   w, h, d);
    else if(k == 5)
        gpu_median_filter_5<<<grid, MAX_THREADS>>>(volume_d, volume_f_d,
                                                   w, h, d);
    else
    {
        std::cout<<"Selected median filter size is not supported"<<std::endl;
        exit(EXIT_FAILURE);
    }
    cudaMemcpy(volume, volume_f_d, volume_B, cudaMemcpyDeviceToHost);
    cudaFree(volume_d);
    cudaFree(volume_f_d);
}

/******************************************************************************
 * reorient_volume_cuda: re-orient axes of volume if necessary
 *
 * Arguments:
 *      volume: volume to be reoriented
 *      w: volume width
 *      h: volume height
 *      d: volume depth / number of slices
 *      cord - current order of the axes
 *      cornt - current orientation of the axes
 *      dord - desired order of the axes
 *      dornt - desired orientation of the axes
 *****************************************************************************/
void reorient_volume_cuda(float *volume,
                          unsigned int w, unsigned int h, unsigned int d,
                          unsigned *cord, short *cornt,
                          unsigned *dord, short *dornt)
{
    bool reorient = false;
    bool permute = false;
    reorient_permute(reorient, permute, cord, cornt, dord, dornt);

    if(reorient or permute)
    {
        float *volume_d;
        float *volume_o_d;
        unsigned int volume_B = h * w * d * sizeof(float);

        cudaMalloc((void **) &volume_d, volume_B);
        cudaMemcpy(volume_d, volume, volume_B, cudaMemcpyHostToDevice);
        cudaMalloc((void **) &volume_o_d, volume_B);

        unsigned int i1, i2;
        i1 = (cord[1] == 0) * w + (cord[1] == 1) * h + (cord[1] == 2) * d;
        i2 = (cord[2] == 0) * w + (cord[2] == 1) * h + (cord[2] == 2) * d;

        dim3 grid(i1, i2);

        gpu_reorient<float><<<grid, MAX_THREADS>>>
                (volume_d, volume_o_d, w, h, d,
                 cord[0], cord[1], cord[2], dord[0], dord[1], dord[2],
                 cornt[0], cornt[1], cornt[2], dornt[0], dornt[1], dornt[2]);

        cudaMemcpy(volume, volume_o_d, volume_B, cudaMemcpyDeviceToHost);
        cudaFree(volume_d);
        cudaFree(volume_o_d);
    }
}

/******************************************************************************
 * reorient_segmentation_cuda: re-orient axes of segmentation if necessary
 *
 * Arguments:
 *      segment: segmentation to be reoriented
 *      w: volume width
 *      h: volume height
 *      d: volume depth / number of slices
 *      cord - current order of the axes
 *      cornt - current orientation of the axes
 *      dord - desired order of the axes
 *      dornt - desired orientation of the axes
 *****************************************************************************/
void reorient_segment_cuda(unsigned char *segment,
                           unsigned int w, unsigned int h, unsigned int d,
                           unsigned *cord, short *cornt,
                           unsigned *dord, short *dornt)
{
    bool reorient = false;
    bool permute = false;
    reorient_permute(reorient, permute, cord, cornt, dord, dornt);

    if(reorient or permute)
    {
        unsigned char *segment_d;
        unsigned char *segment_o_d;
        unsigned int segment_B = h * w * d * sizeof(unsigned char);

        cudaMalloc((void **) &segment_d, segment_B);
        cudaMemcpy(segment_d, segment, segment_B, cudaMemcpyHostToDevice);
        cudaMalloc((void **) &segment_o_d, segment_B);

        unsigned int i1, i2;
        i1 = (cord[1] == 0) * w + (cord[1] == 1) * h + (cord[1] == 2) * d;
        i2 = (cord[2] == 0) * w + (cord[2] == 1) * h + (cord[2] == 2) * d;

        dim3 grid(i1, i2);
        gpu_reorient<unsigned char><<<grid, MAX_THREADS>>>
                (segment_d, segment_o_d, w, h, d,
                 cord[0], cord[1], cord[2], dord[0], dord[1], dord[2],
                 cornt[0], cornt[1], cornt[2], dornt[0], dornt[1], dornt[2]);

        cudaMemcpy(segment, segment_o_d, segment_B, cudaMemcpyDeviceToHost);
        cudaFree(segment_d);
        cudaFree(segment_o_d);
    }
}
