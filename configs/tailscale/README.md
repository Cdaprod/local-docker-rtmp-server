Access Services:

	•	OBS Web GUI: https://obs.${TS_CERT_DOMAIN}
	•	VNC: vnc://${TS_CERT_DOMAIN} (Native VNC Viewer)
	•	RTMP Endpoint: rtmp://${TS_CERT_DOMAIN}
	•	OBS WebSocket: ws://ws.${TS_CERT_DOMAIN}

tailscale serve --config /path/to/TS_SERVE_CONFIG.json --accept-routes

tailscale serve status