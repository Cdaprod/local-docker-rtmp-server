I'll create the code for a Media Metadata Manager CLI that automatically analyzes video/audio content and generates descriptive metadata. Here's the implementation in code blocks:

First, let's set up the basic structure and dependencies:

```javascript
#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readline = require('readline');
const { exec, spawn } = require('child_process');
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
const axios = require('axios');
const cliProgress = require('cli-progress');
const tempy = require('tempy');
const speechToText = require('@google-cloud/speech');
const vision = require('@google-cloud/vision');
const tensorflowNode = require('@tensorflow/tfjs-node');
const { spawn: pythonSpawn } = require('child_process');
```

Next, let's set up the directory structure:

```javascript
// Path configuration
const TOOLS_DIR = path.join(process.cwd(), 'src', 'tools');
const CONFIG_DIR = path.join(TOOLS_DIR, 'config');
const CACHE_DIR = path.join(TOOLS_DIR, 'cache');
const ANALYSIS_DIR = path.join(TOOLS_DIR, 'analysis');
const MODELS_DIR = path.join(TOOLS_DIR, 'models');
const TEMP_DIR = path.join(TOOLS_DIR, 'temp');
const DB_PATH = path.join(CONFIG_DIR, 'metadata.sqlite');
const BACKUP_DIR = path.join(CONFIG_DIR, 'backups');
const CONFIG_FILE = path.join(CONFIG_DIR, 'metadata-config.json');
const PYTHON_SCRIPTS_DIR = path.join(TOOLS_DIR, 'python_scripts');

// Create directories if they don't exist
[CONFIG_DIR, CACHE_DIR, BACKUP_DIR, ANALYSIS_DIR, MODELS_DIR, TEMP_DIR, PYTHON_SCRIPTS_DIR].forEach(dir => {
  if (!fs.existsSync(dir)) {
    mkdirp.sync(dir);
  }
});
```

Now let's set up the configuration:

```javascript
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
    video: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'width', 'height', 'codec', 'bitrate', 'auto_description', 'scene_analysis', 'transcript'],
    audio: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'bitrate', 'sampleRate', 'auto_description', 'transcript'],
    image: ['title', 'artist', 'date', 'comment', 'width', 'height', 'model', 'make', 'exposureTime', 'aperture', 'iso', 'auto_description', 'scene_analysis']
  },
  editableFields: {
    video: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'auto_description'],
    audio: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'auto_description'],
    image: ['title', 'artist', 'date', 'comment', 'auto_description']
  },
  analysisConfig: {
    enabled: true,
    videoFrameSampleRate: 1, // Sample 1 frame per second
    maxFramesToAnalyze: 100,  // Maximum frames to analyze per video
    audioTranscription: true,
    sceneDetection: true,
    objectDetection: true,
    autoCategorization: true,
    autoTagging: true,
    thumbnailGeneration: true,
    apiKeys: {
      openai: process.env.OPENAI_API_KEY || '',
      googleCloud: process.env.GOOGLE_APPLICATION_CREDENTIALS || '',
      aws: {
        accessKeyId: process.env.AWS_ACCESS_KEY_ID || '',
        secretAccessKey: process.env.AWS_SECRET_ACCESS_KEY || ''
      }
    },
    useLocalModels: true,
    modelPaths: {
      objectDetection: path.join(MODELS_DIR, 'object_detection'),
      sceneRecognition: path.join(MODELS_DIR, 'scene_recognition'),
      audioModel: path.join(MODELS_DIR, 'audio_recognition')
    }
  }
};
```

Here's the database schema:

```javascript
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
    metadata TEXT,
    analysis_metadata TEXT,
    analysis_date INTEGER,
    auto_description TEXT,
    transcript TEXT,
    scene_analysis TEXT,
    tags TEXT
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
  
  // Extracted frames for video analysis
  db.run(`CREATE TABLE IF NOT EXISTS video_frames (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    media_id TEXT,
    frame_number INTEGER,
    timestamp REAL,
    filepath TEXT,
    analysis TEXT,
    FOREIGN KEY (media_id) REFERENCES media(id)
  )`);
  
  // Audio segments for transcription
  db.run(`CREATE TABLE IF NOT EXISTS audio_segments (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    media_id TEXT,
    start_time REAL,
    end_time REAL,
    transcript TEXT,
    confidence REAL,
    FOREIGN KEY (media_id) REFERENCES media(id)
  )`);
  
  // Analysis tasks queue and status
  db.run(`CREATE TABLE IF NOT EXISTS analysis_tasks (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    media_id TEXT,
    task_type TEXT,
    status TEXT,
    created_at INTEGER,
    started_at INTEGER,
    completed_at INTEGER,
    error TEXT,
    progress REAL,
    FOREIGN KEY (media_id) REFERENCES media(id)
  )`);

  // Create indexes
  db.run("CREATE INDEX IF NOT EXISTS idx_media_filetype ON media(filetype)");
  db.run("CREATE INDEX IF NOT EXISTS idx_media_filename ON media(filename)");
  db.run("CREATE INDEX IF NOT EXISTS idx_history_media_id ON edit_history(media_id)");
  db.run("CREATE INDEX IF NOT EXISTS idx_media_tags ON media(tags)");
  db.run("CREATE INDEX IF NOT EXISTS idx_video_frames_media_id ON video_frames(media_id)");
  db.run("CREATE INDEX IF NOT EXISTS idx_audio_segments_media_id ON audio_segments(media_id)");
  db.run("CREATE INDEX IF NOT EXISTS idx_analysis_tasks_media_id ON analysis_tasks(media_id)");
  db.run("CREATE INDEX IF NOT EXISTS idx_analysis_tasks_status ON analysis_tasks(status)");
});
```

