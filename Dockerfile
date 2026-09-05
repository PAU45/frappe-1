FROM python:3.11-slim

LABEL maintainer="paulin"
LABEL description="Frappe/ERPNext for Render with PostgreSQL"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FRAPPE_SITE=paulo \
    DB_HOST=dpg-dadlkh67bikc73b97o00-a.virginia-postgres.render.com \
    DB_PORT=5432 \
    DB_NAME=frappe_db_xks5 \
    DB_USER=frappe_db_xks5_user \
    DB_PASSWORD=M7QS0C3X3QoNu0iaMlcGs9dUmvcnO3ns \
    REDIS_CACHE=redis://red-dadll7e7bikc73b9aac0:6379 \
    REDIS_QUEUE=redis://red-dadll7e7bikc73b9aac0:6379 \
    REDIS_SOCKETIO=redis://red-dadll7e7bikc73b9aac0:6379 \
    ADMIN_PASSWORD=2005 \
    WORKERS_CLASS=gthread \
    GUNICORN_WORKERS=4 \
    GUNICORN_THREADS=4

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    wget \
    pkg-config \
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

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash frappe

USER frappe
WORKDIR /home/frappe

RUN python3 -m venv env && \
    . env/bin/activate && \
    pip install --upgrade pip && \
    pip install frappe-bench

ENV PATH="/home/frappe/env/bin:$PATH"

RUN bench init --skip-redis-config-generation --frappe-branch version-16 frappe-bench

COPY --chown=frappe:frappe setup_db_patch.py /home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/setup_db.py

WORKDIR /home/frappe/frappe-bench

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000 9000

USER frappe

ENTRYPOINT ["/entrypoint.sh"]
