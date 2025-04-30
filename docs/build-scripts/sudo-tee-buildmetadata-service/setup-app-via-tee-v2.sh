#!/bin/bash

sudo tee metadata-service/app/__init__.py << 'EOF'
"""
Cdaprod Metadata Service
------------------------
A metadata service for handling event processing and system control.
"""
__version__ = "1.0.0"
EOF

sudo tee metadata-service/app/main.py << 'EOF'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api import events, health, control
from app.core.config import settings
from app.core.logger import setup_logger

# Setup application logger
logger = setup_logger("metadata_service")

app = FastAPI(
    title=settings.PROJECT_NAME,
    description=settings.PROJECT_DESCRIPTION,
    version=settings.VERSION,
    docs_url="/docs",
    redoc_url="/redoc",
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include routers
app.include_router(health.router, prefix="/health", tags=["Health"])
app.include_router(events.router, prefix="/events", tags=["Events"])
app.include_router(control.router, prefix="/control", tags=["Control Plane"])

@app.on_event("startup")
async def startup_event():
    logger.info(f"Starting {settings.PROJECT_NAME} v{settings.VERSION}")

@app.on_event("shutdown")
async def shutdown_event():
    logger.info(f"Shutting down {settings.PROJECT_NAME}")

if __name__ == "__main__":
    import uvicorn
    uvicorn.run("app.main:app", host=settings.HOST, port=settings.PORT, reload=settings.DEBUG)
EOF

sudo tee metadata-service/app/api/__init__.py << 'EOF'
# Empty __init__.py for the API package
EOF

sudo tee metadata-service/app/api/events.py << 'EOF'
from fastapi import APIRouter, Query, HTTPException, Body, Depends
from typing import Optional, Dict, Any
from datetime import datetime
from pydantic import BaseModel, Field
from app.core.rabbitmq import RabbitMQClient
from app.core.logger import setup_logger

logger = setup_logger("events_api")
router = APIRouter()

class EventData(BaseModel):
    user: Optional[str] = None
    stream: Optional[str] = None
    additional_data: Optional[Dict[str, Any]] = Field(default_factory=dict)

class EventResponse(BaseModel):
    status: str
    event_id: str
    timestamp: datetime

def get_rabbitmq_client():
    return RabbitMQClient()

@router.post("/on_publish", response_model=EventResponse)
async def on_publish(
    data: EventData = Body(...),
    rabbitmq: RabbitMQClient = Depends(get_rabbitmq_client)
):
    event_id = f"pub-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{data.user or 'unknown'}"
    enriched_data = {
        "event_id": event_id,
        "event_type": "on_publish",
        "timestamp": datetime.utcnow().isoformat(),
        "data": data.dict(),
        "provenance": {
            "processed_by": "metadata_enricher",
            "processed_at": datetime.utcnow().isoformat(),
            "version": "1.0.0",
        }
    }
    try:
        rabbitmq.publish_message("stream_events", enriched_data)
        logger.info(f"Processed on_publish event: {event_id}")
        return {
            "status": "success",
            "event_id": event_id,
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        logger.error(f"Failed to process on_publish event: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to process event: {str(e)}")

@router.post("/on_publish_done", response_model=EventResponse)
async def on_publish_done(
    data: EventData = Body(...),
    rabbitmq: RabbitMQClient = Depends(get_rabbitmq_client)
):
    event_id = f"pubdone-{datetime.utcnow().strftime('%Y%m%d%H%M%S')}-{data.user or 'unknown'}"
    enriched_data = {
        "event_id": event_id,
        "event_type": "on_publish_done",
        "timestamp": datetime.utcnow().isoformat(),
        "data": data.dict(),
        "provenance": {
            "processed_by": "metadata_enricher",
            "processed_at": datetime.utcnow().isoformat(),
            "version": "1.0.0",
        }
    }
    try:
        rabbitmq.publish_message("stream_events", enriched_data)
        logger.info(f"Processed on_publish_done event: {event_id}")
        return {
            "status": "success",
            "event_id": event_id,
            "timestamp": datetime.utcnow()
        }
    except Exception as e:
        logger.error(f"Failed to process on_publish_done event: {str(e)}")
        raise HTTPException(status_code=500, detail=f"Failed to process event: {str(e)}")
EOF

sudo tee metadata-service/app/api/health.py << 'EOF'
from fastapi import APIRouter, Depends
from typing import Dict, Any
from pydantic import BaseModel
from app.core.rabbitmq import RabbitMQClient
from app.core.dockerctl import DockerControl

router = APIRouter()

class HealthResponse(BaseModel):
    status: str
    components: Dict[str, Any]

def get_rabbitmq_client():
    return RabbitMQClient()

def get_docker_control():
    return DockerControl()

@router.get("/", response_model=HealthResponse)
async def health(
    rabbitmq: RabbitMQClient = Depends(get_rabbitmq_client),
    docker: DockerControl = Depends(get_docker_control)
):
    rabbitmq_status = "healthy"
    docker_status = "healthy"
    try:
        rabbitmq.check_connection()
    except Exception:
        rabbitmq_status = "unhealthy"
    try:
        docker.check_daemon()
    except Exception:
        docker_status = "unhealthy"
    overall_status = "healthy" if all(s == "healthy" for s in [rabbitmq_status, docker_status]) else "degraded"
    return {
        "status": overall_status,
        "components": {
            "api": "healthy",
            "rabbitmq": rabbitmq_status,
            "docker": docker_status
        }
    }
EOF

sudo tee metadata-service/app/api/control.py << 'EOF'
from fastapi import APIRouter, HTTPException, Depends, Body
from typing import Dict, Any, Optional
from datetime import datetime
from pydantic import BaseModel, Field
from app.core.dockerctl import DockerControl
from app.core.logger import setup_logger

logger = setup_logger("control_api")
router = APIRouter()

class ServiceRequest(BaseModel):
    name: str
    parameters: Optional[Dict[str, Any]] = Field(default_factory=dict)

class ServiceResponse(BaseModel):
    status: str
    service: str
    timestamp: datetime
    result: Dict[str, Any]

def get_docker_control():
    return DockerControl()

@router.post("/start_service", response_model=ServiceResponse)
async def control_start_service(
    service: ServiceRequest = Body(...),
    docker: DockerControl = Depends(get_docker_control)
):
    try:
        result = docker.start_service(service.name, service.parameters)
        logger.info(f"Started service: {service.name}")
        return {
            "status": "success",
            "service": service.name,
            "timestamp": datetime.utcnow(),
            "result": result
        }
    except Exception as e:
        logger.error(f"Failed to start service {service.name}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/stop_service", response_model=ServiceResponse)
async def control_stop_service(
    service: ServiceRequest = Body(...),
    docker: DockerControl = Depends(get_docker_control)
):
    try:
        result = docker.stop_service(service.name, service.parameters)
        logger.info(f"Stopped service: {service.name}")
        return {
            "status": "success",
            "service": service.name,
            "timestamp": datetime.utcnow(),
            "result": result
        }
    except Exception as e:
        logger.error(f"Failed to stop service {service.name}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/restart_service", response_model=ServiceResponse)
async def control_restart_service(
    service: ServiceRequest = Body(...),
    docker: DockerControl = Depends(get_docker_control)
):
    try:
        result = docker.restart_service(service.name, service.parameters)
        logger.info(f"Restarted service: {service.name}")
        return {
            "status": "success",
            "service": service.name,
            "timestamp": datetime.utcnow(),
            "result": result
        }
    except Exception as e:
        logger.error(f"Failed to restart service {service.name}: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))
EOF

sudo tee metadata-service/app/core/__init__.py << 'EOF'
# Empty __init__.py for core package
EOF

sudo tee metadata-service/app/core/config.py << 'EOF'
import os
from typing import List
from pydantic import BaseSettings

class Settings(BaseSettings):
    PROJECT_NAME: str = "Cdaprod Metadata Service Control Plane"
    PROJECT_DESCRIPTION: str = "API for controlling metadata services and processing events"
    VERSION: str = "1.0.0"
    DEBUG: bool = os.getenv("DEBUG", "False").lower() == "true"
    HOST: str = os.getenv("HOST", "0.0.0.0")
    PORT: int = int(os.getenv("PORT", "5000"))
    CORS_ORIGINS: List[str] = [
        "http://localhost",
        "http://localhost:8080",
        "http://localhost:3000",
    ]
    RABBITMQ_HOST: str = os.getenv("RABBITMQ_HOST", "rabbitmq")
    RABBITMQ_PORT: int = int(os.getenv("RABBITMQ_PORT", "5672"))
    RABBITMQ_USER: str = os.getenv("RABBITMQ_DEFAULT_USER", "guest")
    RABBITMQ_PASS: str = os.getenv("RABBITMQ_DEFAULT_PASS", "guest")
    DOCKER_COMPOSE_FILE: str = os.getenv("DOCKER_COMPOSE_FILE", "docker-compose.yml")
    DOCKER_PROJECT_NAME: str = os.getenv("DOCKER_PROJECT_NAME", "cdaprod")

    class Config:
        case_sensitive = True

settings = Settings()
EOF

sudo tee metadata-service/app/core/rabbitmq.py << 'EOF'
import os
import json
import logging
import pika
from typing import Dict, Any
from app.core.config import settings

logger = logging.getLogger("rabbitmq")

class RabbitMQClient:
    def __init__(
        self,
        host: str = settings.RABBITMQ_HOST,
        port: int = settings.RABBITMQ_PORT,
        user: str = settings.RABBITMQ_USER,
        password: str = settings.RABBITMQ_PASS
    ):
        self.host = host
        self.port = port
        self.user = user
        self.password = password
        self._connection = None
        self._channel = None

    def _get_connection_params(self) -> pika.ConnectionParameters:
        credentials = pika.PlainCredentials(self.user, self.password)
        return pika.ConnectionParameters(
            host=self.host,
            port=self.port,
            credentials=credentials,
            connection_attempts=3,
            retry_delay=5,
            heartbeat=600
        )

    def get_connection(self) -> pika.BlockingConnection:
        if self._connection is None or self._connection.is_closed:
            try:
                self._connection = pika.BlockingConnection(self._get_connection_params())
                logger.info("Connected to RabbitMQ successfully")
            except Exception as e:
                logger.error(f"Failed to connect to RabbitMQ: {e}")
                raise
        return self._connection

    def get_channel(self) -> pika.channel.Channel:
        if self._channel is None or self._channel.is_closed:
            connection = self.get_connection()
            self._channel = connection.channel()
        return self._channel

    def check_connection(self) -> bool:
        try:
            connection = self.get_connection()
            return not connection.is_closed
        except Exception as e:
            logger.error(f"RabbitMQ connection check failed: {e}")
            return False

    def publish_message(self, queue: str, message: Dict[str, Any], exchange: str = "") -> bool:
        try:
            channel = self.get_channel()
            channel.queue_declare(queue=queue, durable=True)
            channel.basic_publish(
                exchange=exchange,
                routing_key=queue,
                body=json.dumps(message),
                properties=pika.BasicProperties(
                    delivery_mode=2,
                    content_type="application/json"
                )
            )
            logger.info(f"Message published to queue '{queue}'")
            return True
        except Exception as e:
            logger.error(f"Failed to publish message to queue '{queue}': {e}")
            self._connection = None
            self._channel = None
            raise

def publish_message(queue: str, message: Dict[str, Any]) -> bool:
    client = RabbitMQClient()
    return client.publish_message(queue, message)
EOF

sudo tee metadata-service/app/core/dockerctl.py << 'EOF'
import subprocess
import logging
import json
from typing import Dict, Any, Optional, List
from app.core.config import settings

logger = logging.getLogger("dockerctl")

class DockerControl:
    def __init__(
        self,
        compose_file: str = settings.DOCKER_COMPOSE_FILE,
        project_name: str = settings.DOCKER_PROJECT_NAME
    ):
        self.compose_file = compose_file
        self.project_name = project_name

    def _run_docker_compose_command(self, args: List[str]) -> Dict[str, Any]:
        cmd = ["docker-compose", "-f", self.compose_file, "-p", self.project_name] + args
        try:
            result = subprocess.run(
                cmd,
                check=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True
            )
            output = result.stdout.strip()
            logger.info(f"Docker command executed: {' '.join(cmd)}")
            return {
                "success": True,
                "command": " ".join(cmd),
                "output": output,
                "returncode": result.returncode
            }
        except subprocess.CalledProcessError as e:
            error = e.stderr.strip()
            logger.error(f"Docker command failed: {' '.join(cmd)}, Error: {error}")
            return {
                "success": False,
                "command": " ".join(cmd),
                "error": error,
                "returncode": e.returncode
            }

    def check_daemon(self) -> bool:
        try:
            subprocess.run(
                ["docker", "info"],
                check=True,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            return True
        except subprocess.CalledProcessError:
            return False

    def start_service(self, service_name: str, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        args = ["up", "-d"]
        if options and options.get("recreate", False):
            args.append("--force-recreate")
        args.append(service_name)
        return self._run_docker_compose_command(args)

    def stop_service(self, service_name: str, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        args = ["stop"]
        if options and options.get("timeout"):
            args.extend(["--timeout", str(options["timeout"])])
        args.append(service_name)
        return self._run_docker_compose_command(args)

    def restart_service(self, service_name: str, options: Optional[Dict[str, Any]] = None) -> Dict[str, Any]:
        args = ["restart"]
        if options and options.get("timeout"):
            args.extend(["--timeout", str(options["timeout"])])
        args.append(service_name)
        return self._run_docker_compose_command(args)

    def get_service_status(self, service_name: Optional[str] = None) -> Dict[str, Any]:
        args = ["ps", "--format", "json"]
        if service_name:
            args.append(service_name)
        result = self._run_docker_compose_command(args)
        if result["success"] and result["output"]:
            try:
                return {
                    "success": True,
                    "services": json.loads(result["output"])
                }
            except json.JSONDecodeError:
                return {
                    "success": False,
                    "error": "Failed to parse service status output"
                }
        return result

def start_service(service_name: str) -> str:
    docker = DockerControl()
    result = docker.start_service(service_name)
    if not result["success"]:
        raise Exception(result["error"])
    return result["output"]

def stop_service(service_name: str) -> str:
    docker = DockerControl()
    result = docker.stop_service(service_name)
    if not result["success"]:
        raise Exception(result["error"])
    return result["output"]
EOF

sudo tee metadata-service/app/core/logger.py << 'EOF'
import logging
import sys
from typing import Optional

def setup_logger(name: str, level: int = logging.INFO) -> logging.Logger:
    logger = logging.getLogger(name)
    if logger.hasHandlers():
        return logger
    logger.setLevel(level)
    logger.propagate = False
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(level)
    formatter = logging.Formatter("%(asctime)s - %(name)s - %(levelname)s - %(message)s",
                                  datefmt="%Y-%m-%d %H:%M:%S")
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    return logger
EOF

sudo tee metadata-service/app/services/__init__.py << 'EOF'
# Empty __init__.py for services package
EOF

sudo tee metadata-service/app/services/blender.py << 'EOF'
from typing import Dict, Any, Optional
import logging
from app.core.logger import setup_logger

logger = setup_logger("blender_service")

class BlenderService:
    def __init__(self, config: Optional[Dict[str, Any]] = None):
        self.config = config or {}
    
    def start_job(self, job_config: Dict[str, Any]) -> Dict[str, Any]:
        logger.info(f"Starting Blender job with config: {job_config}")
        if not job_config.get("blend_file"):
            raise ValueError("blend_file is required in job_config")
        merged_config = {**self.config, **job_config}
        return {
            "status": "started",
            "job_id": "blender-1234",
            "job_config": merged_config
        }
    
    def check_job_status(self, job_id: str) -> Dict[str, Any]:
        logger.info(f"Checking status for Blender job: {job_id}")
        return {
            "status": "rendering",
            "job_id": job_id,
            "progress": 50,
            "estimated_time_remaining": "00:30:00"
        }

def start_blender_job(job_config: Dict[str, Any]) -> Dict[str, Any]:
    service = BlenderService()
    return service.start_job(job_config)
EOF

sudo tee metadata-service/app/services/obs.py << 'EOF'
from typing import Dict, Any, Optional
import logging
from app.core.logger import setup_logger

logger = setup_logger("obs_service")

class OBSService:
    def __init__(self, host: str = "localhost", port: int = 4444):
        self.host = host
        self.port = port
    
    def execute_action(self, action: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
        logger.info(f"Executing OBS action: {action} with parameters: {parameters}")
        if action == "switch_scene":
            if "scene_name" not in parameters:
                raise ValueError("scene_name is required for switch_scene action")
            scene_name = parameters["scene_name"]
            logger.info(f"Switching to scene: {scene_name}")
            return {
                "status": "success",
                "action": action,
                "scene": scene_name
            }
        elif action == "start_recording":
            logger.info("Starting recording")
            return {
                "status": "success",
                "action": action,
                "recording": True
            }
        elif action == "stop_recording":
            logger.info("Stopping recording")
            return {
                "status": "success",
                "action": action,
                "recording": False
            }
        else:
            raise ValueError(f"Unsupported action: {action}")

def control_obs(action: str, parameters: Dict[str, Any]) -> Dict[str, Any]:
    service = OBSService()
    return service.execute_action(action, parameters)
EOF

sudo tee metadata-service/app/monitor/__init__.py << 'EOF'
# Empty __init__.py for monitor package
EOF

sudo tee metadata-service/app/monitor/device_monitor.py << 'EOF'
import requests
import logging
from typing import Dict, Any
from app.core.logger import setup_logger

logger = setup_logger("device_monitor")

class DeviceMonitor:
    def __init__(self, timeout: int = 5):
        self.timeout = timeout
    
    def check_device(self, ip: str, port: int = None) -> Dict[str, Any]:
        url = f"http://{ip}"
        if port:
            url = f"{url}:{port}"
        url = f"{url}/status"
        try:
            response = requests.get(url, timeout=self.timeout)
            response.raise_for_status()
            status = response.json()
            logger.info(f"Device at {ip} is reachable: {status}")
            return {"status": "online", "ip": ip, "device_status": status}
        except requests.HTTPError as e:
            logger.warning(f"HTTP error monitoring device at {ip}: {e}")
            return {"status": "error", "ip": ip, "message": f"HTTP error: {e}"}
        except requests.ConnectionError:
            logger.warning(f"Connection error monitoring device at {ip}")
            return {"status": "offline", "ip": ip, "message": "Connection failed"}
        except requests.Timeout:
            logger.warning(f"Timeout monitoring device at {ip}")
            return {"status": "timeout", "ip": ip, "message": f"Connection timed out after {self.timeout}s"}
        except Exception as e:
            logger.error(f"Error monitoring device at {ip}: {e}")
            return {"status": "error", "ip": ip, "message": str(e)}
    
    def check_devices(self, ips: list) -> Dict[str, Dict[str, Any]]:
        results = {}
        for ip in ips:
            results[ip] = self.check_device(ip)
        return results

def monitor_device(ip: str) -> Dict[str, Any]:
    monitor = DeviceMonitor()
    return monitor.check_device(ip)
EOF