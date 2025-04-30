from graph import Graph
from nodes.opencv_blur_node import BlurNode

import cv2

# Load webcam
cap = cv2.VideoCapture(0)  # webcam
success, frame = cap.read()

# Load image
img = cv2.imread("input.jpg")

# Setup graph
graph = Graph()

# Nodes
blur_node = BlurNode(name="blur1")

# Add to graph
graph.add_node(blur_node)

# Manually feed input
blur_node.set_input("input", img)

# Run graph
graph.run()

# Get final output
output_img = blur_node.get_output("output")

# Save output
cv2.imwrite("output.jpg", output_img)