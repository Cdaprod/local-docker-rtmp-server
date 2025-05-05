#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const readline = require('readline');
const { exec } = require('child_process');
const ffmpeg = require('fluent-ffmpeg');
const chalk = require('chalk');
const commander = require('commander');
const inquirer = require('inquirer');
const sqlite3 = require('sqlite3').verbose();
const mkdirp = require('mkdirp');
const chokidar = require('chokidar');

// Configuration Constants
const CONFIG_DIR = path.join(process.env.HOME || process.env.USERPROFILE, '.videomanager');
const DB_PATH = path.join(CONFIG_DIR, 'videodb.sqlite');
const BACKUP_DIR = path.join(CONFIG_DIR, 'backups');
const THUMBS_DIR = path.join(CONFIG_DIR, 'thumbnails');
const CONFIG_FILE = path.join(CONFIG_DIR, 'config.json');

// Ensure directory structure exists
mkdirp.sync(CONFIG_DIR);
mkdirp.sync(BACKUP_DIR);
mkdirp.sync(THUMBS_DIR);

// Default configuration
let config = {
  watchFolders: [],
  thumbnailQuality: 'medium',
  backupFrequency: 'daily',
  maxBackups: 10,
  metadataFields: ['title', 'description', 'tags', 'rating'],
  defaultView: 'list'
};

