#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { exec } = require('child_process');
const ffmpeg = require('fluent-ffmpeg');
const chalk = require('chalk');
const commander = require('commander');
const inquirer = require('inquirer');
const sqlite3 = require('sqlite3').verbose();
const mkdirp = require('mkdirp');
const Table = require('cli-table3');
const figlet = require('figlet');
const boxen = require('boxen');
const exiftool = require('node-exiftool');
const exiftoolBin = require('dist-exiftool');
const fuzzy = require('fuzzy');
const MediaInfoFactory = require('mediainfo.js');

// Path configuration
const TOOLS_DIR = path.join(process.cwd(), 'src', 'tools');
const CONFIG_DIR = path.join(TOOLS_DIR, 'config');
const CACHE_DIR = path.join(TOOLS_DIR, 'cache');
const DB_PATH = path.join(CONFIG_DIR, 'metadata.sqlite');
const BACKUP_DIR = path.join(CONFIG_DIR, 'backups');
const CONFIG_FILE = path.join(CONFIG_DIR, 'metadata-config.json');

// Create directories if they don't exist
[CONFIG_DIR, CACHE_DIR, BACKUP_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) {
    mkdirp.sync(dir);
  }
});

// Default configuration
let config = {
  supportedFormats: [
    // Video formats
    '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', 
    // Audio formats
    '.mp3', '.flac', '.wav', '.ogg', '.m4a', '.wma', '.aac',
    // Image formats
    '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff'
  ],
  mediaFolders: [],
  backupBeforeEdits: true,
  maxHistoryItems: 100,
  metadataFieldsToDisplay: {
    video: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'width', 'height', 'codec', 'bitrate'],
    audio: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'bitrate', 'sampleRate'],
    image: ['title', 'artist', 'date', 'comment', 'width', 'height', 'model', 'make', 'exposureTime', 'aperture', 'iso']
  },
  editableFields: {
    video: ['title', 'artist', 'album', 'date', 'genre', 'comment'],
    audio: ['title', 'artist', 'album', 'date', 'genre', 'comment'],
    image: ['title', 'artist', 'date', 'comment']
  }
};

