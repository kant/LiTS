#include "pre_and_post_processor.cuh"
#include "lits_processor.h"


/******************************************************************************
 * LiTS_processor constructor: assigning range thresholds and
 * new range minimum and maximum values and approach; initializing
 * the order and the orientation of the axis
 *
 * Arguments:
 * 		lt: lower threshold of original voxel intensity
 * 		ut: upper threshold of original voxel intensity
 * 		min: minimum value of voxel intensity in new intensity range
 * 		max: maximum value of voxel intensity in new intensity range
 * 		app: "itk"/"cuda" approach
******************************************************************************/
LiTS_processor::LiTS_processor(float lt, float ut, float min, float max,
                               std::string app)
{
    lower_th = lt;
    upper_th = ut;
    min_value = min;
    max_value = max;
    approach = app;

    for(unsigned int i = 0; i < 3; i++)
    {
        ord[i] = i;
        orient[i] = 1;
    }
}

/******************************************************************************
 * preprocess_volume: normalize voxel intensities and
 * order and/or flip axes if necessary
 * it is assumed that:
 * 1. order of the axes provided in header is correct
 * 2. orientations of the last two axes are correct
 *    (it is assumed that orientation label of the first
 *     axes left-right is not convenient = different views used
 *     by radiologists and neurologists)
 *
 * Arguments:
 * 		scan: pointer to the LiTS_scan object
******************************************************************************/
void LiTS_processor::preprocess_volume(LiTS_scan *scan)
{
    unsigned int *cord = scan->get_axes_order();
    short *cornt = scan->get_axes_orient();

    if (!strcmp(approach.c_str(), "itk"))
    {
        // 1. Voxel values range re-scaling
        RescalerType::Pointer rescaler = RescalerType::New();
        rescaler->SetInput(scan->get_volume());
        rescaler->SetWindowMinimum(lower_th);
        rescaler->SetWindowMaximum(upper_th);
        rescaler->SetOutputMinimum(min_value);
        rescaler->SetOutputMaximum(max_value);
        rescaler->UpdateLargestPossibleRegion();

        scan->set_volume(rescaler->GetOutput());

        // 2. Permute and re-orient axes if necessary
        bool reorient = false;
        bool permute = false;
        reorient_permute(reorient, permute, cord, cornt, ord, orient);

        if (reorient or permute)
        {
            VolumeType::DirectionType direction =
                    scan->get_volume()->GetDirection();
            VolumeType::DirectionType dornt;
            dornt[0][0] = orient[0];
            dornt[1][1] = orient[1];
            dornt[2][2] = orient[2];

            OrientVolumeType::Pointer orienter_v = OrientVolumeType::New();

            orienter_v->SetGivenCoordinateDirection(direction);
            orienter_v->SetInput(scan->get_volume());
            orienter_v->SetDesiredCoordinateDirection(dornt);
            orienter_v->UpdateLargestPossibleRegion();
            scan->set_volume(orienter_v->GetOutput());
        }
    }
    else
        preprocess_volume_cuda((scan->get_volume())->GetBufferPointer(),
                               scan->get_width(),
                               scan->get_height(),
                               scan->get_depth(),
                               cord, cornt,
                               lower_th, upper_th, min_value, max_value);
}

/******************************************************************************
 * normalize_volume: normalize voxel intensities
 *
 * Arguments:
 *      scan: pointer to the LiTS_scan object
******************************************************************************/
void LiTS_processor::normalize_volume(LiTS_scan *scan)
{
    if (!strcmp(approach.c_str(), "itk"))
    {
        // 1. Voxel values range re-scaling
        RescalerType::Pointer rescaler = RescalerType::New();
        rescaler->SetInput(scan->get_volume());
        rescaler->SetWindowMinimum(lower_th);
        rescaler->SetWindowMaximum(upper_th);
        rescaler->SetOutputMinimum(min_value);
        rescaler->SetOutputMaximum(max_value);
        rescaler->UpdateLargestPossibleRegion();

        scan->set_volume(rescaler->GetOutput());
    }
    else
        normalize_volume_cuda((scan->get_volume())->GetBufferPointer(),
                              scan->get_width(),
                              scan->get_height(),
                              scan->get_depth(),
                              lower_th, upper_th, min_value, max_value);
}

/******************************************************************************
 * filter_with_median: filters each slice with a square median filter of size k
 *
 * Arguments:
 *      scan: pointer to the LiTS_scan object
 *      k: median filter size
******************************************************************************/
void LiTS_processor::filter_with_median(LiTS_scan *scan, int k)
{
    filter_with_median_cuda((scan->get_volume())->GetBufferPointer(),
                            scan->get_width(),
                            scan->get_height(),
                            scan->get_depth(),
                            k);
}

