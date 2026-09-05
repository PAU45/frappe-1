FROM python:3.11-slim

LABEL maintainer="paulin"
LABEL description="Frappe/ERPNext for Render with PostgreSQL"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FRAPPE_SITE=site1.localhost \
    DB_HOST= \
    DB_PORT=5432 \
    DB_NAME= \
    DB_USER= \
    DB_PASSWORD= \
    REDIS_CACHE=redis://localhost:6379/0 \
    REDIS_QUEUE=redis://localhost:6379/1 \
    REDIS_SOCKETIO=redis://localhost:6379/2 \
    SOCKETIO_PORT=9000 \
    WORKERS_CLASS=gthread \
    GUNICORN_WORKERS=4 \
    GUNICORN_THREADS=4

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    wget \
    python3-dev \
    python3-pip \
    python3-venv \
    libffi-dev \
    libjpeg-dev \
    liblcms2-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libtiff5-dev \
    libwebp-dev \
    libpq-dev \
    postgresql-client \
    redis-tools \
    cron \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN npm install -g yarn

RUN useradd -ms /bin/bash frappe

USER frappe
WORKDIR /home/frappe

RUN python3 -m venv env && \
    . env/bin/activate && \
    pip install --upgrade pip && \
    pip install frappe-bench

ENV PATH="/home/frappe/env/bin:$PATH"

RUN bench init --skip-redis-config-generation --frappe-branch version-15 frappe-bench

WORKDIR /home/frappe/frappe-bench

RUN bench set-config -g db_host $DB_HOST && \
    bench set-config -g db_port $DB_PORT && \
    bench set-config -g db_name $DB_NAME && \
    bench set-config -g db_password $DB_PASSWORD

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000 9000

USER frappe

ENTRYPOINT ["/entrypoint.sh"]
