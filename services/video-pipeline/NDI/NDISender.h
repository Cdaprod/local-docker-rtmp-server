#pragma once
#include "Models/VideoFrame.h"
#include <string>

class NDISender {
public:
    NDISender(const std::string& stream_name);
    bool send(const VideoFrame& frame);
};
