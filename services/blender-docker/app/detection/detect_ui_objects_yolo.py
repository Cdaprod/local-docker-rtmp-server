# /app/detection/detect_ui_objects_yolo.py
from ultralytics import YOLO

def detect_on_frame(image_path, model_path="yolov8n.pt"):
    model = YOLO(model_path)
    res = model(image_path)
    detections = []
    for r in res:
        for box in r.boxes:
            detections.append({
                "bbox": box.xywh.tolist()[0],   # [x,y,w,h]
                "confidence": float(box.conf[0]),
                "class_id": int(box.cls[0])
            })
    return detections