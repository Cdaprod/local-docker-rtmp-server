# handlers/ndi_handler.py

import os
import time
import logging
from pathlib import Path

try:
    import ndi
except ImportError:
    ndi = None

logger = logging.getLogger("ndi_handler")

class NDIHandler:
    def __init__(self, config):
        self.config = config
        self.enabled = config.get('ndi', {}).get('enabled', True)
        self.output_dir = Path(config.get('ndi', {}).get('output_dir', '/mnt/ndi_captures'))
        self.record_duration = config.get('ndi', {}).get('record_duration', 60)  # seconds
        # Add more as needed

    def should_handle(self, src_path=None):
        # Unlike file handlers, NDI isn't path-triggered. It's event/schedule/config triggered.
        return self.enabled and ndi is not None

    def handle(self, src_path=None):
        """Discover and record NDI streams as files (mp4/mov), trigger downstream indexers."""
        if not self.enabled or ndi is None:
            logger.warning("NDIHandler is not enabled or NDI SDK not installed")
            return

        logger.info("Discovering NDI sources...")
        find = ndi.find_create_v2()
        sources = ndi.find_get_current_sources(find)
        ndi.find_destroy(find)

        logger.info(f"NDI sources found: {sources}")

        for source in sources:
            name = source.ndi_name.decode() if hasattr(source.ndi_name, 'decode') else source.ndi_name
            logger.info(f"Connecting to NDI source: {name}")
            recv = ndi.recv_create_v3()
            ndi.recv_connect(recv, source)
            filename = f"{name}_{int(time.time())}.mp4"
            out_path = self.output_dir / filename
            self.record_stream(recv, out_path)
            ndi.recv_destroy(recv)

    def record_stream(self, recv, out_path: Path):
        # Demo: This needs to be implemented with the SDK (frames are raw RGBA/yuv + audio).
        # For demo, let's say you dump 10 seconds to a temp file via ffmpeg/pipe.
        # In real code: you'd use ffmpeg or OBS CLI to do NDI capture if Python API isn't robust.
        logger.info(f"Recording NDI stream to {out_path} (duration {self.record_duration}s)")
        cmd = [
            "ffmpeg",
            "-y",
            "-f", "libndi_newtek",
            "-i", "INSERT_NDI_STREAM_NAME_HERE",  # replace with dynamic NDI source name
            "-t", str(self.record_duration),
            str(out_path)
        ]
        os.system(' '.join(cmd))
        logger.info(f"NDI stream saved to {out_path}")
        # Now trigger the video indexer
        self.notify_indexer(out_path)

    def notify_indexer(self, out_path: Path):
        # POST to your video-indexer endpoint or similar
        pass  # implement HTTP POST as per your media_bridge_agent.py