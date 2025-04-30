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
