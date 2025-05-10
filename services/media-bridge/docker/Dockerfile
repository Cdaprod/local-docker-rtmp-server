FROM python:3.11-slim

WORKDIR /app
COPY . .

RUN pip install watchdog requests pyyaml

ENTRYPOINT ["python", "media_bridge_agent.py"]