// Load or create config
if (fs.existsSync(CONFIG_FILE)) {
  try {
    config = JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
  } catch (e) {
    console.error('Error parsing config file, using defaults');
  }
} else {
  fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

// Initialize database
const db = new sqlite3.Database(DB_PATH);

db.serialize(() => {
  // Videos table
  db.run(`CREATE TABLE IF NOT EXISTS videos (
    id TEXT PRIMARY KEY,
    filename TEXT,
    filepath TEXT,
    filesize INTEGER,
    duration INTEGER,
    width INTEGER,
    height INTEGER,
    codec TEXT,
    created_date INTEGER,
    modified_date INTEGER,
    thumbnail_path TEXT,
    title TEXT,
    description TEXT,
    tags TEXT,
    rating INTEGER,
    views INTEGER DEFAULT 0,
    last_viewed INTEGER
  )`);

  // Collections table
  db.run(`CREATE TABLE IF NOT EXISTS collections (
    id TEXT PRIMARY KEY,
    name TEXT,
    description TEXT,
    created_date INTEGER
  )`);

  // Collection_videos join table
  db.run(`CREATE TABLE IF NOT EXISTS collection_videos (
    collection_id TEXT,
    video_id TEXT,
    added_date INTEGER,
    PRIMARY KEY (collection_id, video_id),
    FOREIGN KEY (collection_id) REFERENCES collections(id),
    FOREIGN KEY (video_id) REFERENCES videos(id)
  )`);

  // Restore points table
  db.run(`CREATE TABLE IF NOT EXISTS restore_points (
    id TEXT PRIMARY KEY,
    name TEXT,
    description TEXT,
    created_date INTEGER,
    db_backup_path TEXT
  )`);

  // Create indexes
  db.run("CREATE INDEX IF NOT EXISTS idx_videos_tags ON videos(tags)");
  db.run("CREATE INDEX IF NOT EXISTS idx_videos_title ON videos(title)");
});

// CLI setup
const program = new commander.Command();

program
  .version('1.0.0')
  .description('Video Manager CLI - Manage large collections of videos with restore points');

// Add a folder to watch
program
  .command('watch <folder>')
  .description('Add a folder to watch for video files')
  .action((folder) => {
    const absPath = path.resolve(folder);
    if (!fs.existsSync(absPath)) {
      console.error(chalk.red(`Folder ${absPath} does not exist`));
      return;
    }
    
    if (!config.watchFolders.includes(absPath)) {
      config.watchFolders.push(absPath);
      fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
      console.log(chalk.green(`Now watching ${absPath} for video files`));
      
      // Scan folder for initial import
      console.log(chalk.yellow('Scanning folder for videos...'));
      scanFolder(absPath);
    } else {
      console.log(chalk.yellow(`Already watching ${absPath}`));
    }
  });

// Scan a folder for videos
function scanFolder(folderPath) {
  const videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'];
  
  function walk(dir) {
    const files = fs.readdirSync(dir);
    
    files.forEach(file => {
      const filePath = path.join(dir, file);
      const stat = fs.statSync(filePath);
      
      if (stat.isDirectory()) {
        walk(filePath);
      } else if (videoExtensions.includes(path.extname(file).toLowerCase())) {
        // Check if video already exists in DB
        const fileId = crypto.createHash('md5').update(filePath).digest('hex');
        
        db.get('SELECT id FROM videos WHERE id = ?', [fileId], (err, row) => {
          if (err) {
            console.error(chalk.red(`Database error: ${err.message}`));
            return;
          }
          
          if (!row) {
            // New video, add to database
            importVideo(filePath);
          }
        });
      }
    });
  }
  
  walk(folderPath);
}

// Import a video file
function importVideo(filePath) {
  console.log(chalk.blue(`Importing: ${filePath}`));
  
  const fileId = crypto.createHash('md5').update(filePath).digest('hex');
  const fileName = path.basename(filePath);
  const stat = fs.statSync(filePath);
  const thumbnailPath = path.join(THUMBS_DIR, `${fileId}.jpg`);
  
  // Extract video metadata with ffmpeg
  ffmpeg.ffprobe(filePath, (err, metadata) => {
    if (err) {
      console.error(chalk.red(`Error analyzing ${filePath}: ${err.message}`));
      return;
    }
    
    const videoStream = metadata.streams.find(stream => stream.codec_type === 'video');
    if (!videoStream) {
      console.error(chalk.red(`No video stream found in ${filePath}`));
      return;
    }
    
    // Generate thumbnail
    ffmpeg(filePath)
      .screenshots({
        count: 1,
        folder: THUMBS_DIR,
        filename: `${fileId}.jpg`,
        size: '320x?'
      })
      .on('end', () => {
        console.log(chalk.green(`Generated thumbnail for ${fileName}`));
        
        // Insert video into database
        db.run(`
          INSERT INTO videos (
            id, filename, filepath, filesize, duration, width, height, codec,
            created_date, modified_date, thumbnail_path, title
          ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        `, [
          fileId,
          fileName,
          filePath,
          stat.size,
          metadata.format.duration || 0,
          videoStream.width || 0,
          videoStream.height || 0,
          videoStream.codec_name || 'unknown',
          stat.birthtime.getTime(),
          stat.mtime.getTime(),
          thumbnailPath,
          fileName // Default title is filename
        ], (err) => {
          if (err) {
            console.error(chalk.red(`Database error adding ${fileName}: ${err.message}`));
          } else {
            console.log(chalk.green(`Added ${fileName} to database`));
          }
        });
      })
      .on('error', (err) => {
        console.error(chalk.red(`Error generating thumbnail: ${err.message}`));
      });
  });
}

// List videos command
program
  .command('list')
  .description('List all videos in the database')
  .option('-s, --sort <field>', 'Sort by field (filename, size, duration, etc)', 'filename')
  .option('-l, --limit <number>', 'Limit results', 50)
  .option('-t, --tag <tag>', 'Filter by tag')
  .action((options) => {
    let query = 'SELECT id, filename, filepath, filesize, duration, rating, tags FROM videos';
    const params = [];
    
    if (options.tag) {
      query += ' WHERE tags LIKE ?';
      params.push(`%${options.tag}%`);
    }
    
    query += ` ORDER BY ${options.sort} LIMIT ?`;
    params.push(parseInt(options.limit));
    
    db.all(query, params, (err, rows) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        return;
      }
      
      if (rows.length === 0) {
        console.log(chalk.yellow('No videos found matching your criteria'));
        return;
      }
      
      console.log(chalk.blue('\nVideos in database:'));
      console.log(chalk.blue('======================================='));
      
      rows.forEach((row, index) => {
        const size = (row.filesize / (1024 * 1024)).toFixed(2) + ' MB';
        const duration = formatDuration(row.duration);
        const rating = '★'.repeat(row.rating || 0);
        const tags = row.tags ? row.tags.split(',').join(', ') : '';
        
        console.log(chalk.green(`${index + 1}. ${row.filename}`));
        console.log(`   Size: ${size} | Duration: ${duration} | Rating: ${rating}`);
        if (tags) console.log(`   Tags: ${tags}`);
        console.log(`   Path: ${row.filepath}`);
        console.log('');
      });
    });
  });