Now let's implement the core function to extract frames from videos for analysis:

```javascript
// Extract frames from video for analysis
async function extractVideoFrames(mediaItem, options = {}) {
  const videoId = mediaItem.id;
  const videoPath = mediaItem.filepath;
  const outputDir = path.join(ANALYSIS_DIR, videoId, 'frames');
  
  // Create output directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    mkdirp.sync(outputDir);
  }
  
  // Get video duration
  const videoDuration = await new Promise((resolve, reject) => {
    ffmpeg.ffprobe(videoPath, (err, metadata) => {
      if (err) reject(err);
      else resolve(metadata.format.duration || 0);
    });
  });
  
  // Calculate frame extraction options
  const frameRate = options.frameRate || config.analysisConfig.videoFrameSampleRate;
  const maxFrames = options.maxFrames || config.analysisConfig.maxFramesToAnalyze;
  
  // If video is very long, adjust the frame rate to stay within maxFrames
  const estimatedFrames = videoDuration * frameRate;
  const adjustedFrameRate = estimatedFrames > maxFrames ? maxFrames / videoDuration : frameRate;
  
  // Create progress bar
  const progressBar = new cliProgress.SingleBar({
    format: 'Extracting frames |{bar}| {percentage}% | {value}/{total} frames',
    barCompleteChar: '\u2588',
    barIncompleteChar: '\u2591',
  }, cliProgress.Presets.shades_classic);
  
  console.log(chalk.blue(`Extracting frames from ${path.basename(videoPath)}...`));
  progressBar.start(Math.min(Math.ceil(videoDuration * adjustedFrameRate), maxFrames), 0);
  
  // Extract frames using ffmpeg
  return new Promise((resolve, reject) => {
    let frameCount = 0;
    const frames = [];
    
    ffmpeg(videoPath)
      .outputOptions([
        `-vf fps=${adjustedFrameRate}`,
        '-q:v 2'  // High quality JPEG
      ])
      .output(path.join(outputDir, 'frame-%04d.jpg'))
      .on('end', () => {
        progressBar.stop();
        console.log(chalk.green(`Extracted ${frameCount} frames from video`));
        resolve(frames);
      })
      .on('progress', (progress) => {
        if (progress.frames) {
          const newFrames = progress.frames - frameCount;
          if (newFrames > 0) {
            frameCount = progress.frames;
            progressBar.update(Math.min(frameCount, maxFrames));
          }
        }
      })
      .on('error', (err) => {
        progressBar.stop();
        console.error(chalk.red(`Error extracting frames: ${err.message}`));
        reject(err);
      })
      .run();
  });
}
```

Let's implement the video scene analysis functionality:

