# open-ndi

Hey everyone, I’m David Cannan 👋 — DevOps engineer, single father, and cinephile. I built **open-ndi** as part of my **portable, flexible virtual cinema studio architecture** project. I needed a completely open-source way to transport live video over a LAN—just like NDI--without closed-source baggage. This is my gift to fellow creators who want low-latency, peer-to-peer video streaming you can drop into any Docker-based studio rig.

## Repository Layout

```text
open-ndi/
├── cmd/
│   ├── sender/       # "open-ndi-sender" binary
│   └── receiver/     # "open-ndi-receiver" binary
├── internal/         # shared libraries (mDNS, TCP control, UDP streaming)
├── Dockerfile.sender
├── Dockerfile.receiver
├── go.mod
└── README.md
``` 

## Outline of Application Requirements

- **cmd/sender**  
  Advertises via mDNS, negotiates over TCP, then pumps UDP packets to your director’s monitor.

- **cmd/receiver**  
  Discovers the sender, handshakes over TCP, then logs or processes incoming UDP frames.

- **internal/**  
  • **discovery**: zeroconf mDNS helpers  
  • **control**: JSON-over-TCP control plane  
  • **streaming**: UDP I/O routines

## Why I Made This

I’m constantly on the move—shooting on location or in improvised studio spaces. Proprietary protocols felt limiting for a truly portable setup. With **open-ndi** you get:

- **Ultra-low latency**: UDP for media, DTLS-like security is on my roadmap  
- **Plug-and-play discovery**: mDNS means zero config in the field  
- **Docker-ready**: Spin it up in seconds on any machine or Pi cluster  

This is the backbone of my **virtual cinema studio**. I’m sharing it so you can build your own director’s monitor, virtual production pipeline, or multi-room screening setup.

## Quickstart

### 1. **Build the images**  
 
```bash
docker build -f Dockerfile.sender   -t open-ndi-sender   .
docker build -f Dockerfile.receiver -t open-ndi-receiver .
```

### 2. Wire it into your docker-compose.yml

```yaml
services:
 ndi-sender:
   image: open-ndi-sender
   ports:
     - "9000:9000/tcp"
     - "5000:5000/udp"

 ndi-receiver:
   image: open-ndi-receiver
   depends_on:
     - ndi-sender
networks:
 default:
   driver: bridge
```

### 3. Bring it online

```bash
docker-compose up
```

- Sender will announce itself and wait on TCP 9000.
- Receiver will discover, negotiate, and log incoming UDP packets on port 5000.

### How to Use Locally

If you prefer Go straight from source, install Go 1.20+ and run inside each folder:

```bash
cd cmd/sender   && go run .
cd cmd/receiver && go run .
```

## Join the Journey

I’m on a quest to wrap cloud-native DevOps principles around real-world cinema workflows. If you:

- ❤️ Love open source
- 🎥 Are building virtual production or remote director tools
- 🚀 Want to push low-latency streaming on Docker / Kubernetes

…then open-ndi is for you. Let’s make portable, flexible studios accessible to everyone.

## Contributing

1. Fork the repo
2. Create a branch (feature/…)
3. Add your enhancements in internal/ or cmd/
4. Send a PR -- I’ll review and merge!

Please follow Go best practices and keep shared logic in internal/ so it stays private to this module.

## License

MIT © David Cannan [Cdaprod](github.com/Cdaprod)

Feel free to tweak and share on GitHub, your blog, or Twitter. Let’s build the future of virtual cinema together!