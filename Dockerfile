FROM frappe/erpnext:v15

LABEL maintainer="paulin"
LABEL description="Frappe/ERPNext for Render deployment"

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
    GUNICORN_THREADS=4 \
    WKHTMLTOPDF_VERSION=0.12.6

USER root

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl \
    git \
    wkhtmltopdf \
    xvfb \
    libffi-dev \
    libjpeg-dev \
    liblcms2-dev \
    libldap2-dev \
    libsasl2-dev \
    libssl-dev \
    libtiff5-dev \
    libwebp-dev \
    redis-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /home/frappe/frappe-bench

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000 9000

ENTRYPOINT ["/entrypoint.sh"]