// Format duration in seconds to HH:MM:SS
function formatDuration(seconds) {
  if (!seconds) return '00:00:00';
  seconds = Math.floor(seconds);
  const h = Math.floor(seconds / 3600);
  const m = Math.floor((seconds % 3600) / 60);
  const s = Math.floor(seconds % 60);
  return [h, m, s].map(v => v.toString().padStart(2, '0')).join(':');
}

// Create restore point command
program
  .command('create-restore <name>')
  .description('Create a restore point')
  .option('-d, --description <text>', 'Description of the restore point')
  .action((name, options) => {
    const id = crypto.randomUUID();
    const timestamp = Date.now();
    const backupPath = path.join(BACKUP_DIR, `${id}.sqlite`);
    
    // Copy current database
    fs.copyFile(DB_PATH, backupPath, (err) => {
      if (err) {
        console.error(chalk.red(`Error creating backup: ${err.message}`));
        return;
      }
      
      // Add restore point to database
      db.run(`
        INSERT INTO restore_points (id, name, description, created_date, db_backup_path)
        VALUES (?, ?, ?, ?, ?)
      `, [
        id,
        name,
        options.description || '',
        timestamp,
        backupPath
      ], (err) => {
        if (err) {
          console.error(chalk.red(`Database error: ${err.message}`));
          return;
        }
        
        console.log(chalk.green(`Restore point "${name}" created successfully`));
        
        // Clean up old backups if over limit
        cleanupOldBackups();
      });
    });
  });

// List restore points
program
  .command('restore-points')
  .description('List all restore points')
  .action(() => {
    db.all(`
      SELECT id, name, description, created_date
      FROM restore_points
      ORDER BY created_date DESC
    `, [], (err, rows) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        return;
      }
      
      if (rows.length === 0) {
        console.log(chalk.yellow('No restore points found'));
        return;
      }
      
      console.log(chalk.blue('\nRestore Points:'));
      console.log(chalk.blue('======================================='));
      
      rows.forEach((row, index) => {
        const date = new Date(row.created_date).toLocaleString();
        console.log(chalk.green(`${index + 1}. ${row.name} (${date})`));
        if (row.description) {
          console.log(`   ${row.description}`);
        }
        console.log(`   ID: ${row.id}`);
        console.log('');
      });
    });
  });

// Restore from restore point
program
  .command('restore <id>')
  .description('Restore database from a restore point')
  .option('-f, --force', 'Force restore without confirmation')
  .action((id, options) => {
    // Find restore point
    db.get('SELECT * FROM restore_points WHERE id = ?', [id], (err, row) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        return;
      }
      
      if (!row) {
        console.error(chalk.red(`Restore point with ID ${id} not found`));
        return;
      }
      
      const confirmRestore = () => {
        // Close current database connection
        db.close();
        
        // Create backup of current state before restoring
        const emergencyBackupPath = path.join(BACKUP_DIR, `emergency_backup_${Date.now()}.sqlite`);
        fs.copyFileSync(DB_PATH, emergencyBackupPath);
        console.log(chalk.yellow(`Emergency backup created at ${emergencyBackupPath}`));
        
        // Restore from backup
        fs.copyFileSync(row.db_backup_path, DB_PATH);
        
        console.log(chalk.green(`Successfully restored to "${row.name}"`));
        console.log(chalk.green('Please restart the application for changes to take effect'));
        process.exit(0);
      };
      
      if (options.force) {
        confirmRestore();
      } else {
        inquirer.prompt([{
          type: 'confirm',
          name: 'confirm',
          message: `Are you sure you want to restore to "${row.name}"? This cannot be undone!`,
          default: false
        }]).then(answers => {
          if (answers.confirm) {
            confirmRestore();
          } else {
            console.log(chalk.yellow('Restore cancelled'));
          }
        });
      }
    });
  });

