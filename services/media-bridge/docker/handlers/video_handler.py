from pathlib import Path
import os
import time
import logging
import requests

# handlers/video_handler.py

logger = logging.getLogger("video_handler")

class VideoHandler:
    def __init__(self, config):
        rules = config.get('rules', {}).get('ingest_to_edit', {})
        self.extensions = set(rules.get('match', {}).get('extensions', []))
        self.delay = rules.get('match', {}).get('delay_seconds', 0)
        self.actions = rules.get('actions', [])
        self.endpoints = config.get('notifications', {}).get('http', {}).get('endpoints', [])

    def should_handle(self, src_path: str) -> bool:
        """Return True if the file extension matches configured video extensions."""
        return Path(src_path).suffix.lower() in self.extensions

    def handle(self, src_path: str):
        """Move the file according to rule and notify downstream services."""
        time.sleep(self.delay)
        src = Path(src_path)
        project_name = self.extract_project(src)

        # Build destination path from the first 'move' action
        dest_template = next((a['move'] for a in self.actions if 'move' in a), None)
        if not dest_template:
            logger.error("No move action defined for video handler")
            return

        dest_dir = Path(dest_template.format(project_name=project_name))
        dest_dir.mkdir(parents=True, exist_ok=True)
        dest_path = dest_dir / src.name

        # Move file
        try:
            src.replace(dest_path)
            logger.info(f"Moved video: {src} → {dest_path}")
        except Exception as e:
            logger.error(f"Failed to move {src} to {dest_path}: {e}")
            return

        # Notify endpoints
        for endpoint in self.endpoints:
            url = endpoint.get('url')
            try:
                resp = requests.post(url, json={"path": str(dest_path)})
                resp.raise_for_status()
                logger.info(f"Notified {url} for {dest_path}")
            except Exception as e:
                logger.error(f"Failed to notify {url}: {e}")

    def extract_project(self, path: Path) -> str:
        """Derive a project name from the file path or name."""
        # Example: use parent directory name
        return path.parent.name or 'General'

# Example usage in media_bridge_agent.py (not executed here)
# handler_plugins = [
#     NDIHandler(config),
#     VideoHandler(config),
#     # ... other handlers
# ]
# if plugin.should_handle(file_path):
#     plugin.handle(file_path)