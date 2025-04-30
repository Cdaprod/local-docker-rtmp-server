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
