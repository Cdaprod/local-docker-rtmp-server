import os
import pandas as pd

CSV_PATH = "indexed-videos.csv"
SRC_BASE = "/volume1"
DEST_BASE = "/opt/minio-data"

# Load and clean
df = pd.read_csv(CSV_PATH, sep="|", engine="python")
df.columns = [col.strip() for col in df.columns]
df = df[["Format", "Source Path"]].dropna()

for _, row in df.iterrows():
    src = row["Source Path"].strip()
    fmt = row["Format"].strip().lower()

    if not os.path.isfile(src):
        print(f"Skipping: {src} does not exist")
        continue

    try:
        rel_path = os.path.relpath(src, SRC_BASE)
        dest = os.path.join(DEST_BASE, fmt, rel_path)

        os.makedirs(os.path.dirname(dest), exist_ok=True)

        if os.path.islink(dest) or os.path.exists(dest):
            os.remove(dest)

        os.symlink(src, dest)
        print(f"Linked: {src} -> {dest}")

    except Exception as e:
        print(f"Error linking {src} -> {dest}: {e}")