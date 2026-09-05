FROM python:3.11-slim

LABEL maintainer="paulin"
LABEL description="Frappe/ERPNext for Render - MariaDB + Redis included"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FRAPPE_SITE=paulo \
    ADMIN_PASSWORD=2005 \
    WORKERS_CLASS=gthread \
    GUNICORN_WORKERS=4 \
    GUNICORN_THREADS=4 \
    DEBIAN_FRONTEND=noninteractive

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
    mariadb-server \
    mariadb-client \
    redis-server \
    cron \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - && \
    apt-get install -y nodejs && \
    npm install -g yarn && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

RUN useradd -ms /bin/bash frappe

RUN mkdir -p /var/run/mysqld /var/run/redis && \
    chown mysql:mysql /var/run/mysqld && \
    chown redis:redis /var/run/redis

USER frappe
WORKDIR /home/frappe

RUN python3 -m venv env && \
    . env/bin/activate && \
    pip install --upgrade pip && \
    pip install frappe-bench

ENV PATH="/home/frappe/env/bin:$PATH"

RUN bench init --skip-redis-config-generation --frappe-branch version-15 frappe-bench

WORKDIR /home/frappe/frappe-bench

RUN echo '[localhost]\nskip_name_resolve\ncharacter-set-server=utf8mb4\ncollation-server=utf8mb4_unicode_ci\ndefault-storage-engine=InnoDB\ninnodb_buffer_pool_size=256M\ninnodb_log_file_size=64M\nmax_connections=100\n' > /tmp/mariadb.cnf && \
    cp /tmp/mariadb.cnf /home/frappe/frappe-bench/sites/mariadb.cnf

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000

USER frappe

ENTRYPOINT ["/entrypoint.sh"]
