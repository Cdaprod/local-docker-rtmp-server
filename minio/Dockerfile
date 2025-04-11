FROM cdaprod/cda-minio

# Optionally install extra packages if needed (like bash, curl, etc.)
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
      bash \
      curl && \
    rm -rf /var/lib/apt/lists/*

# Copy your initialization script into the container.  
# Many MinIO images honor /docker-entrypoint-init.d/ for additional setup.
COPY ./scripts/init-minio.sh /docker-entrypoint-init.d/init-minio.sh

# Ensure the script is executable.
RUN chmod +x /docker-entrypoint-init.d/init-minio.sh

# Use the default entrypoint and command provided by the base image.
# (If you need to override these, you can; but ideally, your base image’s entrypoint
#  will run scripts in /docker-entrypoint-init.d/ before starting the server.)
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["minio", "server", "/data"]