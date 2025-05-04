FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    ffmpeg \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/

# Create necessary directories
RUN mkdir -p /data/index

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV WATCH_DIR=/mnt/videos
ENV INDEX_DIR=/data/index

# Run the application
#CMD ["python", "-m", "src.main"]

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
