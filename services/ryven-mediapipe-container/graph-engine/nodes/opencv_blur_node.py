import cv2

from services.graph_engine.graph import Node

class BlurNode(Node):
    def compute(self):
        img = self.inputs.get("input")
        if img is not None:
            blurred = cv2.GaussianBlur(img, (5, 5), 0)
            self.outputs["output"] = blurred