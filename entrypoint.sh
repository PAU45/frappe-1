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

SITE_NAME="${FRAPPE_SITE:-site1.localhost}"
if [ ! -d "sites/$SITE_NAME" ]; then
    echo "Creating site: $SITE_NAME"
    bench new-site "$SITE_NAME" --admin-password "${ADMIN_PASSWORD:-2005}" --mariadb-root-password "${DB_ROOT_PASSWORD:-root}" --force
    bench use "$SITE_NAME"
    bench --site "$SITE_NAME" install erpnext
else
    bench use "$SITE_NAME"
fi

# Handle Codespace hostname - add to site hosts so Frappe recognizes it
if [ -n "$CODESPACE_NAME" ] && [ -n "$GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN" ]; then
    CODESPACE_HOSTNAME="${CODESPACE_NAME}-8000.${GITHUB_CODESPACES_PORT_FORWARDING_DOMAIN}"
    echo "Codespace hostname: $CODESPACE_HOSTNAME"
    
    # Add hostname to site config
    bench --site "$SITE_NAME" add-to-hosts "$CODESPACE_HOSTNAME" 2>&1 || echo "add-to-hosts failed, continuing..."
    
    # Force create logs directory for this hostname (Frappe expects it here)
    mkdir -p "sites/$CODESPACE_HOSTNAME/logs"
    echo "Created logs dir: sites/$CODESPACE_HOSTNAME/logs"
fi

# Also handle generic hostname from HOSTNAME env
if [ -n "$HOSTNAME" ] && [ "$HOSTNAME" != "localhost" ]; then
    mkdir -p "sites/$HOSTNAME/logs"
fi

# Debug: show site config
echo "=== Site config for $SITE_NAME ==="
cat "sites/$SITE_NAME/site_config.json" 2>/dev/null || echo "No site_config.json"

# Debug: list sites dir
echo "=== Sites directory ==="
ls -la sites/

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