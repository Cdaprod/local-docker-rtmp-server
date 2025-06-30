#!/usr/bin/env bash
set -euo pipefail

# ─── CONFIG ─────────────────────────────────────────────
# 1) Where to scan for videos and (optionally) an existing index
BASE_DIR="/volume1/David"
INDEX_CSV="${INDEX_CSV:-/mnt/data/indexed-videos.csv}"

# 2) Your DirPath→Bucket→Prefix mapping
MAPPING_CSV="/mnt/data/buckets_mapping.csv"

# 3) Local queue of placeholders (persistent until uploaded)
QUEUE_DIR="/var/lib/minio-migration/queue"
LOG_FILE="/var/log/minio-migration.log"

# 4) MinIO alias & creds (must match your `mc alias set`)
MC="mc"
MINIO_ALIAS="local"

# ─── FLAGS ──────────────────────────────────────────────
MODE="prepare"   # default: scan & queue new tasks, then try to process
if [[ "${1:-}" == "--process-only" ]]; then
  MODE="process-only"
elif [[ "${1:-}" == "--dry-run" ]]; then
  MODE="dry-run"
fi

# ─── BOOTSTRAP ──────────────────────────────────────────
mkdir -p "$QUEUE_DIR"
touch "$LOG_FILE"

log() {
  echo "$(date -Iseconds)  $*" | tee -a "$LOG_FILE"
}

# Ensure mapping exists
if [[ ! -f "$MAPPING_CSV" ]]; then
  log "❌ Mapping file not found: $MAPPING_CSV"
  exit 1
fi

# ─── FUNCTION: SCAN & QUEUE NEW PLACEHOLDERS ───────────
prepare() {
  log "▶️  Starting prepare step (mode=$MODE)"

  # If no INDEX_CSV, generate one on-the-fly
  if [[ ! -f "$INDEX_CSV" ]]; then
    log "  • Generating index via find"
    INDEX_CSV="/tmp/indexed-videos.csv"
    echo "FullPath|Filename|Size|MTime" > "$INDEX_CSV"
    find "$BASE_DIR" -type f \( -iname "*.mp4" -o -iname "*.mov" -o -iname "*.mkv" \) \
      -printf "%p|%f|%s|%TY-%Tm-%TdT%TH:%TM:%TS\n" >> "$INDEX_CSV"
  fi

  tail -n +2 "$INDEX_CSV" | while IFS='|' read -r fullpath filename size mtime; do
    dir=$(dirname "$fullpath")
    # lookup mapping
    map_line=$(grep -F "$dir" "$MAPPING_CSV" || true)
    [[ -z "$map_line" ]] && continue

    bucket=$(echo "$map_line" | cut -d'|' -f2)
    prefix=$(echo "$map_line" | cut -d'|' -f3 | sed 's:/*$::')
    obj="${prefix}/${filename}.placeholder.json"

    # build JSON payload
    payload="{\"original_path\":\"$fullpath\",\"filename\":\"$filename\",\"size\":$size,\"mtime\":\"$mtime\",\"placeholder\":true}"

    # queue file path: include bucket + object, safe characters
    safe_obj=$(echo "$bucket/$obj" | tr '/ ' '__')
    queue_file="$QUEUE_DIR/$safe_obj.json"

    # skip if already queued or uploaded
    if [[ -f "$queue_file" ]]; then
      ((MODE=="dry-run")) && log "  [DRY] Already queued → $queue_file"
      continue
    fi

    # write payload to queue
    echo "$payload" > "$queue_file"
    log "  [+] Queued placeholder → $queue_file"
  done
}

# ─── FUNCTION: PROCESS QUEUE (upload placeholders) ──────
process_queue() {
  log "▶️  Starting process step (mode=$MODE)"

  # test MinIO availability
  if ! $MC ls "$MINIO_ALIAS" &>/dev/null; then
    log "  ⚠️  MinIO not reachable, skipping upload"
    return
  fi

  # iterate each queued placeholder
  find "$QUEUE_DIR" -type f -name '*.json' | while read -r queue_file; do
    # reconstruct bucket/object from filename
    rel=$(basename "$queue_file")
    path=$(echo "$rel" | sed 's/__/\//g; s/\.json$//')
    bucket=$(echo "$path" | cut -d'/' -f1)
    obj=$(echo "$path" | cut -d'/' -f2-)

    # ensure bucket
    if [[ "$MODE" == "dry-run" ]]; then
      log "  [DRY] Would create bucket → $bucket"
    else
      log "  [PB] Ensuring bucket → $bucket"
      $MC mb --ignore-existing "$MINIO_ALIAS/$bucket"
    fi

    # upload placeholder
    if [[ "$MODE" == "dry-run" ]]; then
      length=$(wc -c < "$queue_file")
      log "  [DRY] Would upload → $bucket/$obj (${length} bytes)"
    else
      log "  [UP] Uploading → $bucket/$obj"
      if $MC cp "$queue_file" "$MINIO_ALIAS/$bucket/$obj" \
           --attr "x-amz-meta-original-path=$(jq -r '.original_path' "$queue_file")"; then
        rm -f "$queue_file"
        log "    ✓ Success, removed queue file"
      else
        log "    ✗ Failed, will retry later"
      fi
    fi
  done
}

# ─── MAIN ────────────────────────────────────────────────
case "$MODE" in
  dry-run)
    prepare
    process_queue
    log "✅ Dry-run complete; no changes made."
    ;;
  process-only)
    process_queue
    log "✅ Process-only complete."
    ;;
  *)
    prepare
    process_queue
    log "✅ Full run complete; see $LOG_FILE for details."
    ;;
esac