```javascript
// Analyze video frames to detect scenes, objects, and generate descriptions
async function analyzeVideoFrames(mediaItem) {
  const videoId = mediaItem.id;
  const framesDir = path.join(ANALYSIS_DIR, videoId, 'frames');
  
  if (!fs.existsSync(framesDir)) {
    console.error(chalk.red(`No frames found for video ${mediaItem.filename}. Run frame extraction first.`));
    return null;
  }
  
  const frameFiles = fs.readdirSync(framesDir)
    .filter(file => file.endsWith('.jpg'))
    .sort((a, b) => {
      // Sort numerically by frame number
      const numA = parseInt(a.match(/frame-(\d+)/)[1]);
      const numB = parseInt(b.match(/frame-(\d+)/)[1]);
      return numA - numB;
    });
  
  if (frameFiles.length === 0) {
    console.error(chalk.red(`No frame images found in ${framesDir}`));
    return null;
  }
  
  console.log(chalk.blue(`Analyzing ${frameFiles.length} frames from ${mediaItem.filename}...`));
  
  // Create progress bar
  const progressBar = new cliProgress.SingleBar({
    format: 'Analyzing frames |{bar}| {percentage}% | {value}/{total} frames',
    barCompleteChar: '\u2588',
    barIncompleteChar: '\u2591',
  }, cliProgress.Presets.shades_classic);
  
  progressBar.start(frameFiles.length, 0);
  
  // Determine which analysis method to use
  let analysisResults;
  
  if (config.analysisConfig.useLocalModels) {
    // Use local TensorFlow models for analysis
    analysisResults = await analyzeFramesWithTensorflow(frameFiles, framesDir, progressBar);
  } else if (config.analysisConfig.apiKeys.googleCloud) {
    // Use Google Cloud Vision for analysis
    analysisResults = await analyzeFramesWithGoogleVision(frameFiles, framesDir, progressBar);
  } else {
    // Use lightweight built-in analysis
    analysisResults = await analyzeFramesWithBuiltInTools(frameFiles, framesDir, progressBar);
  }
  
  progressBar.stop();
  
  // Process analysis results to identify scenes
  const scenes = detectScenes(analysisResults);
  
  // Generate overall description from scenes
  const description = generateVideoDescription(scenes, mediaItem);
  
  // Save analysis results to database
  await saveVideoAnalysis(mediaItem, analysisResults, scenes, description);
  
  return {
    scenes,
    description,
    frameResults: analysisResults
  };
}

// Scene detection from frame analysis
function detectScenes(frameAnalysis) {
  const scenes = [];
  let currentScene = {
    startFrame: 0,
    endFrame: 0,
    startTime: 0,
    endTime: 0,
    dominant_objects: {},
    colors: [],
    summary: ''
  };
  
  // Scene detection threshold - how different should frames be to be considered a different scene
  const SCENE_THRESHOLD = 0.4;
  
  for (let i = 1; i < frameAnalysis.length; i++) {
    const prevFrame = frameAnalysis[i-1];
    const currentFrame = frameAnalysis[i];
    
    // Calculate similarity between consecutive frames
    const similarity = calculateFrameSimilarity(prevFrame, currentFrame);
    
    // If frames are significantly different, mark a scene boundary
    if (similarity < SCENE_THRESHOLD) {
      // Finish current scene
      currentScene.endFrame = i - 1;
      currentScene.endTime = prevFrame.timestamp;
      
      // Summarize the scene
      currentScene.summary = summarizeScene(frameAnalysis.slice(currentScene.startFrame, currentScene.endFrame + 1));
      
      // Add to scenes array
      scenes.push({...currentScene});
      
      // Start new scene
      currentScene = {
        startFrame: i,
        endFrame: i,
        startTime: currentFrame.timestamp,
        endTime: currentFrame.timestamp,
        dominant_objects: {},
        colors: [],
        summary: ''
      };
    }
    
    // Update current scene's end position
    currentScene.endFrame = i;
    currentScene.endTime = currentFrame.timestamp;
    
    // Update scene objects and colors
    updateSceneStats(currentScene, currentFrame);
  }
  
  // Add the final scene if not empty
  if (currentScene.endFrame > currentScene.startFrame) {
    currentScene.summary = summarizeScene(frameAnalysis.slice(currentScene.startFrame, currentScene.endFrame + 1));
    scenes.push(currentScene);
  }
  
  return scenes;
}

// Calculate similarity between two frames based on their analysis
function calculateFrameSimilarity(frame1, frame2) {
  // This is a simplified similarity metric
  // In a real implementation, you'd use a more sophisticated approach
  
  // Compare detected objects
  const objects1 = new Set(frame1.objects.map(o => o.name));
  const objects2 = new Set(frame2.objects.map(o => o.name));
  
  // Intersection of objects
  const intersection = new Set([...objects1].filter(x => objects2.has(x)));
  
  // Jaccard similarity for objects
  const objectSimilarity = 
    intersection.size / (objects1.size + objects2.size - intersection.size);
  
  // You could also compare color histograms, scene type, etc.
  // and combine these into an overall similarity score
  
  return objectSimilarity;
}

// Update scene statistics with information from a new frame
function updateSceneStats(scene, frame) {
  // Update object counts
  frame.objects.forEach(obj => {
    if (!scene.dominant_objects[obj.name]) {
      scene.dominant_objects[obj.name] = 0;
    }
    scene.dominant_objects[obj.name] += obj.confidence;
  });
  
  // Add dominant colors if not already present
  frame.colors.forEach(color => {
    if (!scene.colors.some(c => c.hex === color.hex)) {
      scene.colors.push(color);
    }
  });
}

// Create a summary for a scene based on all its frames
function summarizeScene(sceneFrames) {
  // Count all objects across frames
  const objectCounts = {};
  sceneFrames.forEach(frame => {
    frame.objects.forEach(obj => {
      if (!objectCounts[obj.name]) {
        objectCounts[obj.name] = 0;
      }
      objectCounts[obj.name] += 1;
    });
  });
  
  // Sort objects by frequency
  const sortedObjects = Object.entries(objectCounts)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(entry => entry[0]);
  
  // Get scene type from most frequent frames
  const sceneTypes = sceneFrames
    .map(frame => frame.scene_type)
    .reduce((count, type) => {
      count[type] = (count[type] || 0) + 1;
      return count;
    }, {});
  
  const dominantSceneType = Object.entries(sceneTypes)
    .sort((a, b) => b[1] - a[1])[0][0];
  
  // Generate a human-readable summary
  return `${dominantSceneType} scene featuring ${sortedObjects.join(', ')}`;
}

// Generate an overall video description from scene analysis
function generateVideoDescription(scenes, mediaItem) {
  // Count unique objects across all scenes
  const allObjects = {};
  scenes.forEach(scene => {
    Object.entries(scene.dominant_objects).forEach(([obj, score]) => {
      if (!allObjects[obj]) {
        allObjects[obj] = 0;
      }
      allObjects[obj] += score;
    });
  });
  
  // Get top objects
  const topObjects = Object.entries(allObjects)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 10)
    .map(entry => entry[0]);
  
  // Count scene types
  const sceneTypes = scenes.map(s => s.summary.split(' ')[0])
    .reduce((count, type) => {
      count[type] = (count[type] || 0) + 1;
      return count;
    }, {});
  
  const dominantSceneTypes = Object.entries(sceneTypes)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 3)
    .map(entry => entry[0]);
  
  // Format the duration
  const duration = mediaItem.metadata ? 
    JSON.parse(mediaItem.metadata).extra?.format?.duration || 0 : 0;
  const formattedDuration = formatDuration(duration);
  
  // Generate description
  return `${formattedDuration} video primarily showing ${dominantSceneTypes.join(', ')} scenes. ` +
    `Main elements include ${topObjects.slice(0, 5).join(', ')}. ` +
    `The video contains ${scenes.length} distinct scenes.`;
}
```

