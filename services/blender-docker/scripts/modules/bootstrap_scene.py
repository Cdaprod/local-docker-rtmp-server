from modules.world_setup import setup_world_background
from modules.terminal_plane import create_terminal_feed_plane
from modules.camera_setup import setup_camera
from modules.lighting import setup_basic_lighting

# === Setup Scene ===
setup_world_background(color=(0.02, 0.02, 0.02, 1), strength=0.75)
create_terminal_feed_plane("/absolute/path/to/your/image.png", location=(0, 0, 0))
setup_camera()
setup_basic_lighting()