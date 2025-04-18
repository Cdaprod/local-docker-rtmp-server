# Create project structure
mkdir -p video-pipeline/{Processing,Inference,NDI,Models}

# Auto-generate header and stub source files
sudo tee video-pipeline/Processing/OverlayProcessor.h > /dev/null <<EOF
#pragma once
#include "Models/VideoFrame.h"
#include "Models/InferenceResult.h"

class OverlayProcessor {
public:
    void apply(VideoFrame& frame, const InferenceResult& result);
};
EOF

sudo tee video-pipeline/Processing/OverlayProcessor.cpp > /dev/null <<EOF
#include "OverlayProcessor.h"
#include <opencv2/opencv.hpp>

void OverlayProcessor::apply(VideoFrame& frame, const InferenceResult& result) {
    // Draw bounding box (example)
    for (const auto& box : result.bounding_boxes) {
        cv::rectangle(frame.image, box, cv::Scalar(0,255,0), 2);
    }
}
EOF

sudo tee video-pipeline/Inference/EdgeTPUWrapper.h > /dev/null <<EOF
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
EOF

sudo tee video-pipeline/Inference/EdgeTPUWrapper.cpp > /dev/null <<EOF
#include "EdgeTPUWrapper.h"

EdgeTPUWrapper::EdgeTPUWrapper(const std::string& model_path) {
    // Load Edge TPU model here
}

InferenceResult EdgeTPUWrapper::run(const cv::Mat& image) {
    // Dummy inference
    return InferenceResult{};
}
EOF

sudo tee video-pipeline/NDI/NDIReceiver.h > /dev/null <<EOF
#pragma once
#include "Models/VideoFrame.h"
#include <string>

class NDIReceiver {
public:
    NDIReceiver(const std::string& source_name);
    bool receive(VideoFrame& frame);
};
EOF

sudo tee video-pipeline/NDI/NDIReceiver.cpp > /dev/null <<EOF
#include "NDIReceiver.h"

NDIReceiver::NDIReceiver(const std::string& source_name) {
    // Connect to NDI source
}

bool NDIReceiver::receive(VideoFrame& frame) {
    // Stub: load frame from NDI
    return true;
}
EOF

sudo tee video-pipeline/NDI/NDISender.h > /dev/null <<EOF
#pragma once
#include "Models/VideoFrame.h"
#include <string>

class NDISender {
public:
    NDISender(const std::string& stream_name);
    bool send(const VideoFrame& frame);
};
EOF

sudo tee video-pipeline/NDI/NDISender.cpp > /dev/null <<EOF
#include "NDISender.h"

NDISender::NDISender(const std::string& stream_name) {
    // Setup NDI output
}

bool NDISender::send(const VideoFrame& frame) {
    // Send frame
    return true;
}
EOF

sudo tee video-pipeline/Models/VideoFrame.h > /dev/null <<EOF
#pragma once
#include <opencv2/core.hpp>

struct VideoFrame {
    cv::Mat image;
};
EOF

sudo tee video-pipeline/Models/InferenceResult.h > /dev/null <<EOF
#pragma once
#include <vector>
#include <opencv2/core.hpp>

struct InferenceResult {
    std::vector<cv::Rect> bounding_boxes;
};
EOF

cd video-pipeline

# Create CMakeLists.txt
sudo tee CMakeLists.txt > /dev/null <<EOF
cmake_minimum_required(VERSION 3.10)
project(video_pipeline)

set(CMAKE_CXX_STANDARD 17)

# Required for OpenCV
find_package(OpenCV REQUIRED)
include_directories(\${OpenCV_INCLUDE_DIRS})

# Include local headers
include_directories(
    \${CMAKE_SOURCE_DIR}/Processing
    \${CMAKE_SOURCE_DIR}/Inference
    \${CMAKE_SOURCE_DIR}/NDI
    \${CMAKE_SOURCE_DIR}/Models
)

add_executable(video_pipeline
    main.cpp
    Processing/OverlayProcessor.cpp
    Inference/EdgeTPUWrapper.cpp
    NDI/NDIReceiver.cpp
    NDI/NDISender.cpp
)

target_link_libraries(video_pipeline \${OpenCV_LIBS})
EOF

# Dockerfile for containerized build
sudo tee Dockerfile > /dev/null <<EOF
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \\
    cmake g++ git wget unzip libopencv-dev \\
    python3-pip libusb-1.0-0-dev && \\
    rm -rf /var/lib/apt/lists/*

# (Optional) Install Edge TPU runtime
RUN echo "[INFO] Installing Edge TPU runtime..." && \\
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \\
    echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | tee /etc/apt/sources.list.d/coral-edgetpu.list && \\
    apt-get update && apt-get install -y libedgetpu1-std

# Copy source
COPY . /app
WORKDIR /app

# Build the binary
RUN cmake . && make -j\$(nproc)

# Entry point
ENTRYPOINT ["./video_pipeline"]
EOF

# Docker entrypoint (if needed later)
sudo tee entrypoint.sh > /dev/null <<EOF
#!/bin/bash
set -e
echo "[INFO] Starting video_pipeline..."
exec ./video_pipeline
EOF
chmod +x entrypoint.sh

# .dockerignore
sudo tee .dockerignore > /dev/null <<EOF
*.o
*.a
*.so
build/
.vscode/
*.log
*.mp4
__pycache__/
*.pyc
EOF