Now let's implement the audio transcription functionality:

```javascript
// Process audio to generate transcription
async function generateAudioTranscript(mediaItem) {
  const mediaId = mediaItem.id;
  const filePath = mediaItem.filepath;
  const outputDir = path.join(ANALYSIS_DIR, mediaId, 'audio');
  
  // Create output directory if it doesn't exist
  if (!fs.existsSync(outputDir)) {
    mkdirp.sync(outputDir);
  }
  
  console.log(chalk.blue(`Generating transcript for ${path.basename(filePath)}...`));
  
  // Extract audio from media file (works for both video and audio files)
  const audioPath = path.join(outputDir, 'audio.wav');
  
  await new Promise((resolve, reject) => {
    ffmpeg(filePath)
      .output(audioPath)
      .audioFrequency(16000)  // 16kHz for better speech recognition
      .audioChannels(1)       // Mono
      .audioCodec('pcm_s16le') // PCM format
      .on('end', () => {
        console.log(chalk.green(`Extracted audio to ${audioPath}`));
        resolve();
      })
      .on('error', (err) => {
        console.error(chalk.red(`Error extracting audio: ${err.message}`));
        reject(err);
      })
      .run();
  });
  
  let transcript = '';
  
  // Determine which transcription method to use
  if (config.analysisConfig.apiKeys.googleCloud) {
    // Use Google Cloud Speech-to-Text
    transcript = await transcribeWithGoogleSpeech(audioPath);
  } else if (config.analysisConfig.useLocalModels) {
    // Use local model for transcription
    transcript = await transcribeWithLocalModel(audioPath);
  } else {
    console.log(chalk.yellow('No transcription service configured. Skipping transcript generation.'));
    return null;
  }
  
  // Save transcript to database
  await saveTranscript(mediaItem, transcript);
  
  return transcript;
}

// Transcribe audio using Google Cloud Speech-to-Text
async function transcribeWithGoogleSpeech(audioPath) {
  // Initialize Google Cloud Speech client
  const speechClient = new speechToText.SpeechClient();
  
  // Read audio file content
  const audioContent = fs.readFileSync(audioPath).toString('base64');
  
  console.log(chalk.blue('Transcribing with Google Cloud Speech-to-Text...'));
  
  // Configure request
  const request = {
    audio: {
      content: audioContent,
    },
    config: {
      encoding: 'LINEAR16',
      sampleRateHertz: 16000,
      languageCode: 'en-US',
      enableWordTimeOffsets: true,
      enableAutomaticPunctuation: true,
    },
  };
  
  try {
    // Perform transcription
    const [response] = await speechClient.recognize(request);
    
    // Combine all transcriptions
    const transcription = response.results
      .map(result => result.alternatives[0].transcript)
      .join('\n');
    
    console.log(chalk.green('Transcription completed successfully'));
    
    return transcription;
  } catch (error) {
    console.error(chalk.red(`Transcription error: ${error.message}`));
    return null;
  }
}

// Transcribe audio using local models
async function transcribeWithLocalModel(audioPath) {
  // This would use a locally downloaded model
  // For simplicity, this is a placeholder - in a real implementation,
  // you would use something like Mozilla DeepSpeech or Whisper
  
  console.log(chalk.blue('Transcribing with local model...'));
  
  // The model path from configuration
  const modelPath = config.analysisConfig.modelPaths.audioModel;
  
  // Call a Python script that uses the local model
  return new Promise((resolve, reject) => {
    const pythonProcess = pythonSpawn('python', [
      path.join(PYTHON_SCRIPTS_DIR, 'transcribe.py'),
      '--audio', audioPath,
      '--model', modelPath,
      '--output', path.join(path.dirname(audioPath), 'transcript.txt')
    ]);
    
    let outputData = '';
    let errorData = '';
    
    pythonProcess.stdout.on('data', (data) => {
      outputData += data.toString();
    });
    
    pythonProcess.stderr.on('data', (data) => {
      errorData += data.toString();
    });
    
    pythonProcess.on('close', (code) => {
      if (code !== 0) {
        console.error(chalk.red(`Transcription process exited with code ${code}`));
        console.error(errorData);
        resolve(''); // Return empty string if failed
      } else {
        // Read the generated transcript file
        const transcriptPath = path.join(path.dirname(audioPath), 'transcript.txt');
        if (fs.existsSync(transcriptPath)) {
          const transcript = fs.readFileSync(transcriptPath, 'utf8');
          console.log(chalk.green('Transcription completed successfully'));
          resolve(transcript);
        } else {
          console.error(chalk.red('Transcript file not found'));
          resolve('');
        }
      }
    });
  });
}

// Save transcript to database
async function saveTranscript(mediaItem, transcript) {
  return new Promise((resolve, reject) => {
    db.run(`
      UPDATE media
      SET transcript = ?, analysis_date = ?
      WHERE id = ?
    `, [
      transcript,
      Date.now(),
      mediaItem.id
    ], (err) => {
      if (err) {
        console.error(chalk.red(`Error saving transcript: ${err.message}`));
        reject(err);
      } else {
        console.log(chalk.green(`Saved transcript for ${mediaItem.filename}`));
        resolve();
      }
    });
  });
}
```

