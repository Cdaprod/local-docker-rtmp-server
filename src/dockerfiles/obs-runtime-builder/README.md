# OBS Runtime Builder (ARM64)

This Dockerfile builds a minimal runtime image with:

- OBS Studio (latest `master`)
- RTSP Server Plugin
- Tagged under `cdaprod/obs-runtime:latest`

## Usage

### 1. Build and Push

```bash
docker buildx build --platform linux/arm64 \
  -t cdaprod/obs-runtime:latest \
  -f src/dockerfiles/obs-runtime-builder/Dockerfile \
  --push .
```

Requires docker buildx and a logged-in DockerHub or GHCR registry.

## **Next Steps**

  Would you like a GitHub Action workflow under `.github/workflows/publish-obs-runtime.yaml` to:
  - Automate building + pushing?
  - Trigger on tag like `v1.0.0`?