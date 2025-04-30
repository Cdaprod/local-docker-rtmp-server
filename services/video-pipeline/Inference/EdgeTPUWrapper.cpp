#include "EdgeTPUWrapper.h"

EdgeTPUWrapper::EdgeTPUWrapper(const std::string& model_path) {
    // Load Edge TPU model here
}

InferenceResult EdgeTPUWrapper::run(const cv::Mat& image) {
    // Dummy inference
    return InferenceResult{};
}
