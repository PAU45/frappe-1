FROM python:3.11-slim

LABEL maintainer="paulin"
LABEL description="Frappe/ERPNext - builds bench at runtime"

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    FRAPPE_SITE=site1.localhost \
    ADMIN_PASSWORD=2005 \
    WORKERS_CLASS=gthread \
    GUNICORN_WORKERS=2 \
    GUNICORN_THREADS=4 \
    DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl git wget pkg-config python3-dev python3-pip python3-venv \
    libffi-dev libjpeg-dev liblcms2-dev libldap2-dev libsasl2-dev \
    libssl-dev libtiff5-dev libwebp-dev mariadb-client redis-tools \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

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

COPY --chown=frappe:frappe init-bench.sh /home/frappe/init-bench.sh
RUN chmod +x /home/frappe/init-bench.sh

WORKDIR /home/frappe/frappe-bench

USER root
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000 9000
ENTRYPOINT ["/entrypoint.sh"]