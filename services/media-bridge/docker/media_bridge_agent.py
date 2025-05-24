# File: services/media-bridge/docker/media_bridge_agent.py

#!/usr/bin/env python3

import sys
import os
import time
import yaml
import logging
import threading
import requests
import shutil
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from handlers.video_handler import VideoHandler
from handlers.ndi_handler import NDIHandler

# ─── Logging Setup ──────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s %(message)s",
    stream=sys.stdout,
)
logger = logging.getLogger("media-bridge-agent")

# ─── Load Configuration ─────────────────────────────────────────────────────────
CONFIG_PATH = '/config/media-bridge.yaml'
try:
    with open(CONFIG_PATH, 'r') as f:
        config = yaml.safe_load(f)
    logger.info(f"Loaded config from {CONFIG_PATH}")
except Exception as e:
    logger.error(f"Failed to load config: {e}")
    sys.exit(1)

# ─── Initialize Handler Plugins ────────────────────────────────────────────────
handler_plugins = [
    VideoHandler(config),
    NDIHandler(config),
]

# ─── File-Based Event Handler ─────────────────────────────────────────────────
class MediaBridgeHandler(FileSystemEventHandler):
    def on_created(self, event):
        if not event.is_directory:
            self._handle_event(Path(event.src_path))

    def on_moved(self, event):
        if not event.is_directory:
            self._handle_event(Path(event.dest_path))

    def _handle_event(self, path: Path):
        for plugin in handler_plugins:
            try:
                # Only file-based handlers should react to a path
                if plugin.should_handle(path):
                    plugin.handle(path)
                    break
            except Exception as e:
                logger.error(f"[{plugin.__class__.__name__}] error handling {path}: {e}")

def start_file_watcher(paths, recursive=True):
    observer = Observer()
    handler = MediaBridgeHandler()
    for p in paths:
        observer.schedule(handler, p, recursive=recursive)
        logger.info(f"Watching path: {p} (recursive={recursive})")
    observer.start()
    return observer

# ─── NDI Polling Loop ──────────────────────────────────────────────────────────
def ndi_polling_loop(interval_sec):
    logger.info(f"Starting NDI polling thread (interval={interval_sec}s)")
    while True:
        for plugin in handler_plugins:
            # Only the NDIHandler should run here
            if isinstance(plugin, NDIHandler) and plugin.should_handle():
                try:
                    plugin.handle()
                except Exception as e:
                    logger.error(f"[NDIHandler] error: {e}")
        time.sleep(interval_sec)

# ─── Main Entrypoint ───────────────────────────────────────────────────────────
def main():
    # Start NDI polling if enabled
    ndi_cfg = config.get('ndi', {})
    if ndi_cfg.get('enabled', False):
        interval = ndi_cfg.get('poll_interval', 60)
        t = threading.Thread(target=ndi_polling_loop, args=(interval,), daemon=True)
        t.start()

    # Start file watcher
    mount_points = config.get('mount_points', {}).get('ingest', [])
    if not mount_points:
        logger.error("No ingest mount_points defined in config.")
        sys.exit(1)
    observer = start_file_watcher(
        mount_points,
        recursive=config.get('rules', {}).get('ingest_to_edit', {}).get('recursive', True)
    )

    # Keep alive until interrupted
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        logger.info("Shutdown requested. Stopping services...")
    finally:
        observer.stop()
        observer.join()
        logger.info("File watcher stopped. Exiting.")

if __name__ == "__main__":
    main()