Now let's add the command to analyze media:

```javascript
// CLI command to analyze media
program
  .command('analyze <mediaId>')
  .description('Analyze media file to generate descriptions, transcripts, and scene analysis')
  .option('-t, --type <type>', 'Type of analysis (all, video, audio, image)', 'all')
  .action(async (mediaId, options) => {
    try {
      // Get media item from database
      const mediaItem = await getMediaItem(mediaId);
      
      if (!mediaItem) {
        console.error(chalk.red(`Media item with ID ${mediaId} not found`));
        return;
      }
      
      console.log(chalk.blue(`Analyzing ${mediaItem.filename}...`));
      
      const analysisType = options.type.toLowerCase();
      let results = {};
      
      // Create an analysis task in the database
      const taskId = await createAnalysisTask(mediaItem.id, analysisType);
      
      try {
        if (mediaItem.filetype === 'video' && (analysisType === 'all' || analysisType === 'video')) {
          // Extract video frames
          await extractVideoFrames(mediaItem);
          
          // Analyze video frames
          const videoAnalysis = await analyzeVideoFrames(mediaItem);
          results.video = videoAnalysis;
          
          // Also do audio analysis for videos if requested
          if (analysisType === 'all') {
            const transcript = await generateAudioTranscript(mediaItem);
            results.audio = { transcript };
          }
        } else if ((mediaItem.filetype === 'audio' || mediaItem.filetype === 'video') && 
                  (analysisType === 'all' || analysisType === 'audio')) {
          // Generate audio transcript
          const transcript = await generateAudioTranscript(mediaItem);
          results.audio = { transcript };
        } else if (mediaItem.filetype === 'image' && (analysisType === 'all' || analysisType === 'image')) {
          // Analyze image
          const imageAnalysis = await analyzeImage(mediaItem);
          results.image = imageAnalysis;
        } else {
          console.log(chalk.yellow(`No ${analysisType} analysis available for ${mediaItem.filetype} files`));
        }
        
        // Generate a combined description based on all available analyses
        const description = generateCombinedDescription(mediaItem, results);
        
        // Update the media item with the auto-generated description
        await updateMediaDescription(mediaItem.id, description);
        
        // Mark task as completed
        await updateAnalysisTask(taskId, 'completed', 100);
        
        console.log(chalk.green(`Analysis completed for ${mediaItem.filename}`));
        console.log(chalk.cyan('Generated Description:'));
        console.log(boxen(description, { padding: 1, borderColor: 'cyan' }));
        
      } catch (error) {
        // Mark task as failed
        await updateAnalysisTask(taskId, 'failed', 0, error.message);
        throw error;
      }
      
    } catch (error) {
      console.error(chalk.red(`Analysis error: ${error.message}`));
    }
  });

// Generate a combined description from all analysis results
function generateCombinedDescription(mediaItem, results) {
  const descriptions = [];
  
  // Add video description if available
  if (results.video && results.video.description) {
    descriptions.push(results.video.description);
  }
  
  // Add audio transcript summary if available
  if (results.audio && results.audio.transcript) {
    const transcriptSummary = summarizeTranscript(results.audio.transcript);
    descriptions.push(`Audio contains: ${transcriptSummary}`);
  }
  
  // Add image description if available
  if (results.image && results.image.description) {
    descriptions.push(results.image.description);
  }
  
  // If no descriptions were generated, provide a basic file description
  if (descriptions.length === 0) {
    const metadata = mediaItem.metadata ? JSON.parse(mediaItem.metadata) : {};
    const fileInfo = [];
    
    // Add basic file info
    fileInfo.push(`${mediaItem.filetype.toUpperCase()} file`);
    
    // Add dimensions for videos and images
    if ((mediaItem.filetype === 'video' || mediaItem.filetype === 'image') && 
        metadata.extra && metadata.extra.streams) {
      const videoStream = metadata.extra.streams.find(s => s.codec_type === 'video');
      if (videoStream) {
        fileInfo.push(`${videoStream.width}x${videoStream.height}`);
      }
    }
    
    // Add duration for audio and video
    if ((mediaItem.filetype === 'audio' || mediaItem.filetype === 'video') && 
        metadata.extra && metadata.extra.format) {
      fileInfo.push(formatDuration(metadata.extra.format.duration));
    }
    
    // Add filesize
    fileInfo.push(formatFileSize(mediaItem.filesize));
    
    descriptions.push(fileInfo.join(', '));
  }
  
  return descriptions.join(' ');
}

// Summarize transcript to a brief description
function summarizeTranscript(transcript) {
  if (!transcript || transcript.length === 0) {
    return "No speech detected";
  }
  
  // If transcript is short, just return it
  if (transcript.length < 100) {
    return transcript;
  }
  
  // For longer transcripts, create a summary
  // Basic approach: extract key sentences
  const sentences = transcript.split(/[.!?]+/).filter(s => s.trim().length > 0);
  
  // Very simple summarization - take first, middle and last sentence
  if (sentences.length <= 3) {
    return sentences.join('. ') + '.';
  } else {
    return [
      sentences[0],
      sentences[Math.floor(sentences.length / 2)], 
      sentences[sentences.length - 1]
    ].join('. ') + '.';
  }
  
  // Note: In a real implementation, you would use NLP techniques
  // or call an external API for better summarization
}

// Get media item from database
async function getMediaItem(mediaId) {
  return new Promise((resolve, reject) => {
    db.get('SELECT * FROM media WHERE id = ?', [mediaId], (err, row) => {
      if (err) {
        reject(err);
      } else {
        resolve(row);
      }
    });
  });
}

// Create a new analysis task
async function createAnalysisTask(mediaId, taskType) {
  return new Promise((resolve, reject) => {
    const now = Date.now();
    db.run(`
      INSERT INTO analysis_tasks 
      (media_id, task_type, status, created_at, progress)
      VALUES (?, ?, ?, ?, ?)
    `, [
      mediaId,
      taskType,
      'pending',
      now,
      0
    ], function(err) {
      if (err) {
        reject(err);
      } else {
        resolve(this.lastID);
      }
    });
  });
}

// Update analysis task status
async function updateAnalysisTask(taskId, status, progress, error = null) {
  return new Promise((resolve, reject) => {
    const now = Date.now();
    let sql, params;
    
    if (status === 'completed') {
      sql = `
        UPDATE analysis_tasks
        SET status = ?, progress = ?, completed_at = ?
        WHERE id = ?
      `;
      params = [status, progress, now, taskId];
    } else if (status === 'failed') {
      sql = `
        UPDATE analysis_tasks
        SET status = ?, progress = ?, error = ?
        WHERE id = ?
      `;
      params = [status, progress, error, taskId];
    } else {
      sql = `
        UPDATE analysis_tasks
        SET status = ?, progress = ?, started_at = ?
        WHERE id = ?
      `;
      params = [status, progress, now, taskId];
    }
    
    db.run(sql, params, (err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}

// Update media description
async function updateMediaDescription(mediaId, description) {
  return new Promise((resolve, reject) => {
    db.run(`
      UPDATE media
      SET auto_description = ?
      WHERE id = ?
    `, [
      description,
      mediaId
    ], (err) => {
      if (err) reject(err);
      else resolve();
    });
  });
}
```

