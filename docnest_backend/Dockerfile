FROM python:3.11-slim-bullseye

WORKDIR /app

# Install system dependencies including libmagic
RUN apt-get update && \
    apt-get install -y --no-install-recommends \
    curl \
    libmagic1 \
    file \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first to leverage Docker cache
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the rest of the application
COPY . .

EXPOSE 80

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "80"]