// Load or create config
if (fs.existsSync(CONFIG_FILE)) {
  try {
    config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
  } catch (e) {
    console.error(chalk.red('Error parsing config file, using defaults'));
  }
} else {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

// Initialize database
const db = new sqlite3.Database(DB_PATH);

db.serialize(() => {
  // Media table
  db.run(`CREATE TABLE IF NOT EXISTS media (
    id TEXT PRIMARY KEY,
    filepath TEXT UNIQUE,
    filename TEXT,
    filetype TEXT,
    filesize INTEGER,
    last_modified INTEGER,
    last_scanned INTEGER,
    metadata TEXT
  )`);

  // Edit history table
  db.run(`CREATE TABLE IF NOT EXISTS edit_history (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    media_id TEXT,
    timestamp INTEGER,
    field TEXT,
    old_value TEXT,
    new_value TEXT,
    FOREIGN KEY (media_id) REFERENCES media(id)
  )`);

  // User-defined collections
  db.run(`CREATE TABLE IF NOT EXISTS collections (
    id TEXT PRIMARY KEY,
    name TEXT,
    description TEXT,
    criteria TEXT,
    created_at INTEGER
  )`);

  // Collection items
  db.run(`CREATE TABLE IF NOT EXISTS collection_items (
    collection_id TEXT,
    media_id TEXT,
    added_at INTEGER,
    PRIMARY KEY (collection_id, media_id),
    FOREIGN KEY (collection_id) REFERENCES collections(id),
    FOREIGN KEY (media_id) REFERENCES media(id)
  )`);

  // Create indexes
  db.run("CREATE INDEX IF NOT EXISTS idx_media_filetype ON media(filetype)");
  db.run("CREATE INDEX IF NOT EXISTS idx_media_filename ON media(filename)");
  db.run("CREATE INDEX IF NOT EXISTS idx_history_media_id ON edit_history(media_id)");
});

// Initialize ExifTool
const ep = new exiftool.ExiftoolProcess(exiftoolBin);

// Helper functions
const getFileType = (filepath) => {
  const ext = path.extname(filepath).toLowerCase();
  if (['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'].includes(ext)) return 'video';
  if (['.mp3', '.flac', '.wav', '.ogg', '.m4a', '.wma', '.aac'].includes(ext)) return 'audio';
  if (['.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff'].includes(ext)) return 'image';
  return 'unknown';
};

const generateId = (filepath) => {
  const crypto = require('crypto');
  return crypto.createHash('md5').update(filepath).digest('hex');
};

const formatFileSize = (bytes) => {
  const sizes = ['Bytes', 'KB', 'MB', 'GB', 'TB'];
  if (bytes === 0) return '0 Byte';
  const i = parseInt(Math.floor(Math.log(bytes) / Math.log(1024)));
  return Math.round((bytes / Math.pow(1024, i)) * 100) / 100 + ' ' + sizes[i];
};

const formatDuration = (seconds) => {
  if (!seconds) return '00:00:00';
  seconds = Math.round(seconds);
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  return [h, m, s].map(v => v.toString().padStart(2, '0')).join(':');
};

// Initialize CLI
const program = new commander.Command();

program
  .version('1.0.0')
  .description('Media Metadata Manager CLI - Interactively browse and edit metadata without disrupting the underlying system');

// Scan directories and build metadata database
program
  .command('scan <directory>')
  .description('Scan a directory for media files and extract metadata')
  .option('-r, --recursive', 'Scan directories recursively', true)
  .option('-u, --update', 'Update existing entries', false)
  .action(async (directory, options) => {
    const absPath = path.resolve(directory);
    if (!fs.existsSync(absPath)) {
      console.error(chalk.red(`Directory ${absPath} does not exist`));
      return;
    }

    console.log(chalk.blue(`Scanning ${absPath} for media files...`));
    
    // Add to config if not already there
    if (!config.mediaFolders.includes(absPath)) {
      config.mediaFolders.push(absPath);
      fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
    }

    // Start ExifTool process
    try {
      await ep.open();
      await scanDirectory(absPath, options.recursive, options.update);
      await ep.close();
      console.log(chalk.green('Scan completed successfully!'));
    } catch (error) {
      console.error(chalk.red(`Error during scan: ${error.message}`));
      try {
        await ep.close();
      } catch (e) {
        // Ignore close errors
      }
    }
  });

async function scanDirectory(directory, recursive = true, update = false) {
  const files = fs.readdirSync(directory);
  
  for (const file of files) {
    const filepath = path.join(directory, file);
    const stat = fs.statSync(filepath);
    
    if (stat.isDirectory() && recursive) {
      await scanDirectory(filepath, recursive, update);
    } else if (stat.isFile()) {
      const ext = path.extname(filepath).toLowerCase();
      if (config.supportedFormats.includes(ext)) {
        await processMediaFile(filepath, stat, update);
      }
    }
  }
}

async function processMediaFile(filepath, stat, update = false) {
  const id = generateId(filepath);
  const filename = path.basename(filepath);
  const filetype = getFileType(filepath);
  const filesize = stat.size;
  const last_modified = stat.mtime.getTime();
  
  // Check if file already exists in database
  const existing = await new Promise((resolve) => {
    db.get('SELECT * FROM media WHERE id = ?', [id], (err, row) => {
      resolve(row);
    });
  });
  
  if (existing && !update) {
    console.log(chalk.yellow(`Skipping ${filename} (already in database)`));
    return;
  }
  
  if (existing && update && existing.last_modified >= last_modified) {
    console.log(chalk.yellow(`Skipping ${filename} (no changes detected)`));
    return;
  }
  
  console.log(chalk.blue(`Processing ${filename}...`));
  
  try {
    // Extract metadata using ExifTool
    const metadata = await ep.readMetadata(filepath, ['-j', '-n', '-a', '-G1']);
    
    if (!metadata || !metadata.data || metadata.data.length === 0) {
      console.log(chalk.yellow(`No metadata found for ${filename}`));
      return;
    }
    
    // For specific media types, also get additional metadata
    let extraMetadata = {};
    
    if (filetype === 'video' || filetype === 'audio') {
      // Use ffprobe for more detailed media info
      extraMetadata = await new Promise((resolve, reject) => {
        ffmpeg.ffprobe(filepath, (err, data) => {
          if (err) reject(err);
          else resolve(data);
        });
      });
    }
    
    // Combine metadata
    const combinedMetadata = {
      exiftool: metadata.data[0],
      extra: extraMetadata
    };
    
    // Insert or update database
    const now = Date.now();
    
    if (existing) {
      db.run(`
        UPDATE media 
        SET filepath = ?, filename = ?, filetype = ?, filesize = ?, 
            last_modified = ?, last_scanned = ?, metadata = ?
        WHERE id = ?
      `, [
        filepath, filename, filetype, filesize,
        last_modified, now, JSON.stringify(combinedMetadata), id
      ]);
      console.log(chalk.green(`Updated ${filename} in database`));
    } else {
      db.run(`
        INSERT INTO media 
        (id, filepath, filename, filetype, filesize, last_modified, last_scanned, metadata)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      `, [
        id, filepath, filename, filetype, filesize,
        last_modified, now, JSON.stringify(combinedMetadata)
      ]);
      console.log(chalk.green(`Added ${filename} to database`));
    }
  } catch (error) {
    console.error(chalk.red(`Error processing ${filename}: ${error.message}`));
  }
}

// Browse and search command
program
  .command('browse')
  .description('Browse and search media files')
  .option('-t, --type <type>', 'Filter by media type (video, audio, image)', '')
  .option('-q, --query <query>', 'Search query', '')
  .option('-s, --sort <field>', 'Sort by field', 'filename')
  .option('-r, --reverse', 'Reverse sort order', false)
  .option('-l, --limit <number>', 'Limit results', 50)
  .action(async (options) => {
    await startBrowseMode(options);
  });

async function startBrowseMode(options) {
  console.log(chalk.blue('\nMedia Metadata Browser'));
  console.log(chalk.blue('====================='));
  
  let query = 'SELECT * FROM media';
  const params = [];
  const conditions = [];
  
  if (options.type) {
    conditions.push('filetype = ?');
    params.push(options.type);
  }
  
  if (options.query) {
    conditions.push('(filename LIKE ? OR metadata LIKE ?)');
    params.push(`%${options.query}%`);
    params.push(`%${options.query}%`);
  }
  
  if (conditions.length > 0) {
    query += ' WHERE ' + conditions.join(' AND ');
  }
  
  query += ` ORDER BY ${options.sort} ${options.reverse ? 'DESC' : 'ASC'} LIMIT ?`;
  params.push(parseInt(options.limit));
  
  const results = await new Promise((resolve) => {
    db.all(query, params, (err, rows) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        resolve([]);
      } else {
        resolve(rows);
      }
    });
  });
  
  if (results.length === 0) {
    console.log(chalk.yellow('No media files found matching your criteria'));
    return;
  }
  
  // Display results
  console.log(chalk.green(`Found ${results.length} items:`));
  
  const table = new Table({
    head: ['#', 'Filename', 'Type', 'Size', 'Last Modified'],
    colWidths: [5, 40, 10, 15, 25]
  });
  
  results.forEach((item, index) => {
    table.push([
      index + 1,
      item.filename.length > 38 ? item.filename.substring(0, 35) + '...' : item.filename,
      item.filetype,
      formatFileSize(item.filesize),
      new Date(item.last_modified).toLocaleString()
    ]);
  });
  
  console.log(table.toString());
  
  // Interactive navigation
  await browseInteractive(results);
}

