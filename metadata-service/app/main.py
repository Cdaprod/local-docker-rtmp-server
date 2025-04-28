from app.api import events, health, control, storage, finalizer


app = FastAPI(
     title=settings.PROJECT_NAME,
     description=settings.PROJECT_DESCRIPTION,
     version=settings.VERSION,
     
app.include_router(health.router)
app.include_router(events.router)
app.include_router(control.router)
app.include_router(storage.router)

from fastapi import FastAPI
from app.api import events, finalizer
from app.services.device_monitoring import monitor_device

app = FastAPI(title="Metadata Service")

# Mount API Routers
app.include_router(events.router, prefix="/events", tags=["Events"])
app.include_router(finalizer.router, prefix="/finalizer", tags=["Finalizer"])

@app.on_event("startup")
async def startup_event():
    """ Startup tasks: device monitoring """
    device_ip = "192.168.0.10"
    monitor_device(device_ip)