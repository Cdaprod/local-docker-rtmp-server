import os
import json
import logging
import requests
import pika
from datetime import datetime
from fastapi import FastAPI, Query
from typing import Dict, Optional

# Initialize FastAPI app
app = FastAPI()

# Configure logging
LOG_FORMAT = "%(asctime)s - %(levelname)s - %(message)s"
logging.basicConfig(level=logging.INFO, format=LOG_FORMAT)
logger = logging.getLogger("VideoEventBroker")

# RabbitMQ connection parameters
RABBITMQ_HOST = os.getenv('RABBITMQ_HOST', 'rabbitmq')
RABBITMQ_USER = os.getenv('RABBITMQ_DEFAULT_USER', 'guest')
RABBITMQ_PASS = os.getenv('RABBITMQ_DEFAULT_PASS', 'guest')

def get_rabbitmq_connection():
    """
    Establish a connection to RabbitMQ.
    """
    try:
        credentials = pika.PlainCredentials(RABBITMQ_USER, RABBITMQ_PASS)
        parameters = pika.ConnectionParameters(host=RABBITMQ_HOST, credentials=credentials)
        connection = pika.BlockingConnection(parameters)
        logger.info("Connected to RabbitMQ successfully.")
        return connection
    except Exception as e:
        logger.error(f"Failed to connect to RabbitMQ: {e}")
        raise

def publish_message(queue: str, message: Dict):
    """
    Publish a message to the specified RabbitMQ queue.
    """
    try:
        connection = get_rabbitmq_connection()
        channel = connection.channel()
        channel.queue_declare(queue=queue, durable=True)
        channel.basic_publish(
            exchange='',
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

@app.get("/health")
async def health_check():
    """ Metadata-Service: Health check endpoint. """
    return {"status": "healthy"}

@app.get("/on_publish")
async def on_publish(user: Optional[str] = Query(None), stream: Optional[str] = Query(None)):
    """
    Handle the 'on_publish' event.
    """
    try:
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
        logger.info(f"Processed 'on_publish' event with data: {data}")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Error processing 'on_publish' event: {e}")
        return {"status": "error", "message": str(e)}

@app.get("/on_publish_done")
async def on_publish_done(user: Optional[str] = Query(None), stream: Optional[str] = Query(None)):
    """
    Handle the 'on_publish_done' event.
    """
    try:
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
        logger.info(f"Processed 'on_publish_done' event with data: {data}")
        return {"status": "success"}
    except Exception as e:
        logger.error(f"Error processing 'on_publish_done' event: {e}")
        return {"status": "error", "message": str(e)}

def monitor_device(ip: str):
    """
    Monitor the status of a device via its IP address.
    """
    try:
        response = requests.get(f"http://{ip}/status", timeout=5)
        status = response.json()
        logger.info(f"Device at {ip} is reachable: {status}")
        return status
    except Exception as e:
        logger.error(f"Error monitoring device at {ip}: {e}")
        return {"status": "error", "message": str(e)}

@app.on_event("startup")
def startup_event():
    """ Run this function when the FastAPI app starts. """
    device_ip = "192.168.0.10"
    logger.info(f"Starting Video Event Broker with device monitoring for IP: {device_ip}")
    device_status = monitor_device(device_ip)
    logger.info(f"Initial device status: {device_status}")