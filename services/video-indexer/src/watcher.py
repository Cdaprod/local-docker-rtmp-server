import logging
import time
from pathlib import Path
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

from .indexer import VideoIndexer
from .config import settings


logger = logging.getLogger(__name__)


class VideoEventHandler(FileSystemEventHandler):
    def __init__(self, indexer: VideoIndexer):
        self.indexer = indexer
    
    def on_created(self, event):
        if event.is_directory:
            return
        
        file_path = Path(event.src_path)
        if file_path.suffix.lower() in settings.video_extensions:
            # Wait a bit to ensure file is fully written
            time.sleep(2)
            self.indexer.index_video(file_path)
    
    def on_moved(self, event):
        if event.is_directory:
            return
        
        file_path = Path(event.dest_path)
        if file_path.suffix.lower() in settings.video_extensions:
            time.sleep(2)
            self.indexer.index_video(file_path)


class VideoWatcher:
    def __init__(self):
        self.indexer = VideoIndexer()
        self.observer = Observer()
    
    def start(self):
        """Start watching for video files"""
        event_handler = VideoEventHandler(self.indexer)
        self.observer.schedule(event_handler, str(settings.watch_dir), recursive=True)
        self.observer.start()
        
        logger.info(f"Started watching {settings.watch_dir} for video files")
        
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            self.observer.stop()
        
        self.observer.join()