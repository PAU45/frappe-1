#!/bin/bash
set -e

echo "=== Frappe/ERPNext Docker - All-in-One ==="

SITE_NAME="paulo"
ADMIN_PASSWORD="2005"
BENCH_DIR="/home/frappe/frappe-bench"

# --- Start MariaDB as mysql user ---
echo "Starting MariaDB..."
su - mysql -s /bin/bash -c "mariadbd --defaults-file=/etc/mysql/mariadb.conf.d/50-server.cnf &"
echo "Waiting for MariaDB..."
for i in $(seq 1 30); do
    if mysqladmin ping -h localhost --silent 2>/dev/null; then
        echo "MariaDB is ready!"
        break
    fi
    sleep 2
done

# --- Start Redis as frappe user ---
echo "Starting Redis..."
su - frappe -s /bin/bash -c "redis-server --daemonize yes --port 6379 --dir /tmp"
echo "Waiting for Redis..."
for i in $(seq 1 10); do
    if redis-cli ping 2>/dev/null | grep -q PONG; then
        echo "Redis is ready!"
        break
    fi
    sleep 1
done

# --- Create MariaDB database ---
echo "Creating MariaDB database..."
mysql -u root <<SQL
CREATE DATABASE IF NOT EXISTS \`$SITE_NAME\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
FLUSH PRIVILEGES;
SQL

# --- Configure Frappe as frappe user ---
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

# --- Create Frappe site as frappe user ---
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating new Frappe site: $SITE_NAME"
    su - frappe -s /bin/bash -c "cd $BENCH_DIR && bench new-site $SITE_NAME --mariadb-root-password '' --admin-password $ADMIN_PASSWORD --force"
    su - frappe -s /bin/bash -c "cd $BENCH_DIR && bench use $SITE_NAME"
    echo "Site created!"
else
    echo "Site $SITE_NAME already exists."
    su - frappe -s /bin/bash -c "cd $BENCH_DIR && bench use $SITE_NAME"
fi

# --- Install apps ---
echo "Installing ERPNEXT..."
su - frappe -s /bin/bash -c "cd $BENCH_DIR && bench --site $SITE_NAME install erpnext" || true

# --- Migrations ---
echo "Running migrations..."
su - frappe -s /bin/bash -c "cd $BENCH_DIR && bench --site $SITE_NAME migrate" || true

echo "Clearing cache..."
su - frappe -s /bin/bash -c "cd $BENCH_DIR && bench --site $SITE_NAME clear-cache" || true

# --- Build assets ---
echo "Building assets (this may take a while)..."
su - frappe -s /bin/bash -c "cd $BENCH_DIR && bench build --force" || true

echo "=== Starting Frappe web server on port ${PORT:-8000} ==="

# Start Frappe web server as frappe user
exec su - frappe -s /bin/bash -c "cd $BENCH_DIR && gunicorn --bind 0.0.0.0:${PORT:-8000} --workers ${GUNICORN_WORKERS:-2} --threads ${GUNICORN_THREADS:-4} --worker-class ${WORKERS_CLASS:-gthread} --timeout 300 --preload frappe.app.application:application"