async function browseInteractive(results) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
    prompt: 'metadata> '
  });
  
  console.log(chalk.blue('\nCommands:'));
  console.log('  view <number>       - View metadata for an item');
  console.log('  edit <number>       - Edit metadata for an item');
  console.log('  history <number>    - View edit history for an item');
  console.log('  export <number>     - Export metadata to JSON file');
  console.log('  search <query>      - Search for media files');
  console.log('  filter <type>       - Filter by media type');
  console.log('  help                - Show these commands');
  console.log('  exit                - Exit browser');
  console.log('');
  
  rl.prompt();
  
  rl.on('line', async (line) => {
    const args = line.trim().split(' ');
    const cmd = args.shift().toLowerCase();
    
    if (cmd === 'exit' || cmd === 'quit') {
      rl.close();
      return;
    }
    
    if (cmd === 'help') {
      console.log(chalk.blue('\nCommands:'));
      console.log('  view <number>       - View metadata for an item');
      console.log('  edit <number>       - Edit metadata for an item');
      console.log('  history <number>    - View edit history for an item');
      console.log('  export <number>     - Export metadata to JSON file');
      console.log('  search <query>      - Search for media files');
      console.log('  filter <type>       - Filter by media type');
      console.log('  help                - Show these commands');
      console.log('  exit                - Exit browser');
      console.log('');
    } else if (cmd === 'view' && args.length > 0) {
      const index = parseInt(args[0]) - 1;
      if (index >= 0 && index < results.length) {
        await viewMetadata(results[index]);
      } else {
        console.log(chalk.red('Invalid item number'));
      }
    } else if (cmd === 'edit' && args.length > 0) {
      const index = parseInt(args[0]) - 1;
      if (index >= 0 && index < results.length) {
        await editMetadata(results[index]);
        // Refresh the item data after edit
        results[index] = await new Promise((resolve) => {
          db.get('SELECT * FROM media WHERE id = ?', [results[index].id], (err, row) => {
            resolve(row || results[index]);
          });
        });
      } else {
        console.log(chalk.red('Invalid item number'));
      }
    } else if (cmd === 'history' && args.length > 0) {
      const index = parseInt(args[0]) - 1;
      if (index >= 0 && index < results.length) {
        await viewHistory(results[index]);
      } else {
        console.log(chalk.red('Invalid item number'));
      }
    } else if (cmd === 'export' && args.length > 0) {
      const index = parseInt(args[0]) - 1;
      if (index >= 0 && index < results.length) {
        await exportMetadata(results[index]);
      } else {
        console.log(chalk.red('Invalid item number'));
      }
    } else if (cmd === 'search' && args.length > 0) {
      const query = args.join(' ');
      const options = { query: query, limit: 50 };
      rl.close();
      await startBrowseMode(options);
      return;
    } else if (cmd === 'filter' && args.length > 0) {
      const type = args[0].toLowerCase();
      if (['video', 'audio', 'image'].includes(type)) {
        const options = { type: type, limit: 50 };
        rl.close();
        await startBrowseMode(options);
        return;
      } else {
        console.log(chalk.red('Invalid media type. Use video, audio, or image.'));
      }
    } else {
      console.log(chalk.yellow('Unknown command. Type "help" for available commands.'));
    }
    
    rl.prompt();
  }).on('close', () => {
    console.log(chalk.blue('Exiting browser mode. Goodbye!'));
  });
}

