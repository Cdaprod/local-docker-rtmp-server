Here’s a detailed and polished README.md for ../scripts/websockets/README.md:

⸻

🎥 OBS WebSocket Scene Management Scripts

This directory contains Python and Bash scripts for managing OBS scenes, sources, overlays, and assets using the OBS WebSocket API. These scripts enable automated scene switching, overlay management, source reloading, and scene backups.

⸻

📂 Directory Structure

/scripts/websockets/
├── manage-scenes.py         # Main script to automate scene switching and management
├── add-iphone-frame.py      # Adds a frame around the iPhone source dynamically
├── switch-scene.py          # Switch between OBS scenes
├── create-scene.py          # Create new OBS scenes programmatically
├── update-overlay.py        # Hot reload updated overlays or browser sources
└── backup-scenes.sh         # Backup OBS scene configurations to GitHub



⸻

⚡️ Getting Started

✅ Pre-requisites:
	1.	Enable OBS WebSocket:
	•	Open OBS and navigate to:

Tools > WebSocket Server Settings


	•	Check Enable WebSocket Server.
	•	Set the port to 4455 (or your preferred port).
	•	Set a strong password to secure WebSocket connections.
	•	Restart OBS to apply the changes.

	2.	Install Required Packages:

sudo apt update && sudo apt install -y python3 python3-pip
pip3 install websocket-client


	3.	Clone OBS Asset Repository:

git clone https://github.com/Cdaprod/obs-assets.git /config/obs-assets



⸻

🚀 Available Scripts

🎬 manage-scenes.py
	•	Purpose: Master script to automate OBS scene switching, source addition, and overlay management.
	•	Usage:

python3 /path/to/scripts/websockets/manage-scenes.py



⸻

🕹️ add-iphone-frame.py
	•	Purpose: Adds a border frame around the iPhone source using WebSocket.
	•	Usage:

python3 /path/to/scripts/websockets/add-iphone-frame.py



⸻

🔄 switch-scene.py
	•	Purpose: Switch between OBS scenes dynamically.
	•	Usage:

python3 /path/to/scripts/websockets/switch-scene.py



⸻

🎥 create-scene.py
	•	Purpose: Create new OBS scenes dynamically and add sources if needed.
	•	Usage:

python3 /path/to/scripts/websockets/create-scene.py



⸻

♻️ update-overlay.py
	•	Purpose: Hot reload or replace an overlay (browser sources or images).
	•	Usage:

python3 /path/to/scripts/websockets/update-overlay.py



⸻

💾 backup-scenes.sh
	•	Purpose: Back up current OBS scene configurations and push them to Cdaprod/obs-assets.git.
	•	Usage:

bash /path/to/scripts/websockets/backup-scenes.sh



⸻

📅 Automating Scripts with Cron Jobs

To automate asset syncing, scene switching, and backups, use cron to run these scripts on a schedule.

🔥 Add Cron Jobs:

Edit your crontab:

crontab -e

Add the following lines to automate scene and asset management:

# Sync assets every 5 mins and reload scenes if changed
*/5 * * * * /usr/bin/python3 /path/to/scripts/websockets/manage-scenes.py

# Backup scenes every 12 hours
0 */12 * * * /path/to/scripts/websockets/backup-scenes.sh



⸻

🎯 Cron Job Breakdown:

1. Asset Sync and Scene Management (Every 5 Mins)

*/5 * * * * /usr/bin/python3 /path/to/scripts/websockets/manage-scenes.py

	•	Syncs the latest assets from Cdaprod/obs-assets.git.
	•	Switches between scenes dynamically based on your configuration.
	•	Automatically reloads sources and overlays if changes are detected.

⸻

2. Scene Backup to GitHub (Every 12 Hours)

0 */12 * * * /path/to/scripts/websockets/backup-scenes.sh

	•	Backs up current OBS scene configurations.
	•	Pushes backups to Cdaprod/obs-assets.git for version control and disaster recovery.

⸻

🔥 Example Workflow
	1.	Initial Setup:

cd /path/to/scripts/websockets/
python3 manage-scenes.py

	2.	Test Scene Switching:

python3 switch-scene.py

	3.	Add iPhone Frame Automatically:

python3 add-iphone-frame.py

	4.	Backup Scenes Manually:

bash backup-scenes.sh



⸻

🕹️ Optional: Hotkey Integration
	•	Configure OBS hotkeys to trigger specific scripts.
	•	If using a Stream Deck, map WebSocket commands to the buttons.

⸻

🧠 Troubleshooting
	•	WebSocket Not Connecting: Check if the OBS WebSocket port (4455) is open.
	•	Authentication Failed: Ensure the password in the Python scripts matches the one configured in OBS.
	•	Scene Not Switching: Verify the scene names in the script match the ones in OBS exactly.

