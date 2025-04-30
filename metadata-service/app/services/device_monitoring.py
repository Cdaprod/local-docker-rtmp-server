import requests
import logging

logger = logging.getLogger("DeviceMonitor")

def monitor_device(ip: str):
    try:
        response = requests.get(f"http://{ip}/status", timeout=5)
        status = response.json()
        logger.info(f"Device at {ip} status: {status}")
        return status
    except Exception as e:
        logger.error(f"Device at {ip} unreachable: {e}")
        return {"status": "error", "message": str(e)}