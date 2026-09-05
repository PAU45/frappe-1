import os

# Patch 1: Fix connect() to use correct user
init_path = '/home/frappe/frappe-bench/apps/frappe/frappe/__init__.py'
with open(init_path, 'r') as f:
    content = f.read()

old_connect = 'user=local.conf.db_name or db_name,'
new_connect = 'user=os.environ.get("DB_USER") or local.conf.get("root_login") or local.conf.db_name or db_name,'

if old_connect in content and 'os.environ.get("DB_USER")' not in content:
    content = content.replace(old_connect, new_connect)
    with open(init_path, 'w') as f:
        f.write(content)
    print("Patched connect()")
else:
    print("connect() already patched")

# Patch 2: Add sslmode=require to psycopg2 connection
db_path = '/home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/database.py'
with open(db_path, 'r') as f:
    lines = f.readlines()

found = False
new_lines = []
for line in lines:
    new_lines.append(line)
    if 'conn = psycopg2.connect(**conn_settings)' in line and 'sslmode' not in ''.join(new_lines):
        indent = line[:len(line) - len(line.lstrip())]
        new_lines.insert(len(new_lines) - 1, indent + 'conn_settings.setdefault("sslmode", "require")\n')
        found = True

if found:
    with open(db_path, 'w') as f:
        f.writelines(new_lines)
    print("Patched SSL in database.py")
else:
    print("SSL already patched in database.py")

# Patch 3: Add sslmode to psql connection strings
init_db_path = '/home/frappe/frappe-bench/apps/frappe/frappe/database/__init__.py'
with open(init_db_path, 'r') as f:
    content = f.read()

if '?sslmode=require' not in content:
    content = content.replace(
        'conn_string = f"postgresql://{user}:{password}@{host}:{port}/{db_name}"',
        'conn_string = f"postgresql://{user}:{password}@{host}:{port}/{db_name}?sslmode=require"'
    )
    content = content.replace(
        'conn_string = f"postgresql://{user}@{host}:{port}/{db_name}"',
        'conn_string = f"postgresql://{user}@{host}:{port}/{db_name}?sslmode=require"'
    )
    with open(init_db_path, 'w') as f:
        f.write(content)
    print("Patched psql strings")
else:
    print("psql strings already patched")

# Verify patches
print("\n=== Verification ===")
with open(db_path, 'r') as f:
    for i, line in enumerate(f.readlines(), 1):
        if 'sslmode' in line:
            print(f"database.py line {i}: {line.rstrip()}")

with open(init_path, 'r') as f:
    for i, line in enumerate(f.readlines(), 1):
        if 'DB_USER' in line:
            print(f"__init__.py line {i}: {line.rstrip()}")
