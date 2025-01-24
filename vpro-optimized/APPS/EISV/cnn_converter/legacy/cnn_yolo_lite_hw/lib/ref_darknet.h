//
// Created by gesper on 23.09.19.
//

#ifndef CNN_YOLO_LITE_REF_DARKNET_H
#define CNN_YOLO_LITE_REF_DARKNET_H

#include <iostream>
#include <iomanip>
#include <string>
#include <vector>
#include <fstream>
#include <thread>

#include "yolo_v2_class.hpp"	// imported functions from DLL

//            image_t img;
//            img.h = mat_img.rows;
//            img.w = mat_img.cols;
//            img.c = mat_img.channels();
//            img.data = mat_img.ptr<float>(0);
//            auto img = detector.load_image(filename);
//            detector.free_image(img);
//            std::vector<bbox_t> result_vec = detector.detect(img);


#include <opencv2/opencv.hpp>
#include "opencv2/core/version.hpp"

static cv::Scalar colors[14] = {cv::Scalar(60, 160, 250),
                                cv::Scalar(120, 0, 250),
                                cv::Scalar(180, 120, 200),
                                cv::Scalar(240, 100, 100),
                                cv::Scalar(180, 60, 0),
                                cv::Scalar(120, 160, 100),
                                cv::Scalar(60, 160, 200),
                                cv::Scalar(0, 0, 260),
                                cv::Scalar(60, 160, 100),
                                cv::Scalar(160, 110, 120),
                                cv::Scalar(180, 90, 20),
                                cv::Scalar(120, 70, 40),
                                cv::Scalar(100, 50, 60),
                                cv::Scalar(10, 30, 80)};

double sigmoid(double x){
    return 1/(1+exp(-x));
}

double *softmax(float *x, int size){
    float max_x = 0;
    for (auto i = 0; i < size; i++){
        max_x = (x[i] > max_x) ? x[i] : max_x;
    }
    auto result= new double[size]();
    auto sum = 0.0;
    for (auto i = 0; i < size; i++){
        result[i] = exp(double(x[i] - max_x));
        sum += result[i];
    }
    for (auto i = 0; i < size; i++){
        result[i] = result[i] / sum;
    }
    return result;
}


void draw_boxes(cv::Mat mat_img, std::vector<bbox_t> result_vec, std::vector<std::string> obj_names, std::string windowname = "window name", unsigned int wait_msec = 0, float threshold = 0.7) {

    cv::Mat result;

    auto scale_x = 224*2 / mat_img.cols;
    auto scale_y = 224*2 / mat_img.rows;
    cv::resize(mat_img, result, cv::Size(), scale_x, scale_y, cv::INTER_CUBIC);

    for (auto &i : result_vec) {
        if (i.prob > threshold){
            i.x *= scale_x;
            i.y *= scale_y;
            i.w *= scale_x;
            i.h *= scale_y;

            auto color = colors[(i.obj_id % 14)];
            cv::rectangle(result, cv::Rect(i.x, i.y, i.w, i.h), color, 2);
            if(obj_names.size() > i.obj_id)
                putText(result, obj_names[i.obj_id], cv::Point2f(i.x, i.y - 10), cv::FONT_HERSHEY_COMPLEX_SMALL, 1, color);
            if(i.track_id > 0)
                putText(result, std::to_string(i.track_id), cv::Point2f(i.x+5, i.y + 15), cv::FONT_HERSHEY_COMPLEX_SMALL, 1, color);
        }
    }
    cv::imshow(windowname, result);
    cv::waitKey(wait_msec);
}

void show_result(std::vector<bbox_t> const result_vec, std::vector<std::string> const obj_names) {
    for (auto &i : result_vec) {
        if (obj_names.size() > i.obj_id) std::cout << obj_names[i.obj_id] << " - ";
        std::cout << "obj_id = " << i.obj_id << ",  x = " << i.x << ", y = " << i.y
                  << ", w = " << i.w << ", h = " << i.h
                  << std::setprecision(3) << ", prob = " << i.prob << std::endl;
    }
}

std::vector<std::string> objects_names_from_file(std::string const filename) {
    std::ifstream file(filename);
    std::vector<std::string> file_lines;
    if (!file.is_open()) return file_lines;
    for(std::string line; file >> line;) file_lines.push_back(line);
    std::cout << "object names loaded \n";
    return file_lines;
}

//struct bbox_t {
//    unsigned int x, y, w, h;    // (x,y) - top-left corner, (w, h) - width & height of bounded box
//    float prob;                    // confidence - probability that the object was found correctly
//    unsigned int obj_id;        // class of object - from range [0, classes-1]
//    unsigned int track_id;        // tracking id for video (0 - untracked, 1 - inf - tracked object)
//    unsigned int frames_counter;// counter of frames on which the object was detected
//};


#endif //CNN_YOLO_LITE_REF_DARKNET_H
