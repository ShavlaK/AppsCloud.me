FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY *.py ./
COPY templates/ ./templates/
COPY config.json.example ./config.json.example

# Create necessary directories
RUN mkdir -p data logs

# Expose web server port
EXPOSE 8080

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV WEB_HOST=0.0.0.0
ENV WEB_PORT=8080

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8080/api/status || exit 1

# Run the application
CMD ["python", "main.py"]
