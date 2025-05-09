# src/openai_helpers.py

import os
import base64
import subprocess
import openai
from pathlib import Path
from typing import List, Dict

openai.api_key = os.getenv("OPENAI_API_KEY")

def extract_media(video_path: Path, frame_rate: int = 1) -> (Path, Path):
    frames_dir = video_path.parent / "frames"
    audio_file = video_path.parent / "audio.wav"
    frames_dir.mkdir(exist_ok=True)

    subprocess.run([
        "ffmpeg", "-i", str(video_path),
        "-vf", f"fps={frame_rate}",
        str(frames_dir / "frame_%04d.jpg")
    ], check=True)

    subprocess.run([
        "ffmpeg", "-i", str(video_path),
        "-vn", "-ac", "1", "-ar", "16000",
        str(audio_file)
    ], check=True)

    return frames_dir, audio_file

def describe_frame(frame_path: Path) -> str:
    b64 = base64.b64encode(frame_path.read_bytes()).decode()
    response = openai.ChatCompletion.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "You are a video analysis assistant."},
            {"role": "user", "content": [
                {"type": "text", "text": "Describe what’s happening in this frame."},
                {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{b64}"}}
            ]}
        ]
    )
    return response.choices[0].message.content.strip()

def summarize_audio(audio_path: Path) -> str:
    # Placeholder: assume audio upload API coming to GPT-4o
    response = openai.ChatCompletion.create(
        model="gpt-4o",
        messages=[
            {"role": "system", "content": "You summarize audio files."},
            {"role": "user", "content": f"Summarize this audio file: {audio_path.name}"}
        ],
        functions=[{
            "name": "upload_audio",
            "description": "Audio upload",
            "parameters": {
                "type": "object",
                "properties": {
                    "audio": {"type": "string", "format": "binary"}
                },
                "required": ["audio"]
            }
        }],
        function_call={"name": "upload_audio", "arguments": str(audio_path)}
    )
    return response.choices[0].message.content.strip()

def generate_thumbnail_from_description(prompt: str, out_path: Path) -> Path:
    response = openai.Image.create(
        model="dall-e-3",
        prompt=prompt,
        size="512x512",
        n=1
    )
    image_data = base64.b64decode(response.data[0].b64_json)
    out_path.write_bytes(image_data)
    return out_path