# Create and write all required files for wifi-hdmi-transmission

mkdir -p services/wifi-hdmi-transmission/dev/master
mkdir -p services/wifi-hdmi-transmission/dev/slave

sudo tee services/wifi-hdmi-transmission/Dockerfile > /dev/null <<'EOF'
# Base Dockerfile for wifi-hdmi-transmission role-based builds
ARG ROLE

FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ffmpeg \
    iproute2 \
    hostapd \
    dnsmasq \
    iputils-ping \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY ./dev/${ROLE}/ /app

RUN pip install --no-cache-dir -r requirements.txt || true

CMD ["python", "main.py"]
EOF

sudo tee services/wifi-hdmi-transmission/docker-compose.yaml > /dev/null <<'EOF'
version: '3.8'

services:
  master:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        ROLE: master
    container_name: hdmi-master
    network_mode: host
    restart: unless-stopped
    environment:
      - DEVICE_ROLE=master
    volumes:
      - /dev:/dev
      - /tmp:/tmp
    cap_add:
      - NET_ADMIN
    privileged: true

  slave:
    build:
      context: .
      dockerfile: Dockerfile
      args:
        ROLE: slave
    container_name: hdmi-slave
    network_mode: host
    restart: unless-stopped
    environment:
      - DEVICE_ROLE=slave
    volumes:
      - /dev:/dev
      - /tmp:/tmp
    cap_add:
      - NET_ADMIN
    privileged: true
EOF

sudo tee services/wifi-hdmi-transmission/dev/master/Dockerfile > /dev/null <<'EOF'
# Just a placeholder if you want to build master-specific standalone image
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ffmpeg \
    hostapd \
    dnsmasq \
    iputils-ping \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY . /app
RUN pip install --no-cache-dir -r requirements.txt || true

CMD ["python", "main.py"]
EOF

sudo tee services/wifi-hdmi-transmission/dev/slave/Dockerfile > /dev/null <<'EOF'
# Just a placeholder if you want to build slave-specific standalone image
FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    ffmpeg \
    iputils-ping \
    curl \
    && rm -rf /var/lib/apt/lists/*

COPY . /app
RUN pip install --no-cache-dir -r requirements.txt || true

CMD ["python", "main.py"]
EOF

sudo tee services/wifi-hdmi-transmission/README.md > /dev/null <<'EOF'
docker compose -f services/wifi-hdmi-transmission/docker-compose.yaml up --build
EOF
