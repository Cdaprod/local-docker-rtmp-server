class Node:
    def __init__(self, name):
        self.name = name
        self.inputs = {}
        self.outputs = {}

    def set_input(self, key, value):
        self.inputs[key] = value

    def get_output(self, key):
        return self.outputs.get(key)

    def compute(self):
        # Each node defines its own behavior
        pass

class Graph:
    def __init__(self):
        self.nodes = []
        self.edges = []  # (output_node, output_key, input_node, input_key)

    def add_node(self, node):
        self.nodes.append(node)

    def connect(self, output_node, output_key, input_node, input_key):
        self.edges.append((output_node, output_key, input_node, input_key))

    def run(self):
        for node in self.nodes:
            node.compute()
        for output_node, output_key, input_node, input_key in self.edges:
            value = output_node.get_output(output_key)
            input_node.set_input(input_key, value)