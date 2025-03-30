#!/usr/bin/env python3
import glob, os, shutil, sys
from os.path import basename, dirname, exists, join
from datetime import datetime

# Logs messages to stderr
def log(message):
    print(message, file=sys.stderr)
    sys.stderr.flush()

# Extract and move files for a component
def extractComponent(inputDir, outputDir, component, description, items):
    log(f"\nExtracting {description}...")

    # Create the output component directory with a timestamp
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    componentDir = join(outputDir, component, timestamp)
    os.makedirs(componentDir, exist_ok=True)

    # Move files to the component output directory
    for item in items:
        if not exists(item):
            log(f"Skipping non-existent item: {item}")
            continue

        log(f"Moving: {item}")

        # Ensure parent directory exists in output
        parent = dirname(item).replace(inputDir, componentDir)
        os.makedirs(parent, exist_ok=True)

        # Move file or directory
        shutil.move(item, join(parent, basename(item)))

# Input and Output Paths
inputDir = sys.argv[1]  # Typically your OBS config dir: /config/basic/
outputDir = sys.argv[2]  # Where the backups will go: /path/to/backups/

# Scene Backup
scenes = glob.glob(join(inputDir, "scenes", "*.json"))
extractComponent(inputDir, outputDir, "Scenes", "OBS Scenes", scenes)

# Overlay Backup
overlays = glob.glob(join(inputDir, "scenes", "assets", "*.png")) + glob.glob(
    join(inputDir, "scenes", "assets", "*.jpg")
)
extractComponent(inputDir, outputDir, "Overlays", "Overlay Images", overlays)

# Crash Log Backup
crashLogs = glob.glob(join(inputDir, "logs", "crashes", "*.log"))
extractComponent(inputDir, outputDir, "CrashLogs", "Crash Reports", crashLogs)

# Plugin Backup
plugins = glob.glob(join(inputDir, "plugins", "*"))
extractComponent(inputDir, outputDir, "Plugins", "OBS Plugins", plugins)

log("Extraction completed successfully.")