#!/bin/bash
set -e

echo "=== Frappe/ERPNext Docker - All-in-One ==="

SITE_NAME="paulo"
ADMIN_PASSWORD="2005"
BENCH_DIR="/home/frappe/frappe-bench"

# --- Start MariaDB ---
echo "Starting MariaDB..."
mysqld_safe --defaults-file="$BENCH_DIR/sites/mariadb.cnf" &
echo "Waiting for MariaDB..."
for i in $(seq 1 30); do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "MariaDB is ready!"
        break
    fi
    sleep 2
done

# --- Start Redis ---
echo "Starting Redis..."
redis-server --daemonize yes --port 6379 --dir /tmp
echo "Waiting for Redis..."
for i in $(seq 1 10); do
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        echo "Redis is ready!"
        break
    fi
    sleep 1
done

# --- Configure Frappe ---
cd "$BENCH_DIR"

echo "Creating common_site_config.json..."
cat > sites/common_site_config.json <<EOF
{
    "db_host": "localhost",
    "db_port": 3306,
    "db_name": "$SITE_NAME",
    "db_type": "mariadb",
    "redis_cache": "redis://localhost:6379/0",
    "redis_queue": "redis://localhost:6379/1",
    "redis_socketio": "redis://localhost:6379/2",
    "socketio_port": 9000
}
EOF

# --- Create MariaDB user and database ---
echo "Creating MariaDB database and user..."
mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`$SITE_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'root'@'localhost' IDENTIFIED BY '';
GRANT ALL PRIVILEGES ON \`$SITE_NAME\`.* TO 'root'@'localhost';
FLUSH PRIVILEGES;
SQL

# --- Create Frappe site ---
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating new Frappe site: $SITE_NAME"
    bench new-site "$SITE_NAME" \
        --mariadb-root-password "" \
        --admin-password "$ADMIN_PASSWORD" \
        --force

    bench use "$SITE_NAME"
    echo "Site created!"
else
    echo "Site $SITE_NAME already exists."
    bench use "$SITE_NAME"
fi

# --- Install apps if needed ---
echo "Installing ERPNEXT..."
bench --site "$SITE_NAME" install erpnext || true

# --- Migrations ---
echo "Running migrations..."
bench --site "$SITE_NAME" migrate || true

echo "Clearing cache..."
bench --site "$SITE_NAME" clear-cache || true

# --- Build assets ---
echo "Building assets (this may take a while)..."
bench build --force || true

# --- Fix permissions ---
chmod -R 755 sites/ 2>/dev/null || true

echo "=== Starting Frappe web server on port ${PORT:-8000} ==="

# Start Frappe web server
exec gunicorn \
    --bind 0.0.0.0:${PORT:-8000} \
    --workers "${GUNICORN_WORKERS:-2}" \
    --threads "${GUNICORN_THREADS:-4}" \
    --worker-class "${WORKERS_CLASS:-gthread}" \
    --timeout 300 \
    --preload \
    frappe.app.application:application
