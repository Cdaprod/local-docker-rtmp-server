#!/bin/bash
set -euo pipefail

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

# Function to verify directories and permissions
setup_directories() {
    local dirs=("/var/www/recordings" "/tmp/hls" "/usr/share/nginx/html/assets")
    for dir in "${dirs[@]}"; do
        echo "Setting up directory: $dir"
        mkdir -p "$dir"
        chmod -R 755 "$dir"
    done
}

# Function to mount NAS
mount_nas() {
    echo "Attempting to mount NAS..."

    if [ -z "${NAS_IP_OR_HOSTNAME:-}" ] || [ -z "${NAS_SHARE_NAME:-}" ]; then
        echo "Error: NAS_IP_OR_HOSTNAME and NAS_SHARE_NAME must be set!"
        exit 1
    fi

    NAS_MOUNT_POINT="/var/www/recordings"

    mkdir -p "$NAS_MOUNT_POINT"
    mount -t cifs \
        //"$NAS_IP_OR_HOSTNAME"/"$NAS_SHARE_NAME" \
        "$NAS_MOUNT_POINT" \
        -o username="${NAS_USERNAME:-},password=${NAS_PASSWORD:-},rw" || {
            echo "Error: Failed to mount NAS at $NAS_MOUNT_POINT"
            exit 1
        }

    echo "NAS successfully mounted at $NAS_MOUNT_POINT"
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
    nginx -t -c /etc/nginx/nginx.conf || {
        echo "Error: Nginx configuration validation failed!"
        exit 1
    }
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