/******************************************************************************
 * reorient_volume: re-order and/or flip axes if necessary
 *
 * Arguments:
 *      scan: pointer to the LiTS_scan object
 *      cord: current order of the axes
 *      corient: current orientation of the axes
 *      dord: desired order of the axes
 *      dorient: desired orientation of the axes
******************************************************************************/
void LiTS_processor::reorient_volume(LiTS_scan *scan,
                                     unsigned *cord, short *cornt,
                                     unsigned *dord, short *dornt)
{
    if (!strcmp(approach.c_str(), "itk"))
    {

        // 1. Permute and re-orient axes if necessary
        bool reorient = false;
        bool permute = false;
        reorient_permute(reorient, permute, cord, cornt, dord, dornt);

        if (reorient or permute)
        {
            VolumeType::DirectionType dir = scan->get_volume()->GetDirection();
            VolumeType::DirectionType desired_orient;
            desired_orient[0][0] = dornt[0];
            desired_orient[1][1] = dornt[1];
            desired_orient[2][2] = dornt[2];

            OrientVolumeType::Pointer orienter_v = OrientVolumeType::New();
            orienter_v->SetGivenCoordinateDirection(dir);
            orienter_v->SetInput(scan->get_volume());
            orienter_v->SetDesiredCoordinateDirection(desired_orient);
            orienter_v->UpdateLargestPossibleRegion();
            scan->set_volume(orienter_v->GetOutput());
        }
    }
    else
        reorient_volume_cuda((scan->get_volume())->GetBufferPointer(),
                             scan->get_width(),
                             scan->get_height(),
                             scan->get_depth(),
                             cord, cornt, dord, dornt);
}

/******************************************************************************
 * reorient_volume: re-order and/or flip axes if necessary
 *
 * Arguments:
 *      volume: pointer to the volume
 *      w: volume width
 *      h: volume height
 *      d: volume depth/number of slices
 *      cord: current order of the axes
 *      cornt: current orientation of the axes
 *      dord: desired order of the axes
 *      dornt: desired orientation of the axes
******************************************************************************/
void LiTS_processor::reorient_volume(float * volume,
                                     unsigned w, unsigned h, unsigned d,
                                     unsigned *cord, short *cornt,
                                     unsigned *dord, short *dornt)
{
    reorient_volume_cuda(volume, w, h, d, cord, cornt, dord, dornt);
}

/******************************************************************************
 * reorient_segmentation: re-order and/or flip axes if necessary
 *
 * Arguments:
 *      scan: pointer to the LiTS_scan object
 *      cord: current order of the axes
 *      corient: current orientation of the axes
 *      dord: desired order of the axes
 *      dorient: desired orientation of the axes
******************************************************************************/
void LiTS_processor::reorient_segment(LiTS_scan *scan,
                                      unsigned *cord, short *cornt,
                                      unsigned *dord, short *dornt)
{
    if (!strcmp(approach.c_str(), "itk"))
    {
        // 1. Permute and re-orient axes if necessary
        bool reorient = false;
        bool permute = false;
        reorient_permute(reorient, permute, cord, cornt, dord, dornt);

        if (reorient or permute)
        {
            SegmentType::DirectionType dir =
                    scan->get_segment()->GetDirection();
            SegmentType::DirectionType desired_orient;
            desired_orient[0][0] = dornt[0];
            desired_orient[1][1] = dornt[1];
            desired_orient[2][2] = dornt[2];

            OrientSegmentType::Pointer orienter_s = OrientSegmentType::New();
            orienter_s->SetGivenCoordinateDirection(dir);
            orienter_s->SetInput(scan->get_segment());
            orienter_s->SetDesiredCoordinateDirection(desired_orient);
            orienter_s->UpdateLargestPossibleRegion();
            scan->set_segment(orienter_s->GetOutput());
        }
    }
    else
        reorient_segment_cuda((scan->get_segment())-> GetBufferPointer(),
                              scan->get_width(),
                              scan->get_height(),
                              scan->get_depth(),
                              cord, cornt, dord, dornt);
}

/******************************************************************************
 * reorient_segmentation: re-order and/or flip axes if necessary
 *
 * Arguments:
 *      segment: pointer to the segmentation
 *      w: segmentation width
 *      h: segmentation height
 *      d: segmentation depth/number of slices
 *      cord: current order of the axes
 *      cornt: current orientation of the axes
 *      dord: desired order of the axes
 *      dornt: desired orientation of the axes
******************************************************************************/
void LiTS_processor::reorient_segment(unsigned char * segment,
                                      unsigned w, unsigned h, unsigned d,
                                      unsigned *cord, short *cornt,
                                      unsigned *dord, short *dornt)
{
    reorient_segment_cuda(segment, w, h, d, cord, cornt, dord, dornt);
}

/******************************************************************************
 * get_axes_orientation: returns the orientation of the axes
******************************************************************************/
short * LiTS_processor::get_axes_orient()
{
    return orient;
}

/******************************************************************************
 * get_axes_order: returns the order of the axes
******************************************************************************/
unsigned * LiTS_processor::get_axes_order()
{
    return ord;
}

/******************************************************************************
 * set_low_threshold: set value of lower voxel value threshold
 *
 * Arguments:
 * 		lt: lower threshold value
******************************************************************************/
void LiTS_processor::set_low_threshold(float lt)
{
	lower_th = lt;
}

/******************************************************************************
 * set_high_threshold: set value of higher voxel value threshold
 *
 * Arguments:
 * 		ht: higher threshold value
******************************************************************************/
void LiTS_processor::set_high_threshold(float ht)
{
	upper_th = ht;
}
