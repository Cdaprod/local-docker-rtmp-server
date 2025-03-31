Access Services:

	•	OBS Web GUI: https://obs.${TS_CERT_DOMAIN}
	•	VNC: vnc://${TS_CERT_DOMAIN} (Native VNC Viewer)
	•	RTMP Endpoint: rtmp://${TS_CERT_DOMAIN}
	•	OBS WebSocket: ws://ws.${TS_CERT_DOMAIN}

`tailscale serve --config /path/to/TS_SERVE_CONFIG.json --accept-routes`

`tailscale serve status`

Or is using docker-compose:

```yaml
services:
  tailscale:
    image: tailscale/tailscale
    volumes:
      - ./config/TS_SERVE_CONFIG.json:/var/lib/tailscale/TS_SERVE_CONFIG.json
```  