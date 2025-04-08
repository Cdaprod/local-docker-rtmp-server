#!/bin/bash
set -euo pipefail

# NAS mount details
NAS_IP_OR_HOSTNAME=${NAS_IP_OR_HOSTNAME:-"192.168.0.19"}
NAS_SHARE_NAME=${NAS_SHARE_NAME:-"volume1/videos"}
NAS_USERNAME=${NAS_USERNAME:-""}
NAS_PASSWORD=${NAS_PASSWORD:-""}
NAS_MOUNT_PATH=${NAS_MOUNT_PATH:-"/var/www/recordings"}

# Function to verify SSL certificates
check_ssl_certificates() {
    if [ ! -f "/etc/nginx/ssl/cert.pem" ] || [ ! -f "/etc/nginx/ssl/key.pem" ]; then
        echo "Warning: SSL certificates not found. Generating self-signed certificates..."
        mkdir -p /etc/nginx/ssl
        openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
            -keyout /etc/nginx/ssl/key.pem \
            -out /etc/nginx/ssl/cert.pem \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost"
    fi
}

# Function to verify and set up directories
setup_directories() {
    local dirs=("/var/www/recordings" "/tmp/hls" "/usr/share/nginx/html/assets")
    for dir in "${dirs[@]}"; do
        mkdir -p "$dir"
    done
    echo "Directories are set up."
}

# Mount NAS function
mount_nas() {
    echo "Checking NAS mount at ${NAS_MOUNT_PATH}..."
    if mountpoint -q "${NAS_MOUNT_PATH}"; then
        echo "NAS is already mounted at ${NAS_MOUNT_PATH}"
        return 0
    fi

    echo "Attempting to mount NAS at ${NAS_MOUNT_PATH}..."
    mkdir -p "${NAS_MOUNT_PATH}"

    local mount_options="rw,vers=3.0,uid=1000,gid=1000"
    if [ -n "${NAS_USERNAME}" ] && [ -n "${NAS_PASSWORD}" ]; then
        mount -t cifs "//${NAS_IP_OR_HOSTNAME}/${NAS_SHARE_NAME}" "${NAS_MOUNT_PATH}" \
            -o username="${NAS_USERNAME}",password="${NAS_PASSWORD}",${mount_options}
    else
        mount -t cifs "//${NAS_IP_OR_HOSTNAME}/${NAS_SHARE_NAME}" "${NAS_MOUNT_PATH}" -o "${mount_options}"
    fi

    if mountpoint -q "${NAS_MOUNT_PATH}"; then
        echo "NAS mounted successfully at ${NAS_MOUNT_PATH}"
    else
        echo "Error: Failed to mount NAS at ${NAS_MOUNT_PATH}"
        exit 1
    fi
}

# Function to generate nginx configuration
generate_nginx_conf() {
    echo "Generating nginx configuration..."
    if [ ! -f "/etc/nginx/nginx.conf.template" ]; then
        echo "Error: nginx.conf.template not found!"
        exit 1
    fi

    # Export additional variables for template substitution
    export NGINX_WORKER_PROCESSES=${NGINX_WORKER_PROCESSES:-auto}
    export NGINX_WORKER_CONNECTIONS=${NGINX_WORKER_CONNECTIONS:-2048}
    export MAX_SEGMENT_DURATION=${MAX_SEGMENT_DURATION:-6}

    envsubst '${NGINX_WORKER_PROCESSES} ${NGINX_WORKER_CONNECTIONS} ${MAX_SEGMENT_DURATION}' \
        < /etc/nginx/nginx.conf.template > /etc/nginx/nginx.conf

    # Validate nginx configuration
    if ! nginx -t -c /etc/nginx/nginx.conf; then
        echo "Error: Nginx configuration validation failed!"
        exit 1
    fi
}

# Main execution
main() {
    echo "Starting RTMP server initialization..."

    # Run setup functions
    check_ssl_certificates
    setup_directories
    mount_nas
    generate_nginx_conf

    # Start nginx
    echo "Starting nginx..."
    exec nginx -g 'daemon off;'
}

# Execute main function
main "$@"