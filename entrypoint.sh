#!/bin/bash
set -e

echo "=== Frappe/ERPNext Docker Entry Point ==="
echo "Starting services..."

# Wait for PostgreSQL
echo "Waiting for PostgreSQL..."
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER" 2>/dev/null; do
    sleep 2
done
echo "PostgreSQL is ready!"

# Wait for Redis
echo "Waiting for Redis..."
until redis-cli -h "${REDIS_CACHE#redis://}" ping 2>/dev/null | grep -q PONG; do
    sleep 2
done
echo "Redis is ready!"

BENCH_DIR="/home/frappe/frappe-bench"
SITE_NAME="${FRAPPE_SITE:-site1.localhost}"

cd "$BENCH_DIR"

# Configure database
export PGHOST="$DB_HOST"
export PGPORT="$DB_PORT"
export PGDATABASE="$DB_NAME"
export PGUSER="$DB_USER"
export PGPASSWORD="$DB_PASSWORD"

# Check if site exists
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating new Frappe site: $SITE_NAME"

    bench new-site "$SITE_NAME" \
        --db-type postgres \
        --db-host "$DB_HOST" \
        --db-port "$DB_PORT" \
        --db-name "$DB_NAME" \
        --db-user "$DB_USER" \
        --db-password "$DB_PASSWORD" \
        --admin-password "${ADMIN_PASSWORD:-admin}" \
        --no-mariadb-socket \
        --force

    bench use "$SITE_NAME"

    # Install ERPNext
    if [ -d "apps/erpnext" ]; then
        echo "Installing ERPNext..."
        bench --site "$SITE_NAME" execute erpnext.installer.setup_erpnext || true
    fi

    echo "Site setup complete!"
else
    echo "Site $SITE_NAME already exists, skipping setup."
    bench use "$SITE_NAME"
fi

# Run migrations
echo "Running migrations..."
bench --site "$SITE_NAME" migrate || true

# Clear cache
echo "Clearing cache..."
bench --site "$SITE_NAME" clear-cache || true

# Build assets
echo "Building assets..."
bench build --force || true

echo "=== Starting Frappe web server ==="

exec gunicorn \
    --bind 0.0.0.0:${PORT:-8000} \
    --workers "${GUNICORN_WORKERS:-4}" \
    --threads "${GUNICORN_THREADS:-4}" \
    --worker-class "${WORKERS_CLASS:-gthread}" \
    --timeout 300 \
    --preload \
    frappe.app.application:application
