import subprocess, os

def run(filepath, config):
    # Example: only transcode .insv
    if not filepath.endswith('.insv'):
        return
    out_dir = config.get('output_dir', '/tmp')
    basename = os.path.splitext(os.path.basename(filepath))[0]
    out_path = os.path.join(out_dir, basename + '.mp4')
    subprocess.run([
        "ffmpeg", "-i", filepath, "-c", "copy", out_path
    ], check=False)
    print(f"[ffmpeg_transcode] {filepath} → {out_path}")