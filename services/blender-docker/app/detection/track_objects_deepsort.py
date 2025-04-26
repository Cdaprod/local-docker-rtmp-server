# /app/detection/track_objects_deepsort.py
from deep_sort_realtime.deepsort_tracker import DeepSort

def track_sequence(detections_per_frame):
    tracker = DeepSort(max_age=30)
    tracked = []
    for frame_idx, dets in enumerate(detections_per_frame, start=1):
        tracks = tracker.update_tracks(
            dets, frame=frame_idx
        )
        objs = []
        for t in tracks:
            if not t.is_confirmed():
                continue
            bbox = t.to_ltwh()  # left, top, w, h
            objs.append({
                "id": t.track_id,
                "bbox": bbox
            })
        tracked.append({"frame": frame_idx, "objects": objs})
    return tracked