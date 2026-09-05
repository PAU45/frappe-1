#!/bin/bash
set -ex

echo "=== Frappe/ERPNext Docker Entry Point ==="

DB_HOST="dpg-dadlkh67bikc73b97o00-a.virginia-postgres.render.com"
DB_PORT="5432"
DB_NAME="frappe_db_xks5"
DB_USER="frappe_db_xks5_user"
DB_PASSWORD="M7QS0C3X3QoNu0iaMlcGs9dUmvcnO3ns"
REDIS_HOST="red-dadll7e7bikc73b9aac0"
ADMIN_PASSWORD="2005"
SITE_NAME="paulo"

export PGHOST="$DB_HOST"
export PGPORT="$DB_PORT"
export PGDATABASE="$DB_NAME"
export PGUSER="$DB_USER"
export PGPASSWORD="$DB_PASSWORD"
export PGSSLMODE=require

echo "Waiting for PostgreSQL on $DB_HOST:$DB_PORT..."
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" 2>/dev/null; do
    sleep 3
done
echo "PostgreSQL is ready!"

echo "Waiting for Redis on $REDIS_HOST..."
until redis-cli -h "$REDIS_HOST" ping 2>/dev/null | grep -q PONG; do
    sleep 3
done
echo "Redis is ready!"

BENCH_DIR="/home/frappe/frappe-bench"
cd "$BENCH_DIR"

cat > sites/common_site_config.json <<EOF
{
    "db_host": "$DB_HOST",
    "db_port": $DB_PORT,
    "db_name": "$DB_NAME",
    "db_user": "$DB_USER",
    "db_password": "$DB_PASSWORD",
    "db_type": "postgres",
    "db_socket": "",
    "redis_cache": "redis://$REDIS_HOST:6379/0",
    "redis_queue": "redis://$REDIS_HOST:6379/1",
    "redis_socketio": "redis://$REDIS_HOST:6379/2",
    "root_login": "$DB_USER",
    "root_password": "$DB_PASSWORD"
}
EOF

if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating new Frappe site: $SITE_NAME"
    bench new-site "$SITE_NAME" \
        --db-type postgres \
        --db-host "$DB_HOST" \
        --db-port "$DB_PORT" \
        --db-name "$DB_NAME" \
        --db-root-username "$DB_USER" \
        --db-root-password "$DB_PASSWORD" \
        --admin-password "$ADMIN_PASSWORD" \
        --force

    bench use "$SITE_NAME"
    echo "Site setup complete!"
else
    echo "Site $SITE_NAME already exists, skipping setup."
    bench use "$SITE_NAME"
fi

echo "Running migrations..."
bench --site "$SITE_NAME" migrate || true

echo "Clearing cache..."
bench --site "$SITE_NAME" clear-cache || true

echo "Building assets..."
bench build --force || true

echo "=== Starting Frappe web server on port ${PORT:-8000} ==="

exec gunicorn \
    --bind 0.0.0.0:${PORT:-8000} \
    --workers "${GUNICORN_WORKERS:-4}" \
    --threads "${GUNICORN_THREADS:-4}" \
    --worker-class "${WORKERS_CLASS:-gthread}" \
    --timeout 300 \
    --preload \
    frappe.app.application:application
