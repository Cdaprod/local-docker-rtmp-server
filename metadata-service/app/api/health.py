from fastapi import APIRouter, Depends
from typing import Dict, Any
from pydantic import BaseModel
from app.core.rabbitmq import RabbitMQClient
from app.core.dockerctl import DockerControl
from app.core.minio_client import MinIOClient

router = APIRouter()

class HealthResponse(BaseModel):
    status: str
    components: Dict[str, Any]

def get_rabbitmq_client():
    return RabbitMQClient()

def get_docker_control():
    return DockerControl()

def get_minio_client():
    return MinIOClient()

@router.get("/", response_model=HealthResponse)
async def health(
    rabbitmq: RabbitMQClient = Depends(get_rabbitmq_client),
    docker: DockerControl = Depends(get_docker_control),
    minio: MinIOClient = Depends(get_minio_client)
):
    rabbitmq_status = "healthy"
    docker_status = "healthy"
    minio_status = "healthy"
    
    try:
        rabbitmq.check_connection()
    except Exception:
        rabbitmq_status = "unhealthy"
    
    try:
        docker.check_daemon()
    except Exception:
        docker_status = "unhealthy"
    
    try:
        minio.check_connection()
    except Exception:
        minio_status = "unhealthy"
    
    overall_status = "healthy" if all(
        status == "healthy" for status in [rabbitmq_status, docker_status, minio_status]
    ) else "degraded"
    
    return {
        "status": overall_status,
        "components": {
            "api": "healthy",
            "rabbitmq": rabbitmq_status,
            "docker": docker_status,
            "minio": minio_status
        }
    }
