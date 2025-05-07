# rudp/

Simple Reliable UDP Packet Layer

Implements a tiny custom packet format:
- 4 bytes: Sequence Number
- 4 bytes: ACK Number
- 1 byte: Flags
- N bytes: Payload

Used for wrapping stream frames with lightweight control.