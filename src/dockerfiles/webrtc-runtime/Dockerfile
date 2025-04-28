# syntax=docker/dockerfile:1

# ==============================================================================
# Stage 1: Build the Node.js app
# ==============================================================================
FROM node:18-alpine AS builder

WORKDIR /app

# Copy the whole app folder instead of just package.json
COPY app/ .

# Check if package.json exists and install dependencies properly
RUN if [ ! -f package.json ]; then npm init -y && npm install express ws; else npm install; fi

# ==============================================================================
# Stage 2: Final lightweight runtime
# ==============================================================================
FROM alpine:3.19

# Install coturn and tini only
RUN apk add --no-cache coturn tini nodejs npm

# Copy the TURN server config
COPY turnserver.conf /etc/coturn/turnserver.conf

# Copy built Node.js app from builder
COPY --from=builder /app /app

WORKDIR /app

# Expose necessary ports
EXPOSE 3478/tcp
EXPOSE 3478/udp
EXPOSE 8080/tcp
EXPOSE 49152-65535/udp

# Init process with tini to reap zombies
ENTRYPOINT ["/sbin/tini", "--"]

# Start both coturn and signaling server
CMD ["sh", "-c", "turnserver -c /etc/coturn/turnserver.conf & node server.js"]