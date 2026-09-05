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

RUN cd /home/frappe/frappe-bench/apps/frappe && \
    cat > /tmp/setup_db_patch.py << 'PYEOF'
import os
import frappe
from frappe.utils import cint

def setup_database():
    pass

def bootstrap_database(verbose, source_sql=None):
    frappe.connect()
    import_db_from_sql(source_sql, verbose)
    frappe.connect()

def import_db_from_sql(source_sql=None, verbose=False):
    if verbose:
        print("Starting database import...")
    db_name = frappe.conf.db_name
    if not source_sql:
        source_sql = os.path.join(os.path.dirname(__file__), "framework_postgres.sql")
    from frappe.database.db_manager import DbManager
    DbManager(frappe.local.db).restore_database(
        verbose, db_name, source_sql, db_name, frappe.conf.db_password
    )
    if verbose:
        print("Imported from database {}".format(source_sql))

def get_root_connection(root_login=None, root_password=None):
    if not frappe.local.flags.root_connection:
        frappe.local.flags.root_connection = frappe.database.get_db(
            socket=frappe.conf.db_socket,
            host=frappe.conf.db_host,
            port=frappe.conf.db_port,
            user=root_login or frappe.conf.get("root_login"),
            password=root_password or frappe.conf.get("root_password"),
            cur_db_name=frappe.conf.db_name,
        )
    return frappe.local.flags.root_connection

def drop_user_and_database(db_name, root_login, root_password):
    pass
PYEOF
    cp /tmp/setup_db_patch.py frappe/database/postgres/setup_db.py

WORKDIR /home/frappe/frappe-bench

USER root

COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 8000 9000

USER frappe

ENTRYPOINT ["/entrypoint.sh"]
