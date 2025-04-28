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
  -t cdaprod/obs-runtime:vX.X.X \
  -f ./Dockerfile \
  --push .
```

## Usage

### Build and Push (standard Docker)

```bash
docker build -t cdaprod/obs-runtime:latest \
  -t cdaprod/obs-runtime:v1.2.1 \
  -f Dockerfile .
```

### 2. Run It

```bash
docker run --rm -it --name obs-runtime \
  -p 5800:5800 -p 5900:5900 -p 4455:4455 \
  cdaprod/obs-runtime:v1.2.1
``` 

Requires docker buildx and a logged-in DockerHub or GHCR registry.

## **Next Steps**

  Would you like a GitHub Action workflow under `.github/workflows/publish-obs-runtime.yaml` to:
  - Automate building + pushing?
  - Trigger on tag like `v1.0.0`?


## My Docker Build Commands 

``` 
docker buildx build \
  --builder cda-builder \                      
  --platform linux/arm64 \
  --target runtime
  --no-cache \
  --tag cdaprod/obs-runtime:latest \
  --file Dockerfile \
  --push \
  .
``` 

```
docker buildx build \
  --builder cda-builder \                      
  --platform linux/arm64 \
  --no-cache \
  --tag cdaprod/obs-runtime:latest \
  --file Dockerfile \
  --push \
  --progress=tty \
  .
``` 

```
# --cache-from type=registry,ref=cdaprod/obs-runtime:cache,mode=max \
```