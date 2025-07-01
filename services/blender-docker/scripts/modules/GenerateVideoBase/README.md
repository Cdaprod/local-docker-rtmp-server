Below is a turnkey pattern you can copy-and-paste into your own repo to (1) build or pull a headless Blender container, (2) render a clip to H.264 MP4, and (3) stream Docker events so your host script can react as soon as frames or final video files appear. Everything happens without a GUI, so it will work in CI, on a render farm, or from the same "container-watcher" shell you’ve been running all day.

⸻

Quick summary

Blender ships a fully scriptable command-line interface (blender -b) that renders just fine inside Docker. Community images such as linuxserver/blender and nytimes/blender already expose that interface; you only need to mount a workspace volume, pass a "headless" render command, and (optionally) enable NVIDIA GPU support. While the container runs, you can use docker events (host side) or inotifywait (inside the container) to fire hooks whenever a frame hits disk or whenever the container exits.  ￼ ￼ ￼ ￼

⸻

1 · Choose or build an image

Common ready-made options

Image	CPU / GPU tags	Multi-arch	Notes
linuxserver/blender	<version> (CPU)	amd64 · arm64 · armv7	Small, weekly rebuilds.  ￼
nytimes/blender	*-cpu / *-gpu	amd64	CUDA & OptiX variants for Cycles GPU.  ￼

If you prefer deterministic supply-chain inputs, create your own image that simply unpacks the official Blender binary:

FROM ubuntu:22.04
ARG BLENDER_VERSION=4.4.3
RUN apt-get update && apt-get install -y wget ca-certificates ffmpeg \
 && wget -q https://download.blender.org/release/Blender${BLENDER_VERSION%.*}/blender-${BLENDER_VERSION}-linux-x64.tar.xz \
 && tar -xf blender-${BLENDER_VERSION}-linux-x64.tar.xz -C /opt \
 && ln -s /opt/blender-${BLENDER_VERSION}-linux-x64/blender /usr/local/bin/blender
ENTRYPOINT ["blender","-b"]

(This mirrors the approach recommended by Blender build-bot threads.)

⸻

2 · Render a video in the container

Blender’s CLI lets you specify both the scene file and the output codec. Example shell wrapper (render.sh):

#!/usr/bin/env bash
# $1 = path to .blend  •  $2 = start frame  •  $3 = end frame (optional)
SCENE=${1:?blend required}
START=${2:-1}
END=${3:-$START}

blender -b "$SCENE" \
  --python-expr "import bpy; \
    bpy.context.scene.render.image_settings.file_format='FFMPEG'; \
    bpy.context.scene.render.ffmpeg.format='MPEG4'; \
    bpy.context.scene.render.ffmpeg.codec='H264'; \
    bpy.context.scene.render.filepath='/render/out.mp4'" \
  -s "$START" -e "$END" -a

Run it with LinuxServer’s image:

docker run --rm \
  -v "$PWD/assets":/work \
  -v "$PWD/output":/render \
  linuxserver/blender:4.4.3 \
  /work/render.sh /work/scene.blend 1 250

Blender’s official manual documents all CLI flags  ￼, while Stack Overflow shows identical FFmpeg settings for manual encodes.  ￼

⸻

3 · Enable GPU (optional)

Install the NVIDIA Container Toolkit on the host, then invoke:

docker run --gpus all -e BLENDER_GPU="CUDA,OPTIX" ... nytimes/blender:latest-gpu ...

People switched to a CUDA 11 runtime base layer in 2024 to fix missing libraries, so verify the tag you pick matches your driver.  ￼ ￼

⸻

4 · Watch for files & container lifecycle

Using docker events from the host

docker events \
  --filter 'container=my_blender_job' \
  --filter 'event=die' \
  --format '{{json .}}' | while read evt; do
      echo "Render finished, processing output"
      # trigger downstream tool here
  done

docker events streams JSON describing every state-change, perfect for chaining commands once the container exits.  ￼ ￼

Tracking file writes in real-time

If you need per-frame hooks, bake inotify-tools into the image or side-car it:

docker run --rm -v "$PWD/output":/render devodev/inotify \
  inotifywait -m -e CLOSE_WRITE /render | while read dir ev file; do
      echo "Frame ready: $file"
      # e.g., assemble video, sync to cloud, etc.
  done

inotifywait reacts the instant Blender closes each PNG or EXR.  ￼ ￼

⸻

5 · End-to-end compose example

version: "3.9"
services:
  blender:
    image: linuxserver/blender:4.4.3
    volumes:
      - ./assets:/work
      - ./output:/render
    command: /work/render.sh /work/scene.blend 1 250
  watcher:
    image: devodev/inotify
    depends_on: [blender]
    volumes:
      - ./output:/render
    entrypoint: |
      sh -c "inotifywait -m -e CLOSE_WRITE /render |
             while read d e f; do echo RENDERED:$f; done"

Compose starts the headless renderer, the watcher waits for frames, and your host still receives high-level container events for orchestration. Tutorials show the same workflow for render farms and monitoring proofs-of-concept.  ￼ ￼

⸻

6 · Tips & troubleshooting
	•	Eevee inside a container needs an EGL or VirtualGL OpenGL stack; Haiyi Mei’s images bundle it if you truly need real-time shaders.  ￼
	•	ARM Macs / Pi render nodes: only LinuxServer builds multi-arch manifests today.  ￼
	•	Pin the exact Blender version in CI to avoid hash mismatches when scripts are sensitive to floating-point changes between micro releases.

⸻

You now have:
	1.	A Docker image (or Dockerfile) you can drop into any pipeline.
	2.	A render script that produces H.264 video or frame sequences.
	3.	Event hooks at both the container and filesystem layers to wire into your existing "generate-and-watch" loop.

Happy rendering!