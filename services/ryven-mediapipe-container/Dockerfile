FROM python:3.10-slim

ENV DEBIAN_FRONTEND=noninteractive

# Install system dependencies
RUN apt-get update && apt-get install -y \
    ffmpeg \
    libgl1-mesa-glx \
    libglib2.0-0 \
    git \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Install Python deps
RUN pip install --upgrade pip

# Install Ryven + dependencies
RUN pip install pyqt5 opencv-python-headless mediapipe numpy

# Clone Ryven
WORKDIR /app
RUN git clone https://github.com/leon-thomm/Ryven.git
WORKDIR /app/Ryven

# Optional: install example nodes
RUN git clone https://github.com/leon-thomm/RyvenStdLib.git stdlib

# Expose Ryven GUI or headless socket
EXPOSE 5000

# Default run command (GUI only runs on host for now)
CMD ["python", "main.py"]