Now let's add functionality to view and edit metadata with the auto-generated description:

```javascript
// View metadata including auto-generated fields
async function viewMetadata(mediaItem) {
  console.log(chalk.blue('\nMetadata for ') + chalk.green(mediaItem.filename));
  console.log(chalk.blue('='.repeat(50)));
  
  console.log(chalk.yellow('File Information:'));
  console.log(`Path: ${mediaItem.filepath}`);
  console.log(`Type: ${mediaItem.filetype}`);
  console.log(`Size: ${formatFileSize(mediaItem.filesize)}`);
  console.log(`Last Modified: ${new Date(mediaItem.last_modified).toLocaleString()}`);
  console.log(`Last Scanned: ${new Date(mediaItem.last_scanned).toLocaleString()}`);
  
  // Display auto-generated description if available
  if (mediaItem.auto_description) {
    console.log(chalk.yellow('\nAuto-Generated Description:'));
    console.log(boxen(mediaItem.auto_description, { padding: 1, borderColor: 'green' }));
  }
  
  // Display transcript if available (truncated if it's long)
  if (mediaItem.transcript) {
    console.log(chalk.yellow('\nTranscript:'));
    const truncated = mediaItem.transcript.length > 500 
      ? mediaItem.transcript.substring(0, 500) + '...' 
      : mediaItem.transcript;
    console.log(boxen(truncated, { padding: 1, borderColor: 'blue' }));
    
    if (mediaItem.transcript.length > 500) {
      console.log(chalk.gray(`[Transcript truncated. Full transcript is ${mediaItem.transcript.length} characters]`));
    }
  }
  
  // Display scene analysis if available
  if (mediaItem.scene_analysis) {
    console.log(chalk.yellow('\nScene Analysis:'));
    try {
      const scenes = JSON.parse(mediaItem.scene_analysis);
      scenes.forEach((scene, index) => {
        console.log(chalk.cyan(`\nScene ${index + 1}: ${formatDuration(scene.startTime)} - ${formatDuration(scene.endTime)}`));
        console.log(`Description: ${scene.summary}`);
        
        // Show top objects in the scene
        const topObjects = Object.entries(scene.dominant_objects)
          .sort((a, b) => b[1] - a[1])
          .slice(0, 5)
          .map(([obj, score]) => `${obj} (${Math.round(score * 100) / 100})`);
        
        if (topObjects.length > 0) {
          console.log(`Key elements: ${topObjects.join(', ')}`);
        }
      });
    } catch (error) {
      console.error(chalk.red(`Error parsing scene analysis: ${error.message}`));
    }
  }
  
  try {
    const metadata = JSON.parse(mediaItem.metadata);
    const fileType = mediaItem.filetype;
    
    console.log(chalk.yellow('\nStandard Metadata Fields:'));
    
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
      
      // Skip auto-generated fields that are already displayed separately
      if (['auto_description', 'transcript', 'scene_analysis'].includes(key)) {
        return null;
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
      if (value !== null) {
        console.log(`${field.charAt(0).toUpperCase() + field.slice(1)}: ${value}`);
      }
    }
    
  } catch (error) {
    console.error(chalk.red(`Error parsing metadata: ${error.message}`));
  }
}

// Edit metadata including auto-generated description
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
      // Special handling for auto-generated description
      if (field === 'auto_description') {
        currentValues[field] = mediaItem.auto_description || '';
        continue;
      }
      
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
    const questions = editableFields.map(field => {
      // Special handling for auto_description to use editor
      if (field === 'auto_description') {
        return {
          type: 'editor',
          name: field,
          message: 'Edit Auto-Generated Description:',
          default: String(currentValues[field] || ''),
          postfix: '.md',  // Use markdown for nicer editing
        };
      }
      
      return {
        type: 'input',
        name: field,
        message: `${field.charAt(0).toUpperCase() + field.slice(1)}:`,
        default: String(currentValues[field] || '')
      };
    });
    
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
          // Special handling for auto_description
          if (field === 'auto_description') {
            // Update auto_description directly in the database
            await updateMediaDescription(mediaItem.id, answers[field]);
            
            // Track history entry
            historyEntries.push({
              field: field,
              old_value: String(currentValues[field] || ''),
              new_value: String(answers[field])
            });
            
            continue;
          }
          
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
      
      // Apply ExifTool changes if there are any
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
      }
      
      // Record history entries
      const now = Date.now();
      for (const entry of historyEntries) {
        db.run(`
          INSERT INTO edit_history (media_id, timestamp, field, old_value, new_value)
          VALUES (?, ?, ?, ?, ?)
        `, [
          mediaItem.id, now, entry.field, entry.old_value, entry.new_value
        ]);
      }
      
      // If we had ExifTool changes, rescan the file to update the database
      if (exiftoolArgs.length > 0) {
        const stat = fs.statSync(mediaItem.filepath);
        await processMediaFile(mediaItem.filepath, stat, true);
      }
      
      console.log(chalk.green('Metadata updated successfully!'));
      
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
```

