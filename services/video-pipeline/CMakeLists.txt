cmake_minimum_required(VERSION 3.10)
project(video_pipeline)

set(CMAKE_CXX_STANDARD 17)

# Required for OpenCV
find_package(OpenCV REQUIRED)
include_directories(${OpenCV_INCLUDE_DIRS})

# Include local headers
include_directories(
    ${CMAKE_SOURCE_DIR}/Processing
    ${CMAKE_SOURCE_DIR}/Inference
    ${CMAKE_SOURCE_DIR}/NDI
    ${CMAKE_SOURCE_DIR}/Models
)

add_executable(video_pipeline
    main.cpp
    Processing/OverlayProcessor.cpp
    Inference/EdgeTPUWrapper.cpp
    NDI/NDIReceiver.cpp
    NDI/NDISender.cpp
)

target_link_libraries(video_pipeline ${OpenCV_LIBS})
