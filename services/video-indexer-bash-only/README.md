# CDAPROD: Persistent Video Indexer Container

## Core Features:

- Watches mounted /mnt/b (NAS)
- Only indexes unique video files (more than just filename: size, modtime, hash)
- Runs as a privileged, ephemeral Docker container
- Saves persistent index to /mnt/b/video-index/index.json
- Read-only access to videos
- Exposes the list via http://localhost:3100/index.json (or via shared volume)

### Persistent Behavior:

- Index JSON is persisted to /mnt/b/video-index/index.json
- Will not re-index the same file (based on path, size, and mtime)
- Easily extendable to hash comparison later (e.g. md5sum or blake3)


## Optional: Serve the Index via HTTP

Add another container (or use python’s built-in HTTP server):

```bash
docker run --rm -d -v /mnt/b/video-index:/srv -p 3100:80 halverneus/static-file-server:latest -root=/srv
``` 

Accessible at:
http://cda-ds.local:3100/index.json

This is now ready to ship.

---

## Next Actions

- Add a metadata extractor (e.g. ffprobe) for each video?
- Extend it to feed Sanity or Weaviate with the generated JSON?