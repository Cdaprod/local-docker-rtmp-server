#pragma once
#include "Models/VideoFrame.h"
#include <string>

class NDIReceiver {
public:
    NDIReceiver(const std::string& source_name);
    bool receive(VideoFrame& frame);
};