async function viewMetadata(mediaItem) {
  console.log(chalk.blue('\nMetadata for ') + chalk.green(mediaItem.filename));
  console.log(chalk.blue('='.repeat(50)));
  
  console.log(chalk.yellow('File Information:'));
  console.log(`Path: ${mediaItem.filepath}`);
  console.log(`Type: ${mediaItem.filetype}`);
  console.log(`Size: ${formatFileSize(mediaItem.filesize)}`);
  console.log(`Last Modified: ${new Date(mediaItem.last_modified).toLocaleString()}`);
  console.log(`Last Scanned: ${new Date(mediaItem.last_scanned).toLocaleString()}`);
  
  try {
    const metadata = JSON.parse(mediaItem.metadata);
    const fileType = mediaItem.filetype;
    
    console.log(chalk.yellow('\nMetadata Fields:'));
    
    // Display fields based on the file type
    const fieldsToShow = config.metadataFieldsToDisplay[fileType] || [];
    
    // Helper function to extract values from nested metadata
    const extractValue = (obj, key) => {
      if (!obj) return 'N/A';
      
      // Special handling for common fields
      if (key === 'duration' && metadata.extra && metadata.extra.format) {
        return formatDuration(metadata.extra.format.duration);
      }
      
      if (key === 'width' && metadata.extra && metadata.extra.streams) {
        const videoStream = metadata.extra.streams.find(s => s.codec_type === 'video');
        return videoStream ? videoStream.width : 'N/A';
      }
      
      if (key === 'height' && metadata.extra && metadata.extra.streams) {
        const videoStream = metadata.extra.streams.find(s => s.codec_type === 'video');
        return videoStream ? videoStream.height : 'N/A';
      }
      
      if (key === 'codec' && metadata.extra && metadata.extra.streams) {
        const stream = metadata.extra.streams.find(s => s.codec_type === fileType);
        return stream ? stream.codec_name : 'N/A';
      }
      
      if (key === 'bitrate' && metadata.extra && metadata.extra.format) {
        return metadata.extra.format.bit_rate 
          ? `${Math.round(metadata.extra.format.bit_rate / 1000)} kbps` 
          : 'N/A';
      }
      
      if (key === 'sampleRate' && metadata.extra && metadata.extra.streams) {
        const audioStream = metadata.extra.streams.find(s => s.codec_type === 'audio');
        return audioStream ? `${audioStream.sample_rate} Hz` : 'N/A';
      }
      
      // Check in ExifTool data first - iterate through groups
      if (metadata.exiftool) {
        for (const group in metadata.exiftool) {
          if (metadata.exiftool[group] && 
              (metadata.exiftool[group][key] !== undefined || 
               metadata.exiftool[group][key.toLowerCase()] !== undefined ||
               metadata.exiftool[group][key.toUpperCase()] !== undefined)) {
            return metadata.exiftool[group][key] || 
                  metadata.exiftool[group][key.toLowerCase()] || 
                  metadata.exiftool[group][key.toUpperCase()];
          }
        }
      }
      
      return 'N/A';
    };
    
    for (const field of fieldsToShow) {
      const value = extractValue(metadata, field);
      console.log(`${field.charAt(0).toUpperCase() + field.slice(1)}: ${value}`);
    }
    
    console.log(chalk.yellow('\nAll Available Tags:'));
    console.log('(These vary by file format and available metadata)');
    
    // Display all available tags by group
    if (metadata.exiftool) {
      for (const group in metadata.exiftool) {
        if (typeof metadata.exiftool[group] === 'object' && metadata.exiftool[group] !== null) {
          console.log(chalk.cyan(`\n${group}:`));
          for (const tag in metadata.exiftool[group]) {
            if (tag !== 'SourceFile' && tag !== 'Directory' && tag !== 'ExifToolVersion') {
              let value = metadata.exiftool[group][tag];
              // Truncate long values
              if (typeof value === 'string' && value.length > 60) {
                value = value.substring(0, 57) + '...';
              }
              console.log(`  ${tag}: ${value}`);
            }
          }
        }
      }
    }
    
  } catch (error) {
    console.error(chalk.red(`Error parsing metadata: ${error.message}`));
  }
}

