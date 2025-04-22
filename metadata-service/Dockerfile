# --------------------------------------------
# Stage 1: Python Builder (for caching pip)
# --------------------------------------------
FROM python:3.9-slim AS metadata-builder

WORKDIR /app

# Install system tools
RUN apt-get update && apt-get install -y --no-install-recommends curl \
 && rm -rf /var/lib/apt/lists/*

# Copy and install Python deps
COPY ./requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# --------------------------------------------
# Stage 2: Final Runtime
# --------------------------------------------
FROM python:3.9-slim

LABEL org.opencontainers.image.title="metadata-service" \
      org.opencontainers.image.description="Python FastAPI service for event-driven metadata processing" \
      org.opencontainers.image.version="1.0.0" \
      org.opencontainers.image.authors="David Cannan <Cdaprod@Cdaprod.dev>" \
      org.opencontainers.image.licenses="MIT" \
      org.opencontainers.image.source="https://github.com/Cdaprod/local-docker-rtmp-server" \
      com.cdaprod.role="RabbitMQ Metadata Consumer" \
      com.cdaprod.module="FastAPI, Metadata Queue, Sanity pipeline" \
      com.cdaprod.env="production"

WORKDIR /app

# Copy dependencies from builder
COPY --from=metadata-builder /usr/local/lib/python3.9/site-packages /usr/local/lib/python3.9/site-packages
COPY --from=metadata-builder /usr/local/bin /usr/local/bin

# Copy your code
COPY app.py .
COPY healthcheck.sh .
RUN chmod +x healthcheck.sh

EXPOSE 5000

ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "5000", "--workers", "4"]