from fastapi import APIRouter, Query
from typing import Optional
from datetime import datetime
from app.services.rabbitmq_service import publish_message

router = APIRouter()

@router.get("/health")
async def health_check():
    """Simple health check."""
    return {"status": "healthy"}

@router.get("/on_publish")
async def on_publish(
    app: Optional[str] = Query(None),
    name: Optional[str] = Query(None),
    addr: Optional[str] = Query(None),
    clientid: Optional[str] = Query(None)
):
    data = {"app": app, "name": name, "addr": addr, "clientid": clientid}
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
    return {"status": "success"}

@router.get("/on_publish_done")
async def on_publish_done(
    user: Optional[str] = Query(None),
    stream: Optional[str] = Query(None)
):
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
    return {"status": "success"}