// Clean up old backups
function cleanupOldBackups() {
  if (!config.maxBackups) return;
  
  db.all(`
    SELECT id, db_backup_path FROM restore_points
    ORDER BY created_date DESC
    LIMIT -1 OFFSET ?
  `, [config.maxBackups], (err, rows) => {
    if (err || !rows || rows.length === 0) return;
    
    rows.forEach(row => {
      // Delete backup file
      if (fs.existsSync(row.db_backup_path)) {
        fs.unlinkSync(row.db_backup_path);
      }
      
      // Delete restore point from database
      db.run('DELETE FROM restore_points WHERE id = ?', [row.id]);
    });
    
    console.log(chalk.yellow(`Cleaned up ${rows.length} old backup(s)`));
  });
}

// Tag management
program
  .command('tag <videoId> <tags>')
  .description('Add tags to a video (comma separated)')
  .action((videoId, tagsStr) => {
    const tags = tagsStr.split(',').map(tag => tag.trim()).filter(Boolean);
    
    db.get('SELECT tags FROM videos WHERE id = ?', [videoId], (err, row) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        return;
      }
      
      if (!row) {
        console.error(chalk.red(`Video with ID ${videoId} not found`));
        return;
      }
      
      // Merge existing tags with new ones
      const existingTags = row.tags ? row.tags.split(',') : [];
      const allTags = [...new Set([...existingTags, ...tags])].join(',');
      
      db.run('UPDATE videos SET tags = ? WHERE id = ?', [allTags, videoId], (err) => {
        if (err) {
          console.error(chalk.red(`Error updating tags: ${err.message}`));
          return;
        }
        
        console.log(chalk.green(`Tags updated for video: ${allTags}`));
      });
    });
  });

// Collection management
program
  .command('create-collection <name>')
  .description('Create a new collection')
  .option('-d, --description <text>', 'Description of the collection')
  .action((name, options) => {
    const id = crypto.randomUUID();
    const timestamp = Date.now();
    
    db.run(`
      INSERT INTO collections (id, name, description, created_date)
      VALUES (?, ?, ?, ?)
    `, [
      id,
      name,
      options.description || '',
      timestamp
    ], (err) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        return;
      }
      
      console.log(chalk.green(`Collection "${name}" created with ID: ${id}`));
    });
  });

// Add video to collection
program
  .command('add-to-collection <collectionId> <videoId>')
  .description('Add a video to a collection')
  .action((collectionId, videoId) => {
    const timestamp = Date.now();
    
    db.run(`
      INSERT INTO collection_videos (collection_id, video_id, added_date)
      VALUES (?, ?, ?)
    `, [
      collectionId,
      videoId,
      timestamp
    ], (err) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        return;
      }
      
      console.log(chalk.green(`Video added to collection successfully`));
    });
  });

