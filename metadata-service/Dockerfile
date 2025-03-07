# Use official Python runtime as a parent image
FROM python:3.9-slim

# Set the working directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy the requirements.txt and install Python dependencies
COPY ./requirements.txt /app/requirements.txt
RUN pip3 install --no-cache-dir -r /app/requirements.txt

# Copy the application code
COPY app.py .
COPY healthcheck.sh .

# Ensure healthcheck script is executable
RUN chmod +x healthcheck.sh

# Expose port if needed (optional)
EXPOSE 5000

# Define environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

# Run the application
# CMD ["python", "app.py"]

# Run the application in development mode
ENV FLASK_APP=app.py
ENV FLASK_ENV=development
ENV FLASK_DEBUG=1

# CMD ["flask", "run", "--host=0.0.0.0", "--port=5000", "--reload"] # Flask
CMD ["gunicorn", "app:app", "-w", "4", "-b", "0.0.0.0:5000"]