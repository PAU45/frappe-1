#!/bin/bash
set -e

echo "=== Frappe/ERPNext Docker Entry Point ==="
echo "Starting services..."

# Wait for MariaDB
echo "Waiting for MariaDB..."
until mysqladmin ping -h "$DB_HOST" --silent 2>/dev/null; do
    sleep 2
done
echo "MariaDB is ready!"

# Wait for Redis
echo "Waiting for Redis..."
until redis-cli -h redis-cache ping 2>/dev/null | grep -q PONG; do
    sleep 2
done
echo "Redis is ready!"

# Create or update bench environment
BENCH_DIR="/home/frappe/frappe-bench"
SITES_DIR="$BENCH_DIR/sites"
SITE_NAME="${FRAPPE_SITE:-site1.localhost}"

cd "$BENCH_DIR"

# Check if bench init is needed
if [ ! -d "$SITES_DIR/$SITE_NAME" ]; then
    echo "Setting up new Frappe site: $SITE_NAME"

    # Create site
    bench new-site "$SITE_NAME" \
        --mariadb-root-password "${DB_ROOT_PASSWORD:-root}" \
        --admin-password "${ADMIN_PASSWORD:-admin}" \
        --no-mariadb-socket \
        --force

    # Set site as default
    bench use "$SITE_NAME"

    # Install ERPNext if available
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

# Start the web server
exec gunicorn \
    --bind 0.0.0.0:8000 \
    --workers "${GUNICORN_WORKERS:-4}" \
    --threads "${GUNICORN_THREADS:-4}" \
    --worker-class "${WORKERS_CLASS:-gthread}" \
    --timeout 300 \
    --preload \
    frappe.app.application:application
