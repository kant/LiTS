/*
 * lits_database.h
 *
 *  Created on: Feb 11, 2017
 *      Author: sara
 */

#ifndef LITS_DATABASE_H_
#define LITS_DATABASE_H_

#include <string>
#include <vector>
#include <iostream>
#include <boost/filesystem.hpp>
#include <algorithm>
#include <cstdlib>

namespace fs = boost::filesystem;

/*
 * Class LiTS_db is a class for database management.
 *
 * It has means of creating lists of all available subjects
 * in the database from training and testing batches;
 * splitting the training data into development, validation
 * and evaluation parts; getting the number and subjects of the
 * training, development, validation, evaluation and testing
 * subsets;
 * getting the volume and segmentation paths of the training
 * and testing scans
 *
 * Attributes:
 *
 * 		in_db_path: path to the directory which contains folders
 * 		    "Training Batch 1", "Training Batch 2" and
 * 		    "Testing Batch"
 * 	    out_db_path: path to the directory where the output of the
 * 	    	experiment would be placed
 *
 * 		train_subjects: vector for storing subjects' names
 * 			from the training batches
 * 		develop_subjects: vector for storing subjects' names
 * 			for algorithm development/training
 * 		valid_subjects: vector for storing subjects' names
 * 			for algorithm validation
 * 		eval_subjects: vector for storing subjects' names
 * 			for algorithm evaluation
 * 		test_subjects: vector for storing subjects' names
 * 			from the testing batch
 *
 * 		n_train: the total number of training subjects
 * 		n_dev: the total number of development subjects
 * 		n_valid: the total number of validation subjects
 * 		n_eval: the total number of evaluation subjects
 * 		n_test: the total number of testing subjects
 *
 * Methods:
 *
 * 		LiTS_db: constructor
 *
 * 		load_train_subjects_names: loading train subjects' names
 * 		load_test_subjects_names: loading test subjects' names
 *
 * 		train_data_split: splitting data into development, validation
 * 			and evaluation parts
 *
 * 		empty_split: reseting data split
 *
 * 		get_number_of_training: get the total number of training subjects
 * 		get_number_of_development: get the total number of development subjects
 * 		get_number_of_validation: get the total number of validation subjects
 * 		get_number_of_evaluation: get the total number of evaluation subjects
 * 		get_number_of_testing: get the total number of testing subjects
 *
 * 		get_train_subject_name: get subject's name from the training set
 * 			at required position
 * 		get_develop_subject_name: get subject's name from the development set
 * 			at required position
 * 		get_valid_subject_name: get subject's name from the validation set
 * 			at required position
 * 		get_eval_subject_name: get subject's name from the evaluation set
 * 			at required position
 * 		get_test_subject_name: get subject's name from the testing set
 * 			at required position
 *
 * 		get_train_paths: get training subject's volume and segmentation paths
 * 		get_train_volume_path: get training subject's volume path
 * 		get_train_segment_path: get training subject's segmentation path
 * 		get_train_meta_segment_path: get training subject's
 * 		    meta segmentation path
 *      get_test_volume_path: get testing subject's volume path
 *      get_test_segment_path: get testing subject's segmentation path
 *      get_train_liver_side_gt_path: get train liver side ground truth
 */

class LiTS_db
{

private:

    std::string in_db_path;
    std::string out_db_path;
    std::vector<std::string> train_subjects;
    std::vector<std::string> develop_subjects;
    std::vector<std::string> valid_subjects;
    std::vector<std::string> eval_subjects;
    std::vector<std::string> test_subjects;

    int n_train;
    int n_dev;
    int n_valid;
    int n_eval;
    int n_test;

public:

    LiTS_db(std::string in_db_path_, std::string out_db_path_);

    void load_train_subjects_names();
    void load_test_subjects_names();
    void train_data_split(int split_ratio, int selection);
    void empty_split();

    int get_number_of_training();
    int get_number_of_development();
    int get_number_of_validation();
    int get_number_of_evaluation();
    int get_number_of_testing();

    std::string get_train_subject_name(int position);
    std::string get_develop_subject_name(int position);
    std::string get_valid_subject_name(int position);
    std::string get_eval_subject_name(int position);
    std::string get_test_subject_name(int position);

    void get_train_paths(const std::string subject_name,
                         std::string &volume_path,
                         std::string &segment_path);

    void get_train_volume_path(const std::string subject_name,
                               std::string &volume_path);

    void get_train_segment_path(const std::string subject_name,
                                std::string &segment_path);

    void get_train_meta_segment_path(const std::string subject_name,
                                     std::string &meta_segment_path);

    void get_train_liver_side_gt_path(const std::string subject_name,
                                      std::string &liver_side_gt_path);

    void get_test_volume_path(const std::string subject_name,
                              std::string &volume_path);

    void get_test_segment_path(const std::string subject_name,
                               std::string &segment_path);
};

#endif /* LITS_DATABASE_H_ */

