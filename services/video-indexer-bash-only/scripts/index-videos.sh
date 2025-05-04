#!/bin/bash

WATCH_DIR="/mnt/videos"
INDEX_PATH="/mnt/index/index.json"
PROCESSED_LOG="/mnt/index/processed.log"
TMP_INDEX="/tmp/_index.json"

touch "$INDEX_PATH" "$PROCESSED_LOG"
echo "[]" > "$TMP_INDEX"

is_duplicate() {
  local path="$1"
  local size=$(stat -c%s "$path")
  local mtime=$(stat -c%Y "$path")

  jq -e --arg path "$path" --argjson size "$size" --argjson mtime "$mtime" \
    '.[] | select(.path == $path or (.size == $size and .mtime == $mtime))' "$INDEX_PATH" > /dev/null
}

echo "[*] Watching $WATCH_DIR for new video files..."

inotifywait -m -r -e create -e moved_to --format '%w%f' "$WATCH_DIR" | while read NEWFILE; do
  [[ "$NEWFILE" =~ \.(mp4|mov|webm|mkv|avi|m4v)$ ]] || continue

  if is_duplicate "$NEWFILE"; then
    echo "[SKIP] Already indexed: $NEWFILE"
    continue
  fi

  size=$(stat -c%s "$NEWFILE")
  mtime=$(stat -c%Y "$NEWFILE")
  name=$(basename "$NEWFILE")

  jq --arg path "$NEWFILE" --arg name "$name" --argjson size "$size" --argjson mtime "$mtime" \
    '. += [{"name": $name, "path": $path, "size": $size, "mtime": $mtime}]' "$INDEX_PATH" > "$TMP_INDEX" && mv "$TMP_INDEX" "$INDEX_PATH"

  echo "[NEW] Indexed: $NEWFILE"
done