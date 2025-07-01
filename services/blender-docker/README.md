# Go get local-docker-blender-api or whichever python api job and task service (decide which)

# Is there A Public Blender Image?

Docker Hub does host several public, headless-ready Blender images, but -- crucially -- none of them are published by the Blender Foundation itself.
Instead, community maintainers (LinuxServer.io, The New York Times R&D, BlenderKit, Haiyi Mei, etc.) build and update images that launch Blender in command-line/"background" mode so you can render or script without a GUI.

⸻

1  Is there an "official" Blender image?
	•	The Docker Official-Images programme lists hundreds of upstream-maintained repos, but Blender is not one of them  ￼ ￼.
	•	Historically, a library/blender image existed briefly, but it was deprecated and eventually removed from the catalogue; today no namespace owned by blender or blenderfoundation appears on Docker Hub search results.

Bottom line: all current images are community-supported; you should evaluate their update cadence and feature set just as you would any third-party package.

⸻

2  Popular headless Blender images

Maintainer / Repo	Latest tag style	CPU / GPU variants	Architectures	Notes
LinuxServer.io linuxserver/blender	4.4.3, latest	CPU only (GPU not enabled)	amd64, arm64, arm/v7, etc.  ￼ ￼	Multi-platform manifests; frequent releases (ls### tags).
NYTimes R&D nytimes/blender	latest or `-cpu	gpu-ubuntu18.04`	Separate CPU & CUDA/OptiX images  ￼ ￼	amd64
BlenderKit blenderkit/headless-blender	blender-4.2, etc.	CPU	amd64  ￼	Minimal base for their add-on backend.
Haiyi Mei meihaiyi/blender	blender-3.6-cuda11.7.1-ubuntu20.04	CPU & GPU (EGL headless OpenGL)  ￼	amd64	Supports Eevee and Cycles with EGL, so no X11 is required.

All of these images start Blender with the CLI entry-point (blender -b) so no GUI libraries are bundled -- keeping images smaller and eliminating the need for X11/VNC.

Tip: If you ever do need interactive UI inside a container, look at desktop-streaming images such as kasmweb/blender, which wrap Blender in a browser-served VNC/NoVNC session  ￼.

⸻

3  Quick-start: running a headless render

# CPU-only render of scene.blend with LinuxServer image
docker run --rm -v "$PWD":/data \
    linuxserver/blender:4.4.3 \
    blender -b /data/scene.blend -o /data/frame_##### -F PNG -f 1

# GPU (CUDA) render with NYTimes image
docker run --rm --gpus all -v "$PWD":/scene \
    nytimes/blender:latest \
    blender -b /scene/demo.blend -o /scene/out/frame_##### -f 1

The --gpus all flag requires the NVIDIA Container Toolkit on the host.

⸻

4  Choosing the right image
	1.	Match your Blender version – verify the tag offers the exact major/minor you need; LinuxServer and NYTimes publish version-pinned tags.
	2.	GPU vs. CPU – LinuxServer is CPU-only  ￼, while NYTimes and Haiyi Mei provide CUDA builds  ￼ ￼.
	3.	Architecture – ARM builds (Raspberry Pi, Apple Silicon) are available only from LinuxServer today  ￼.
	4.	Update cadence & support – LinuxServer maintains a documented support policy and pushes weekly rebuilds  ￼ ￼.

⸻

5  If you need something "official"

Because the Foundation doesn’t ship Docker images, teams that demand reproducible, supply-chain-audited builds often create an internal image that:
	•	Downloads the official binary tarball from download.blender.org;
	•	Adds only the libraries your pipeline needs;
	•	Pins build hashes in a locked Dockerfile.

The Devtalk thread on release-build containers outlines the approach used by Blender’s own buildbot for Linux packages  ￼.

⸻

Key Take-aways
	•	Yes – you can pull ready-made headless Blender images from Docker Hub today.
	•	No – none are maintained by the Blender Foundation; they’re third-party builds.
	•	Pick a community image that matches your CPU/GPU needs, or roll your own for maximum control and reproducibility.