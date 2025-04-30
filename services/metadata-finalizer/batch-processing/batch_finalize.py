#!/usr/bin/env python3
"""
Batch processor for CDA Metadata Finalizer pipelines.

Usage:
  ./batch_finalize.py \
    --csv videos.csv \
    --share-mount /mnt/video_share \
    --output-dir /data/batches \
    --ftp-host ftp.blackboxglobal.com \
    --ftp-user USERNAME \
    --ftp-pass PASSWORD \
    --ftp-dir /incoming
"""
import os
import csv
import argparse
import tempfile
import shutil
import logging
import subprocess
from ftplib import FTP

# Import the library functions from your existing finalize.py
from finalize import get_video, generate_thumbnail, create_metadata

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s: %(message)s")

def parse_args():
    p = argparse.ArgumentParser(description="Batch finalize videos + upload via FTP")
    p.add_argument("--csv",         required=True, help="CSV with headers: source_path,batch_name[,remove_ranges]")
    p.add_argument("--share-mount", required=True, help="Mount point for 192.168.0.19 volume1 share")
    p.add_argument("--output-dir",  default="batches_output", help="Where to collect per-batch dirs")
    p.add_argument("--ftp-host",    required=True, help="FTP server hostname")
    p.add_argument("--ftp-user",    required=True)
    p.add_argument("--ftp-pass",    required=True)
    p.add_argument("--ftp-dir",     required=True, help="Target directory on FTP server")
    p.add_argument("--dry-run",     action="store_true", help="Do not execute commands, only print them")
    return p.parse_args()

def remove_stock_segments(input_path, output_path, ranges):
    """
    Remove stock segments defined in 'ranges'.
    ranges: list of (start, end) timestamps, e.g. [("00:00:00","00:00:05"), ...]
    THIS IS A PLACEHOLDER: implements only single-range removal by dropping [start,end).
    """
    if not ranges:
        # no removal requested → copy through
        shutil.copy(input_path, output_path)
        return

    # example: drop the first segment, keep from ranges[0][1] → end
    _, end_ts = ranges[0]
    cmd = [
        "ffmpeg", "-y",
        "-i", input_path,
        "-ss", end_ts,
        "-c", "copy",
        output_path
    ]
    logging.info(f"Removing stock segment {ranges[0][0]}–{end_ts} from {os.path.basename(input_path)}")
    subprocess.run(cmd, check=True)

def process_batch(rows, share_mount, out_base, ftp_cfg, dry_run):
    batches = {}
    # group rows by batch_name
    for src, batch, ranges in rows:
        batches.setdefault(batch, []).append((src, ranges))

    for batch_name, items in batches.items():
        batch_dir = os.path.join(out_base, batch_name)
        os.makedirs(batch_dir, exist_ok=True)

        logging.info(f"Processing batch '{batch_name}' → {len(items)} videos")
        for src_path, ranges in items:
            full_input = os.path.join(share_mount, src_path)
            if not os.path.exists(full_input):
                logging.error(f"Missing source file: {full_input}")
                continue

            # work in a temp dir
            with tempfile.TemporaryDirectory() as td:
                temp_vid = os.path.join(td, os.path.basename(full_input))
                # strip stock
                remove_stock_segments(full_input, temp_vid, ranges)
                # finalize: thumbnail + metadata (written alongside temp_vid)
                generate_thumbnail(temp_vid, os.path.splitext(temp_vid)[0] + "_thumb.jpg")
                create_metadata(temp_vid, os.path.splitext(temp_vid)[0] + "_thumb.jpg")

                # move outputs into batch_dir
                for f in os.listdir(td):
                    shutil.move(os.path.join(td, f), batch_dir)

        # create tarball
        tarname = f"{batch_name}.tar.gz"
        tarpath = os.path.join(out_base, tarname)
        cmd = ["tar", "czf", tarpath, "-C", out_base, batch_name]
        if dry_run:
            print("DRY RUN:", " ".join(cmd))
        else:
            subprocess.run(cmd, check=True)

        # upload via FTP
        if not dry_run:
            ftp = FTP(ftp_cfg["host"])
            ftp.login(ftp_cfg["user"], ftp_cfg["pass"])
            ftp.cwd(ftp_cfg["dir"])
            with open(tarpath, "rb") as f:
                ftp.storbinary(f"STOR {tarname}", f)
            ftp.quit()
            logging.info(f"Uploaded {tarname} to FTP:{ftp_cfg['dir']}")

def parse_csv(path):
    """
    Expect CSV cols: source_path,batch_name,remove_ranges?
    remove_ranges format: "00:00:00-00:00:05;00:01:00-00:01:10"
    """
    rows = []
    with open(path, newline="") as cf:
        reader = csv.DictReader(cf)
        for r in reader:
            src = r["source_path"]
            batch = r["batch_name"]
            rngs = []
            if r.get("remove_ranges"):
                for seg in r["remove_ranges"].split(";"):
                    start,end = seg.split("-",1)
                    rngs.append((start.strip(), end.strip()))
            rows.append((src, batch, rngs))
    return rows

def main():
    args = parse_args()
    rows = parse_csv(args.csv)
    ftp_cfg = {
        "host": args.ftp_host,
        "user": args.ftp_user,
        "pass": args.ftp_pass,
        "dir":  args.ftp_dir,
    }
    process_batch(rows, args.share_mount, args.output_dir, ftp_cfg, args.dry_run)

if __name__ == "__main__":
    main()