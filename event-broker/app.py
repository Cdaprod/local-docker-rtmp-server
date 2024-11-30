from flask import Flask, request, jsonify
import pika
import os
import json
from datetime import datetime
import requests
import logging

# Initialize Flask app
app = Flask(__name__)

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

def publish_message(queue, message):
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

@app.route('/on_publish', methods=['GET'])
def on_publish():
    """
    Handle the 'on_publish' event.
    """
    try:
        data = request.args.to_dict()
        enriched_data = {
            'event_type': 'on_publish',
            'timestamp': datetime.utcnow().isoformat(),
            'data': data,
            'provenance': {
                'processed_by': 'metadata_enricher',
                'processed_at': datetime.utcnow().isoformat(),
                'version': '1.0.0'
            }
        }
        publish_message('stream_events', enriched_data)
        logger.info(f"Processed 'on_publish' event with data: {data}")
        return jsonify({'status': 'success'}), 200
    except Exception as e:
        logger.error(f"Error processing 'on_publish' event: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

@app.route('/on_publish_done', methods=['GET'])
def on_publish_done():
    """
    Handle the 'on_publish_done' event.
    """
    try:
        data = request.args.to_dict()
        enriched_data = {
            'event_type': 'on_publish_done',
            'timestamp': datetime.utcnow().isoformat(),
            'data': data,
            'provenance': {
                'processed_by': 'metadata_enricher',
                'processed_at': datetime.utcnow().isoformat(),
                'version': '1.0.0'
            }
        }
        publish_message('stream_events', enriched_data)
        logger.info(f"Processed 'on_publish_done' event with data: {data}")
        return jsonify({'status': 'success'}), 200
    except Exception as e:
        logger.error(f"Error processing 'on_publish_done' event: {e}")
        return jsonify({'status': 'error', 'message': str(e)}), 500

def monitor_device(ip):
    """
    Monitor the status of a device via its IP address.
    """
    try:
        response = requests.get(f"http://{ip}/status", timeout=5)
        status = response.json()
        logger.info(f"Device at {ip} is reachable: {status}")
        return status
    except Exception as e:
        error_message = {"status": "error", "message": str(e)}
        logger.error(f"Error monitoring device at {ip}: {error_message}")
        return error_message

if __name__ == '__main__':
    device_ip = "192.168.0.10"
    logger.info(f"Starting Video Event Broker with device monitoring for IP: {device_ip}")
    device_status = monitor_device(device_ip)
    logger.info(f"Initial device status: {device_status}")
    app.run(host='0.0.0.0', port=5000)