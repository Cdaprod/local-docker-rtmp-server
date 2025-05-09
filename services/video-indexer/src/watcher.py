import logging
import time
import os
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from .indexer import VideoIndexer
from .config import settings


logger = logging.getLogger(__name__)


class VideoEventHandler(FileSystemEventHandler):
    def __init__(self, indexer: VideoIndexer):
        self.indexer = indexer

    def handle_event(self, path: Path):
        if path.suffix.lower() in settings.video_extensions:
            # Wait for write to finish
            time.sleep(2)
            self.indexer.index_video(path)

    def on_created(self, event):
        if not event.is_directory:
            self.handle_event(Path(event.src_path))

    def on_moved(self, event):
        if not event.is_directory:
            self.handle_event(Path(event.dest_path))


class VideoWatcher:
    def __init__(self):
        self.indexer = VideoIndexer()
        self.observer = Observer()

    def _scan_existing(self):
        logger.info("Performing initial scan of existing files...")
        for root, _, files in os.walk(settings.watch_dir):
            for name in files:
                file_path = Path(root) / name
                if file_path.suffix.lower() in settings.video_extensions:
                    self.indexer.index_video(file_path)

    def start(self):
        """Start watching for video files"""
        self._scan_existing()

        event_handler = VideoEventHandler(self.indexer)
        self.observer.schedule(
            event_handler,
            str(settings.watch_dir),
            recursive=settings.recursive_watch
        )
        self.observer.start()

        logger.info(f"Started watching {settings.watch_dir} recursively={settings.recursive_watch}")

        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.observer.stop()

        self.observer.join()