import os, time, yaml, importlib
from watchdog.observers import Observer
from watchdog.events import FileSystemEventHandler

CONFIG_PATH = os.environ.get("CONFIG_PATH", "/app/config.yaml")

with open(CONFIG_PATH, "r") as f:
    config = yaml.safe_load(f)

ACTIONS = {}
for name in config["actions"]:
    ACTIONS[name] = importlib.import_module(f"actions.{name}")

class Handler(FileSystemEventHandler):
    def __init__(self, actions, action_cfg):
        super().__init__()
        self.actions = actions
        self.action_cfg = action_cfg
    def on_created(self, event):
        if event.is_directory: return
        print(f"[watchdog] New file: {event.src_path}")
        for act_name in self.actions:
            act_mod = ACTIONS[act_name]
            act_conf = config["actions"].get(act_name, {})
            try:
                act_mod.run(event.src_path, act_conf)
            except Exception as e:
                print(f"[{act_name}] error: {e}")

def main():
    observers = []
    for entry in config["watch_paths"]:
        path = entry["path"]
        acts = entry.get("actions", [])
        handler = Handler(acts, config["actions"])
        observer = Observer()
        observer.schedule(handler, path, recursive=False)
        observer.start()
        print(f"[watchdog] Watching {path} for actions: {acts}")
        observers.append(observer)
    try:
        while True: time.sleep(1)
    except KeyboardInterrupt:
        for ob in observers: ob.stop()
        for ob in observers: ob.join()

if __name__ == "__main__":
    main()