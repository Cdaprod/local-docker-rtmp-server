# src/blackbox_metadata.py

import json
from pathlib import Path
import pandas as pd
import openai
from .config import settings
from .openai_helpers import describe_frame, summarize_audio

class BlackBoxMetadataGenerator:
    def __init__(self):
        openai.api_key = settings.openai_api_key

    def is_target_batch(self, batch_dir: Path) -> bool:
        """Only process directories that contain a marker file."""
        return (batch_dir / ".generate_metadata").exists()

    def process_batch(self, batch_dir: Path):
        """Generate a BlackBox-style Excel for one batch."""
        records = []
        for video in sorted(batch_dir.iterdir()):
            if video.suffix.lower() in settings.video_extensions:
                # 1️⃣ extract AI data
                frame_desc = describe_frame(next(batch_dir.glob("frames/frame_0001.jpg"), video))
                audio_summary = summarize_audio(batch_dir / "audio.wav")

                # 2️⃣ ask GPT to produce Title, Description, Keywords JSON
                prompt = (
                    f"Given this frame description:\n\n{frame_desc}\n\n"
                    f"And this audio summary:\n\n{audio_summary}\n\n"
                    "Generate a JSON object with keys: "
                    "\"Title\" (short title), "
                    "\"Description\" (50-200 chars), "
                    "\"Keywords\" (list of 8–12 words)."
                )
                resp = openai.ChatCompletion.create(
                    model=settings.metadata_model,
                    messages=[{"role":"user","content":prompt}],
                    temperature=0.7
                )
                try:
                    md = json.loads(resp.choices[0].message.content)
                except json.JSONDecodeError:
                    # fallback: wrap raw text
                    md = {"Title":"", "Description": resp.choices[0].message.content, "Keywords":[]}

                records.append({
                    "Filename": video.name,
                    "Title": md.get("Title",""),
                    "Description": md.get("Description",""),
                    "Keywords": ", ".join(md.get("Keywords",[])),
                    "Duration": "",     # you can fill via ffmpeg probe if desired
                    "Resolution": ""    # likewise
                })

        if not records:
            return

        # 3️⃣ write to Excel
        out_dir = settings.blackbox_output_dir / batch_dir.name
        out_dir.mkdir(parents=True, exist_ok=True)
        out_path = out_dir / "BlackBox_Metadata.xlsx"
        pd.DataFrame(records).to_excel(out_path, index=False)
        print(f"[BlackBox] Generated metadata for {batch_dir.name} → {out_path}")

    def scan_and_process(self, base_dir: Path):
        """Find all target batches under WATCH_DIR and process them."""
        for child in sorted(base_dir.iterdir()):
            if child.is_dir() and self.is_target_batch(child):
                self.process_batch(child)