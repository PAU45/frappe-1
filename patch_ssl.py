import re
import os

# Patch 1: Fix connect() to use db_user instead of db_name as user
init_path = '/home/frappe/frappe-bench/apps/frappe/frappe/__init__.py'
with open(init_path, 'r') as f:
    content = f.read()

old_connect = 'user=local.conf.db_name or db_name,'
new_connect = 'user=os.environ.get("DB_USER") or local.conf.get("root_login") or local.conf.db_name or db_name,'

if old_connect in content and 'os.environ.get("DB_USER")' not in content:
    content = content.replace(old_connect, new_connect)
    with open(init_path, 'w') as f:
        f.write(content)
    print("Patched connect() in __init__.py")
else:
    print("connect() already patched or not found")

# Patch 2: Add sslmode to psycopg2 connection
db_path = '/home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/database.py'
with open(db_path, 'r') as f:
    lines = f.readlines()

new_lines = []
for i, line in enumerate(lines):
    new_lines.append(line)
    if 'conn = psycopg2.connect(**conn_settings)' in line:
        indent = line[:len(line) - len(line.lstrip())]
        new_lines.insert(-1, indent + 'conn_settings.setdefault("sslmode", "require")\n')

with open(db_path, 'w') as f:
    f.writelines(new_lines)
print("Patched psycopg2 SSL in database.py")
