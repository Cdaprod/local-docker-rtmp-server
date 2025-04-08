FROM python:3.11-slim

RUN apt-get update && apt-get install -y libusb-1.0-0 libusb-1.0-0-dev && \
    pip install --upgrade pip

WORKDIR /app
COPY . /app

RUN pip install -r requirements.txt

ENTRYPOINT ["python", "main.py"]