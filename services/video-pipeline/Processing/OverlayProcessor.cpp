#include "OverlayProcessor.h"
#include <opencv2/opencv.hpp>

void OverlayProcessor::apply(VideoFrame& frame, const InferenceResult& result) {
    // Draw bounding box (example)
    for (const auto& box : result.bounding_boxes) {
        cv::rectangle(frame.image, box, cv::Scalar(0,255,0), 2);
    }
}
