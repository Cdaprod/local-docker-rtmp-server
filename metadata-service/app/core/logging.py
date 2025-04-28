import threading
import time
import logging
import docker
import weakref
from typing import Optional, Callable, Dict, List, Any

class LogStreamer(logging.Logger):
    _instance: Optional["LogStreamer"] = None
    _lock = threading.Lock()

    def __new__(cls, name="LogStreamer", level=logging.INFO):
        with cls._lock:
            if cls._instance is None:
                cls._instance = super().__new__(cls)
                logging.Logger.__init__(cls._instance, name, level)
                cls._instance._init_streamer()
        return cls._instance

    def _init_streamer(self):
        self.client = docker.from_env()
        self.services: List[str] = []
        self.threads: Dict[str, threading.Thread] = {}
        self.running = False
        self.log_callback: Optional[Callable[[Dict[str, Any]], None]] = None
        self._log_level = logging.INFO

    def set_services(self, services: List[str]):
        """Set services to stream logs from"""
        self.services = services

    def set_callback(self, callback: Callable[[Dict[str, Any]], None]):
        """Set a callback for log output (can be print, websocket, queue, etc.)"""
        self.log_callback = callback

    def set_level_filter(self, level: int):
        """Only emit logs at this level or above"""
        self._log_level = level

    def get_container(self, service_name: str):
        """Locate container by partial service name"""
        for container in self.client.containers.list(all=True):
            if service_name in container.name:
                return container
        raise ValueError(f"No container found for service '{service_name}'")

    def _stream_logs(self, service: str):
        try:
            container = self.get_container(service)
            logs = container.logs(stream=True, follow=True, tail=10)

            for line in logs:
                if not self.running:
                    break

                msg = line.decode("utf-8").strip()
                if not msg:
                    continue

                log_entry = {
                    "service": service,
                    "container_id": container.id[:12],
                    "timestamp": time.time(),
                    "message": msg
                }

                if self.log_callback:
                    self.log_callback(log_entry)
                elif self.isEnabledFor(self._log_level):
                    self.log(self._log_level, f"[{service}] {msg}")

        except Exception as e:
            self.error(f"Error streaming logs from {service}: {str(e)}")

    def start(self):
        if self.running:
            self.warning("LogStreamer already running")
            return

        if not self.services:
            self.warning("No services configured to stream")
            return

        self.running = True
        for service in self.services:
            if service not in self.threads or not self.threads[service].is_alive():
                thread = threading.Thread(target=self._stream_logs, args=(service,), daemon=True)
                self.threads[service] = thread
                thread.start()

        self.info(f"LogStreamer started for: {self.services}")

    def stop(self):
        self.running = False
        for service, thread in list(self.threads.items()):
            if thread.is_alive():
                thread.join(timeout=2)
        self.threads.clear()
        self.info("LogStreamer stopped")

# Singleton-style access
log_streamer: LogStreamer = LogStreamer()

# Example usage: log_streamer.info("Hello from metadata!")