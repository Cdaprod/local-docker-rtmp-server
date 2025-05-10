#!/bin/bash
set -e

# MODE can be "watcher" (default) or "api"
MODE="${MODE:-watcher}"

if [ "$MODE" = "api" ]; then
  echo -e "${GREEN}Launching FastAPI server...${NC}"
  exec uvicorn src.main:app --host 0.0.0.0 --port 5000 --reload
else
  echo -e "${GREEN}Launching Video Watcher service...${NC}"
  exec python -m src.main
fi

# Colors
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${GREEN}Starting Video Indexer Entrypoint...${NC}"

# Directories
INDEX_DIR="${INDEX_DIR:-/data/index}"
THUMB_DIR="${THUMBNAIL_DIR:-/data/thumbnails}"
WATCH_DIR="${WATCH_DIR:-/mnt/videos}"
REPO_DIR="${REPO_DIR:-/repo-data}"

echo -e "${YELLOW}Ensuring directories...${NC}"
mkdir -p "$INDEX_DIR" "$THUMB_DIR" "$WATCH_DIR" "$REPO_DIR/index"

# Restore on cold start
if [ -f "$REPO_DIR/index/index.json" ] && [ ! -f "$INDEX_DIR/index.json" ]; then
  echo -e "${YELLOW}Restoring index.json from repo...${NC}"
  cp "$REPO_DIR/index/index.json" "$INDEX_DIR/index.json"
  cp "$REPO_DIR/index/processed.log" "$INDEX_DIR/processed.log" 2>/dev/null || true
fi

# Git setup (assumes REPO_DIR is a git worktree with origin set & SSH creds mounted)
cd "$REPO_DIR"
git config user.name "video-indexer-bot"
git config user.email "ci@local"

# Function: commit & push metadata changes
commit_metadata(){
  cd "$REPO_DIR"
  if git diff --quiet --exit-code index/index.json index/processed.log; then
    return
  fi
  echo -e "${GREEN}Committing metadata changes...${NC}"
  git add index/index.json index/processed.log
  git commit -m "chore(ci): update video index @ $(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  git push origin HEAD  
}

# Periodic background sync+commit
(
  while sleep 300; do
    # copy latest into repo
    cp "$INDEX_DIR/index.json" "$REPO_DIR/index/index.json"
    cp "$INDEX_DIR/processed.log" "$REPO_DIR/index/processed.log" 2>/dev/null || true
    commit_metadata
  done
) &

# Final cleanup on exit
cleanup(){
  echo -e "${YELLOW}Shutting down – final metadata sync...${NC}"
  cp "$INDEX_DIR/index.json" "$REPO_DIR/index/index.json"
  cp "$INDEX_DIR/processed.log" "$REPO_DIR/index/processed.log" 2>/dev/null || true
  commit_metadata
  exit 0
}
trap cleanup SIGTERM SIGINT

# Hand off to your Python service
echo -e "${GREEN}Launching Video Indexer application...${NC}"
exec python -m src.main