# My Watchdog Containerized Server 
## For maintaining congruency within local development

This containerized service runs watchdog with docker and python. It is used to watch for changes on specific network shared devices—in particular it is a platform responsible for local networked, detection-triggered, automation and observability.

## Project Structure 
```
my-watchdog/
├── Dockerfile
├── requirements.txt
├── app/
│   ├── main.py
│   ├── actions/
│   │   ├── __init__.py
│   │   ├── ffmpeg_transcode.py
│   │   ├── enrich_api.py
│   │   └── ... (add new actions here)
│   └── config.yaml
├── example.env
└── README.md
```