async function editMetadata(mediaItem) {
  console.log(chalk.blue('\nEdit Metadata for ') + chalk.green(mediaItem.filename));
  console.log(chalk.blue('='.repeat(50)));
  
  try {
    const metadata = JSON.parse(mediaItem.metadata);
    const fileType = mediaItem.filetype;
    const editableFields = config.editableFields[fileType] || [];
    
    if (editableFields.length === 0) {
      console.log(chalk.yellow('No editable fields configured for this file type.'));
      return;
    }
    
    // Extract current values
    const currentValues = {};
    for (const field of editableFields) {
      // Get from ExifTool data first
      let value = null;
      if (metadata.exiftool) {
        for (const group in metadata.exiftool) {
          if (metadata.exiftool[group] && 
             (metadata.exiftool[group][field] !== undefined || 
              metadata.exiftool[group][field.toLowerCase()] !== undefined ||
              metadata.exiftool[group][field.toUpperCase()] !== undefined)) {
            value = metadata.exiftool[group][field] || 
                   metadata.exiftool[group][field.toLowerCase()] || 
                   metadata.exiftool[group][field.toUpperCase()];
            break;
          }
        }
      }
      currentValues[field] = value || '';
    }
    
    // Create prompts for each field
    const questions = editableFields.map(field => ({
      type: 'input',
      name: field,
      message: `${field.charAt(0).toUpperCase() + field.slice(1)}:`,
      default: String(currentValues[field] || '')
    }));
    
    // Ask user for new values
    const answers = await inquirer.prompt(questions);
    
    // Check if any values changed
    let changed = false;
    for (const field of editableFields) {
      if (String(answers[field]) !== String(currentValues[field])) {
        changed = true;
        break;
      }
    }
    
    if (!changed) {
      console.log(chalk.yellow('No changes were made.'));
      return;
    }
    
    // Confirm changes
    const confirmResult = await inquirer.prompt([{
      type: 'confirm',
      name: 'confirm',
      message: 'Apply these changes to the metadata?',
      default: false
    }]);
    
    if (!confirmResult.confirm) {
      console.log(chalk.yellow('Changes canceled.'));
      return;
    }
    
    // Create backup if configured
    if (config.backupBeforeEdits) {
      await createBackup(mediaItem);
    }
    
    // Start ExifTool process if not running
    let startedExiftool = false;
    if (!ep.isOpen) {
      await ep.open();
      startedExiftool = true;
    }
    
    try {
      // Prepare ExifTool arguments
      const exiftoolArgs = [];
      const historyEntries = [];
      
      for (const field of editableFields) {
        if (String(answers[field]) !== String(currentValues[field])) {
          // Find which group contained this field
          let tagGroup = null;
          if (metadata.exiftool) {
            for (const group in metadata.exiftool) {
              if (metadata.exiftool[group] && 
                 (metadata.exiftool[group][field] !== undefined || 
                  metadata.exiftool[group][field.toLowerCase()] !== undefined ||
                  metadata.exiftool[group][field.toUpperCase()] !== undefined)) {
                tagGroup = group;
                break;
              }
            }
          }
          
          // Format the tag for ExifTool
          let tagName = field;
          if (tagGroup) {
            // Use the exact case that was found
            for (const tag in metadata.exiftool[tagGroup]) {
              if (tag.toLowerCase() === field.toLowerCase()) {
                tagName = tag;
                break;
              }
            }
            
            // Add group prefix if we have one
            if (tagGroup !== 'File' && tagGroup !== 'System') {
              tagName = `${tagGroup}:${tagName}`;
            }
          }
          
          exiftoolArgs.push(`-${tagName}=${answers[field]}`);
          
          // Track history entry
          historyEntries.push({
            field: field,
            old_value: String(currentValues[field] || ''),
            new_value: String(answers[field])
          });
        }
      }
      
      if (exiftoolArgs.length > 0) {
        // Apply changes using ExifTool
        const result = await ep.writeMetadata(
          mediaItem.filepath, 
          exiftoolArgs, 
          ['overwrite_original']
        );
        
        if (result.error) {
          throw new Error(result.error);
        }
        
        // Update database
        const now = Date.now();
        
        // Record history entries
        for (const entry of historyEntries) {
          db.run(`
            INSERT INTO edit_history (media_id, timestamp, field, old_value, new_value)
            VALUES (?, ?, ?, ?, ?)
          `, [
            mediaItem.id, now, entry.field, entry.old_value, entry.new_value
          ]);
        }
        
        // Rescan the file to update the database
        const stat = fs.statSync(mediaItem.filepath);
        await processMediaFile(mediaItem.filepath, stat, true);
        
        console.log(chalk.green('Metadata updated successfully!'));
      }
    } finally {
      // Close ExifTool if we started it
      if (startedExiftool) {
        await ep.close();
      }
    }
    
  } catch (error) {
    console.error(chalk.red(`Error editing metadata: ${error.message}`));
  }
}

