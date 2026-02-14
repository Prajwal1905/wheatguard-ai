FROM python:3.10-slim

WORKDIR /app

RUN apt-get update && apt-get install -y \
    build-essential \
    libpq-dev \
    gcc \
    g++ \
    curl \
    libgl1 \
    libglib2.0-0 \
    && rm -rf /var/lib/apt/lists/*

ENV PIP_DEFAULT_TIMEOUT=1000
ENV PIP_NO_CACHE_DIR=1

COPY backend/requirements.txt .

RUN pip install --upgrade pip && \
    pip install --retries 20 --timeout 1000 -r requirements.txt

COPY backend/app ./app
COPY backend/uploads ./uploads

EXPOSE 8000

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000"]
