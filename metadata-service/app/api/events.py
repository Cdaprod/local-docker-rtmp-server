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
