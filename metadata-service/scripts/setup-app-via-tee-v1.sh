#!/bin/bash

sudo tee metadata-service/app/__init__.py << 'EOF'
# Empty __init__.py for package initialization
EOF

sudo tee metadata-service/app/main.py << 'EOF'
from fastapi import FastAPI
from app.api import events, health, control

app = FastAPI(title="Cdaprod Metadata Service Control Plane")

app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(events.router, prefix="/events", tags=["Events"])
app.include_router(control.router, prefix="/control", tags=["Control Plane"])

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host="0.0.0.0", port=5000, reload=True)
EOF

sudo tee metadata-service/app/api/__init__.py << 'EOF'
# Empty __init__.py for the API package
EOF

sudo tee metadata-service/app/api/events.py << 'EOF'
from fastapi import APIRouter, Query
from datetime import datetime
from app.core.rabbitmq import publish_message
import logging

router = APIRouter()
logger = logging.getLogger("EventsAPI")

@router.get("/on_publish")
async def on_publish(user: str = Query(None), stream: str = Query(None)):
    data = {"user": user, "stream": stream}
    enriched_data = {
        "event_type": "on_publish",
        "timestamp": datetime.utcnow().isoformat(),
        "data": data,
        "provenance": {
            "processed_by": "metadata_enricher",
            "processed_at": datetime.utcnow().isoformat(),
            "version": "1.0.0",
        }
    }
    publish_message("stream_events", enriched_data)
    logger.info(f"Processed on_publish event: {data}")
    return {"status": "success"}

@router.get("/on_publish_done")
async def on_publish_done(user: str = Query(None), stream: str = Query(None)):
    data = {"user": user, "stream": stream}
    enriched_data = {
        "event_type": "on_publish_done",
        "timestamp": datetime.utcnow().isoformat(),
        "data": data,
        "provenance": {
            "processed_by": "metadata_enricher",
            "processed_at": datetime.utcnow().isoformat(),
            "version": "1.0.0",
        }
    }
    publish_message("stream_events", enriched_data)
    logger.info(f"Processed on_publish_done event: {data}")
    return {"status": "success"}
EOF

sudo tee metadata-service/app/api/health.py << 'EOF'
from fastapi import APIRouter

router = APIRouter()

@router.get("/")
async def health():
    return {"status": "healthy"}
EOF

sudo tee metadata-service/app/api/control.py << 'EOF'
from fastapi import APIRouter, HTTPException
from app.core.dockerctl import start_service, stop_service
from datetime import datetime

router = APIRouter()

@router.post("/start_service")
async def control_start_service(name: str):
    try:
        result = start_service(name)
        return {
            "status": "success",
            "started_at": datetime.utcnow().isoformat(),
            "result": result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stop_service")
async def control_stop_service(name: str):
    try:
        result = stop_service(name)
        return {
            "status": "success",
            "stopped_at": datetime.utcnow().isoformat(),
            "result": result
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
EOF

sudo tee metadata-service/app/core/__init__.py << 'EOF'
# Empty __init__.py for the core package
EOF

sudo tee metadata-service/app/core/rabbitmq.py << 'EOF'
import os
import json
import logging
import pika

logger = logging.getLogger("RabbitMQCore")

RABBITMQ_HOST = os.getenv("RABBITMQ_HOST", "rabbitmq")
RABBITMQ_USER = os.getenv("RABBITMQ_DEFAULT_USER", "guest")
RABBITMQ_PASS = os.getenv("RABBITMQ_DEFAULT_PASS", "guest")

def get_rabbitmq_connection():
    try:
        credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
        parameters = pika.ConnectionParameters(host=RABBITMQ_HOST, credentials=credentials)
        connection = pika.BlockingConnection(parameters)
        logger.info("Connected to RabbitMQ successfully.")
        return connection
    except Exception as e:
        logger.error(f"Failed to connect to RabbitMQ: {e}")
        raise

def publish_message(queue: str, message: dict):
    try:
        connection = get_rabbitmq_connection()
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=True)
        channel.basic_publish(
            exchange="",
            routing_key=queue,
            body=json.dumps(message),
            properties=pika.BasicProperties(
                delivery_mode=2,  # Make message persistent
            )
        )
        connection.close()
        logger.info(f"Message published to queue '{queue}': {message}")
    except Exception as e:
        logger.error(f"Failed to publish message to queue '{queue}': {e}")
EOF

sudo tee metadata-service/app/core/dockerctl.py << 'EOF'
import subprocess
import logging

logger = logging.getLogger("DockerCtl")

def start_service(service_name: str):
    try:
        result = subprocess.check_output(["docker-compose", "up", "-d", service_name])
        logger.info(f"Started service {service_name}")
        return result.decode("utf-8")
    except subprocess.CalledProcessError as e:
        logger.error(f"Error starting service {service_name}: {e.output.decode('utf-8')}")
        raise

def stop_service(service_name: str):
    try:
        result = subprocess.check_output(["docker-compose", "stop", service_name])
        logger.info(f"Stopped service {service_name}")
        return result.decode("utf-8")
    except subprocess.CalledProcessError as e:
        logger.error(f"Error stopping service {service_name}: {e.output.decode('utf-8')}")
        raise
EOF

sudo tee metadata-service/app/core/logger.py << 'EOF'
import logging

def setup_logger(name: str, level=logging.INFO):
    logger = logging.getLogger(name)
    if not logger.hasHandlers():
        logger.setLevel(level)
        handler = logging.StreamHandler()
        formatter = logging.Formatter("%(asctime)s - %(levelname)s - %(message)s")
        handler.setFormatter(formatter)
        logger.addHandler(handler)
    return logger
EOF

sudo tee metadata-service/app/services/__init__.py << 'EOF'
# Empty __init__.py for services package
EOF

sudo tee metadata-service/app/services/blender.py << 'EOF'
def start_blender_job(job_config: dict):
    """
    Placeholder function to launch a Blender job.
    Implement job submission to your Blender orchestration logic.
    """
    # For now, just return a dummy response.
    return {"status": "blender job started", "job_config": job_config}
EOF

sudo tee metadata-service/app/services/obs.py << 'EOF'
def control_obs(action: str, parameters: dict):
    """
    Placeholder function to control OBS.
    This could switch scenes, start/stop recording, etc.
    """
    # For now, simply return a dummy response.
    return {"status": "OBS action executed", "action": action, "parameters": parameters}
EOF

sudo tee metadata-service/app/monitor/__init__.py << 'EOF'
# Empty __init__.py for the monitor package
EOF

sudo tee metadata-service/app/monitor/device_monitor.py << 'EOF'
import requests
import logging

logger = logging.getLogger("DeviceMonitor")

def monitor_device(ip: str):
    """
    Ping a device by IP and return its status.
    """
    try:
        response = requests.get(f"http://{ip}/status", timeout=5)
        status = response.json()
        logger.info(f"Device at {ip} is reachable: {status}")
        return status
    except Exception as e:
        logger.error(f"Error monitoring device at {ip}: {e}")
        return {"status": "error", "message": str(e)}
EOF