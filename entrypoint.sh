#!/bin/bash
set -e

echo "=== Frappe/ERPNext Starting ==="

echo "Waiting for MariaDB..."
for i in $(seq 1 30); do
    if mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" --silent 2>/dev/null; then
        echo "MariaDB ready!"
        break
    fi
    sleep 2
done

echo "Waiting for Redis..."
for i in $(seq 1 10); do
    if redis-cli -h redis-cache ping 2>/dev/null | grep -q PONG; then
        echo "Redis ready!"
        break
    fi
    sleep 1
done

cd /home/frappe
if [ ! -d "frappe-bench" ]; then
    ./init-bench.sh
fi

cd /home/frappe/frappe-bench

cat > sites/common_site_config.json <<EOF
{
    "db_host": "${DB_HOST:-mariadb}",
    "db_port": ${DB_PORT:-3306},
    "db_name": "${DB_NAME:-frappe}",
    "db_type": "mariadb",
    "redis_cache": "${REDIS_CACHE:-redis://redis-cache:6379/0}",
    "redis_queue": "${REDIS_QUEUE:-redis://redis-queue:6379/1}",
    "redis_socketio": "${REDIS_SOCKETIO:-redis://redis-socketio:6379/2}",
    "socketio_port": 9000
}
EOF

# FORCE site name to site1.localhost (ignore FRAPPE_SITE if it's a codespace URL)
SITE_NAME="site1.localhost"
CODESPACE_HOSTNAME=""

if [ -n "$CODESPACE_NAME" ] && [ -n "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN" ]; then
    CODESPACE_HOSTNAME="${CODESPACE_NAME}-8000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "Codespace detected: $CODESPACE_HOSTNAME"
fi

if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating site: $SITE_NAME"
    bench new-site "$SITE_NAME" --admin-password "${ADMIN_PASSWORD:-2005}" --mariadb-root-password "${DB_ROOT_PASSWORD:-root}" --force
    bench use "$SITE_NAME"
    bench --site "$SITE_NAME" install erpnext
else
    bench use "$SITE_NAME"
fi

# Add Codespace hostname as alias to the site
if [ -n "$CODESPACE_HOSTNAME" ]; then
    echo "Adding hostname alias: $CODESPACE_HOSTNAME"
    bench --site "$SITE_NAME" add-to-hosts "$CODESPACE_HOSTNAME" 2>&1 || true
    
    # Create logs dir for the hostname (Frappe expects it at sites/<hostname>/logs/)
    mkdir -p "sites/$CODESPACE_HOSTNAME/logs"
    # Also symlink so both paths work
    ln -sfn "$SITE_NAME" "sites/$CODESPACE_HOSTNAME" 2>/dev/null || true
fi

# Ensure logs dir exists for main site
mkdir -p "sites/$SITE_NAME/logs"

bench --site "$SITE_NAME" migrate
bench --site "$SITE_NAME" clear-cache
bench build --force

echo "=== Starting on port ${PORT:-8000} ==="
exec gunicorn --bind 0.0.0.0:${PORT:-8000} \
    --workers ${GUNICORN_WORKERS:-2} \
    --threads ${GUNICORN_THREADS:-4} \
    --worker-class ${WORKERS_CLASS:-gthread} \
    --timeout 300 \
    --preload frappe.app.application:application