// List collections
program
  .command('collections')
  .description('List all collections')
  .action(() => {
    db.all(`
      SELECT c.id, c.name, c.description, c.created_date, COUNT(cv.video_id) as video_count
      FROM collections c
      LEFT JOIN collection_videos cv ON c.id = cv.collection_id
      GROUP BY c.id
      ORDER BY c.name
    `, [], (err, rows) => {
      if (err) {
        console.error(chalk.red(`Database error: ${err.message}`));
        return;
      }
      
      if (rows.length === 0) {
        console.log(chalk.yellow('No collections found'));
        return;
      }
      
      console.log(chalk.blue('\nCollections:'));
      console.log(chalk.blue('======================================='));
      
      rows.forEach((row, index) => {
        const date = new Date(row.created_date).toLocaleString();
        console.log(chalk.green(`${index + 1}. ${row.name} (${row.video_count} videos)`));
        if (row.description) {
          console.log(`   ${row.description}`);
        }
        console.log(`   ID: ${row.id} | Created: ${date}`);
        console.log('');
      });
    });
  });

// Interactive mode
program
  .command('interactive')
  .alias('i')
  .description('Start interactive mode')
  .action(() => {
    console.log(chalk.blue('\nVideo Manager CLI - Interactive Mode'));
    console.log(chalk.blue('======================================='));
    console.log('Type "help" for available commands, "exit" to quit\n');
    
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      prompt: 'video-manager> '
    });
    
    rl.prompt();
    
    rl.on('line', (line) => {
      const args = line.trim().split(' ');
      const cmd = args.shift();
      
      if (cmd === 'exit' || cmd === 'quit') {
        rl.close();
        return;
      }
      
      if (cmd === 'help') {
        console.log(chalk.blue('\nAvailable commands:'));
        console.log('  list                    - List videos');
        console.log('  find <search>           - Search for videos');
        console.log('  tag <id> <tags>         - Add tags to a video');
        console.log('  play <id>               - Play a video');
        console.log('  info <id>               - Show detailed info about a video');
        console.log('  collections             - List collections');
        console.log('  create-restore <name>   - Create a restore point');
        console.log('  restore-points          - List restore points');
        console.log('  restore <id>            - Restore from a restore point');
        console.log('  exit                    - Exit interactive mode');
        console.log('');
      } else if (cmd === 'list') {
        // Simplified list for interactive mode
        db.all(`
          SELECT id, filename, filesize, duration
          FROM videos
          ORDER BY filename
          LIMIT 20
        `, [], (err, rows) => {
          if (err) {
            console.error(chalk.red(`Database error: ${err.message}`));
          } else if (rows.length === 0) {
            console.log(chalk.yellow('No videos found'));
          } else {
            rows.forEach((row, index) => {
              const size = (row.filesize / (1024 * 1024)).toFixed(2) + ' MB';
              const duration = formatDuration(row.duration);
              console.log(`${index + 1}. ${chalk.green(row.filename)} (${size}, ${duration}) ID: ${row.id.substring(0, 8)}...`);
            });
          }
          console.log('');
        });
      } else if (cmd === 'find' && args.length > 0) {
        const search = args.join(' ');
        db.all(`
          SELECT id, filename, filepath
          FROM videos
          WHERE filename LIKE ? OR tags LIKE ?
          ORDER BY filename
          LIMIT 20
        `, [`%${search}%`, `%${search}%`], (err, rows) => {
          if (err) {
            console.error(chalk.red(`Database error: ${err.message}`));
          } else if (rows.length === 0) {
            console.log(chalk.yellow(`No videos found matching "${search}"`));
          } else {
            console.log(chalk.blue(`\nSearch results for "${search}":`));
            rows.forEach((row, index) => {
              console.log(`${index + 1}. ${chalk.green(row.filename)} [ID: ${row.id.substring(0, 8)}...]`);
              console.log(`   ${row.filepath}`);
            });
          }
          console.log('');
        });
      } else if (cmd === 'play' && args.length > 0) {
        const videoId = args[0];
        db.get('SELECT filepath FROM videos WHERE id = ?', [videoId], (err, row) => {
          if (err) {
            console.error(chalk.red(`Database error: ${err.message}`));
          } else if (!row) {
            console.error(chalk.red(`Video with ID ${videoId} not found`));
          } else {
            // Try to detect OS and use appropriate video player
            let command;
            if (process.platform === 'win32') {
              command = `start "${row.filepath}"`;
            } else if (process.platform === 'darwin') {
              command = `open "${row.filepath}"`;
            } else {
              command = `xdg-open "${row.filepath}"`;
            }
            
            exec(command, (err) => {
              if (err) {
                console.error(chalk.red(`Error opening video: ${err.message}`));
              } else {
                console.log(chalk.green(`Playing: ${row.filepath}`));
                
                // Update view count
                db.run('UPDATE videos SET views = views + 1, last_viewed = ? WHERE id = ?', 
                  [Date.now(), videoId]);
              }
            });
          }
        });
      } else if (cmd === 'info' && args.length > 0) {
        const videoId = args[0];
        db.get('SELECT * FROM videos WHERE id = ?', [videoId], (err, row) => {
          if (err) {
            console.error(chalk.red(`Database error: ${err.message}`));
          } else if (!row) {
            console.error(chalk.red(`Video with ID ${videoId} not found`));
          } else {
            console.log(chalk.blue('\nVideo Details:'));
            console.log(chalk.blue('======================================='));
            console.log(chalk.green(`Title: ${row.title || row.filename}`));
            console.log(`File: ${row.filepath}`);
            console.log(`Size: ${(row.filesize / (1024 * 1024)).toFixed(2)} MB`);
            console.log(`Duration: ${formatDuration(row.duration)}`);
            console.log(`Resolution: ${row.width}x${row.height}`);
            console.log(`Codec: ${row.codec}`);
            if (row.tags) console.log(`Tags: ${row.tags}`);
            console.log(`Rating: ${'★'.repeat(row.rating || 0)}`);
            console.log(`Views: ${row.views || 0}`);
            if (row.last_viewed) {
              console.log(`Last viewed: ${new Date(row.last_viewed).toLocaleString()}`);
            }
            console.log(`Created: ${new Date(row.created_date).toLocaleString()}`);
            console.log(`Modified: ${new Date(row.modified_date).toLocaleString()}`);
            if (row.description) {
              console.log(`\nDescription:\n${row.description}`);
            }
            console.log('');
          }
        });
      } else {
        // Pass to the main program parser
        program.parse(['node', 'video-manager', ...line.trim().split(' ')], { from: 'user' });
      }
      
      rl.prompt();
    }).on('close', () => {
      console.log(chalk.blue('Goodbye!'));
      process.exit(0);
    });
  });

