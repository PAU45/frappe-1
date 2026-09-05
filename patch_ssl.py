import re

with open('/home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/database.py', 'r') as f:
    content = f.read()

old = '\t\t    conn = psycopg2.connect(**conn_settings)'
new = '\t\t    conn_settings.setdefault("sslmode", "require")\n\t\t    conn = psycopg2.connect(**conn_settings)'

if old not in content:
    old2 = 'conn = psycopg2.connect(**conn_settings)'
    lines = content.split('\n')
    for i, line in enumerate(lines):
        if old2 in line:
            indent = line[:len(line) - len(line.lstrip())]
            lines[i] = indent + 'conn_settings.setdefault("sslmode", "require")\n' + line
            break
    content = '\n'.join(lines)
else:
    content = content.replace(old, new)

with open('/home/frappe/frappe-bench/apps/frappe/frappe/database/postgres/database.py', 'w') as f:
    f.write(content)

print("SSL patched successfully")
