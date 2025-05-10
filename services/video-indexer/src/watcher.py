import logging
import time
import os
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from .indexer import VideoIndexer
from .blackbox_metadata import BlackboxService  # Your modular service
from .config import settings

logger = logging.getLogger(__name__)


class VideoEventHandler(FileSystemEventHandler):
    def __init__(self, indexer: VideoIndexer, blackbox: BlackboxService):
        self.indexer = indexer
        self.blackbox = blackbox

    def handle_event(self, path: Path):
        if path.suffix.lower() in settings.video_extensions:
            time.sleep(2)
            self.indexer.index_video(path)

        elif path.name == ".generate_metadata":
            logger.info(f"Triggering Blackbox metadata for: {path.parent}")
            self.blackbox.process_batch(path.parent)

    def on_created(self, event):
        if not event.is_directory:
            self.handle_event(Path(event.src_path))

    def on_moved(self, event):
        if not event.is_directory:
            self.handle_event(Path(event.dest_path))


class VideoWatcher:
    def __init__(self):
        self.indexer = VideoIndexer()
        self.blackbox = BlackboxService()
        self.observer = Observer()

    def _scan_existing(self):
        logger.info("Performing initial scan of existing files...")
        for root, _, files in os.walk(settings.watch_dir):
            for name in files:
                file_path = Path(root) / name
                if file_path.suffix.lower() in settings.video_extensions:
                    self.indexer.index_video(file_path)
                elif name == ".generate_metadata":
                    self.blackbox.process_batch(file_path.parent)

    def start(self):
        self._scan_existing()

        event_handler = VideoEventHandler(self.indexer, self.blackbox)
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