async function createBackup(mediaItem) {
  try {
    const backupDir = path.join(BACKUP_DIR, mediaItem.id);
    if (!fs.existsSync(backupDir)) {
      mkdirp.sync(backupDir);
    }
    
    const timestamp = new Date().toISOString().replace(/:/g, '-');
    const backupPath = path.join(backupDir, `${timestamp}.json`);
    
    fs.writeFileSync(backupPath, JSON.stringify({
      id: mediaItem.id,
      filepath: mediaItem.filepath,
      filename: mediaItem.filename,
      metadata: JSON.parse(mediaItem.metadata),
      timestamp: Date.now()
    }, null, 2));
    
    console.log(chalk.blue(`Created backup at ${backupPath}`));
    return backupPath;
  } catch (error) {
    console.error(chalk.red(`Error creating backup: ${error.message}`));
    return null;
  }
}

async function viewHistory(mediaItem) {
  console.log(async function viewHistory(mediaItem) {
  console.log(chalk.blue('\nEdit History for ') + chalk.green(mediaItem.filename));
  console.log(chalk.blue('='.repeat(50)));
  
  // Query the database for history entries
  const history = await new Promise((resolve) => {
    db.all(`
      SELECT * FROM edit_history 
      WHERE media_id = ? 
      ORDER BY timestamp DESC
      LIMIT 100
    `, [mediaItem.id], (err, rows) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        resolve([]);
      } else {
        resolve(rows);
      }
    });
  });
  
  if (history.length === 0) {
    console.log(chalk.yellow('No edit history found for this item.'));
    return;
  }
  
  // Display history entries
  console.log(chalk.green(`Found ${history.length} edit(s):`));
  
  history.forEach((entry, index) => {
    console.log(chalk.cyan(`\n[${new Date(entry.timestamp).toLocaleString()}]`));
    console.log(`Field: ${entry.field}`);
    console.log(`Old value: ${entry.old_value || '(empty)'}`);
    console.log(`New value: ${entry.new_value || '(empty)'}`);
  });
}

