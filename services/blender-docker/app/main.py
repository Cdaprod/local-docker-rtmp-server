from fastapi import FastAPI, UploadFile, File, Form
from fastapi.responses import FileResponse
from jobs.render import process_blender_render

app = FastAPI()

@app.post("/process")
async def process_videos(
    background: UploadFile = File(...),
    overlay: UploadFile = File(...),
    chroma_key: str = Form("#00FF00")
):
    return await process_blender_render(background, overlay, chroma_key)