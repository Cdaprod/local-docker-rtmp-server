FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake g++ git wget unzip libopencv-dev \
    python3-pip libusb-1.0-0-dev && \
    rm -rf /var/lib/apt/lists/*

# (Optional) Install Edge TPU runtime
RUN echo "[INFO] Installing Edge TPU runtime..." && \
    curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key add - && \
    echo "deb https://packages.cloud.google.com/apt coral-edgetpu-stable main" | tee /etc/apt/sources.list.d/coral-edgetpu.list && \
    apt-get update && apt-get install -y libedgetpu1-std

# Copy source
COPY . /app
WORKDIR /app

# Build the binary
RUN cmake . && make -j$(nproc)

# Entry point
ENTRYPOINT ["./video_pipeline"]