Finally, let's add the Python script for transcription:

```python
#!/usr/bin/env python3
# transcribe.py - Audio transcription script using a local model

import argparse
import os
import torch
import librosa
import numpy as np
from transformers import Wav2Vec2ForCTC, Wav2Vec2Processor

def main():
    parser = argparse.ArgumentParser(description="Transcribe audio using local model")
    parser.add_argument("--audio", required=True, help="Path to audio file")
    parser.add_argument("--model", required=True, help="Path to model directory")
    parser.add_argument("--output", required=True, help="Path to output transcript file")
    
    args = parser.parse_args()
    
    print(f"Loading model from {args.model}")
    processor = Wav2Vec2Processor.from_pretrained(args.model)
    model = Wav2Vec2ForCTC.from_pretrained(args.model)
    
    print(f"Processing audio file: {args.audio}")
    # Load audio file with librosa
    speech_array, sampling_rate = librosa.load(args.audio, sr=16000)
    
    # Process in chunks to avoid memory issues
    chunk_size = 10 * sampling_rate  # 10 seconds chunks
    transcript_chunks = []
    
    for i in range(0, len(speech_array), chunk_size):
        chunk = speech_array[i:i+chunk_size]
        
        # Convert to tensor
        input_values = processor(chunk, sampling_rate=16000, return_tensors="pt").input_values
        
        # Get logits
        with torch.no_grad():
            logits = model(input_values).logits
        
        # Get predicted ids
        predicted_ids = torch.argmax(logits, dim=-1)
        
        # Decode
        transcript = processor.batch_decode(predicted_ids)[0]
        transcript_chunks.append(transcript)
    
    # Combine chunks
    full_transcript = " ".join(transcript_chunks)
    
    # Write to output file
    with open(args.output, "w") as f:
        f.write(full_transcript)
    
    print(f"Transcription completed and saved to {args.output}")

if __name__ == "__main__":
    main()
```

