#pragma once
#include <vector>
#include <opencv2/core.hpp>

struct InferenceResult {
    std::vector<cv::Rect> bounding_boxes;
};
