#!/bin/bash
set -e

if [ ! -d "/home/frappe/frappe-bench" ]; then
    cd /home/frappe
    bench init --skip-redis-config-generation --frappe-branch version-15 frappe-bench
    cd frappe-bench
    bench get-app --branch version-15 erpnext
fi