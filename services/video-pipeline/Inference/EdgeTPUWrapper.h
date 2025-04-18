#pragma once
#include "Models/VideoFrame.h"
#include "Models/InferenceResult.h"
#include <string>

class EdgeTPUWrapper {
public:
    EdgeTPUWrapper(const std::string& model_path);
    InferenceResult run(const cv::Mat& image);
private:
    // tflite::Interpreter etc. as needed
};