Here's the README.md for this project:

```markdown
# Media Metadata Manager CLI

A powerful command-line tool for managing media metadata with advanced analysis features.

## Features

- **Auto-description generation** through video and audio content analysis
- **Scene detection and analysis** for videos
- **Audio transcription** for speech in videos and audio files
- **Metadata editing** without disturbing the underlying media files
- **Backup system** for safe metadata operations
- **Database storage** for efficient metadata management

## Installation

### Prerequisites

- Node.js (v14+)
- Python 3.7+ (for advanced analysis features)
- ffmpeg
- ExifTool

### Install dependencies

```bash
# Node.js dependencies
npm install

# Python dependencies (for advanced analysis)
pip install torch librosa transformers
```

### Configuration

The tool will create a configuration file at `src/tools/config/metadata-config.json` with default settings.

## Usage

### Scan media files

```bash
./metadata-manager scan /path/to/media/folder --recursive
```

### Browse media database

```bash
./metadata-manager browse
```

### Analyze media content

```bash
# Analyze everything (video scenes, generate description, create transcript)
./metadata-manager analyze <media-id> --type all

# Analyze only video content
./metadata-manager analyze <media-id> --type video

# Analyze only audio content
./metadata-manager analyze <media-id> --type audio
```

### Interactive Mode

```bash
./metadata-manager interactive
```

## Directory Structure

- `src/tools/config/` - Configuration and database
- `src/tools/cache/` - Temporary cache files
- `src/tools/analysis/` - Analysis outputs (frames, transcripts)
- `src/tools/models/` - Local ML models
- `src/tools/python_scripts/` - Python helper scripts

## API Key Configuration

For cloud-based analysis features, set the following environment variables:

```bash
export OPENAI_API_KEY="your-key-here"
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/credentials.json"
export AWS_ACCESS_KEY_ID="your-key-id"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

## Local Model Setup

Download the required models:

```bash
# For transcription
mkdir -p src/tools/models/audio_recognition
# Download Wav2Vec2 model

# For object detection
mkdir -p src/tools/models/object_detection
# Download YOLO or other models

# For scene recognition
mkdir -p src/tools/models/scene_recognition
# Download scene recognition models
```
```

This Media Metadata Manager CLI solution will:

1. Automatically analyze video to generate visual scene descriptions
2. Transcribe audio content for both videos and audio files
3. Combine these analyses into comprehensive metadata descriptions
4. Allow you to view and edit this automatically generated metadata
5. Preserve all changes in a database without disrupting the original files
6. Create restore points so you can revert changes if needed

The tool is designed to be modular and extensible, supporting both cloud-based AI services and local machine learning models for processing your media files.​​​​​​​​​​​​​​​​