⸻

📚 References:
	•	OBS WebSocket Documentation
	•	OBS Studio Documentation

⸻

📝 Author

David Cannan
GitHub: Cdaprod
Blog: Sanity.Cdaprod.dev

⸻

⚡️ License

MIT License. Feel free to use and modify these scripts to suit your OBS automation needs!

⸻

Let me know if you need help configuring the cron jobs or fine-tuning any of the scripts! 🎥🚀

---

# Addition of extract-obs-components.py

This version of extract-obs-components.py is a highly optimized and flexible solution that fits perfectly into your OBS WebSocket and containerized Pi OBS setup. It handles backing up critical OBS components such as:
	•	🎥 Scenes – Ensuring scene versions are backed up with timestamps.
	•	🖼️ Overlay Assets – PNG and JPG assets used in your scenes.
	•	📝 Crash Logs – Useful for debugging OBS-related errors.
	•	🧩 Plugins – Backing up all installed OBS plugins.

⸻

📂 Recommended Directory Structure

To fit this script into your existing pi-obs-container environment:

/pi-obs-container/
├── config
│   ├── basic
│   │   ├── scenes
│   │   └── plugins
│   └── logs
├── scripts
│   ├── websockets
│   │   ├── manage-scenes.py
│   │   ├── switch-scene.py
│   │   ├── backup-scenes.sh
│   │   ├── update-overlay.py
│   │   └── extract-obs-components.py  # <-- This script
├── backups
│   └── Scenes
│   └── Overlays
│   └── CrashLogs
│   └── Plugins
└── docker-compose.obs.yaml



⸻

🎯 Goal:
	•	Automate regular backups of key OBS components.
	•	Store the backups with timestamps for versioning and disaster recovery.
	•	Enable seamless integration with WebSocket scene management.

⸻

📝 Full Script: extract-obs-components.py

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



⸻

🚀 Usage and Automation

⸻

✅ Manual Execution

To run the script manually:

# Run the script to extract components
python3 /path/to/scripts/websockets/extract-obs-components.py /config/basic /path/to/backups

Example:

python3 /pi-obs-container/scripts/websockets/extract-obs-components.py /config/basic /pi-obs-container/backups



⸻

📅 Automating with Cron

Set up a cron job to run this backup script at regular intervals:

crontab -e

Add the following line:

# Backup OBS components every 6 hours
0 */6 * * * /usr/bin/python3 /pi-obs-container/scripts/websockets/extract-obs-components.py /config/basic /pi-obs-container/backups



⸻

♻️ Retention Policy: Automatically Remove Old Backups

To prevent excessive backup storage, add this cron job to clean up backups older than 7 days:

# Clean backups older than 7 days every night at 2 AM
0 2 * * * find /pi-obs-container/backups/ -type d -mtime +7 -exec rm -rf {} \;



⸻

🧠 Advanced Concepts You Can Add

⸻

📦 1. Add Compression for Backups

To compress the extracted backup directories, modify the extractComponent() function to add a zip step:

shutil.make_archive(join(outputDir, component, timestamp), 'zip', componentDir)
shutil.rmtree(componentDir)  # Clean up after compression



⸻

🔀 2. Sync Backups to Remote Storage (e.g., MinIO or S3)

Use rclone or aws s3 sync to push backups to cloud storage:

# Sync to MinIO or S3 after each backup
rclone sync /pi-obs-container/backups minio:/obs-backups/



⸻

🕹️ 3. WebSocket Hook to Trigger Backups

If you want to trigger a backup after specific WebSocket commands (e.g., after changing a scene):
	•	Modify your WebSocket scripts (manage-scenes.py) to include:

os.system("/usr/bin/python3 /path/to/extract-obs-components.py /config/basic /pi-obs-container/backups")



⸻

🔥 Example Workflow

1. Initial Setup:

# Clone OBS asset repo
git clone https://github.com/Cdaprod/obs-assets.git /config/obs-assets

# Create backup directory
mkdir -p /pi-obs-container/backups

2. Run Backup Manually:

python3 /pi-obs-container/scripts/websockets/extract-obs-components.py /config/basic /pi-obs-container/backups

3. Verify Backup:

Check the backups in /pi-obs-container/backups:

ls /pi-obs-container/backups/Scenes/



⸻

🎯 Final Workflow Summary

✅ Scene and Asset Backup: Automatically extract and archive OBS components.
✅ Versioned Timestamps: Scene, overlay, and crash logs are backed up with timestamps.
✅ Cron Automation: Backup runs every 6 hours, with retention policy for cleanup.
✅ Compression and Sync Options: Can be expanded with cloud sync or zip archives.

Let me know if you’re ready to test and fine-tune this, or if you’d like to extend it further! 🎥🚀