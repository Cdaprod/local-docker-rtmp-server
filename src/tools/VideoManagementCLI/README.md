# Video Manager CLI

A standalone command-line tool for managing large video collections with restore points.

## Features

- **Organize thousands of videos** with collections, tags, and metadata
- **Create restore points** to safely revert changes if needed
- **Auto-detect new videos** in watched folders
- **Extract metadata** like duration, resolution, and codec info
- **Generate thumbnails** for visual reference
- **Interactive mode** for easier navigation

## Installation

### Prerequisites

- Node.js (v14+)
- npm
- ffmpeg

### Install ffmpeg

```bash
# macOS
brew install ffmpeg

# Ubuntu/Debian
sudo apt install ffmpeg

# Windows
# Download from ffmpeg.org and add to PATH
```

### Install Video Manager

```bash
# Clone or download the repo
git clone https://github.com/yourusername/video-manager.git
cd video-manager

# Install dependencies
npm install

# Link globally
npm link
```

## Quick Start

```bash
# Start watching a folder
video-manager watch /path/to/videos

# Create your first restore point
video-manager create-restore "Initial State"

# List your videos
video-manager list

# Start interactive mode
video-manager i
```

## Command Reference

### Video Management

```bash
# Watch a folder for videos
video-manager watch <folder>

# List videos in database
video-manager list
video-manager list --sort duration --limit 20 --tag vacation

# Tag a video
video-manager tag <video-id> "vacation,family,2023"
```

### Restore Points

```bash
# Create a restore point
video-manager create-restore "Before reorganizing" --description "Optional description"

# List restore points
video-manager restore-points

# Restore from a point
video-manager restore <restore-point-id>
```

### Collections

```bash
# Create a collection
video-manager create-collection "Best Videos" --description "My favorites"

# Add video to collection
video-manager add-to-collection <collection-id> <video-id>

# List collections
video-manager collections
```

## Interactive Mode

Start with `video-manager interactive` or `video-manager i`

Commands available in interactive mode:
- `list` - List videos
- `find <search>` - Search videos
- `tag <id> <tags>` - Add tags
- `play <id>` - Play a video
- `info <id>` - Show video details
- `collections` - List collections
- `create-restore <name>` - Create restore point
- `restore-points` - List restore points
- `restore <id>` - Restore from point
- `help` - Show all commands
- `exit` - Exit interactive mode

## Configuration

Configuration and data are stored in `~/.videomanager/`:
- `config.json` - Settings
- `videodb.sqlite` - Database
- `backups/` - Restore points
- `thumbnails/` - Video thumbnails

## Tips

- Create restore points before making significant changes
- Use tags to make videos easier to find
- Collections are great for organizing projects or themes
- Use interactive mode for easier navigation