// Start file watcher if there are folders to watch
if (config.watchFolders && config.watchFolders.length > 0) {
  const watcher = chokidar.watch(config.watchFolders, {
    persistent: true,
    ignoreInitial: true
  });
  
  watcher
    .on('add', path => {
      const videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'];
      if (videoExtensions.includes(path.extname(path).toLowerCase())) {
        console.log(chalk.blue(`New video detected: ${path}`));
        importVideo(path);
      }
    })
    .on('unlink', path => {
      const videoExtensions = ['.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v'];
      if (videoExtensions.includes(path.extname(path).toLowerCase())) {
        const fileId = crypto.createHash('md5').update(path).digest('hex');
        db.run('DELETE FROM videos WHERE id = ?', [fileId], (err) => {
          if (err) {
            console.error(chalk.red(`Error removing deleted video from database: ${err.message}`));
          } else {
            console.log(chalk.yellow(`Removed deleted video from database: ${path}`));
          }
        });
      }
    });
}

// Parse command line arguments
program.parse(process.argv);

// If no command is provided, show help
if (process.argv.length <= 2) {
  program.help();
}

// Process cleanup
process.on('exit', () => {
  if (db) {
    db.close();
  }
});

process.on('SIGINT', () => {
  console.log(chalk.blue('\nGracefully shutting down...'));
  if (db) {
    db.close();
  }
  process.exit(0);
});