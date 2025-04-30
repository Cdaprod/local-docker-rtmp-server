#pragma once
#include "Models/VideoFrame.h"
#include "Models/InferenceResult.h"

class OverlayProcessor {
public:
    void apply(VideoFrame& frame, const InferenceResult& result);
};