// Export metadata to a JSON file
async function exportMetadata(mediaItem) {
  try {
    const metadata = JSON.parse(mediaItem.metadata);
    
    // Create a friendly filename
    const safeFilename = mediaItem.filename.replace(/[^\w\s.-]/g, '_');
    const exportPath = path.join(process.cwd(), `${safeFilename}_metadata.json`);
    
    // Format the export data
    const exportData = {
      filename: mediaItem.filename,
      filepath: mediaItem.filepath,
      filetype: mediaItem.filetype,
      filesize: mediaItem.filesize,
      last_modified: mediaItem.last_modified,
      metadata: metadata
    };
    
    // Write to file
    fs.writeFileSync(exportPath, JSON.stringify(exportData, null, 2));
    
    console.log(chalk.green(`Exported metadata to ${exportPath}`));
  } catch (error) {
    console.error(chalk.red(`Error exporting metadata: ${error.message}`));
  }
}

// Interactive mode command
program
  .command('interactive')
  .alias('i')
  .description('Start interactive mode')
  .action(async () => {
    console.log(chalk.blue(figlet.textSync('Metadata Manager', { font: 'Standard' })));
    console.log(chalk.blue('Interactive Mode - Type "help" for available commands'));
    
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      prompt: 'metadata> '
    });
    
    rl.prompt();
    
    rl.on('line', async (line) => {
      const args = line.trim().split(' ');
      const cmd = args.shift().toLowerCase();
      
      if (cmd === 'exit' || cmd === 'quit') {
        rl.close();
        return;
      }
      
      if (cmd === 'help') {
        console.log(chalk.blue('\nAvailable commands:'));
        console.log('  scan <directory>      - Scan directory for media files');
        console.log('  browse                - Browse media files');
        console.log('  search <query>        - Search for media files');
        console.log('  view <id>             - View metadata for an item by ID');
        console.log('  edit <id>             - Edit metadata for an item by ID');
        console.log('  history <id>          - View edit history for an item by ID');
        console.log('  export <id>           - Export metadata to JSON file');
        console.log('  config                - View current configuration');
        console.log('  help                  - Show these commands');
        console.log('  exit                  - Exit interactive mode');
        console.log('');
      } else if (cmd === 'scan' && args.length > 0) {
        const dir = args.join(' ');
        await program.parseAsync(['node', 'metadata-manager', 'scan', dir]);
      } else if (cmd === 'browse') {
        const options = {};
        await startBrowseMode(options);
      } else if (cmd === 'search' && args.length > 0) {
        const query = args.join(' ');
        const options = { query: query };
        await startBrowseMode(options);
      } else if (cmd === 'view' && args.length > 0) {
        const mediaId = args[0];
        const mediaItem = await getMediaItem(mediaId);
        if (mediaItem) {
          await viewMetadata(mediaItem);
        } else {
          console.log(chalk.red(`Media item with ID ${mediaId} not found`));
        }
      } else if (cmd === 'edit' && args.length > 0) {
        const mediaId = args[0];
        const mediaItem = await getMediaItem(mediaId);
        if (mediaItem) {
          await editMetadata(mediaItem);
        } else {
          console.log(chalk.red(`Media item with ID ${mediaId} not found`));
        }
      } else if (cmd === 'history' && args.length > 0) {
        const mediaId = args[0];
        const mediaItem = await getMediaItem(mediaId);
        if (mediaItem) {
          await viewHistory(mediaItem);
        } else {
          console.log(chalk.red(`Media item with ID ${mediaId} not found`));
        }
      } else if (cmd === 'export' && args.length > 0) {
        const mediaId = args[0];
        const mediaItem = await getMediaItem(mediaId);
        if (mediaItem) {
          await exportMetadata(mediaItem);
        } else {
          console.log(chalk.red(`Media item with ID ${mediaId} not found`));
        }
      } else if (cmd === 'config') {
        console.log(chalk.blue('\nCurrent Configuration:'));
        console.log(JSON.stringify(config, null, 2));
      } else {
        console.log(chalk.yellow('Unknown command. Type "help" for available commands.'));
      }
      
      rl.prompt();
    }).on('close', () => {
      console.log(chalk.blue('Exiting interactive mode. Goodbye!'));
      process.exit(0);
    });
  });

