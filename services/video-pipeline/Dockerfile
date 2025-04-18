# Use multi-stage build for smaller final image
FROM alpine:3.19 AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    clang \
    git \
    wget \
    unzip \
    pkgconfig \
    linux-headers \
    # OpenCV dependencies
    libjpeg-turbo-dev \
    libpng-dev \
    ffmpeg-dev \
    libusb-dev

# Create working directory
WORKDIR /build

# Copy source code
COPY . .

# Build with optimizations
RUN cmake \
    -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_C_COMPILER=clang \
    -DCMAKE_CXX_COMPILER=clang++ \
    -DCMAKE_C_FLAGS="-Os -fomit-frame-pointer" \
    -DCMAKE_CXX_FLAGS="-Os -fomit-frame-pointer" \
    . && \
    make -j$(nproc)

# Create minimal runtime image
FROM alpine:3.19

# Install runtime dependencies only
RUN apk add --no-cache \
    libstdc++ \
    libusb \
    ffmpeg-libs \
    libjpeg-turbo \
    libpng \
    bash

# Add Edge TPU support
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing" >> /etc/apt/sources.list.d/edge.list && \
    apk add --no-cache libedgetpu1@testing

# Create non-root user
RUN addgroup -S appgroup && \
    adduser -S appuser -G appgroup

# Copy only what's needed from the builder stage
COPY --from=builder /build/video_pipeline /app/
COPY entrypoint.sh /app/

# Set working directory
WORKDIR /app

# Fix permissions and make entrypoint executable
RUN chmod +x /app/entrypoint.sh /app/video_pipeline && \
    chown -R appuser:appgroup /app

# Switch to non-root user
USER appuser

# Set entrypoint
ENTRYPOINT ["/app/entrypoint.sh"]