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
