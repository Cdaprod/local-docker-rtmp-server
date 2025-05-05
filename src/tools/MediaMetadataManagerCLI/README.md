# Media Metadata Manager CLI

A command-line tool for interactive metadata management without disturbing underlying media files.

## Features

- **Browse and search** your media collection
- **View detailed metadata** for video, audio, and image files
- **Edit metadata** without modifying the original files themselves
- **Track edit history** for all metadata changes
- **Create backups** before making changes
- **Export metadata** to JSON format

## Installation

### Prerequisites

- Node.js (v14+)
- npm
- ExifTool
- ffmpeg

### Setup

1. Clone this repository:
   ```bash
   git clone https://github.com/yourusername/media-metadata-manager.git
   cd media-metadata-manager
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Link the command for global use:
   ```bash
   npm link
   ```

## Usage

### Scan media directories

```bash
metadata-manager scan /path/to/your/media
```

### Browse your media

```bash
metadata-manager browse
```

Options:
- `-t, --type <type>` - Filter by media type (video, audio, image)
- `-q, --query <query>` - Search query
- `-s, --sort <field>` - Sort by field
- `-r, --reverse` - Reverse sort order
- `-l, --limit <number>` - Limit results

### Interactive mode

```bash
metadata-manager interactive
# or
metadata-manager i
```

Interactive commands:
- `scan <directory>` - Scan directory for media files
- `browse` - Browse all media files
- `search <query>` - Search for media files
- `view <id>` - View metadata for an item by ID
- `edit <id>` - Edit metadata for an item by ID
- `history <id>` - View edit history for an item by ID
- `export <id>` - Export metadata to JSON file
- `config` - View current configuration
- `help` - Show available commands
- `exit` - Exit interactive mode

### View or modify configuration

```bash
metadata-manager config
```

Options:
- `-s, --set <key=value>` - Set configuration value
- `-r, --reset` - Reset configuration to defaults

## Structure

- All metadata is stored in a SQLite database at `src/tools/config/metadata.sqlite`
- Backups are stored in `src/tools/backups/`
- Configuration is stored in `src/tools/config/metadata-config.json`

## Supported Formats

- **Video**: mp4, mkv, avi, mov, wmv, flv, webm, m4v
- **Audio**: mp3, flac, wav, ogg, m4a, wma, aac
- **Image**: jpg, jpeg, png, gif, bmp, tiff

## License

MIT

---
---
---

# TODO and then Graveyard

This completes the Media Metadata Manager CLI tool that allows users to:

1. Scan their media files and extract metadata
2. Browse and search their media collection
3. View detailed metadata for any media file
4. Edit metadata without modifying the original files
5. Track the history of all metadata changes
6. Export metadata to JSON format

The tool keeps a database of all metadata separately from the media files themselves, allowing users to make changes without disturbing the underlying system.​​​​​​​​​​​​​​​​

## Assembly

You raise a good question about how to organize these two files. Let me explain how the VideoAudioDetection.js and MediaMetadataManagerCLI.js would work together in your project structure.

These two files serve complementary purposes:

1. **MediaMetadataManagerCLI.js** - The main command-line interface that handles browsing, viewing, and editing metadata

2. **VideoAudioDetection.js** - A specialized module that would handle the automated content analysis (scene detection, audio transcription, etc.)

## Recommended Directory Structure

I recommend organizing them in the following structure:

```
src/
└── tools/
    ├── MediaMetadataManagerCLI.js       # Main CLI tool
    ├── modules/
    │   └── VideoAudioDetection.js       # Detection module
    ├── config/                          # Configuration files and database
    ├── cache/                           # Temporary cache files 
    ├── analysis/                        # Output from analysis
    ├── models/                          # ML models for content analysis
    └── python_scripts/                  # Python helpers for analysis
```

## Integration Approach

To integrate these files:

1. In your MediaMetadataManagerCLI.js, add the following code to import the detection module:

```javascript
// Near the top of MediaMetadataManagerCLI.js, add:
const videoAudioDetection = require('./modules/VideoAudioDetection');
```

2. Then, create an "analyze" command that uses the detection module:

```javascript
// Add this command to your CLI program
program
  .command('analyze <mediaId>')
  .description('Analyze media content to generate descriptions and transcripts')
  .option('-t, --type <type>', 'Type of analysis (scene, audio, full)', 'full')
  .action(async (mediaId, options) => {
    try {
      // Get media item from database
      const mediaItem = await getMediaItem(mediaId);
      
      if (!mediaItem) {
        console.error(chalk.red(`Media item with ID ${mediaId} not found`));
        return;
      }
      
      console.log(chalk.blue(`Analyzing ${mediaItem.filename}...`));
      
      // Call the appropriate function based on the media type and analysis type
      if (mediaItem.filetype === 'video') {
        if (options.type === 'scene' || options.type === 'full') {
          const sceneAnalysis = await videoAudioDetection.analyzeVideoScene(mediaItem.filepath);
          // Store scene analysis in database
          await updateMediaSceneAnalysis(mediaItem.id, sceneAnalysis);
        }
        
        if (options.type === 'audio' || options.type === 'full') {
          const transcript = await videoAudioDetection.generateTranscript(mediaItem.filepath);
          // Store transcript in database
          await updateMediaTranscript(mediaItem.id, transcript);
        }
      } else if (mediaItem.filetype === 'audio') {
        const transcript = await videoAudioDetection.generateTranscript(mediaItem.filepath);
        // Store transcript in database
        await updateMediaTranscript(mediaItem.id, transcript);
      }
      
      console.log(chalk.green(`Analysis completed for ${mediaItem.filename}`));
    } catch (error) {
      console.error(chalk.red(`Analysis error: ${error.message}`));
    }
  });
```

## Enhancing the Database Schema

You'll need to modify your database schema in MediaMetadataManagerCLI.js to store the analysis results:

```javascript
db.serialize(() => {
  // Media table (add new columns)
  db.run(`CREATE TABLE IF NOT EXISTS media (
    id TEXT PRIMARY KEY,
    filepath TEXT UNIQUE,
    filename TEXT,
    filetype TEXT,
    filesize INTEGER,
    last_modified INTEGER,
    last_scanned INTEGER,
    metadata TEXT,
    scene_analysis TEXT,    /* New column */
    transcript TEXT,        /* New column */
    auto_description TEXT   /* New column */
  )`);
  
  // ... rest of your schema
});
```

This approach maintains a clean separation of concerns while making it easy to integrate the automated content analysis features with your metadata management tool.​​​​​​​​​​​​​​​​