// Helper function to get a media item by ID
async function getMediaItem(mediaId) {
  return new Promise((resolve) => {
    db.get('SELECT * FROM media WHERE id = ?', [mediaId], (err, row) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        resolve(null);
      } else {
        resolve(row);
      }
    });
  });
}

// Configuration command
program
  .command('config')
  .description('View or modify configuration')
  .option('-s, --set <key=value>', 'Set configuration value')
  .option('-r, --reset', 'Reset configuration to defaults')
  .action((options) => {
    if (options.reset) {
      // Reset configuration to defaults
      config = {
        supportedFormats: [
          // Video formats
          '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v', 
          // Audio formats
          '.mp3', '.flac', '.wav', '.ogg', '.m4a', '.wma', '.aac',
          // Image formats
          '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff'
        ],
        mediaFolders: [],
        backupBeforeEdits: true,
        maxHistoryItems: 100,
        metadataFieldsToDisplay: {
          video: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'width', 'height', 'codec', 'bitrate'],
          audio: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'bitrate', 'sampleRate'],
          image: ['title', 'artist', 'date', 'comment', 'width', 'height', 'model', 'make', 'exposureTime', 'aperture', 'iso']
        },
        editableFields: {
          video: ['title', 'artist', 'album', 'date', 'genre', 'comment'],
          audio: ['title', 'artist', 'album', 'date', 'genre', 'comment'],
          image: ['title', 'artist', 'date', 'comment']
        }
      };
      fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
      console.log(chalk.green('Configuration reset to defaults.'));
    } else if (options.set) {
      // Set a specific configuration value
      const [key, value] = options.set.split('=');
      if (!key || value === undefined) {
        console.error(chalk.red('Invalid format. Use --set key=value'));
        return;
      }
      
      // Handle nested keys with dot notation
      const keys = key.split('.');
      let target = config;
      
      for (let i = 0; i < keys.length - 1; i++) {
        if (typeof target[keys[i]] !== 'object') {
          target[keys[i]] = {};
        }
        target = target[keys[i]];
      }
      
      // Convert value to appropriate type
      let typedValue = value;
      if (value === 'true') typedValue = true;
      else if (value === 'false') typedValue = false;
      else if (!isNaN(value)) typedValue = Number(value);
      
      // Set the value
      target[keys[keys.length - 1]] = typedValue;
      
      fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
      console.log(chalk.green(`Configuration updated: ${key} = ${typedValue}`));
    } else {
      // Display current configuration
      console.log(chalk.blue('\nCurrent Configuration:'));
      console.log(JSON.stringify(config, null, 2));
    }
  });

// Parse command line arguments
program.parse(process.argv);

// If no command is provided, start interactive mode
if (process.argv.length <= 2) {
  program.parseAsync(['node', 'metadata-manager', 'interactive']);
}

// Handle process exit
process.on('exit', () => {
  // Close database connection
  if (db) {
    db.close();
  }
  
  // Close ExifTool process if running
  if (ep && ep.isOpen) {
    ep.close();
  }
});

// Handle CTRL+C
process.on('SIGINT', () => {
  console.log(chalk.blue('\nGracefully shutting down...'));
  
  // Close database connection
  if (db) {
    db.close();
  }
  
  // Close ExifTool process if running
  if (ep && ep.isOpen) {
    ep.close();
  }
  
  process.exit(0);
});