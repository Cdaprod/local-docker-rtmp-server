#!/usr/bin/env python3
import glob
import os
import shutil
import sys
from os.path import basename, dirname, exists, join

# Logs a message to stderr
def log(message):
    print(message, file=sys.stderr)
    sys.stderr.flush()


# Extract and move specified components to an output directory
def extract_component(input_dir, output_dir, component, description, items):
    log(f"\nExtracting {description}...")

    # Create component directory if not exists
    component_dir = join(output_dir, component)
    os.makedirs(component_dir, exist_ok=True)

    for item in items:
        # Verify the item exists
        if not exists(item):
            log(f"Skipping non-existent item: {item}")
            continue

        log(f"Moving: {item}")
        parent = dirname(item).replace(input_dir, component_dir)
        os.makedirs(parent, exist_ok=True)
        shutil.move(item, join(parent, basename(item)))


# Retrieve path to OBS configuration root
root_dir = sys.argv[1]  # /config/basic/
output_dir = sys.argv[2]  # /obs-assets/

os.makedirs(output_dir, exist_ok=True)

# Extract scene collections (JSON files)
scene_files = glob.glob(join(root_dir, "scenes", "*.json"))
extract_component(root_dir, output_dir, "scenes", "OBS Scene Collections", scene_files)

# Extract profiles and service configurations
profile_dir = join(root_dir, "profiles", "CdaprodOBS")
profile_files = glob.glob(join(profile_dir, "*.ini")) + glob.glob(
    join(profile_dir, "*.json")
)
extract_component(
    root_dir, output_dir, "profiles", "OBS Profiles and Services", profile_files
)

# Extract overlays and media assets
media_files = glob.glob(join(root_dir, "assets", "**"), recursive=True)
extract_component(root_dir, output_dir, "assets", "Media and Overlays", media_files)

# Extract global OBS configuration files
global_files = [join(root_dir, "global.ini"), join(root_dir, "user.ini")]
extract_component(root_dir, output_dir, "config", "Global OBS Configuration", global_files)

log("\nOBS extraction completed successfully!")