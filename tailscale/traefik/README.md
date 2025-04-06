# Proceed with labeling exterior compose files

Perfect -- thanks for the correction.

You’re using streamctl just as a CLI control tool. The actual services to route traffic to are:
	•	rtmp-service
	•	metadata-service
	•	obs-pi
	•	tailscale-traefik (our load balancer)

Here’s a clean, production‑ready /tailscale-traefik/docker-compose.tailscale-traefik.yaml file that:
	•	Sets up Traefik as the edge router
	•	Runs over Tailscale network
	•	Detects the other containers via labels
	•	Serves as the central ingress for your hybrid cloud mesh

⸻

/tailscale-traefik/docker-compose.tailscale-traefik.yaml

version: "3.8"

services:
  traefik:
    container_name: tailscale-traefik
    image: traefik:v2.10
    restart: always
    command:
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"
      - "--entrypoints.rtmp.address=:1935"
      - "--entrypoints.ws.address=:4455"  # for obs-websocket
      - "--api.dashboard=true"
      - "--log.level=INFO"
      - "--accesslog=true"
      - "--certificatesresolvers.tsresolver.acme.tlschallenge=true"
      - "--certificatesresolvers.tsresolver.acme.email=admin@cdaprod.dev"
      - "--certificatesresolvers.tsresolver.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
      - "1935:1935"     # Optional: for RTMP
      - "4455:4455"     # Optional: for OBS WebSocket
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./letsencrypt:/letsencrypt
    networks:
      - tailscale

networks:
  tailscale:
    external: true



⸻

Requirements
	•	You must create a Docker external network named tailscale:

docker network create tailscale

(It connects to Tailscale either via host mode or a sidecar per service.)

⸻

Next Step: Wire Services into It

Here’s how you’d label each service in their own docker-compose files, e.g.:

rtmp-service

labels:
  - "traefik.enable=true"
  - "traefik.tcp.routers.rtmp.rule=HostSNI(`*`)"
  - "traefik.tcp.routers.rtmp.entrypoints=rtmp"
  - "traefik.tcp.services.rtmp.loadbalancer.server.port=1935"



⸻

metadata-service

labels:
  - "traefik.enable=true"
  - "traefik.http.routers.meta.rule=Host(`meta.tailnet.domain`)"
  - "traefik.http.routers.meta.entrypoints=web"
  - "traefik.http.services.meta.loadbalancer.server.port=5000"



⸻

obs-pi

labels:
  - "traefik.enable=true"
  - "traefik.tcp.routers.obs.rule=HostSNI(`*`)"
  - "traefik.tcp.routers.obs.entrypoints=ws"
  - "traefik.tcp.services.obs.loadbalancer.server.port=4455"



⸻

Summary

Your load balancer (tailscale-traefik) is now:
	•	Running in the tailscale Docker network
	•	Exposing ports 80, 443, 1935 (RTMP), and 4455 (OBS WebSocket)
	•	Ready to route to any container labeled accordingly
	•	Built to auto-renew TLS via Let’s Encrypt (if needed)
	•	Acts as the control plane entrypoint for the mesh

⸻

Let me know if you want a global .env loader, TLS fallback logic, or a preview dashboard subdomain. We can also wrap this in an Ansible playbook or GitHub Actions CD if needed.