# /app/jobs/render.py
import os
import uuid
import subprocess
from fastapi import UploadFile

async def process_blender_render(
    background: UploadFile,
    overlay: UploadFile,
    chroma_key: str
):
    """
    1) Save incoming uploads to disk
    2) Invoke Blender headlessly with blender_script.py
    3) Return path to the rendered output
    """
    # -- prepare directories
    input_dir = "/mnt/b/assets/input"
    output_dir = "/mnt/b/app/exports"
    os.makedirs(input_dir, exist_ok=True)
    os.makedirs(output_dir, exist_ok=True)

    # -- save files
    bg_name = f"{uuid.uuid4()}_bg.mov"
    ov_name = f"{uuid.uuid4()}_ov.mov"
    bg_path = os.path.join(input_dir, bg_name)
    ov_path = os.path.join(input_dir, ov_name)

    with open(bg_path, "wb") as f:
        f.write(await background.read())
    with open(ov_path, "wb") as f:
        f.write(await overlay.read())

    # -- output file
    out_name = f"render_{uuid.uuid4()}.mp4"
    out_path = os.path.join(output_dir, out_name)

    # -- call Blender in headless mode
    cmd = [
        "blender", "--background", "--python", "blender_script.py", "--",
        "--bg", bg_path,
        "--ov", ov_path,
        "--chroma", chroma_key,
        "--out", out_path
    ]
    subprocess.run(cmd, check=True, cwd=os.getcwd())

    return {"output_path": out_path}