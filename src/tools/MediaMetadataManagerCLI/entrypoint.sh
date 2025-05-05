#!/bin/bash
set -e

# Create config.json if it doesn't exist
if [ ! -f "/app/src/tools/config/metadata-config.json" ]; then
    echo "Initializing default configuration..."
    node -e "
        const fs = require('fs');
        const path = require('path');
        const configPath = '/app/src/tools/config/metadata-config.json';
        const config = {
            supportedFormats: [
                '.mp4', '.mkv', '.avi', '.mov', '.wmv', '.flv', '.webm', '.m4v',
                '.mp3', '.flac', '.wav', '.ogg', '.m4a', '.wma', '.aac',
                '.jpg', '.jpeg', '.png', '.gif', '.bmp', '.tiff'
            ],
            mediaFolders: ['/media'],
            backupBeforeEdits: true,
            maxHistoryItems: 100,
            metadataFieldsToDisplay: {
                video: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'width', 'height', 'codec', 'bitrate', 'auto_description', 'scene_analysis', 'transcript'],
                audio: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'duration', 'bitrate', 'sampleRate', 'auto_description', 'transcript'],
                image: ['title', 'artist', 'date', 'comment', 'width', 'height', 'model', 'make', 'exposureTime', 'aperture', 'iso', 'auto_description']
            },
            editableFields: {
                video: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'auto_description'],
                audio: ['title', 'artist', 'album', 'date', 'genre', 'comment', 'auto_description'],
                image: ['title', 'artist', 'date', 'comment', 'auto_description']
            },
            analysisConfig: {
                enabled: true,
                videoFrameSampleRate: ${process.env.VIDEO_FRAME_SAMPLE_RATE || 1},
                maxFramesToAnalyze: ${process.env.MAX_FRAMES_TO_ANALYZE || 100},
                audioTranscription: ${process.env.ENABLE_AUDIO_TRANSCRIPTION || 'true'},
                sceneDetection: ${process.env.ENABLE_SCENE_DETECTION || 'true'}
            }
        };
        fs.writeFileSync(configPath, JSON.stringify(config, null, 2));
        console.log('Default configuration created successfully!');
    "
fi

# Check if we need to scan the media directory on startup
if [ "$1" = "scan" ]; then
    echo "Starting initial media scan..."
    metadata-manager scan /media
    shift
fi

# If no arguments provided, start interactive mode
if [ $# -eq 0 ]; then
    exec metadata-manager interactive
else
    exec metadata-manager "$@"
fi