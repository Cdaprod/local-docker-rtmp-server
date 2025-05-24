import yaml
import requests
import os
import shutil
import time
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler
from handlers.ndi_handler import NDIHandler
from handlers.video_handler import VideoHandler


handler_plugins = [
    NDIHandler(config),
    VideoHandler(config),
    # ...other handlers
]

# Example: Periodically check for NDI streams
def run_ndi_capture_periodically():
    while True:
        for plugin in handler_plugins:
            if hasattr(plugin, 'handle') and plugin.should_handle():
                plugin.handle()
        time.sleep(60)  # check every 60 seconds

CONFIG_PATH = '/config/media-bridge.yaml'

with open(CONFIG_PATH, 'r') as f:
    config = yaml.safe_load(f)

class MediaBridgeHandler(FileSystemEventHandler):
    def process_file(self, src_path):
        ext = os.path.splitext(src_path)[1].lower()
        rules = config['rules']
        
        for rule in rules.values():
            if rule['enabled'] and ext in rule['match']['extensions']:
                dest_template = rule['actions'][0]['move']
                project_name = self.extract_project(src_path)
                dest = dest_template.format(project_name=project_name)
                os.makedirs(dest, exist_ok=True)
                shutil.move(src_path, dest)
                
                # Trigger indexing API
                endpoints = config['notifications']['http']['endpoints']
                for endpoint in endpoints:
                    try:
                        requests.post(endpoint['url'], json={"path": dest})
                        print(f"Triggered indexing for: {dest}")
                    except Exception as e:
                        print(f"Failed to trigger API: {e}")

    def extract_project(self, path):
        # Placeholder: logic to derive project name from path/filename
        return 'General'

    def on_created(self, event):
        if not event.is_directory:
            time.sleep(config['rules']['ingest_to_edit']['match']['delay_seconds'])
            self.process_file(event.src_path)

observer = Observer()
watch_paths = config['mount_points']['ingest']

for path in watch_paths:
    observer.schedule(MediaBridgeHandler(), path=path, recursive=True)

print(f"Watching: {watch_paths}")

observer.start()
try:
    while True:
        time.sleep(1)
except KeyboardInterrupt:
    observer.stop()
observer.join()


if __name__ == "__main__":
    # ... your file watch setup
    # Start the NDI polling thread
    import threading
    t = threading.Thread(target=run_ndi_capture_periodically, daemon=True)
    t.start()
    # ... file watcher as normal